/// 80mm termal printer uchun qator uzunligi (Font A).
const int kThermalChars80mm = 48;

/// 58mm termal printer uchun qator uzunligi (Font A).
const int kThermalChars58mm = 32;

/// Uzun matnni termal chek kengligiga mos qatorlarga bo‘lish.
class ThermalReceiptLineWrap {
  ThermalReceiptLineWrap._();

  static List<String> wrapAll(
    List<String> lines, {
    int maxWidth = kThermalChars80mm,
  }) {
    final out = <String>[];
    for (final line in lines) {
      if (line.isEmpty) {
        if (out.isEmpty || out.last.isEmpty) continue;
        out.add('');
        continue;
      }
      if (line.startsWith('^')) {
        out.addAll(wrapLine(line.substring(1), maxWidth: maxWidth).map((p) => '^$p'));
        continue;
      }
      if (_isSeparatorLine(line)) {
        out.add(fullSeparator(maxWidth, from: line));
        continue;
      }
      out.addAll(wrapLine(line, maxWidth: maxWidth));
    }
    return out;
  }

  static bool _isSeparatorLine(String line) {
    final t = line.trim();
    return t.isNotEmpty && RegExp(r'^[-─—_=.]+$').hasMatch(t);
  }

  /// Mahsulotlar orasidagi chiziq — chek kengligiga to‘liq (48 belgi @ 80mm).
  static String fullSeparator(int width, {String? from}) {
    if (width <= 0) return '';
    final sample = (from ?? '-').trim();
    final char = sample.isNotEmpty ? sample[0] : '-';
    return char * width;
  }

  static List<String> wrapLine(String line, {int maxWidth = kThermalChars80mm}) {
    final t = line.trim();
    if (t.isEmpty) return [''];
    if (t.length <= maxWidth) return [t];

    final out = <String>[];
    var rest = t;
    while (rest.length > maxWidth) {
      var breakAt = rest.lastIndexOf(' ', maxWidth);
      if (breakAt <= 0) breakAt = maxWidth;
      out.add(rest.substring(0, breakAt).trim());
      rest = rest.substring(breakAt).trim();
    }
    if (rest.isNotEmpty) out.add(rest);
    return out.isEmpty ? [t.substring(0, maxWidth)] : out;
  }

  /// Jadval qatori: chap (miqdor x narx) + o‘ng (summa so'm).
  static String formatTwoColumns(
    String left,
    String right, {
    int totalWidth = kThermalChars80mm,
    int rightWidth = 20,
  }) {
    final l = left.trim();
    final r = right.trim();
    if (r.isEmpty) return l;
    final gap = 1;
    final leftMax = (totalWidth - rightWidth - gap).clamp(10, totalWidth);
    if (l.length + gap + r.length <= totalWidth) {
      return '${l.padRight(leftMax)}${' ' * gap}${r.padLeft(rightWidth)}';
    }
    return '$l  $r';
  }
}
