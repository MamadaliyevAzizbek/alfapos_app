import '../models/product.dart';

/// Shtrix yorliq matnlari — barcode paketisiz (tez import).
class BarcodeLabelFormat {
  BarcodeLabelFormat._();

  static String labelPriceText(Product product) {
    if (product.sellingPriceCurrency.toLowerCase() == 'usd') {
      final v = (product.sellingPriceApi ?? product.priceUzs).toDouble();
      return v == v.roundToDouble() ? '${v.round()}' : v.toStringAsFixed(2);
    }
    return _commaThousands(product.priceUzs);
  }

  static String _commaThousands(int n) {
    final s = n.abs().toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return n < 0 ? '-$buf' : buf.toString();
  }
}
