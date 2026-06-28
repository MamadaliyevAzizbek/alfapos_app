import 'dart:io';

import 'package:flutter/material.dart';

import '../core/input_formatters.dart';
import '../models/receipt_design_config.dart';
import '../utils/receipt_store_title.dart';
import '../utils/thermal_receipt_large_text.dart';
import '../utils/thermal_receipt_formatter.dart';
import '../utils/thermal_receipt_line_wrap.dart';
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

  const ReceiptRow({
    required this.productName,
    required this.quantityStr,
    required this.price,
    required this.sum,
    this.catalogPrice,
    this.catalogSum,
  });

  bool get hasUnitDiscount =>
      catalogPrice != null && catalogPrice! > price;

  bool get hasSumDiscount =>
      catalogSum != null && catalogSum! > sum;
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
  });

  static String _fmt(int n) => formatThousandsComma(n);

  String get _displayTitle =>
      ReceiptStoreTitle.resolve(design: design, branchName: branchName);

  List<String> toThermalPrintLines() {
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
        isPrecheck: isPrecheck,
        products: productRows
            .map(
              (r) => ThermalReceiptProductLine(
                name: r.productName,
                quantity: r.quantityStr,
                unitPrice: _fmt(r.price),
                lineTotal: _fmt(r.sum),
                catalogUnitPrice: r.hasUnitDiscount ? _fmt(r.catalogPrice!) : null,
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
        queueNumber: queueNumber,
        isRestaurantLayout: isRestaurantLayout,
      ),
      config: design,
    );
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
            Center(
              child: ReceiptLogoImage(
                path: design.logoFilePath!,
                height: 56,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 8),
          ],
          Center(
            child: Text(
              _displayTitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade900,
              ),
            ),
          ),
          if (isPrecheck) ...[
            const SizedBox(height: 8),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                style: textStyle,
              ),
            ),
          ],
          if (isRestaurantLayout &&
              !isPrecheck &&
              queueNumber != null &&
              queueNumber! > 0 &&
              design.showRestaurantQueueNumber) ...[
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
                  fontSize: isRestaurantLayout ? 42 : ThermalReceiptLargeText.onScreenFontSize,
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
          const SizedBox(height: 6),
          Text(
            isPrecheck
                ? "${design.receiptNumberLabel}: to'lov oldin"
                : '${design.receiptNumberLabel}: $receiptNumber',
            style: textStyle,
          ),
          Text('${design.sellerLabel}: $sellerName', style: textStyle),
          if (design.showSellerPhone &&
              sellerPhone != null &&
              sellerPhone!.trim().isNotEmpty)
            Text('${design.sellerPhoneLabel}: ${sellerPhone!.trim()}', style: textStyle),
          if (design.showClientLine &&
              clientName != null &&
              clientName!.trim().isNotEmpty)
            Text('${design.clientLabel}: ${clientName!.trim()}', style: textStyle),
          if (design.showClientPhone &&
              clientPhone != null &&
              clientPhone!.trim().isNotEmpty)
            Text('${design.clientPhoneLabel}: ${clientPhone!.trim()}', style: textStyle),
          if (design.showClientAddress &&
              clientAddress != null &&
              clientAddress!.trim().isNotEmpty)
            Text('${design.clientAddressLabel}: ${clientAddress!.trim()}', style: textStyle),
          if ((description ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('Tavsif: ${description!.trim()}', style: textStyle),
          ],
          const SizedBox(height: 6),
          for (var i = 0; i < productRows.length; i++) ...[
            Text(
              design.numberedProducts
                  ? '${i + 1}) ${productRows[i].productName}'
                  : productRows[i].productName,
              style: headerStyle,
            ),
            if (isRestaurantLayout)
              _restaurantProductLineWidget(productRows[i], textStyle)
            else
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _productPriceLine(productRows[i], textStyle, som)),
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
                ThermalReceiptLineWrap.fullSeparator(42, from: design.itemSeparator),
                style: textStyle.copyWith(fontSize: 11, letterSpacing: 0),
              ),
            ],
            const SizedBox(height: 6),
          ],
          if (!isPrecheck)
            for (final row in paymentRows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Expanded(child: Text(row.methodName, style: textStyle)),
                    Text(
                      _amountText(row.sum, som, isRestaurantLayout),
                      style: textStyle,
                      softWrap: false,
                    ),
                  ],
                ),
              ),
          if (discount > 0) ...[
            Row(
              children: [
                Expanded(child: Text(design.discountLabel, style: textStyle)),
                Text(_amountText(discount, som, isRestaurantLayout), style: textStyle, softWrap: false),
              ],
            ),
            if (design.showItemSeparator) ...[
              const SizedBox(height: 4),
              Text(
                ThermalReceiptLineWrap.fullSeparator(42, from: design.itemSeparator),
                style: textStyle.copyWith(fontSize: 11, letterSpacing: 0),
              ),
            ],
          ] else if (design.showItemSeparator) ...[
            const SizedBox(height: 4),
            Text(
              ThermalReceiptLineWrap.fullSeparator(42, from: design.itemSeparator),
              style: textStyle.copyWith(fontSize: 11, letterSpacing: 0),
            ),
          ],
          Row(
            children: [
              Expanded(
                child: Text(
                  design.totalLabel,
                  style: headerStyle,
                ),
              ),
              Text(
                _amountText(totalSum, som, isRestaurantLayout),
                style: headerStyle,
                softWrap: false,
              ),
            ],
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
    return qty
        .replaceAll('шт', 'dona')
        .replaceAll('Шт', 'dona')
        .replaceAll('×', 'x');
  }

  static TextStyle _strikeStyle(TextStyle base) =>
      base.copyWith(
        decoration: TextDecoration.lineThrough,
        decorationThickness: 2,
        decorationColor: Colors.grey.shade700,
        color: Colors.grey.shade600,
      );

  static String _amountText(int amount, String som, bool restaurantLayout) {
    final formatted = _fmt(amount);
    return restaurantLayout ? formatted : '$formatted $som';
  }

  static Widget _restaurantProductLineWidget(ReceiptRow row, TextStyle textStyle) {
    final qty = _normalizeQty(row.quantityStr);
    if (row.hasUnitDiscount) {
      return Text.rich(
        TextSpan(
          style: textStyle,
          children: [
            TextSpan(text: '$qty x '),
            TextSpan(text: '${_fmt(row.catalogPrice!)}', style: _strikeStyle(textStyle)),
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

  static Widget _productPriceLine(ReceiptRow row, TextStyle textStyle, String som) {
    final qty = _normalizeQty(row.quantityStr);
    if (row.hasUnitDiscount) {
      return Text.rich(
        TextSpan(
          style: textStyle,
          children: [
            TextSpan(text: '$qty x '),
            TextSpan(text: '${_fmt(row.catalogPrice!)}', style: _strikeStyle(textStyle)),
            TextSpan(text: ' ${_fmt(row.price)} $som'),
          ],
        ),
      );
    }
    return Text('$qty x ${_fmt(row.price)} $som', style: textStyle);
  }

  static Widget _productSumColumn(ReceiptRow row, TextStyle textStyle, String som) {
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
