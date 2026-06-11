/// Termal chekda avtomatik kichik shrift (Font B) — uzun qatorlar sig‘ishi uchun.
abstract class ThermalReceiptCompactText {
  ThermalReceiptCompactText._();

  static const marker = '!COMPACT!';

  /// 80mm Font B — taxminiy belgilar soni.
  static const int chars80mm = 64;

  /// 58mm Font B — taxminiy belgilar soni.
  static const int chars58mm = 42;

  static String line(String text) => '$marker$text';

  static bool isCompactLine(String line) => line.startsWith(marker);

  static String unwrap(String line) =>
      isCompactLine(line) ? line.substring(marker.length) : line;
}
