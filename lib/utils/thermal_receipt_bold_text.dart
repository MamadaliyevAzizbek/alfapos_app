/// Termal chekda qalin qator (Font A).
abstract class ThermalReceiptBoldText {
  ThermalReceiptBoldText._();

  static const marker = '!BOLD!';

  static String line(String text) => '$marker$text';

  static bool isBoldLine(String line) => line.startsWith(marker);

  static String unwrap(String line) =>
      isBoldLine(line) ? line.substring(marker.length) : line;
}

/// Yarim qator bo'shliq (to'liq `feed(1)` emas).
abstract class ThermalReceiptHalfGap {
  ThermalReceiptHalfGap._();

  static const marker = '!HALF_GAP!';

  static String line() => marker;

  static bool isHalfGap(String line) => line == marker;
}
