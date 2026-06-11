/// Termal chekda katta matn (navbat raqami va h.k.).
abstract class ThermalReceiptLargeText {
  ThermalReceiptLargeText._();

  static const marker = '!LARGE!';

  static String line(String text) => '$marker$text';

  static bool isLargeLine(String line) => line.startsWith(marker);

  static String unwrap(String line) =>
      isLargeLine(line) ? line.substring(marker.length) : line;
}
