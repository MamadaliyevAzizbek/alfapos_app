import '../models/cart_item.dart';
import '../models/product.dart';
import '../providers/clients_provider.dart';
import '../utils/customer_groups_list.dart';
import '../utils/customer_store_body.dart';
import 'cart_discount_percent.dart';

/// Mijoz guruhi: narx turi + foiz.
/// **−** foiz → chegirma (narxdan ayirish), **+** foiz → ustiga qo'shish.
/// Mahsulotning katalog (asl) narxi o'zgarmaydi — faqat [CartItem.salePriceOverride].
class CustomerGroupDiscount {
  CustomerGroupDiscount._();

  static const selling = 'selling';
  static const purchase = 'purchase';
  static const wholesale = 'wholesale';

  static Map<String, dynamic>? _groupById(int? id, List<Map<String, dynamic>> groups) {
    if (id == null) return null;
    for (final g in groups) {
      if (CustomerGroupsListParser.groupIdFrom(g) == id) return g;
    }
    return null;
  }

  static num? discountPercentFromClient(
    Client? c, {
    List<Map<String, dynamic>> groups = const [],
  }) {
    if (c == null) return null;
    final fromClient = c.customerGroupDiscount;
    if (fromClient != null && fromClient != 0) return fromClient;

    final grp = _groupById(c.customerGroupId, groups);
    if (grp != null) {
      final gd = CustomerGroupsListParser.groupDiscount(grp);
      if (gd != 0) return gd;
    }
    return null;
  }

  static String? priceTypeFromClient(
    Client? c, {
    List<Map<String, dynamic>> groups = const [],
  }) {
    if (c == null) return null;
    final fromClient = c.customerGroupDiscountPriceType?.trim();
    if (fromClient != null && fromClient.isNotEmpty) {
      return _normalizePriceType(fromClient);
    }
    final grp = _groupById(c.customerGroupId, groups);
    if (grp != null) {
      final fromGroup = CustomerStoreBody.priceTypeFromGroup(grp);
      if (fromGroup != null && fromGroup.isNotEmpty) {
        return _normalizePriceType(fromGroup);
      }
    }
    return null;
  }

  /// [percent]: −10 = 10% chegirma, +10 = 10% ustiga qo'shish.
  static double applyPercentToUnitPrice(double base, num percent) {
    if (percent == 0) return base;
    final raw = base * (100 + percent) / 100;
    return CartDiscountPercent.roundPercentPrice(raw, percent).toDouble();
  }

  static String? _normalizePriceType(String raw) {
    final k = raw.toLowerCase().replaceAll(' ', '_').replaceAll('-', '_');
    if (k == selling || k == 'sell' || k == 'sale' || k == 'sotish' || k == 'sotish_narxi') {
      return selling;
    }
    if (k == purchase ||
        k == 'cost' ||
        k == 'buying' ||
        k == 'buy' ||
        k == 'kelish' ||
        k == 'kelish_narxi' ||
        k == 'receiving') {
      return purchase;
    }
    if (k == wholesale || k == 'ulgurji' || k == 'ulgurji_narx' || k == 'whole_sale') {
      return wholesale;
    }
    return k;
  }

  /// Tanlangan narx turi bo'yicha 1 dona / 1 pachka bazasi (katalog Product o'zgarmaydi).
  static num catalogUnitPriceForItem(CartItem item, String priceType) {
    final p = item.product;
    final type = _normalizePriceType(priceType) ?? selling;

    switch (type) {
      case purchase:
        if (item.sellByPack && p.canSellByPack) {
          final pack = p.purchasePackUnitPriceNum;
          if (pack != null && pack > 0) return pack;
        }
        final cost = p.costPriceUzs;
        if (cost != null && cost > 0) return cost;
        return item.defaultLineUnitPrice;
      case wholesale:
        if (item.sellByPack && p.canSellByPack) {
          final pack = p.wholesalePackUnitPriceNum;
          if (pack != null && pack > 0) return pack;
        }
        return p.wholesalePiecePriceNum;
      case selling:
      default:
        return item.defaultLineUnitPrice;
    }
  }

  static void applyCustomerPricingToCart(
    List<CartItem> items,
    Client? client, {
    List<Map<String, dynamic>> groups = const [],
  }) {
    if (client == null) {
      clearCustomerPricingFromCart(items);
      return;
    }

    final resolvedGroups = groups.isNotEmpty ? groups : ClientsProvider.instance.cachedCustomerGroups;
    final priceType = priceTypeFromClient(client, groups: resolvedGroups);
    final percent = discountPercentFromClient(client, groups: resolvedGroups);

    for (final item in items) {
      // Qo‘lda / tiklangan chegirmali narxni mijoz guruhi o‘chirib yubormasin.
      if (item.priceLocked) continue;

      final normalizedType =
          priceType != null ? (_normalizePriceType(priceType) ?? selling) : selling;
      final base = catalogUnitPriceForItem(item, normalizedType).toDouble();

      // Savat foizi shu narx turi bazasidan (kelish / sotish / ulgurji)
      item.unitPriceBaseForCartPercent = base;

      if (percent != null && percent != 0) {
        item.salePriceOverride = applyPercentToUnitPrice(base, percent);
      } else if (normalizedType != selling) {
        // Foiz 0 bo'lsa ham tanlangan narx turi (masalan kelish)
        item.salePriceOverride = base;
      } else {
        item.salePriceOverride = null;
      }
    }
  }

  static void clearCustomerPricingFromCart(List<CartItem> items) {
    for (final item in items) {
      if (item.priceLocked) continue;
      item.salePriceOverride = null;
      item.unitPriceBaseForCartPercent = item.defaultLineUnitPrice.toDouble();
    }
  }

  @Deprecated('Use applyCustomerPricingToCart')
  static void applyToCart(List<CartItem> items, num percent) {
    if (percent == 0) return;
    for (final item in items) {
      final base = item.defaultLineUnitPrice.toDouble();
      item.salePriceOverride = applyPercentToUnitPrice(base, percent);
    }
  }
}
