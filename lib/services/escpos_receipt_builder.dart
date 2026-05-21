import 'dart:io';
import 'dart:typed_data';

import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:image/image.dart' as img;

import '../models/receipt_design_config.dart';
import '../utils/escpos_text_codec.dart';
import '../utils/thermal_receipt_line_wrap.dart';

/// API dan parse qilingan matn qatorlarini ESC/POS ga aylantirish.
class EscPosReceiptBuilder {
  EscPosReceiptBuilder._();

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
  }) async {
    final profile = await CapabilityProfile.load();
    final g = Generator(paperSize, profile);
    final bytes = <int>[];

    final maxWidth = paperSize == PaperSize.mm58
        ? kThermalChars58mm
        : kThermalChars80mm;
    final wrapped = ThermalReceiptLineWrap.wrapAll(lines, maxWidth: maxWidth);
    final cfg = design ?? ReceiptDesignConfig.defaults;

    bytes.addAll(g.reset());
    final codeTable = _codeTableId(cfg.printerCodePage);
    bytes.addAll(g.setGlobalCodeTable(codeTable));
    if (cfg.showLogo && cfg.logoFilePath != null && cfg.logoFilePath!.isNotEmpty) {
      final logoBytes = await _loadLogoBytes(cfg.logoFilePath!);
      if (logoBytes != null) {
        final decoded = img.decodeImage(logoBytes);
        if (decoded != null) {
          final maxW = paperSize == PaperSize.mm58 ? 320 : 480;
          final resized = decoded.width > maxW
              ? img.copyResize(decoded, width: maxW)
              : decoded;
          bytes.addAll(g.image(resized, align: PosAlign.center));
          bytes.addAll(g.feed(1));
        }
      }
    }

    for (final line in wrapped) {
      if (line.isEmpty) {
        bytes.addAll(g.feed(1));
        continue;
      }
      final centered = line.startsWith('^');
      final text = centered ? line.substring(1) : line;
      final enc = await EscPosTextCodec.encode(text, codePage: cfg.printerCodePage);
      if (centered) {
        bytes.addAll(
          g.textEncoded(
            enc,
            styles: PosStyles(
              codeTable: codeTable,
              fontType: PosFontType.fontA,
              align: PosAlign.center,
            ),
            maxCharsPerLine: maxWidth,
          ),
        );
      } else {
        final isTotal = text.toLowerCase().contains('umumiy summa') ||
            text.toLowerCase().contains('jami');
        bytes.addAll(
          g.textEncoded(
            enc,
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

    bytes.addAll(g.feed(2));
    bytes.addAll(g.cut());
    return bytes;
  }

  static String _codeTableId(String page) {
    final p = page.toUpperCase();
    if (p.contains('1251')) return 'CP1251';
    return 'CP866';
  }

  static Future<Uint8List?> _loadLogoBytes(String path) async {
    try {
      final f = File(path);
      if (await f.exists()) return await f.readAsBytes();
    } catch (_) {}
    return null;
  }
}
