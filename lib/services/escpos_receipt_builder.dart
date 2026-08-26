import 'dart:io';

import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../models/receipt_design_config.dart';
import '../utils/escpos_text_codec.dart';
import '../utils/receipt_strikethrough_text.dart';
import '../utils/thermal_receipt_compact_text.dart';
import '../utils/thermal_receipt_large_text.dart';
import '../utils/thermal_receipt_total_text.dart';
import '../utils/thermal_receipt_line_wrap.dart';
import '../utils/thermal_receipt_logo_fit.dart';
import '../utils/thermal_receipt_note_text.dart';
import '../utils/thermal_receipt_product_title_text.dart';
import 'printer_paper_profile.dart';

/// API dan parse qilingan matn qatorlarini ESC/POS ga aylantirish.
class EscPosReceiptBuilder {
  EscPosReceiptBuilder._();

  static CapabilityProfile? _cachedProfile;
  static String? _cachedLogoKey;
  static img.Image? _cachedLogoImage;

  static Future<CapabilityProfile> _profile() async {
    return _cachedProfile ??= await CapabilityProfile.load();
  }

  /// Birinchi chekdan oldin profilni yuklash (sotuv/to‘lovdan keyin tezroq chop).
  static Future<void> warmup() async {
    await _profile();
  }

  /// Faqat naqd qutisini ochish (chekdan alohida — ikki printerda ishonchli ishlaydi).
  static Future<List<int>> buildCashDrawerPulse({
    PosDrawer cashDrawerPin = PosDrawer.pin2,
    PaperSize paperSize = PaperSize.mm80,
  }) async {
    final profile = await _profile();
    final g = Generator(paperSize, profile, spaceBetweenRows: 0);
    return <int>[...g.reset(), ...g.drawer(pin: cashDrawerPin)];
  }

  static Future<List<int>> buildFromLines(
    List<String> lines, {
    PaperSize paperSize = PaperSize.mm80,
    ReceiptDesignConfig? design,
  }) =>
      buildReceipt(lines: lines, design: design, paperSize: paperSize);

