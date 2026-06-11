import 'dart:io';

import 'package:flutter/material.dart';

import '../models/receipt_design_config.dart';
import '../utils/receipt_strikethrough_text.dart';
import '../utils/thermal_receipt_large_text.dart';

/// Termal printer chiqishi — logo + matn qatorlari (sozlamalar va ko‘rinish).
class ThermalReceiptPreview extends StatelessWidget {
  final List<String> lines;
  final ReceiptDesignConfig design;
  final double width;

  const ThermalReceiptPreview({
    super.key,
    required this.lines,
    required this.design,
    this.width = 302,
  });

  bool get _showLogo {
    final path = design.logoFilePath;
    return design.showLogo &&
        path != null &&
        path.isNotEmpty &&
        File(path).existsSync();
  }

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty && !_showLogo) {
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
          if (_showLogo) ...[
            Center(
              child: Image.file(
                File(design.logoFilePath!),
                height: 56,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 8),
          ],
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
    if (ThermalReceiptLargeText.isLargeLine(line)) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(
          ThermalReceiptLargeText.unwrap(line),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.w800,
            height: 1.1,
            color: Colors.black,
          ),
        ),
      );
    }

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

/// Mahalliy chek qatorlari — printer ko‘rinishi (logo bilan).
class ReceiptLinesPreview extends StatelessWidget {
  final List<String> lines;
  final ReceiptDesignConfig? design;
  final double width;

  const ReceiptLinesPreview({
    super.key,
    required this.lines,
    this.design,
    this.width = 302,
  });

  @override
  Widget build(BuildContext context) {
    return ThermalReceiptPreview(
      lines: lines,
      design: design ?? ReceiptDesignConfig.defaults.copyWith(showLogo: false),
      width: width,
    );
  }
}
