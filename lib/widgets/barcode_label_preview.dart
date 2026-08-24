import 'package:barcode/barcode.dart';
import 'package:flutter/material.dart';

import '../models/barcode_label_config.dart';
import '../models/product.dart';
import '../utils/barcode_label_format.dart';

/// Shtrix kod yorlig‘i — preview va chop etish bir xil ko‘rinish.
class BarcodeLabelPreview extends StatelessWidget {
  const BarcodeLabelPreview({
    super.key,
    required this.product,
    required this.barcode,
    required this.config,
    this.border = false,
  });

  final Product product;
  final String barcode;
  final BarcodeLabelConfig config;
  final bool border;

  static String labelPriceText(Product product) =>
      BarcodeLabelFormat.labelPriceText(product);

  String get _headerText => switch (config.template) {
        BarcodeLabelTemplate.standard => labelPriceText(product),
        BarcodeLabelTemplate.shopName =>
          config.shopName.trim().isNotEmpty ? config.shopName.trim() : 'Do‘kon nomi',
      };

  static ({Barcode barcode, String payload}) resolveBarcode(String data) {
    final raw = data.trim();
    final digits = raw.replaceAll(RegExp(r'\D'), '');

    final ean13 = Barcode.ean13();
    if ((digits.length == 12 || digits.length == 13) && ean13.isValid(digits)) {
      return (barcode: ean13, payload: digits);
    }
    final ean8 = Barcode.ean8();
    if ((digits.length == 7 || digits.length == 8) && ean8.isValid(digits)) {
      return (barcode: ean8, payload: digits);
    }
    final code128 = Barcode.code128();
    final payload = code128.isValid(raw)
        ? raw
        : (digits.isNotEmpty && code128.isValid(digits) ? digits : raw);
    return (barcode: code128, payload: payload);
  }

  @override
  Widget build(BuildContext context) {
    final resolved = resolveBarcode(barcode);
    final payload = resolved.payload;
    final bc = resolved.barcode;

    final body = ColoredBox(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                _headerText,
                maxLines: 2,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: config.template == BarcodeLabelTemplate.shopName ? 14 : 22,
                  fontWeight: FontWeight.w900,
                  color: Colors.black,
                  height: 1.05,
                  letterSpacing: config.template == BarcodeLabelTemplate.shopName ? 0 : -0.5,
                ),
              ),
            ),
            const SizedBox(height: 3),
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: 2.8,
                  child: _BarcodeBars(data: payload, barcode: bc),
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              barcode,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Colors.black,
                letterSpacing: 0.6,
                height: 1.0,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              product.name.toUpperCase(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: Colors.black,
                height: 1.08,
              ),
            ),
          ],
        ),
      ),
    );

    if (!border) return SizedBox.expand(child: body);

    return SizedBox.expand(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.black26),
          borderRadius: BorderRadius.circular(4),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: body,
        ),
      ),
    );
  }
}

class _BarcodeBars extends StatelessWidget {
  const _BarcodeBars({
    required this.data,
    required this.barcode,
  });

  final String data;
  final Barcode barcode;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _BarcodePainter(data: data, barcode: barcode),
      child: const SizedBox.expand(),
    );
  }
}

class _BarcodePainter extends CustomPainter {
  _BarcodePainter({
    required this.data,
    required this.barcode,
  });

  final String data;
  final Barcode barcode;

  @override
  void paint(Canvas canvas, Size size) {
    if (!barcode.isValid(data) || size.width <= 0 || size.height <= 0) return;

    final elements = barcode.make(
      data,
      width: size.width,
      height: size.height,
      drawText: false,
    );

    var minL = size.width;
    var maxR = 0.0;
    for (final e in elements) {
      if (e is! BarcodeBar || !e.black) continue;
      minL = minL < e.left ? minL : e.left;
      maxR = maxR > e.left + e.width ? maxR : e.left + e.width;
    }
    if (maxR <= minL) return;

    final barW = maxR - minL;
    final offsetX = (size.width - barW) / 2 - minL;

    final paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill
      ..isAntiAlias = false;

    for (final element in elements) {
      if (element is! BarcodeBar || !element.black) continue;
      canvas.drawRect(
        Rect.fromLTWH(
          element.left + offsetX,
          0,
          element.width.clamp(1.0, size.width),
          size.height,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BarcodePainter oldDelegate) =>
      oldDelegate.data != data || oldDelegate.barcode != barcode;
}
