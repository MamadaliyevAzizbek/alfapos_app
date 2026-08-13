import 'thermal_receipt_compact_text.dart';
import 'thermal_receipt_large_text.dart';
import 'thermal_receipt_logo_fit.dart';
import 'thermal_receipt_total_text.dart';

/// Chek skrinshoti va chop etish uchun o‘lcham hisob-kitobi.
abstract class ThermalReceiptLayoutMetrics {
  ThermalReceiptLayoutMetrics._();

  static const double receiptLogicalWidth = 302;
  static const double containerPadding = 6;
  static const double logoBlockHeight = ThermalReceiptLogoFit.previewHeight + 8;

  /// Qatorlar soniga qarab taxminiy balandlik (ekran chegarasidan qat’i nazar).
  static double estimateHeight({
    required List<String> lines,
    bool showLogo = false,
  }) {
    var height = containerPadding * 2;
    if (showLogo) height += logoBlockHeight;

    for (final line in lines) {
      if (line.isEmpty) {
        height += 6;
        continue;
      }
      if (ThermalReceiptLargeText.isLargeLine(line)) {
        height += 20 + (ThermalReceiptLargeText.previewFontSize * 1.1);
        continue;
      }
      if (ThermalReceiptTotalText.isTotalLine(line)) {
        height += 4 + (ThermalReceiptTotalText.previewAmountSize * 1.35);
        continue;
      }
      if (ThermalReceiptCompactText.isCompactLine(line)) {
        height += 4 + (11 * 1.35);
        continue;
      }
      height += 4 + (12.0 * 1.35);
    }

    // Xavfsiz zaxira — uzun nomlar va shrift farqlari uchun.
    height *= 1.08;
    return height.clamp(240, 24000);
  }
}
