import 'dart:io';

import 'package:flutter/material.dart';

import '../models/receipt_design_config.dart';
import 'receipt_logo_image.dart';
import '../utils/receipt_strikethrough_text.dart';
import '../utils/thermal_receipt_compact_text.dart';
import '../utils/thermal_receipt_large_text.dart';
import '../utils/thermal_receipt_product_title_text.dart';
import '../utils/thermal_receipt_total_text.dart';
import '../utils/thermal_receipt_logo_fit.dart';

const _previewText = TextStyle(
  color: Colors.black,
  height: 1.35,
  fontFamily: 'monospace',
  fontWeight: FontWeight.w500,
);

/// Termal printer chiqishi — logo + matn qatorlari (sozlamalar ko‘rinishi).
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
      key: ValueKey('receipt_preview_${design.logoFilePath}_${design.showLogo}'),
      width: width,
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
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
              child: ReceiptLogoImage(
                path: design.logoFilePath!,
                width: ThermalReceiptLogoFit.previewWidth,
                height: ThermalReceiptLogoFit.previewHeight,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 4),
          ],
          for (final line in lines)
            if (line.isEmpty)
              const SizedBox(height: 4)
            else
              _line(line),
        ],
      ),
    );
  }

  Widget _line(String line) {
    if (ThermalReceiptProductTitleText.isGapLine(line)) {
      return const SizedBox(height: 2);
    }

    if (ThermalReceiptProductTitleText.isTitleLine(line)) {
      return Padding(
        padding: const EdgeInsets.only(top: 1),
        child: ReceiptStrikethroughText.richLine(
          ThermalReceiptProductTitleText.unwrap(line),
          style: _previewText.copyWith(
            fontSize: ThermalReceiptProductTitleText.previewFontSize,
            fontWeight: FontWeight.w800,
            height: 1.2,
          ),
          textAlign: TextAlign.start,
          bold: true,
        ),
      );
    }

    if (ThermalReceiptCompactText.isAnyCompactLine(line)) {
      final text = ThermalReceiptCompactText.unwrap(line);
      final bold = ThermalReceiptCompactText.isCompactBoldLine(line);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: ReceiptStrikethroughText.richLine(
          text,
          style: _previewText.copyWith(
            fontSize: 11,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
          ),
          textAlign: TextAlign.start,
          bold: bold,
        ),
      );
    }

    if (ThermalReceiptTotalText.isTotalLine(line)) {
      final total = ThermalReceiptTotalText.parse(line);
      final text = [
        if (total.label.isNotEmpty) total.label,
        if (total.value.isNotEmpty) total.value,
      ].join(' - ');
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _previewText.copyWith(
            fontSize: ThermalReceiptTotalText.previewAmountSize,
            fontWeight: FontWeight.w500,
            fontFamily: 'monospace',
            height: 1.35,
          ),
        ),
      );
    }

    if (ThermalReceiptLargeText.isLargeLine(line)) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Text(
          ThermalReceiptLargeText.unwrap(line),
          textAlign: TextAlign.center,
          style: _previewText.copyWith(
            fontSize: ThermalReceiptLargeText.previewFontSize,
            fontWeight: FontWeight.w700,
            height: 1.05,
          ),
        ),
      );
    }

    final centered = line.startsWith('^');
    final text = centered ? line.substring(1) : line;
    final isSep = RegExp(r'^[-─—_=.]+$').hasMatch(text.trim());
    final isTotal = text.toLowerCase().contains('umumiy summa');

    if (isSep) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          text,
          style: _previewText.copyWith(fontSize: 12, color: Colors.black54),
          softWrap: false,
          overflow: TextOverflow.clip,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: ReceiptStrikethroughText.richLine(
        text,
        style: _previewText.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          fontFamily: 'monospace',
          height: 1.35,
        ),
        textAlign: centered ? TextAlign.center : TextAlign.start,
        bold: false,
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
