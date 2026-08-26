/// Termal chekda qalin qator (Font A).
abstract class ThermalReceiptBoldText {
  ThermalReceiptBoldText._();

  static const marker = '!BOLD!';
  /// Mahsulot miqdori — printerda 2× baland (asl +1px emas, ESC/POS chegarasi).
  static const largeMarker = '!BOLD_LG!';

  static String line(String text) => '$marker$text';

  static String largeLine(String text) => '$largeMarker$text';

  static bool isLargeBoldLine(String line) => line.startsWith(largeMarker);

  static bool isBoldLine(String line) =>
      line.startsWith(marker) || isLargeBoldLine(line);

  static String unwrap(String line) {
    if (isLargeBoldLine(line)) return line.substring(largeMarker.length);
    if (line.startsWith(marker)) return line.substring(marker.length);
    return line;
  }
}

/// Yarim qator bo'shliq (to'liq `feed(1)` emas).
abstract class ThermalReceiptHalfGap {
  ThermalReceiptHalfGap._();

  static const marker = '!HALF_GAP!';

  static String line() => marker;

  static bool isHalfGap(String line) => line == marker;
}
