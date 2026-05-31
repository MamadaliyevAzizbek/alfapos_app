import 'package:flutter/material.dart';

import '../utils/receipt_strikethrough_text.dart';

/// Mahalliy chek qatorlari — printer ko‘rinishi (sozlamalar).
class ReceiptLinesPreview extends StatelessWidget {
  final List<String> lines;
  final double width;

  const ReceiptLinesPreview({
    super.key,
    required this.lines,
    this.width = 302,
  });

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) {
      return SizedBox(
        width: width,
        child: const Text('Chek bo‘sh', style: TextStyle(color: Colors.grey)),
      );
    }

    return Container(
      width: width,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final line in lines)
            if (line.isEmpty)
              const SizedBox(height: 6)
            else
              _line(line),
        ],
      ),
    );
  }

  Widget _line(String line) {
    final centered = line.startsWith('^');
    final text = centered ? line.substring(1) : line;
    final isSep = text.startsWith('---');
    final isTotal = text.toLowerCase().contains('umumiy summa');

    if (isSep) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          text,
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: ReceiptStrikethroughText.richLine(
        text,
        style: TextStyle(
          fontSize: isTotal ? 14 : 13,
          fontWeight: isTotal || centered ? FontWeight.w700 : FontWeight.w500,
          color: Colors.black,
          height: 1.35,
        ),
        textAlign: centered ? TextAlign.center : TextAlign.start,
        bold: isTotal || centered,
      ),
    );
  }
}
