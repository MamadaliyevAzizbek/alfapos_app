import 'dart:typed_data';

import '../models/receipt_design_config.dart';
import '../services/receipt_design_storage.dart';
import '../utils/thermal_receipt_capture.dart';
import '../utils/thermal_receipt_layout_metrics.dart';
import '../widgets/receipt_lines_preview.dart';

/// Mobil → kompyuter relay uchun chekni PNG ga aylantirish (TSPL printerlar).
class NetworkReceiptPngRenderer {
  NetworkReceiptPngRenderer._();

  static Future<Uint8List> render(
    List<String> lines, {
    ReceiptDesignConfig? design,
  }) async {
    final resolved = design ?? await ReceiptDesignStorage.prepareForPrint(null);
    final showLogo = resolved.showLogo &&
        resolved.logoFilePath != null &&
        resolved.logoFilePath!.trim().isNotEmpty;
    final height = ThermalReceiptLayoutMetrics.estimateHeight(
      lines: lines,
      showLogo: showLogo,
    );
    return captureReceiptWidget(
      ThermalReceiptPreview(lines: lines, design: resolved),
      targetHeight: height + 40,
      targetWidth: 360,
      lineCount: lines.length,
    );
  }
}
