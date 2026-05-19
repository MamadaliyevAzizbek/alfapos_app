import 'dart:io';

import 'package:flutter/material.dart';

import '../core/input_formatters.dart';
import '../models/receipt_design_config.dart';

/// Bir qator chek qatori: mahsulot, miqdor, narx, summa
class ReceiptRow {
  final String productName;
  final String quantityStr;
  final int price;
  final int sum;

  const ReceiptRow({
    required this.productName,
    required this.quantityStr,
    required this.price,
    required this.sum,
  });
}

/// To'lov qatori: usul, summa
class ReceiptPaymentRow {
  final String methodName;
  final int sum;

  const ReceiptPaymentRow({
    required this.methodName,
    required this.sum,
  });
}

/// Mahalliy chek — Xprinter 80mm, dizayn sozlamalariga mos.
class ReceiptWidget extends StatelessWidget {
  final ReceiptDesignConfig design;
  final String storeName;
  final DateTime dateTime;
  final String receiptNumber;
  final String sellerName;
  final String? sellerPhone;
  final String? clientName;
  final String? description;
  final List<ReceiptRow> productRows;
  final List<ReceiptPaymentRow> paymentRows;
  final int discount;
  final int totalSum;
  final String barcodeData;
  final bool isPrecheck;

  const ReceiptWidget({
    super.key,
    required this.design,
    required this.storeName,
    required this.dateTime,
    required this.receiptNumber,
    required this.sellerName,
    this.sellerPhone,
    this.clientName,
    this.description,
    required this.productRows,
    required this.paymentRows,
    required this.discount,
    required this.totalSum,
    this.barcodeData = '',
    this.isPrecheck = false,
  });

  static const double receiptWidth = 302;

  double get _fontSize => 13 * design.fontScale.clamp(0.85, 1.25);
  double get _titleSize => 20 * design.fontScale.clamp(0.9, 1.2);
  double get _headerSize => 13 * design.fontScale.clamp(0.85, 1.2);

  String _fmtMoney(int n) {
    final base = formatThousands(n);
    return design.useSomSuffix ? "$base so'm" : base;
  }

