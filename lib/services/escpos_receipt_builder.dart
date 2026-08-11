import 'dart:io';

import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:image/image.dart' as img;

import '../models/receipt_design_config.dart';
import '../utils/escpos_text_codec.dart';
import '../utils/receipt_strikethrough_text.dart';
import '../utils/thermal_receipt_compact_text.dart';
import '../utils/thermal_receipt_large_text.dart';
import '../utils/thermal_receipt_total_text.dart';
import '../utils/thermal_receipt_formatter.dart';
import '../utils/thermal_receipt_line_wrap.dart';
import '../utils/thermal_receipt_logo_fit.dart';
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

    final maxWidth = paperSize == PaperSize.mm58
        ? kThermalChars58mm
        : kThermalChars80mm;
    final wrapped = ThermalReceiptLineWrap.wrapAll(lines, maxWidth: maxWidth);
    final cfg = design ?? ReceiptDesignConfig.defaults;
    final codeTable = _codeTableId(cfg.printerCodePage);
    final codePage = cfg.printerCodePage;

    bytes.addAll(g.reset());
    bytes.addAll(g.setGlobalCodeTable(codeTable));
    bytes.addAll(PrinterPaperProfile.fullWidthMarginBytes());
    final xp80 = PrinterPaperProfile.isXprinter80(printerName);
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
        // XP-80C: GS v 0 — qator oralig‘ini buzmaydi. Boshqa: ESC * + keyin ESC 3 24.
        if (xp80) {
          bytes.addAll(g.imageRaster(logoImage, align: PosAlign.center));
        } else {
          bytes.addAll(g.image(logoImage, align: PosAlign.center));
        }
        bytes.addAll(PrinterPaperProfile.restoreCompactSpacingBytes());
      }
    }

    for (final line in wrapped) {
      if (line.isEmpty) {
        continue;
      }
      if (ThermalReceiptProductTitleText.isGapLine(line)) {
        bytes.addAll(g.feed(1));
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

  /// Font A, qalin, balandligi 2× — bir qatorda qoladi, to‘lov qatoridan ajraladi.
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
    // 2× balandlik ~48 nuqta: ESC 3 32 yetmaydi — keyingi qator ustiga chiqadi.
    return <int>[
      27, 51, 56,
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
    final bytes = <int>[];
    for (final seg in ReceiptStrikethroughText.parseSegments(text)) {
      final enc = EscPosTextCodec.encodeSync(seg.text, codePage: codePage);
      bytes.addAll(
        g.textEncoded(
          enc,
          styles: PosStyles(
            codeTable: codeTable,
            fontType: fontType,
            bold: bold,
            underline: seg.strike,
            height: height,
            width: width,
          ),
          maxCharsPerLine: maxWidth,
        ),
      );
    }
    return bytes;
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

  static Future<img.Image?> _loadLogoImage(String path, {required bool mm58}) async {
    final key = '$path|${mm58 ? 58 : 80}';
    if (_cachedLogoKey == key && _cachedLogoImage != null) {
      return _cachedLogoImage;
    }
    try {
      final f = File(path);
      if (!await f.exists()) return null;
      final decoded = img.decodeImage(await f.readAsBytes());
      if (decoded == null) return null;
      final fitted = ThermalReceiptLogoFit.fit(decoded, mm58: mm58);
      _cachedLogoKey = key;
      _cachedLogoImage = fitted;
      return fitted;
    } catch (_) {}
    return null;
  }

  static void invalidateLogoCache() {
    _cachedLogoKey = null;
    _cachedLogoImage = null;
  }
}
