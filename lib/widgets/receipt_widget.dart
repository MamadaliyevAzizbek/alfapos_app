import 'dart:io';

import 'package:flutter/material.dart';

import '../core/input_formatters.dart';
import '../models/receipt_design_config.dart';
import '../utils/thermal_receipt_large_text.dart';
import '../utils/thermal_receipt_note_text.dart';
import '../utils/thermal_receipt_product_title_text.dart';
import '../utils/product_weight.dart';
import '../utils/thermal_receipt_formatter.dart';
import '../utils/thermal_receipt_line_wrap.dart';
import '../utils/thermal_receipt_logo_fit.dart';
import 'receipt_logo_image.dart';

/// Bir qator chek qatori: mahsulot, miqdor, narx, summa
class ReceiptRow {
  final String productName;
  final String quantityStr;

  /// To'langan birlik narxi
  final int price;

  /// To'langan qator jami
  final int sum;

  /// Katalog birlik narxi (chegirma bo'lsa — ustidan chiziladi)
  final int? catalogPrice;

  /// Katalog qator jami (chegirma bo'lsa — ustidan chiziladi)
  final int? catalogSum;

  /// Qator og'irligi (kg).
  final double? lineWeightKg;

  const ReceiptRow({
    required this.productName,
    required this.quantityStr,
    required this.price,
    required this.sum,
    this.catalogPrice,
    this.catalogSum,
    this.lineWeightKg,
  });

  bool get hasUnitDiscount => catalogPrice != null && catalogPrice! > price;

  bool get hasSumDiscount => catalogSum != null && catalogSum! > sum;
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

/// Alfapos.pdf ko‘rinishidagi chek (tahrirlanadigan dizayn bilan).
class ReceiptWidget extends StatelessWidget {
  final DateTime dateTime;
  final String receiptNumber;
  final String sellerName;
  final String? sellerPhone;

  /// API filial nomi (sarlavha uchun; Kassa 1 emas).
  final String branchName;
  final String? clientName;
  final String? clientPhone;
  final String? clientAddress;
  final String? description;
  final List<ReceiptRow> productRows;
  final List<ReceiptPaymentRow> paymentRows;
  final int discount;
  final int totalSum;
  final String barcodeData;
  final bool isPrecheck;
  final int? queueNumber;
  final bool isRestaurantLayout;
  final ReceiptDesignConfig design;
  final int thermalLineWidth;

  const ReceiptWidget({
    super.key,
    required this.dateTime,
    required this.receiptNumber,
    required this.sellerName,
    this.sellerPhone,
    this.branchName = '',
    this.clientName,
    this.clientPhone,
    this.clientAddress,
    this.description,
    required this.productRows,
    required this.paymentRows,
    required this.discount,
    required this.totalSum,
    this.barcodeData = '',
    this.isPrecheck = false,
    this.queueNumber,
    this.isRestaurantLayout = false,
    this.design = ReceiptDesignConfig.defaults,
    this.thermalLineWidth = kThermalChars80mm,
  });

  static String _fmt(int n) => formatThousandsComma(n);

  List<String> toThermalPrintLines({int? lineWidth}) {
    final width = lineWidth ?? thermalLineWidth;
    final totalWeight = _totalWeightKg();
    return ThermalReceiptFormatter.toPrintLines(
      ThermalReceiptPrintData(
        storeName: branchName,
        dateTime: dateTime,
        receiptNumber: receiptNumber,
        sellerName: sellerName,
        sellerPhone: sellerPhone,
        clientName: clientName,
        clientPhone: clientPhone,
        clientAddress: clientAddress,
        description: description,
        isPrecheck: isPrecheck,
        products: productRows
            .map(
              (r) => ThermalReceiptProductLine(
                name: r.productName,
                quantity: r.quantityStr,
                unitPrice: _fmt(r.price),
                lineTotal: _fmt(r.sum),
                catalogUnitPrice:
                    r.hasUnitDiscount ? _fmt(r.catalogPrice!) : null,
                lineWeightKg: r.lineWeightKg,
              ),
            )
            .toList(),
        payments: paymentRows
            .map(
              (r) => ThermalReceiptPaymentLine(
                method: r.methodName,
                amount: _fmt(r.sum),
              ),
            )
            .toList(),
        discountAmount: _fmt(discount),
        totalAmount: _fmt(totalSum),
        totalWeightKg: totalWeight,
        queueNumber: queueNumber,
        isRestaurantLayout: isRestaurantLayout,
      ),
      config: design,
      maxWidth: width,
    );
  }

