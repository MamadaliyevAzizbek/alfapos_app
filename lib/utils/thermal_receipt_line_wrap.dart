import 'thermal_receipt_compact_text.dart';
import 'thermal_receipt_large_text.dart';
import 'thermal_receipt_product_title_text.dart';

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
      if (ThermalReceiptLargeText.isLargeLine(line) ||
          ThermalReceiptCompactText.isAnyCompactLine(line) ||
          ThermalReceiptProductTitleText.isAnySpecialLine(line)) {
        out.add(line);
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
      if (_isRightAlignedAmountLine(line, maxWidth)) {
        out.add(line);
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

  /// Summa alohida qatorida — qayta bo‘linmasin.
  static bool _isRightAlignedAmountLine(String line, int width) {
    if (line.length != width) return false;
    final trimmed = line.trimLeft();
    if (trimmed.isEmpty) return false;
    return RegExp(r'^[\d\s,.]+(\s*so.?m)?$', caseSensitive: false).hasMatch(trimmed) ||
        RegExp(r'^\S+.*\d').hasMatch(trimmed);
  }

  /// Mahsulotlar orasidagi chiziq — chek kengligiga to‘liq.
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

  /// Jadval qatori: chap (miqdor x narx) + o‘ng (summa).
  /// Sig‘masa avval kichik shrift, keyin summa alohida qatorda (qator tuzilmasi saqlanadi).
  static List<String> formatTwoColumnRows(
    String left,
    String right, {
    int totalWidth = kThermalChars80mm,
    int rightWidth = 20,
    int compactWidth = ThermalReceiptCompactText.chars80mm,
  }) {
    final l = left.trim();
    final r = right.trim();
    if (r.isEmpty) return wrapLine(l, maxWidth: totalWidth);

    final single = _alignedTwoColumn(l, r, totalWidth: totalWidth, rightWidth: rightWidth);
    if (single != null) return [single];

    final compact = _alignedTwoColumn(
      l,
      r,
      totalWidth: compactWidth,
      rightWidth: rightWidth,
    );
    if (compact != null) {
      return [ThermalReceiptCompactText.line(compact)];
    }

    final leftLines = wrapLine(l, maxWidth: totalWidth);
    final sumLine = r.padLeft(totalWidth);
    return [...leftLines, sumLine];
  }

  static String? _alignedTwoColumn(
    String left,
    String right, {
    required int totalWidth,
    required int rightWidth,
  }) {
    final gap = 1;
    final leftMax = (totalWidth - rightWidth - gap).clamp(8, totalWidth);
    if (left.length + gap + right.length > totalWidth) return null;
    return '${left.padRight(leftMax)}${' ' * gap}${right.padLeft(rightWidth)}';
  }

  /// Eski API — bitta qator (yangi formatTwoColumnRows ishlatiladi).
  static String formatTwoColumns(
    String left,
    String right, {
    int totalWidth = kThermalChars80mm,
    int rightWidth = 20,
  }) {
    final rows = formatTwoColumnRows(
      left,
      right,
      totalWidth: totalWidth,
      rightWidth: rightWidth,
    );
    return rows.first;
  }

  /// Mahsulot nomi — avval oddiy, keyin kichik shrift, oxirida bo‘linadi.
  static List<String> formatProductNameRows(
    String name, {
    required bool numbered,
    required int index,
    int maxWidth = kThermalChars80mm,
    int compactWidth = ThermalReceiptCompactText.chars80mm,
  }) {
    final text = numbered ? '$index) $name' : name;
    if (text.length <= maxWidth) return [text];
    if (text.length <= compactWidth) {
      return [ThermalReceiptCompactText.line(text)];
    }
    return wrapLine(text, maxWidth: maxWidth);
  }
}
