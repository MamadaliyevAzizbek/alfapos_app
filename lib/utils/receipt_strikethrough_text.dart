import 'package:flutter/material.dart';

/// Termal chek qatorlarida eski narxni belgilash: §5,000§ → ustidan chiziq.
class ReceiptStrikethroughText {
  ReceiptStrikethroughText._();

  static const marker = '§';

  static String wrap(String text) => '$marker$text$marker';

  static bool containsMarker(String line) => line.contains(marker);

  static List<({String text, bool strike})> parseSegments(String line) {
    if (!line.contains(marker)) {
      return [(text: line, strike: false)];
    }
    final out = <({String text, bool strike})>[];
    final parts = line.split(marker);
    for (var i = 0; i < parts.length; i++) {
      final part = parts[i];
      if (part.isEmpty) continue;
      out.add((text: part, strike: i.isOdd));
    }
    return out;
  }

  static TextSpan toTextSpan(String line, TextStyle base, {TextStyle? strikeStyle}) {
    final strike = strikeStyle ??
        base.copyWith(
          decoration: TextDecoration.lineThrough,
          decorationThickness: 2,
          decorationColor: Colors.grey.shade700,
          color: Colors.grey.shade600,
        );
    if (!containsMarker(line)) return TextSpan(text: line, style: base);
    return TextSpan(
      style: base,
      children: [
        for (final seg in parseSegments(line))
          TextSpan(text: seg.text, style: seg.strike ? strike : base),
      ],
    );
  }

  static Widget richLine(
    String line, {
    required TextStyle style,
    TextAlign textAlign = TextAlign.start,
    bool bold = false,
  }) {
    final base = bold ? style.copyWith(fontWeight: FontWeight.w700) : style;
    if (!containsMarker(line)) {
      return Text(line, style: base, textAlign: textAlign);
    }
    return Text.rich(
      toTextSpan(line, base),
      textAlign: textAlign,
    );
  }
}
