import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import '../models/receipt_design_config.dart';
import '../services/receipt_design_storage.dart';
import '../services/receipt_font_settings.dart';
import '../utils/thermal_receipt_capture.dart';
import '../widgets/receipt_lines_preview.dart';

/// Chekni tanlangan shrift bilan rasmga chizib, termal printerga yuborish.
class ThermalReceiptImageBuilder {
  ThermalReceiptImageBuilder._();

  static CapabilityProfile? _cachedProfile;

  static Future<void> warmup() async {
    await Future.wait([
      _profile(),
      ReceiptFontSettings.preload(),
    ]);
  }

  static Future<CapabilityProfile> _profile() async {
    return _cachedProfile ??= await CapabilityProfile.load();
  }

  static Future<List<int>> buildReceipt({
    required List<String> lines,
    ReceiptDesignConfig? design,
    PaperSize paperSize = PaperSize.mm80,
    bool openCashDrawer = false,
    PosDrawer cashDrawerPin = PosDrawer.pin2,
  }) async {
    if (lines.isEmpty) {
      throw StateError('Chek matni bo\'sh');
    }

    final cfg = design ?? await ReceiptDesignStorage.reload();
    final font = await ReceiptFontSettings.getSelectedFont();
    await ReceiptFontSettings.ensureFontLoaded(font);
    final png = await captureReceiptForThermal(
      ThermalReceiptPreview(
        lines: lines,
        design: cfg,
        forPrint: true,
        fontOverride: font,
      ),
    );

    final decoded = img.decodeImage(png);
    if (decoded == null) {
      throw StateError('Chek rasmini o\'qib bo\'lmadi');
    }

    final profile = await _profile();
    final g = Generator(paperSize, profile);
    final bytes = <int>[];

    bytes.addAll(g.reset());
    if (openCashDrawer) {
      bytes.addAll(g.drawer(pin: cashDrawerPin));
    }

    final maxW = paperSize == PaperSize.mm58 ? 384 : 576;
    final raster = decoded.width > maxW
        ? img.copyResize(decoded, width: maxW, interpolation: img.Interpolation.linear)
        : decoded;

    bytes.addAll(g.image(raster, align: PosAlign.center));
    bytes.addAll(g.feed(2));
    bytes.addAll(g.cut());
    return bytes;
  }
}
