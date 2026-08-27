import '../models/cart_item.dart';

/// Aralash / oddiy to'lov hisobi — test qilinadigan.
class PaymentCheckoutMath {
  PaymentCheckoutMath._();

  static num quantize(num value) =>
      CartItem.quantizeLineTotal(value.toDouble());

  /// Kiritilgan summalarni jami limit bo'yicha taqsimlash.
  static Map<String, num> allocate({
    required Map<String, num> entered,
    required List<String> keyOrder,
    required num totalAfterDiscount,
    int clientBalanceCap = 0x7FFFFFFF,
    bool Function(String key)? isClientBalance,
    bool Function(String key)? isTolovsiz,
  }) {
    final out = <String, num>{};
    var remaining = totalAfterDiscount.toDouble();
    for (final key in keyOrder) {
      final raw = (entered[key] ?? 0).toDouble();
      if (raw <= 0 || remaining <= 0) continue;
      var take = raw > remaining ? remaining : raw;
      if (isClientBalance != null &&
          isTolovsiz != null &&
          isClientBalance(key) &&
          !isTolovsiz(key) &&
          take > clientBalanceCap) {
        take = clientBalanceCap.toDouble();
      }
      if (take <= 0) continue;
      out[key] = take;
      remaining -= take;
    }
    return out;
  }

  static num sumValues(Map<String, num> values) =>
      values.values.fold<num>(0, (s, e) => s + e);

  static bool coversTotal({required num paid, required num total}) {
    return quantize(paid) >= quantize(total);
  }

  static num remaining({required num total, required num paid}) {
    final rem = total - paid;
    if (rem <= 0) return 0;
    return quantize(rem);
  }

  static bool canComplete({
    required num totalAfterDiscount,
    required num paid,
  }) {
    return paid > 0 && coversTotal(paid: paid, total: totalAfterDiscount);
  }
}