  static Future<List<int>> buildReceipt({
    required List<String> lines,
    ReceiptDesignConfig? design,
    PaperSize paperSize = PaperSize.mm80,
    bool openCashDrawer = false,
    PosDrawer cashDrawerPin = PosDrawer.pin2,
    String? printerName,
  }) async {
    final profile = await _profile();
    final g = Generator(paperSize, profile, spaceBetweenRows: 0);
    final bytes = <int>[];

    final maxWidth =
        paperSize == PaperSize.mm58 ? kThermalChars58mm : kThermalChars80mm;
    final wrapped = ThermalReceiptLineWrap.wrapAll(lines, maxWidth: maxWidth);
    final cfg = design ?? ReceiptDesignConfig.defaults;
    final codeTable = _codeTableId(cfg.printerCodePage);
    final codePage = cfg.printerCodePage;

    bytes.addAll(List<int>.from(g.reset()));
    bytes.addAll(List<int>.from(g.setGlobalCodeTable(codeTable)));
    bytes.addAll(PrinterPaperProfile.fullWidthMarginBytes());
    final cutFeed = PrinterPaperProfile.feedBeforeCut(printerName);

    if (openCashDrawer) {
      bytes.addAll(g.drawer(pin: cashDrawerPin));
    }

    if (cfg.showLogo &&
        cfg.logoFilePath != null &&
        cfg.logoFilePath!.isNotEmpty) {
      final mm58 = paperSize == PaperSize.mm58;
      final logoImage = await _loadLogoImage(cfg.logoFilePath!, mm58: mm58);
      if (logoImage != null) {
        bytes.addAll(_encodeLogo(g, logoImage));
      } else {
        debugPrint('[ChekLogo] rasm o‘qilmadi: ${cfg.logoFilePath}');
      }
    } else {
      debugPrint(
        '[ChekLogo] o‘tkazib yuborildi show=${cfg.showLogo} path=${cfg.logoFilePath}',
      );
    }

    var contentStarted = false;
    for (final line in wrapped) {
      final isBlank =
          line.isEmpty || ThermalReceiptProductTitleText.isGapLine(line);
      if (isBlank) {
        if (!contentStarted) continue;
        bytes.addAll(List<int>.from(g.feed(1)));
        continue;
      }
      contentStarted = true;

      if (ThermalReceiptNoteText.isNoteLine(line)) {
        final text = ThermalReceiptNoteText.unwrap(line);
        bytes.addAll(
          g.textEncoded(
            EscPosTextCodec.encodeSync(text, codePage: codePage),
            styles: PosStyles(
              codeTable: codeTable,
              fontType: PosFontType.fontA,
              align: PosAlign.left,
              bold: true,
            ),
            maxCharsPerLine: maxWidth,
          ),
        );
        continue;
      }

      if (ThermalReceiptProductTitleText.isTitleLine(line)) {
        final text = ThermalReceiptProductTitleText.unwrap(line);
        bytes.addAll(
          g.textEncoded(
            EscPosTextCodec.encodeSync(text, codePage: codePage),
            styles: PosStyles(
              codeTable: codeTable,
              fontType: PosFontType.fontA,
              align: PosAlign.left,
              bold: true,
            ),
            maxCharsPerLine: maxWidth,
          ),
        );
        continue;
      }

      if (ThermalReceiptCompactText.isAnyCompactLine(line)) {
        final text = ThermalReceiptCompactText.unwrap(line);
        final bold = ThermalReceiptCompactText.isCompactBoldLine(line);
        final compactMax = paperSize == PaperSize.mm58
            ? ThermalReceiptCompactText.chars58mm
            : ThermalReceiptCompactText.chars80mm;
        if (ReceiptStrikethroughText.containsMarker(text)) {
          bytes.addAll(
            _printMarkedLine(
              g,
              text,
              codeTable: codeTable,
              codePage: codePage,
              maxWidth: compactMax,
              fontType: PosFontType.fontB,
              bold: bold,
            ),
          );
        } else {
          bytes.addAll(
            g.textEncoded(
              EscPosTextCodec.encodeSync(text, codePage: codePage),
              styles: PosStyles(
                codeTable: codeTable,
                fontType: PosFontType.fontB,
                align: PosAlign.left,
                bold: bold,
              ),
              maxCharsPerLine: compactMax,
            ),
          );
        }
        continue;
      }

      if (ThermalReceiptTotalText.isTotalLine(line)) {
        bytes.addAll(
          _printTotalBlock(
            g,
            ThermalReceiptTotalText.parse(line),
            codeTable: codeTable,
            codePage: codePage,
            maxWidth: maxWidth,
          ),
        );
        continue;
      }

      if (ThermalReceiptLargeText.isLargeLine(line)) {
        final text = ThermalReceiptLargeText.unwrap(line);
        final compactPaper = paperSize == PaperSize.mm58;
        final queueSize = _queueTextSize(
          compactPaper
              ? ThermalReceiptLargeText.printerSize58mm
              : ThermalReceiptLargeText.printerSize80mm,
        );
        bytes.addAll(
          g.textEncoded(
            EscPosTextCodec.encodeSync(text, codePage: codePage),
            styles: PosStyles(
              codeTable: codeTable,
              fontType: PosFontType.fontA,
              align: PosAlign.center,
              bold: true,
              height: queueSize,
              width: queueSize,
            ),
            maxCharsPerLine: compactPaper ? 16 : 24,
          ),
        );
        continue;
      }

      final centered = line.startsWith('^');
      final text = centered ? line.substring(1) : line;
      if (centered) {
        bytes.addAll(
          g.textEncoded(
            EscPosTextCodec.encodeSync(text, codePage: codePage),
            styles: PosStyles(
              codeTable: codeTable,
              fontType: PosFontType.fontA,
              align: PosAlign.center,
              bold: _isDateTimeLine(text),
            ),
            maxCharsPerLine: maxWidth,
          ),
        );
      } else {
        final plainTotal = ThermalReceiptTotalText.tryParsePlain(text);
        if (plainTotal != null) {
          bytes.addAll(
            _printTotalBlock(
              g,
              plainTotal,
              codeTable: codeTable,
              codePage: codePage,
              maxWidth: maxWidth,
            ),
          );
        } else if (ReceiptStrikethroughText.containsMarker(text)) {
          bytes.addAll(
            _printMarkedLine(
              g,
              text,
              codeTable: codeTable,
              codePage: codePage,
              maxWidth: maxWidth,
            ),
          );
        } else {
          bytes.addAll(
            g.textEncoded(
              EscPosTextCodec.encodeSync(text, codePage: codePage),
              styles: PosStyles(
                codeTable: codeTable,
                fontType: PosFontType.fontA,
              ),
              maxCharsPerLine: maxWidth,
            ),
          );
        }
      }
    }

    bytes.addAll(
      PrinterPaperProfile.minimalCutBytes(feedLines: cutFeed),
    );
    return bytes;
  }

  /// Font A, qalin, balandligi 2× — qator oralig‘i kengaytirilgan (yig‘ilib ketmasin).
  static List<int> _printTotalBlock(
    Generator g,
    ({String label, String value}) total, {
    required String codeTable,
    required String codePage,
    required int maxWidth,
  }) {
    final label = total.label.trim();
    final value = total.value.trim();
    final text = [
      if (label.isNotEmpty) label,
      if (value.isNotEmpty) value,
    ].join(' - ');
    if (text.isEmpty) return const [];
    // 2× balandlik ~48–64 nuqta: ESC 3 72 — harflar siqilib ketmasin.
    return <int>[
      27,
      51,
      72,
      ...g.textEncoded(
        EscPosTextCodec.encodeSync(text, codePage: codePage),
        styles: PosStyles(
          codeTable: codeTable,
          fontType: PosFontType.fontA,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size1,
        ),
        maxCharsPerLine: maxWidth,
      ),
      ...PrinterPaperProfile.restoreCompactSpacingBytes(),
    ];
  }

