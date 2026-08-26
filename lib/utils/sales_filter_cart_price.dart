import '../models/cart_item.dart';
import '../providers/sales_session_provider.dart';
import 'customer_group_discount.dart';

/// Sotuv filtri: ulgurji / kelish narxida savatga qo'shish (chegirmali narx).
class SalesFilterCartPrice {
  SalesFilterCartPrice._();

  static void applySessionPriceToItem(CartItem item, SalesSessionProvider sales) {
    if (item.priceLocked) return;
    final type = sales.activeSellPriceType;
    if (type == null) {
      item.salePriceOverride = null;
      item.unitPriceBaseForCartPercent = item.defaultLineUnitPrice.toDouble();
      return;
    }
    final base = CustomerGroupDiscount.catalogUnitPriceForItem(item, type).toDouble();
    item.unitPriceBaseForCartPercent = base;
    item.salePriceOverride = base;
  }

  static void applySessionPriceToCart(
    Iterable<CartItem> items,
    SalesSessionProvider sales,
  ) {
    for (final item in items) {
      applySessionPriceToItem(item, sales);
    }
  }
}
