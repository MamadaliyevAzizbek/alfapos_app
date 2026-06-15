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

  /// Restoran chekida navbat — katta, lekin qog‘oz tejash uchun biroz kichikroq.
  static const int restaurantPrinterSize80mm = 3;

  /// 58mm printerda navbat raqami kattaligi.
  static const int printerSize58mm = 3;

  /// Restoran chekida 58mm navbat.
  static const int restaurantPrinterSize58mm = 2;

  static String line(String text) => '$marker$text';

  static bool isLargeLine(String line) => line.startsWith(marker);

  static String unwrap(String line) =>
      isLargeLine(line) ? line.substring(marker.length) : line;
}