  /// Chegirmali narx: matn ustidan `-` bilan chizish (underline emas).
  static List<int> _printMarkedLine(
    Generator g,
    String text, {
    required String codeTable,
    required String codePage,
    required int maxWidth,
    bool bold = false,
    PosFontType fontType = PosFontType.fontA,
    PosTextSize height = PosTextSize.size1,
    PosTextSize width = PosTextSize.size1,
  }) {
    final segments = ReceiptStrikethroughText.parseSegments(text);
    if (segments.isEmpty) return const [];
    final bytes = <int>[];
    final dotsPerChar = fontType == PosFontType.fontB ? 9 : 12;

    for (var i = 0; i < segments.length; i++) {
      final seg = segments[i];
      final isLast = i == segments.length - 1;
      final enc = EscPosTextCodec.encodeSync(seg.text, codePage: codePage);
      bytes.addAll(
        g.textEncoded(
          enc,
          styles: PosStyles(
            codeTable: codeTable,
            fontType: fontType,
            bold: bold,
            height: height,
            width: width,
          ),
          linesAfter: -1,
          maxCharsPerLine: null,
        ),
      );

      if (seg.strike && seg.text.isNotEmpty) {
        // Kursorni chapga qaytarib, xuddi shu joyga chiziq chizamiz.
        bytes.addAll(_relativeMoveDots(-(seg.text.length * dotsPerChar)));
        final strike = '-' * seg.text.length;
        bytes.addAll(
          g.textEncoded(
            EscPosTextCodec.encodeSync(strike, codePage: codePage),
            styles: PosStyles(
              codeTable: codeTable,
              fontType: fontType,
              bold: bold,
              height: height,
              width: width,
            ),
            linesAfter: -1,
            maxCharsPerLine: null,
          ),
        );
      }

      if (isLast) {
        bytes.addAll(g.emptyLines(1));
      }
    }
    return bytes;
  }

  /// ESC \ nL nH — gorizontal siljish (nuqta), manfiy = chapga.
  static List<int> _relativeMoveDots(int dots) {
    final n = dots & 0xFFFF;
    return [27, 92, n & 0xFF, (n >> 8) & 0xFF];
  }

  static PosTextSize _queueTextSize(int level) {
    switch (level.clamp(1, 8)) {
      case 1:
        return PosTextSize.size1;
      case 2:
        return PosTextSize.size2;
      case 3:
        return PosTextSize.size3;
      case 4:
        return PosTextSize.size4;
      case 5:
        return PosTextSize.size5;
      case 6:
        return PosTextSize.size6;
      case 7:
        return PosTextSize.size7;
      case 8:
        return PosTextSize.size8;
      default:
        return PosTextSize.size4;
    }
  }

  static String _codeTableId(String page) {
    final p = page.toUpperCase();
    if (p.contains('1251')) return 'CP1251';
    return 'CP866';
  }

  /// GS v 0 raster: qora-oq logo, invert/ESC* xirasiz. Kutubxona `imageRaster` emas.
  static List<int> _encodeLogo(Generator _, img.Image logo) {
    try {
      final raster = ThermalReceiptLogoFit.rasterGsV0(logo);
      if (raster.isEmpty) return const [];
      final out = <int>[
        ...raster,
        ...PrinterPaperProfile.restoreCompactSpacingBytes(),
      ];
      debugPrint(
        '[ChekLogo] GSv0 ${logo.width}x${logo.height} bytes=${out.length}',
      );
      return out;
    } catch (e) {
      debugPrint('[ChekLogo] GSv0 o‘tkazib yuborildi: $e');
      return const [];
    }
  }

  static bool _isDateTimeLine(String text) =>
      RegExp(r'^\d{4}-\d{2}-\d{2}\s*\|').hasMatch(text.trim());

  static Future<img.Image?> _loadLogoImage(String path,
      {required bool mm58}) async {
    final key = '$path|${mm58 ? 58 : 80}';
    if (_cachedLogoKey == key && _cachedLogoImage != null) {
      return _cachedLogoImage;
    }
    try {
      final f = File(path);
      if (!await f.exists()) {
        debugPrint('[ChekLogo] fayl yo‘q: $path');
        return null;
      }
      final decoded = img.decodeImage(await f.readAsBytes());
      if (decoded == null) {
        debugPrint('[ChekLogo] decode bo‘lmadi: $path');
        return null;
      }
      final fitted = ThermalReceiptLogoFit.fit(decoded, mm58: mm58);
      debugPrint(
        '[ChekLogo] decode ${decoded.width}x${decoded.height} → ${fitted.width}x${fitted.height}',
      );
      _cachedLogoKey = key;
      _cachedLogoImage = fitted;
      return fitted;
    } catch (e) {
      debugPrint('[ChekLogo] load xato: $e');
    }
    return null;
  }

  static void invalidateLogoCache() {
    _cachedLogoKey = null;
    _cachedLogoImage = null;
  }
}
