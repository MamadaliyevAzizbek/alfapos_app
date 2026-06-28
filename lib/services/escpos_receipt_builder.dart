import 'dart:io';

import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:image/image.dart' as img;

import '../models/receipt_design_config.dart';
import '../utils/escpos_text_codec.dart';
import '../utils/receipt_strikethrough_text.dart';
import '../utils/thermal_receipt_compact_text.dart';
import '../utils/thermal_receipt_large_text.dart';
import '../utils/thermal_receipt_formatter.dart';
import '../utils/thermal_receipt_line_wrap.dart';
import 'printer_paper_profile.dart';

/// API dan parse qilingan matn qatorlarini ESC/POS ga aylantirish.
class EscPosReceiptBuilder {
  EscPosReceiptBuilder._();

  static CapabilityProfile? _cachedProfile;
  static String? _cachedLogoPath;
  static img.Image? _cachedLogoImage;

  static Future<CapabilityProfile> _profile() async {
    return _cachedProfile ??= await CapabilityProfile.load();
  }

  /// Birinchi chekdan oldin profilni yuklash (sotuv/to‘lovdan keyin tezroq chop).
  static Future<void> warmup() async {
    await _profile();
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
    bool compactRestaurant = false,
    String? printerName,
  }) async {
    final profile = await _profile();
    final compactLayout = compactRestaurant ||
        PrinterPaperProfile.needsCompactLayout(printerName);
    final rowGap = compactLayout ? 0 : 6;
    final g = Generator(paperSize, profile, spaceBetweenRows: rowGap);
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
    if (compactLayout) {
      bytes.addAll(PrinterPaperProfile.fullWidthMarginBytes());
    }

    if (openCashDrawer) {
      bytes.addAll(g.drawer(pin: cashDrawerPin));
    }

    if (cfg.showLogo &&
        cfg.logoFilePath != null &&
        cfg.logoFilePath!.isNotEmpty) {
      final logoMaxW = paperSize == PaperSize.mm58 ? 320 : paperSize.width;
      final logoImage = await _loadLogoImage(cfg.logoFilePath!, maxW: logoMaxW);
      if (logoImage != null) {
        bytes.addAll(g.image(logoImage, align: PosAlign.center));
        if (!compactLayout) {
          bytes.addAll(g.feed(1));
        }
      }
    }

    for (final line in wrapped) {
      if (line.isEmpty) {
        if (!compactLayout) {
          bytes.addAll(g.feed(1));
        }
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

      if (ThermalReceiptLargeText.isLargeLine(line)) {
        final text = ThermalReceiptLargeText.unwrap(line);
        final compactPaper = paperSize == PaperSize.mm58;
        final queueSize = _queueTextSize(
          compactRestaurant
              ? (compactPaper
                  ? ThermalReceiptLargeText.restaurantPrinterSize58mm
                  : ThermalReceiptLargeText.restaurantPrinterSize80mm)
              : (compactPaper
                  ? ThermalReceiptLargeText.printerSize58mm
                  : ThermalReceiptLargeText.printerSize80mm),
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
        final lower = text.toLowerCase();
        final isTotal = !compactRestaurant &&
            (lower.contains('umumiy summa') ||
                lower.contains('jami') ||
                lower.contains('итого'));
        if (ReceiptStrikethroughText.containsMarker(text)) {
          bytes.addAll(
            _printMarkedLine(
              g,
              text,
              codeTable: codeTable,
              codePage: codePage,
              maxWidth: maxWidth,
              bold: isTotal,
            ),
          );
        } else {
          bytes.addAll(
            g.textEncoded(
              EscPosTextCodec.encodeSync(text, codePage: codePage),
              styles: PosStyles(
                codeTable: codeTable,
                fontType: PosFontType.fontA,
                bold: isTotal,
                height: isTotal ? PosTextSize.size2 : PosTextSize.size1,
                width: isTotal ? PosTextSize.size1 : PosTextSize.size1,
              ),
              maxCharsPerLine: maxWidth,
            ),
          );
        }
      }
    }

    if (compactLayout) {
      bytes.addAll(PrinterPaperProfile.minimalCutBytes());
    } else {
      bytes.addAll(g.feed(2));
      bytes.addAll(g.cut());
    }
    return bytes;
  }

  static List<int> _printMarkedLine(
    Generator g,
    String text, {
    required String codeTable,
    required String codePage,
    required int maxWidth,
    bool bold = false,
    PosFontType fontType = PosFontType.fontA,
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

  static Future<img.Image?> _loadLogoImage(String path, {required int maxW}) async {
    if (_cachedLogoPath == path && _cachedLogoImage != null) {
      final decoded = _cachedLogoImage!;
      return decoded.width > maxW ? img.copyResize(decoded, width: maxW) : decoded;
    }
    try {
      final f = File(path);
      if (!await f.exists()) return null;
      final decoded = img.decodeImage(await f.readAsBytes());
      if (decoded == null) return null;
      _cachedLogoPath = path;
      _cachedLogoImage = decoded;
      return decoded.width > maxW ? img.copyResize(decoded, width: maxW) : decoded;
    } catch (_) {}
    return null;
  }

  static void invalidateLogoCache() {
    _cachedLogoPath = null;
    _cachedLogoImage = null;
  }
}
