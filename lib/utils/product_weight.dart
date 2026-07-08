import '../models/cart_item.dart';
import '../models/product.dart';

/// Mahsulot `weight` maydoni (kg) — product-weight-api.md.
abstract final class ProductWeight {
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
}