  @override
  Widget build(BuildContext context) {
    const padding = 12.0;
    // Termal printer: faqat qora (kulrang anti-alias xira chiqadi).
    final textStyle = TextStyle(
      fontSize: _fontSize,
      color: Colors.black,
      fontWeight: FontWeight.w500,
      height: 1.3,
      letterSpacing: 0.1,
    );
    final headerStyle = TextStyle(
      fontSize: _headerSize,
      fontWeight: FontWeight.w700,
      color: Colors.black,
      letterSpacing: 0.15,
    );
    final titleStyle = TextStyle(
      fontSize: _titleSize,
      fontWeight: FontWeight.w800,
      color: Colors.black,
      height: 1.1,
      letterSpacing: 0.2,
    );

    return Container(
      width: receiptWidth,
      padding: const EdgeInsets.all(padding),
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_hasLogo) ...[
            Center(child: _buildLogo(maxHeight: 72)),
            const SizedBox(height: 8),
          ],
          Center(
            child: Text(
              storeName,
              textAlign: TextAlign.center,
              style: titleStyle,
            ),
          ),
          if (design.headerExtraText.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Center(
              child: Text(
                design.headerExtraText.trim(),
                textAlign: TextAlign.center,
                style: textStyle.copyWith(fontSize: _fontSize - 1),
              ),
            ),
          ],
          if (isPrecheck) ...[
            const SizedBox(height: 8),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black54, width: 1.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'OLDINDAN CHEK',
                  style: headerStyle.copyWith(letterSpacing: 1),
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Center(
            child: Text(
              _dateTimeLine(),
              style: textStyle,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isPrecheck ? "Chek raqami: to'lov oldin" : 'Chek raqami: $receiptNumber',
            style: textStyle,
          ),
          Text('Sotuvchi: $sellerName', style: textStyle),
          if (design.showSellerPhone &&
              sellerPhone != null &&
              sellerPhone!.trim().isNotEmpty)
            Text('Sotuvchi nomeri: ${sellerPhone!.trim()}', style: textStyle),
          if (design.showClient && clientName != null && clientName!.trim().isNotEmpty)
            Text('Mijoz: ${clientName!.trim()}', style: textStyle),
          if (design.showDescription && (description ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('Tavsif: ${description!.trim()}', style: textStyle),
          ],
          const SizedBox(height: 10),
          if (design.usesNumberedProducts)
            ..._buildNumberedProducts(textStyle, headerStyle)
          else
            ..._buildTableProducts(textStyle, headerStyle),
          if (!isPrecheck) ...[
            const SizedBox(height: 4),
            for (final row in paymentRows) _paymentLine(row, textStyle),
            _summaryLine('Chegirma', discount, textStyle),
            _summaryLine('Umumiy summa', totalSum, headerStyle),
          ] else ...[
            _summaryLine('Chegirma', discount, textStyle),
            _summaryLine('Umumiy summa', totalSum, headerStyle),
            const SizedBox(height: 8),
            Center(
              child: Text(
                "To'lov hali amalga oshirilmagan",
                textAlign: TextAlign.center,
                style: textStyle.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ],
          if (!isPrecheck) ...[
            if (design.showBarcode) ...[
              const SizedBox(height: 12),
              Center(
                child: _BarcodeStrip(
                  data: barcodeData.isEmpty ? receiptNumber : barcodeData,
                  width: receiptWidth - padding * 2,
                ),
              ),
            ],
            ..._buildFooter(textStyle),
          ],
        ],
      ),
    );
  }

  bool get _hasLogo {
    final p = design.logoPath;
    return p != null && p.isNotEmpty && File(p).existsSync();
  }

  bool get _hasFooterImage {
    final p = design.footerImagePath;
    return p != null && p.isNotEmpty && File(p).existsSync();
  }

  String _dateTimeLine() {
    final sep = design.template == ReceiptTemplateKind.numberedList ? ' | ' : ' - ';
    return '${_dateStr(dateTime)}$sep${_timeStr(dateTime)}';
  }

  Widget _buildLogo({required double maxHeight}) {
    final path = design.logoPath!;
    return Image.file(
      File(path),
      height: maxHeight,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
    );
  }

  List<Widget> _buildNumberedProducts(TextStyle textStyle, TextStyle headerStyle) {
    final out = <Widget>[];
    var i = 1;
    for (final row in productRows) {
      out.add(Text('$i) ${row.productName}', style: textStyle));
      out.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 6, top: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  '${row.quantityStr} x ${_fmtMoney(row.price)}.',
                  style: textStyle,
                ),
              ),
              Text(_fmtMoney(row.sum), style: textStyle, textAlign: TextAlign.right),
            ],
          ),
        ),
      );
      i++;
    }
    return out;
  }

  List<Widget> _buildTableProducts(TextStyle textStyle, TextStyle headerStyle) {
    final w = receiptWidth - 24;
    final out = <Widget>[];
    if (design.showTableHeaders) {
      out.add(
        Row(
          children: [
            SizedBox(width: w * 0.36, child: Text('Mahsulot', style: headerStyle)),
            SizedBox(width: w * 0.16, child: Text('Miqdor', style: headerStyle)),
            SizedBox(width: w * 0.22, child: Text('Narx', style: headerStyle)),
            Expanded(child: Text('Summa', style: headerStyle, textAlign: TextAlign.right)),
          ],
        ),
      );
      out.add(_dashedLine(w));
    }
    for (final row in productRows) {
      out.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: w * 0.36,
                child: Text(row.productName, style: textStyle),
              ),
              SizedBox(
                width: w * 0.16,
                child: Text(row.quantityStr, style: textStyle),
              ),
              SizedBox(
                width: w * 0.22,
                child: Text(formatThousands(row.price), style: textStyle),
              ),
              Expanded(
                child: Text(
                  formatThousands(row.sum),
                  style: textStyle,
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (productRows.isNotEmpty) out.add(_dashedLine(w));
    return out;
  }

  Widget _paymentLine(ReceiptPaymentRow row, TextStyle textStyle) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(row.methodName, style: textStyle)),
          Text(_fmtMoney(row.sum), style: textStyle, textAlign: TextAlign.right),
        ],
      ),
    );
  }

  Widget _summaryLine(String label, int amount, TextStyle style) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(_fmtMoney(amount), style: style, textAlign: TextAlign.right),
        ],
      ),
    );
  }

  List<Widget> _buildFooter(TextStyle textStyle) {
    final out = <Widget>[];
    if (_hasFooterImage) {
      out.add(const SizedBox(height: 10));
      out.add(
        Center(
          child: Image.file(
            File(design.footerImagePath!),
            height: 64,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
        ),
      );
    }
    if (design.footerText.trim().isNotEmpty) {
      out.add(const SizedBox(height: 8));
      out.add(
        Center(
          child: Text(
            design.footerText.trim(),
            textAlign: TextAlign.center,
            style: textStyle.copyWith(fontSize: _fontSize),
          ),
        ),
      );
    }
    return out;
  }

  static String _dateStr(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  static String _timeStr(DateTime d) {
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}:${d.second.toString().padLeft(2, '0')}';
  }

  static Widget _dashedLine(double w) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: CustomPaint(
        size: Size(w, 1),
        painter: _DashedLinePainter(),
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black..strokeWidth = 1;
    const dash = 4.0;
    const gap = 3.0;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset((x + dash).clamp(0, size.width), 0), paint);
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BarcodeStrip extends StatelessWidget {
  final String data;
  final double width;

  const _BarcodeStrip({required this.data, required this.width});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, 48),
      painter: _BarcodePainter(seed: data),
    );
  }
}

class _BarcodePainter extends CustomPainter {
  final String seed;

  _BarcodePainter({required this.seed});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black;
    final codes = seed.codeUnits;
    var i = 0;
    double x = 0;
    while (x < size.width) {
      final v = codes.isEmpty ? (i * 7 + 3) : codes[i % codes.length];
      final w = 1.0 + (v % 4);
      final isBar = ((v + i) % 2) == 0;
      if (isBar) {
        canvas.drawRect(Rect.fromLTWH(x, 0, w, size.height), paint);
      }
      x += w + 1;
      i++;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