  double? _totalWeightKg() {
    var total = 0.0;
    var hasAny = false;
    for (final row in productRows) {
      final w = row.lineWeightKg;
      if (w == null || w <= 0) continue;
      total += w;
      hasAny = true;
    }
    if (!hasAny) return null;
    return double.parse(total.toStringAsFixed(3));
  }

  @override
  Widget build(BuildContext context) {
    const width = 340.0;
    const padding = 16.0;
    final textStyle = TextStyle(
      fontSize: 13,
      color: Colors.grey.shade800,
      height: 1.35,
    );
    final headerStyle = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      color: Colors.grey.shade900,
    );
    final som = design.currencySuffix;

    return Container(
      width: width,
      padding: const EdgeInsets.all(padding),
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (design.showLogo &&
              design.logoFilePath != null &&
              design.logoFilePath!.isNotEmpty &&
              File(design.logoFilePath!).existsSync()) ...[
            const SizedBox(height: 14),
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
          if (isPrecheck) ...[
            const SizedBox(height: 8),
            Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade700, width: 1.5),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  design.precheckBanner,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: Colors.grey.shade900,
                  ),
                ),
              ),
            ),
          ],
          if (design.showDateTime) ...[
            const SizedBox(height: 8),
            Center(
              child: Text(
                '${_dateStr(dateTime)} | ${_timeStr(dateTime)}',
                style: textStyle.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
          ],
          if (isRestaurantLayout &&
              !isPrecheck &&
              queueNumber != null &&
              queueNumber! > 0) ...[
            const SizedBox(height: 8),
            Center(
              child: Text(
                design.restaurantQueueLabel,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade800,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Center(
              child: Text(
                '$queueNumber',
                style: TextStyle(
                  fontSize: ThermalReceiptLargeText.onScreenFontSize,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Courier',
                  fontFamilyFallback: const ['monospace'],
                  height: 1.05,
                  letterSpacing: 1,
                  color: Colors.grey.shade900,
                ),
              ),
            ),
            if (design.restaurantQueueHint.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Center(
                child: Text(
                  design.restaurantQueueHint.trim(),
                  style: textStyle.copyWith(fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ],
          const SizedBox(height: 10),
          Text(
            isPrecheck
                ? "${design.receiptNumberLabel}: to'lov oldin"
                : '${design.receiptNumberLabel}: $receiptNumber',
            style: textStyle,
          ),
          const SizedBox(height: 4),
          Text('${design.sellerLabel}: $sellerName', style: textStyle),
          if (design.showSellerPhone &&
              sellerPhone != null &&
              sellerPhone!.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('${design.sellerPhoneLabel}: ${sellerPhone!.trim()}',
                style: textStyle),
          ],
          if ((clientName ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '${design.clientLabel}: ${clientName!.trim()}',
              style: textStyle.copyWith(fontWeight: FontWeight.w700),
            ),
            if ((clientPhone ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                '${design.clientPhoneLabel}: ${clientPhone!.trim()}',
                style: textStyle.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
            if ((clientAddress ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                '${design.clientAddressLabel}: ${clientAddress!.trim()}',
                style: textStyle.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ],
          if ((description ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Izoh: ${description!.trim()}',
              style: textStyle.copyWith(
                fontSize: ThermalReceiptNoteText.onScreenFontSize,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
          const SizedBox(height: 6),
          for (var i = 0; i < productRows.length; i++) ...[
            Text(
              design.numberedProducts
                  ? '${i + 1}) ${productRows[i].productName}'
                  : productRows[i].productName,
              style: isRestaurantLayout
                  ? headerStyle.copyWith(
                      fontSize: ThermalReceiptProductTitleText.onScreenFontSize,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    )
                  : headerStyle,
            ),
            if (isRestaurantLayout) const SizedBox(height: 2),
            if (isRestaurantLayout)
              _restaurantProductLineWidget(productRows[i], textStyle)
            else
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                        child:
                            _productPriceLine(productRows[i], textStyle, som)),
                    SizedBox(
                      width: 108,
                      child: _productSumColumn(productRows[i], textStyle, som),
                    ),
                  ],
                ),
              ),
            if (design.showItemSeparator) ...[
              const SizedBox(height: 4),
              Text(
                ThermalReceiptLineWrap.fullSeparator(kReceiptPreviewChars,
                    from: design.itemSeparator),
                style: textStyle.copyWith(fontSize: 11, letterSpacing: 0),
                softWrap: false,
                overflow: TextOverflow.clip,
              ),
            ],
            const SizedBox(height: 6),
          ],
          ..._buildReceiptSummarySection(
            design: design,
            paymentRows: paymentRows,
            discount: discount,
            totalSum: totalSum,
            totalWeightKg: _totalWeightKg(),
            som: som,
            isPrecheck: isPrecheck,
            isRestaurantLayout: isRestaurantLayout,
            textStyle: textStyle,
            headerStyle: headerStyle,
          ),
          if (!isPrecheck) ...[
            if (design.showBarcode) ...[
              const SizedBox(height: 16),
              Center(
                child: _BarcodeStrip(
                  data: barcodeData.isEmpty ? receiptNumber : barcodeData,
                  width: width - padding * 2,
                ),
              ),
            ],
            if (design.showFooter && design.footerText.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Center(
                child: Text(
                  design.footerText.trim(),
                  style: const TextStyle(fontSize: 12, color: Colors.black87),
                ),
              ),
            ],
          ] else ...[
            const SizedBox(height: 12),
            Center(
              child: Text(
                "To'lov hali amalga oshirilmagan",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _dateStr(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  static String _timeStr(DateTime d) {
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}:${d.second.toString().padLeft(2, '0')}';
  }

  static String _normalizeQty(String qty) {
    return ProductWeight.trimQuantityDecimals(
      qty
          .replaceAll('шт', 'dona')
          .replaceAll('Шт', 'dona')
          .replaceAll('×', 'x'),
    );
  }

  static TextStyle _strikeStyle(TextStyle base) => base.copyWith(
        decoration: TextDecoration.lineThrough,
        decorationThickness: 2,
        decorationColor: Colors.grey.shade700,
        color: Colors.grey.shade600,
      );

  static List<Widget> _buildReceiptSummarySection({
    required ReceiptDesignConfig design,
    required List<ReceiptPaymentRow> paymentRows,
    required int discount,
    required int totalSum,
    required double? totalWeightKg,
    required String som,
    required bool isPrecheck,
    required bool isRestaurantLayout,
    required TextStyle textStyle,
    required TextStyle headerStyle,
  }) {
    final paymentSummary = <({String label, String value})>[
      if (!isPrecheck)
        for (final row in paymentRows)
          (
            label: row.methodName,
            value: _amountText(row.sum, som, isRestaurantLayout),
          ),
    ];
    final discountSummary = <({String label, String value})>[
      if (discount > 0)
        (
          label: design.discountLabel,
          value: _amountText(discount, som, isRestaurantLayout),
        ),
    ];
    final summaryRows = [...paymentSummary, ...discountSummary];
    final totalRow = (
      label: design.totalLabel,
      value: _amountText(totalSum, som, isRestaurantLayout),
    );
    final cols = summaryRows.isEmpty
        ? ThermalReceiptLineWrap.equalsColumnWidths([totalRow])
        : ThermalReceiptLineWrap.equalsColumnWidths([...summaryRows, totalRow]);

    return [
      if (paymentSummary.isNotEmpty)
        ..._buildSummaryLines(
          paymentSummary,
          textStyle.copyWith(fontWeight: FontWeight.w700),
          labelWidth: cols.labelWidth,
          valueWidth: cols.valueWidth,
          bold: true,
        ),
      if (discountSummary.isNotEmpty) ...[
        if (paymentSummary.isNotEmpty) const SizedBox(height: 4),
        ..._buildSummaryLines(
          discountSummary,
          textStyle.copyWith(fontWeight: FontWeight.w700),
          labelWidth: cols.labelWidth,
          valueWidth: cols.valueWidth,
          bold: true,
        ),
      ],
      if (design.showItemSeparator) ...[
        const SizedBox(height: 4),
        Text(
          ThermalReceiptLineWrap.fullSeparator(kReceiptPreviewChars,
              from: design.itemSeparator),
          style: textStyle.copyWith(fontSize: 11, letterSpacing: 0),
          softWrap: false,
          overflow: TextOverflow.clip,
        ),
      ],
      const SizedBox(height: 4),
      ..._buildSummaryLines(
        [totalRow],
        headerStyle.copyWith(
            fontSize: 16, fontWeight: FontWeight.w800, height: 1.35),
        labelWidth: cols.labelWidth,
        valueWidth: cols.valueWidth,
        bold: true,
      ),
      if (!isRestaurantLayout &&
          totalWeightKg != null &&
          totalWeightKg > 0) ...[
        const SizedBox(height: 4),
        Text(
          'Jami og\'irlik: ${ProductWeight.formatKg(totalWeightKg)}',
          style: textStyle.copyWith(fontSize: 12, color: Colors.grey.shade800),
          softWrap: false,
        ),
      ],
    ];
  }

  static List<Widget> _buildSummaryLines(
    List<({String label, String value})> rows,
    TextStyle style, {
    bool bold = false,
    int? labelWidth,
    int? valueWidth,
  }) {
    if (rows.isEmpty) return const [];
    final cols = labelWidth != null && valueWidth != null
        ? (labelWidth: labelWidth, valueWidth: valueWidth)
        : ThermalReceiptLineWrap.equalsColumnWidths(rows);
    final textStyle =
        bold ? style.copyWith(fontWeight: FontWeight.w700) : style;
    return [
      for (final row in rows)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Text(
            '${row.label.padRight(cols.labelWidth)} - ${row.value.padLeft(cols.valueWidth)}',
            style: textStyle,
            softWrap: false,
          ),
        ),
    ];
  }

  static String _amountText(int amount, String som, bool restaurantLayout) {
    final formatted = _fmt(amount);
    return restaurantLayout ? formatted : '$formatted $som';
  }

  static Widget _restaurantProductLineWidget(
      ReceiptRow row, TextStyle textStyle) {
    final qty = _normalizeQty(row.quantityStr);
    if (row.hasUnitDiscount) {
      return Text.rich(
        TextSpan(
          style: textStyle,
          children: [
            TextSpan(text: '$qty x '),
            TextSpan(
                text: '${_fmt(row.catalogPrice!)}',
                style: _strikeStyle(textStyle)),
            TextSpan(text: ' ${_fmt(row.price)}=${_fmt(row.sum)}'),
          ],
        ),
        softWrap: false,
      );
    }
    return Text(
      '$qty x ${_fmt(row.price)}=${_fmt(row.sum)}',
      style: textStyle,
      softWrap: false,
    );
  }

  static Widget _productPriceLine(
      ReceiptRow row, TextStyle textStyle, String som) {
    final qty = _normalizeQty(row.quantityStr);
    if (row.hasUnitDiscount) {
      return Text.rich(
        TextSpan(
          style: textStyle,
          children: [
            TextSpan(text: '$qty x '),
            TextSpan(
                text: '${_fmt(row.catalogPrice!)}',
                style: _strikeStyle(textStyle)),
            TextSpan(text: ' ${_fmt(row.price)} $som'),
          ],
        ),
      );
    }
    return Text('$qty x ${_fmt(row.price)} $som', style: textStyle);
  }

  static Widget _productSumColumn(
      ReceiptRow row, TextStyle textStyle, String som) {
    return Text(
      '${_fmt(row.sum)} $som',
      style: textStyle,
      textAlign: TextAlign.right,
      maxLines: 1,
      overflow: TextOverflow.visible,
      softWrap: false,
    );
  }
}

class _BarcodeStrip extends StatelessWidget {
  final String data;
  final double width;

  const _BarcodeStrip({required this.data, required this.width});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, 56),
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
