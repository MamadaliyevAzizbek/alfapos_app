import '../models/cart_item.dart';

/// Savatdagi «Foiz qo'shish» — har qator chegirmali narxiga (+ qo'shadi, - ayiradi).
class CartDiscountPercent {
  CartDiscountPercent._();

  static const int roundStepUzs = 1000;

  /// Foizdan keyingi narx: **+** foiz → [roundStepUzs] ga **yuqoriga**, **−** foiz → **pastga**.
  static int roundPercentPrice(double uzs, num percent) {
    if (uzs <= 0) return 0;
    if (percent > 0) {
      return (uzs / roundStepUzs).ceil() * roundStepUzs;
    }
    if (percent < 0) {
      return (uzs / roundStepUzs).floor() * roundStepUzs;
    }
    return (uzs / roundStepUzs).round() * roundStepUzs;
  }

  @Deprecated('Use roundPercentPrice(uzs, percent)')
  static int roundToThousand(double uzs) => roundPercentPrice(uzs, 0);

  static double baseUnitPrice(CartItem item) {
    return item.unitPriceBaseForCartPercent ?? item.defaultLineUnitPrice.toDouble();
  }

  static void syncBaseFromCurrent(CartItem item) {
    item.unitPriceBaseForCartPercent = item.unitPriceForLine;
  }

  static void initNewItem(CartItem item) {
    item.unitPriceBaseForCartPercent = item.defaultLineUnitPrice.toDouble();
    applyToItem(item, 0);
  }

  /// Mijoz guruhi narx bazasidan keyin — savat foizini ustiga qo'shish (bazani qayta yozmaydi).
  static void afterCustomerPricing(List<CartItem> items, int percent) {
    applyToItems(items, percent);
  }

  static void applyToItems(List<CartItem> items, int percent) {
    for (final item in items) {
      applyToItem(item, percent);
    }
  }

  static void applyToItem(CartItem item, int percent) {
    final base = baseUnitPrice(item);
    item.unitPriceBaseForCartPercent = base;
    if (percent == 0) {
      final catalogSell = item.defaultLineUnitPrice.toDouble();
      final typedBase = item.unitPriceBaseForCartPercent;
      // Mijoz guruhi: kelish/ulgurji bazasi — savat foizi 0 bo'lsa ham saqlanadi
      final keepCustomerPricing = typedBase != null && (typedBase - catalogSell).abs() >= 0.5;
      if (keepCustomerPricing) return;
      if ((base - catalogSell).abs() < 0.5) {
        item.salePriceOverride = null;
      } else {
        item.salePriceOverride = base;
      }
      return;
    }
    final raw = base * (100 + percent) / 100;
    item.salePriceOverride = roundPercentPrice(raw, percent).toDouble();
  }

  /// Qo'lda «Chegirmali narx» o'zgartirilganda.
  static void onManualUnitPrice(CartItem item, double? override, int currentPercent) {
    if (override == null) {
      item.unitPriceBaseForCartPercent = item.defaultLineUnitPrice.toDouble();
      applyToItem(item, currentPercent);
      return;
    }
    if (currentPercent == 0) {
      item.unitPriceBaseForCartPercent = override;
      item.salePriceOverride = override;
    } else {
      final factor = (100 + currentPercent) / 100;
      item.unitPriceBaseForCartPercent = override / factor;
      item.salePriceOverride = override;
    }
  }

  static int catalogLinesTotal(Iterable<CartItem> items) {
    return items.fold<int>(0, (s, e) => s + (e.defaultLineUnitPrice * e.quantity).round());
  }

  /// UI chegirma foizi (0–100) → ichki format (−100…0).
  static int discountPercentFromUi(int uiPercent) {
    if (uiPercent <= 0) return 0;
    return -uiPercent.clamp(0, 100);
  }

  /// Ichki foiz (−100…0) → UI ko‘rinishi (0–100).
  static int discountPercentToUi(int internalPercent) {
    if (internalPercent >= 0) return 0;
    return internalPercent.abs().clamp(0, 100);
  }

  /// UI foizi bo‘yicha taxminiy chegirma summasi (so‘m).
  static int previewDiscountUzs(int cartTotal, int uiPercent) {
    if (uiPercent <= 0 || cartTotal <= 0) return 0;
    final internal = discountPercentFromUi(uiPercent);
    final newTotal = roundPercentPrice(cartTotal * (100 + internal) / 100.0, internal);
    return cartTotal - newTotal;
  }
}
