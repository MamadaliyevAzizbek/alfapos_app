/// Chekdagi izoh qatori — barcha printer va previewlarda bir xil aniqlanadi.
abstract class ThermalReceiptNoteText {
  ThermalReceiptNoteText._();

  static const marker = '!RECEIPT_NOTE!';

  /// Termal chek previewidagi oddiy 12px matndan 2px katta.
  static const double previewFontSize = 14;

  /// `ReceiptWidget`dagi oddiy 13px matndan 2px katta.
  static const double onScreenFontSize = 15;

  static String line(String text) => '$marker$text';

  /// Marker eski/API qatorlarida bo‘lmasligi mumkin. Ularni ham bir xil
  /// ko‘rsatish uchun `Izoh:` va `Tavsif:` prefikslari tan olinadi.
  static bool isNoteLine(String line) {
    if (line.startsWith(marker)) return true;
    final text = line.trimLeft().toLowerCase();
    return text.startsWith('izoh:') || text.startsWith('tavsif:');
  }

  static String unwrap(String line) =>
      line.startsWith(marker) ? line.substring(marker.length) : line;
}
