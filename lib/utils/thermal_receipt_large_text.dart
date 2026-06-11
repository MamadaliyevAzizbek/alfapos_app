/// Termal chekda katta matn (navbat raqami va h.k.).
abstract class ThermalReceiptLargeText {
  ThermalReceiptLargeText._();

  static const marker = '!LARGE!';

  /// Chek preview (sozlamalar) — printerga yaqin, lekin o‘qilishi aniq.
  static const double previewFontSize = 46;

  /// To‘lovdan keyin ekrandagi chek ko‘rinishi.
  static const double onScreenFontSize = 54;

  /// 80mm printerda navbat raqami kattaligi (1–8; 4 = aniq va xavfsiz).
  static const int printerSize80mm = 4;

  /// 58mm printerda navbat raqami kattaligi.
  static const int printerSize58mm = 3;

  static String line(String text) => '$marker$text';

  static bool isLargeLine(String line) => line.startsWith(marker);

  static String unwrap(String line) =>
      isLargeLine(line) ? line.substring(marker.length) : line;
}
