import '../models/cart_item.dart';
import '../models/product.dart';

/// Mahsulot `weight` maydoni (kg) — product-weight-api.md.
abstract final class ProductWeight {
  /// Qop birligi uchun standart 1 qop og'irligi (kg). To'ldirish shart emas.
  static const double defaultKgPerQop = 40;

  static double? parse(dynamic value) {
    if (value == null) return null;
    if (value is num) {
      final d = value.toDouble();
      return d < 0 ? null : double.parse(d.toStringAsFixed(3));
    }
    final s = value.toString().trim().replaceAll(',', '.');
    if (s.isEmpty) return null;
    final d = double.tryParse(s);
    if (d == null || d < 0) return null;
    return double.parse(d.toStringAsFixed(3));
  }

  static String formatKg(double kg) {
    if (kg <= 0) return '0 kg';
    var s = kg.toStringAsFixed(3);
    s = s.replaceFirst(RegExp(r'\.?0+$'), '');
    if (s.isEmpty) return '0 kg';
    return '$s kg';
  }

  static double pieceCount(Product product, num quantity, {bool sellByPack = false}) {
    if (sellByPack && product.canSellByPack) {
      return quantity.toDouble() * product.quantityPerPack;
    }
    return quantity.toDouble();
  }

  static double? lineKg(Product product, num quantity, {bool sellByPack = false}) {
    final unit = product.weightKg;
    if (unit == null || unit <= 0) return null;
    final pieces = pieceCount(product, quantity, sellByPack: sellByPack);
    if (pieces <= 0) return null;
    return double.parse((unit * pieces).toStringAsFixed(3));
  }

  static double? lineKgFromCartItem(CartItem item) =>
      lineKg(item.product, item.quantity, sellByPack: item.sellByPack);

  static double? lineKgFromUnit(double? unitKg, num quantity) {
    if (unitKg == null || unitKg <= 0 || quantity <= 0) return null;
    return double.parse((unitKg * quantity.toDouble()).toStringAsFixed(3));
  }

  static double? totalKgFromCart(Iterable<CartItem> items) {
    var total = 0.0;
    var hasAny = false;
    for (final item in items) {
      final w = lineKgFromCartItem(item);
      if (w == null || w <= 0) continue;
      total += w;
      hasAny = true;
    }
    if (!hasAny) return null;
    return double.parse(total.toStringAsFixed(3));
  }

  /// 1 qop = [weightKg] yoki, bo'sh bo'lsa, [defaultKgPerQop] (40 kg).
  static double kgPerQopFor(Product? product, {double? fallbackWeightKg}) {
    final w = product?.weightKg ?? fallbackWeightKg;
    if (w != null && w > 0) return w;
    return defaultKgPerQop;
  }

  /// Qop birlikli mahsulot: savatchada kg kiritiladi, chekda qop + qoldiq kg.
  /// Standart: 1 qop = 40 kg. Masalan: 40 → "1 qop"; 35 → "35 kg"; 85 → "2 qop 5 kg".
  static String formatQopReceiptQuantity(num kgQuantity, [double kgPerQop = defaultKgPerQop]) {
    final per = kgPerQop > 0 ? kgPerQop : defaultKgPerQop;
    final kg = kgQuantity.toDouble();
    if (kg <= 0) return formatKg(0);
    if (kg < per - 1e-9) return formatKg(kg);

    var fullQops = (kg / per).floor();
    var remainder = double.parse((kg - fullQops * per).toStringAsFixed(3));
    if (remainder >= per - 1e-9) {
      fullQops += 1;
      remainder = 0;
    }
    if (remainder <= 1e-9) return '$fullQops qop';
    return '$fullQops qop ${formatKg(remainder)}';
  }

  static String cartItemQuantityLabel(CartItem item) {
    if (item.sellByPack) return '${_plainQuantity(item.quantity)} pachka';
    final p = item.product;
    if (Product.isQopUnit(p.unit)) {
      return formatQopReceiptQuantity(item.quantity, kgPerQopFor(p));
    }
    final unitLabel = Product.unitDisplayShort(p.unit);
    return '${_plainQuantity(item.quantity)} $unitLabel';
  }

  static String invoiceRowQuantityLabel(
    Map<String, dynamic> row, {
    Product? catalogProduct,
  }) {
    final qtyNum = parseInvoiceQtyNum(row);
    final unitRaw = (row['unit_name'] ??
            row['unit'] ??
            row['unitName'] ??
            row['measure'] ??
            '')
        .toString()
        .trim();
    final unit = catalogProduct?.unit ?? unitRaw;
    final rowWeight = parse(row['weight'] ?? row['product_weight'] ?? row['weight_kg']);

    if (Product.isQopUnit(unit)) {
      return formatQopReceiptQuantity(
        qtyNum,
        kgPerQopFor(catalogProduct, fallbackWeightKg: rowWeight),
      );
    }

    final qty = (row['quantity'] ?? row['qty'] ?? '').toString().trim();
    if (qty.isEmpty) return '—';
    if (unitRaw.isEmpty) return qty;
    return '$qty $unitRaw';
  }

  static num parseInvoiceQtyNum(Map<String, dynamic> r) {
    final raw = (r['quantity'] ?? r['qty'] ?? '1').toString().trim();
    final first = raw.split(RegExp(r'\s+')).first.replaceAll(',', '.');
    return num.tryParse(first) ?? 1;
  }

  static String _plainQuantity(num q) {
    if (q == q.roundToDouble()) return q.toInt().toString();
    return q.toString();
  }
}
