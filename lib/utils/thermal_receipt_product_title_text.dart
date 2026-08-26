/// Restoran chekida mahsulot nomi — qalin va biroz kattaroq.
abstract class ThermalReceiptProductTitleText {
  ThermalReceiptProductTitleText._();

  static const marker = '!PRODUCT_TITLE!';
  static const gapMarker = '!PRODUCT_GAP!';

  /// Ekran preview — asosiy matndan +3px.
  static const double previewFontSize = 15;

  /// To‘lov ekrani preview.
  static const double onScreenFontSize = 16;

  static String line(String text) => '$marker$text';

  static String gapLine() => gapMarker;

  static bool isTitleLine(String line) => line.startsWith(marker);

  static bool isGapLine(String line) => line == gapMarker;

  static bool isAnySpecialLine(String line) => isTitleLine(line) || isGapLine(line);

  static String unwrap(String line) =>
      isTitleLine(line) ? line.substring(marker.length) : line;
}
