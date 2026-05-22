import 'package:flutter/material.dart';

import '../utils/api_receipt_html_parser.dart';

/// API HTML → Alfapos.pdf ko‘rinishidagi ko‘rinish (sozlamalar / tekshiruv).
class ApiReceiptFormattedPreview extends StatelessWidget {
  final String html;
  final double width;

  const ApiReceiptFormattedPreview({
    super.key,
    required this.html,
    this.width = 302,
  });

  @override
  Widget build(BuildContext context) {
    final lines = ApiReceiptHtmlParser.toPrintLines(html);
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
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final line in lines)
            if (line.isEmpty)
              const SizedBox(height: 6)
            else
              _lineWidget(line),
        ],
      ),
    );
  }

  Widget _lineWidget(String line) {
    final centered = line.startsWith('^');
    final text = centered ? line.substring(1) : line;
    final isSep = text.startsWith('---');
    final isTotal = text.toLowerCase().contains('umumiy summa');

    if (isSep) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          text,
          style: const TextStyle(fontSize: 12, color: Colors.black54, letterSpacing: -0.5),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Text(
        text,
        textAlign: centered ? TextAlign.center : TextAlign.start,
        style: TextStyle(
          fontSize: isTotal ? 14 : 13,
          fontWeight: isTotal || (centered && text.length < 30) ? FontWeight.w700 : FontWeight.w500,
          color: Colors.black,
          height: 1.35,
        ),
      ),
    );
  }
}
