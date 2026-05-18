import '../models/cart_item.dart';
import 'cart_discount_percent.dart';

/// Desktop «Chegirma»: mijoz to‘layotgan summa → qoldiq chegirma savat qatorlariga taqsimlanadi.
class CartPaymentDiscount {
  CartPaymentDiscount._();

  /// [weights] — har qator joriy summa; qaytadi har qatorga tushadigan chegirma (so‘m).
  /// Yig‘indi aniq [discountTotal] ga teng (qoldiqsiz).
  static List<int> distributeDiscount(List<int> weights, int discountTotal) {
    if (discountTotal <= 0 || weights.isEmpty) {
      return List.filled(weights.length, 0);
    }
    final sum = weights.fold<int>(0, (a, b) => a + b);
    if (sum <= 0) return List.filled(weights.length, 0);

    final floors = <int>[];
    final fractions = <double>[];
    var allocated = 0;
    for (final w in weights) {
      final exact = discountTotal * w / sum;
      final floor = exact.floor();
      floors.add(floor);
      fractions.add(exact - floor);
      allocated += floor;
    }

    var leftover = discountTotal - allocated;
    if (leftover > 0) {
      final order = List.generate(weights.length, (i) => i)
        ..sort((a, b) => fractions[b].compareTo(fractions[a]));
      for (var k = 0; k < leftover; k++) {
        floors[order[k % order.length]]++;
      }
    }

    assert(floors.fold<int>(0, (a, b) => a + b) == discountTotal);
    return floors;
  }

  /// Joriy savat narxlari bo‘yicha [amountPaidUzs] ga moslab qatorlarni yangilaydi.
  static void applyCustomerPayment(List<CartItem> items, int amountPaidUzs) {
    if (items.isEmpty) return;

    for (final item in items) {
      CartDiscountPercent.syncBaseFromCurrent(item);
    }

    final lineTotals = items.map((e) => e.total).toList();
    final cartTotal = lineTotals.fold<int>(0, (a, b) => a + b);
    if (cartTotal <= 0) return;

    final paid = amountPaidUzs.clamp(0, cartTotal);

    if (paid >= cartTotal) {
      for (final item in items) {
        CartDiscountPercent.applyToItem(item, 0);
      }
      return;
    }

    final discountTotal = cartTotal - paid;
    final allocations = distributeDiscount(lineTotals, discountTotal);

    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final qty = item.quantity.toDouble();
      if (qty <= 0) continue;
      final newLineTotal = lineTotals[i] - allocations[i];
      item.salePriceOverride = newLineTotal / qty;
    }

    _fixRoundingDrift(items, paid);
  }

  static void _fixRoundingDrift(List<CartItem> items, int targetTotal) {
    var sum = items.fold<int>(0, (s, e) => s + e.total);
    var diff = targetTotal - sum;
    if (diff == 0 || items.isEmpty) return;

    final idx = items.length - 1;
    final item = items[idx];
    final qty = item.quantity.toDouble();
    if (qty <= 0) return;

    final adjustedLine = item.total + diff;
    if (adjustedLine < 0) return;
    item.salePriceOverride = adjustedLine / qty;

    sum = items.fold<int>(0, (s, e) => s + e.total);
    diff = targetTotal - sum;
    if (diff != 0 && items.length > 1) {
      final first = items.first;
      final q = first.quantity.toDouble();
      if (q > 0) {
        first.salePriceOverride = (first.total + diff) / q;
      }
    }
  }
}
