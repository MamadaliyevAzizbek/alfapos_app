/// Do‘kon / restoran chekidagi «Umumiy summa» — Font A, qalin, biroz balandroq.
abstract class ThermalReceiptTotalText {
  ThermalReceiptTotalText._();

  static const marker = '!TOTAL!';
  static const fieldSep = '\u001f';

  /// Preview — qalin, oddiy qatordan biroz katta.
  static const double previewLabelSize = 15;
  static const double previewAmountSize = 15;

  static String line(String label, String value) =>
      '$marker${label.trim()}$fieldSep${value.trim()}';

  static bool isTotalLine(String line) => line.startsWith(marker);

  static String unwrap(String line) =>
      isTotalLine(line) ? line.substring(marker.length) : line;

  static ({String label, String value}) parse(String line) {
    final raw = unwrap(line);
    final i = raw.indexOf(fieldSep);
    if (i < 0) {
      return (label: raw.trim(), value: '');
    }
    return (
      label: raw.substring(0, i).trim(),
      value: raw.substring(i + 1).trim(),
    );
  }

  /// Oddiy matndan (API reprint) label/summani ajratish.
  static ({String label, String value})? tryParsePlain(String text) {
    final t = text.trim();
    final lower = t.toLowerCase();
    if (!lower.contains('umumiy summa') &&
        !lower.contains('итого') &&
        !(lower.startsWith('jami') && !lower.contains('og') && !lower.contains('оғ'))) {
      return null;
    }
    for (final sep in [' - ', ' = ', ': ']) {
      final i = t.indexOf(sep);
      if (i > 0) {
        return (
          label: t.substring(0, i).trim(),
          value: t.substring(i + sep.length).trim(),
        );
      }
    }
    return (label: t, value: '');
  }
}
