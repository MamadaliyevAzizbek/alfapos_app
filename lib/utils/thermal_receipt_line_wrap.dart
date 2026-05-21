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
      out.addAll(wrapLine(line, maxWidth: maxWidth));
    }
    return out;
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

  /// Jadval qatori: chap ustun + o‘ng ustun(lar) 80mm chekda.
  static String formatTwoColumns(
    String left,
    String right, {
    int totalWidth = kThermalChars80mm,
    int rightWidth = 14,
  }) {
    final l = left.trim();
    final r = right.trim();
    if (r.isEmpty) return l;
    final leftMax = (totalWidth - rightWidth - 1).clamp(8, totalWidth);
    if (l.length <= leftMax) {
      return '${l.padRight(leftMax)} ${r.padLeft(rightWidth)}';
    }
    return '$l  $r';
  }
}
