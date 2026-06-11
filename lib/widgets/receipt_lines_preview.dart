import 'dart:io';

import 'package:flutter/material.dart';

import '../models/receipt_design_config.dart';
import '../services/receipt_font_settings.dart';
import 'receipt_logo_image.dart';
import '../utils/receipt_strikethrough_text.dart';
import '../utils/thermal_receipt_compact_text.dart';
import '../utils/thermal_receipt_large_text.dart';

/// Termal printer chiqishi — logo + matn qatorlari (sozlamalar va ko‘rinish).
class ThermalReceiptPreview extends StatelessWidget {
  final List<String> lines;
  final ReceiptDesignConfig design;
  final double width;
  final bool forPrint;
  final ReceiptFontId? fontOverride;

  const ThermalReceiptPreview({
    super.key,
    required this.lines,
    required this.design,
    this.width = 302,
    this.forPrint = false,
    this.fontOverride,
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

    if (fontOverride != null) {
      return _buildBody(fontOverride!);
    }

    return ValueListenableBuilder<ReceiptFontId>(
      valueListenable: ReceiptFontSettings.notifier,
      builder: (context, font, _) => _buildBody(font),
    );
  }

  Widget _buildBody(ReceiptFontId font) {
    return Container(
      key: ValueKey('receipt_preview_${design.logoFilePath}_${design.showLogo}'),
      width: width,
      padding: const EdgeInsets.all(12),
      color: forPrint ? Colors.white : null,
      decoration: forPrint
          ? null
          : BoxDecoration(
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
                height: 56,
                fit: BoxFit.contain,
                forceSync: forPrint,
              ),
            ),
            const SizedBox(height: 8),
          ],
          for (final line in lines)
            if (line.isEmpty)
              const SizedBox(height: 6)
            else
              _line(line, font),
        ],
      ),
    );
  }

  Widget _line(String line, ReceiptFontId font) {
    if (ThermalReceiptCompactText.isCompactLine(line)) {
      final text = ThermalReceiptCompactText.unwrap(line);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: ReceiptStrikethroughText.richLine(
          text,
          style: ReceiptFontSettings.style(font: font, fontSize: 11),
          textAlign: TextAlign.start,
        ),
      );
    }

    if (ThermalReceiptLargeText.isLargeLine(line)) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Text(
          ThermalReceiptLargeText.unwrap(line),
          textAlign: TextAlign.center,
          style: ReceiptFontSettings.style(
            font: font,
            fontSize: ThermalReceiptLargeText.previewFontSize,
            fontWeight: FontWeight.w700,
            height: 1.1,
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
          style: ReceiptFontSettings.style(
            font: font,
            fontSize: 12,
            color: Colors.black54,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: ReceiptStrikethroughText.richLine(
        text,
        style: ReceiptFontSettings.style(
          font: font,
          fontSize: isTotal ? 14 : 12,
          fontWeight: isTotal || centered ? FontWeight.w700 : FontWeight.w500,
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
