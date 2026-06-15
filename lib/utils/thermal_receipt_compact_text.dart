/// Termal chekda avtomatik kichik shrift (Font B) — uzun qatorlar sig‘ishi uchun.
abstract class ThermalReceiptCompactText {
  ThermalReceiptCompactText._();

  static const marker = '!COMPACT!';
  static const boldMarker = '!COMPACT_BOLD!';

  /// 80mm Font B — taxminiy belgilar soni.
  static const int chars80mm = 64;

  /// 58mm Font B — taxminiy belgilar soni.
  static const int chars58mm = 42;

  static String line(String text) => '$marker$text';

  static String boldLine(String text) => '$boldMarker$text';

  static bool isCompactLine(String line) => line.startsWith(marker);

  static bool isCompactBoldLine(String line) => line.startsWith(boldMarker);

  static bool isAnyCompactLine(String line) =>
      isCompactLine(line) || isCompactBoldLine(line);

  static String unwrap(String line) {
    if (isCompactBoldLine(line)) return line.substring(boldMarker.length);
    if (isCompactLine(line)) return line.substring(marker.length);
    return line;
  }
}
