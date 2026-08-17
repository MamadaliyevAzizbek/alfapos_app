import '../models/cart_item.dart';
import '../models/product.dart';
import '../providers/cart_provider.dart';

/// Savatga qo‘shishda ombor miqdorini tekshirish.
abstract final class CartStockLimit {
  static const String message = 'Mahsulot omborda yetarli emas';

  static bool sameStockProduct(Product a, Product b) {
    if (a.id != b.id) return false;
    final va = a.variantId;
    final vb = b.variantId;
    if (va == null && vb == null) return true;
    if (va == null || vb == null) return va == vb;
    return va == vb;
  }

  static int piecesForQuantity(Product product, num quantity, bool sellByPack) {
    if (sellByPack && product.canSellByPack) {
      return (quantity * product.quantityPerPack).round();
    }
    return quantity.round();
  }

  /// [allItems] nusxalardan tuzilgan bo‘lsa (desktop sotuv oynalari snapshot’i
  /// `CartItem.copy()` qaytaradi), `identical` mos kelmaydi va o‘zgartirilayotgan
  /// qator ikki marta hisoblanib ketadi. Shuning uchun aynan bitta mos qator
  /// bo‘lsa, qiymat bo‘yicha ham topamiz.
  static CartItem? _resolveReplaceLine(List<CartItem> allItems, CartItem? replaceLine) {
    if (replaceLine == null) return null;
    for (final item in allItems) {
      if (identical(item, replaceLine)) return replaceLine;
    }
    CartItem? single;
    for (final item in allItems) {
      if (!CartProvider.isSameCartLine(item, replaceLine)) continue;
      if (single != null) return null;
      single = item;
    }
    return single;
  }

  static int projectedTotalPieces({
    required List<CartItem> allItems,
    required Product product,
    CartItem? replaceLine,
    num? replaceQuantity,
    bool? replaceSellByPack,
    num? addQuantity,
    bool addSellByPack = false,
  }) {
    var total = 0;
    var replaced = replaceLine == null;
    var mergedAdd = addQuantity == null;
    final replaceTarget = _resolveReplaceLine(allItems, replaceLine);

    for (final item in allItems) {
      if (!sameStockProduct(item.product, product)) continue;

      if (replaceTarget != null && identical(item, replaceTarget)) {
        final qty = replaceQuantity ?? item.quantity;
        final byPack = replaceSellByPack ?? item.sellByPack;
        total += piecesForQuantity(product, qty, byPack);
        replaced = true;
        continue;
      }

      if (addQuantity != null &&
          !mergedAdd &&
          CartProvider.isSameCartLine(
            item,
            CartItem(product: product, quantity: addQuantity, sellByPack: addSellByPack),
          )) {
        total += piecesForQuantity(product, item.quantity + addQuantity, addSellByPack);
        mergedAdd = true;
        continue;
      }

      total += item.quantityToDeduct;
    }

    if (replaceLine != null && !replaced) {
      final qty = replaceQuantity ?? replaceLine.quantity;
      final byPack = replaceSellByPack ?? replaceLine.sellByPack;
      total += piecesForQuantity(product, qty, byPack);
    }

    if (addQuantity != null && !mergedAdd) {
      total += piecesForQuantity(product, addQuantity, addSellByPack);
    }

    return total;
  }

  static bool allowsAdd({
    required Product product,
    required List<CartItem> allItems,
    num addQuantity = 1,
    bool sellByPack = false,
  }) {
    final available = product.availableStockQuantity;
    if (available <= 0) return false;
    final projected = projectedTotalPieces(
      allItems: allItems,
      product: product,
      addQuantity: addQuantity,
      addSellByPack: sellByPack,
    );
    return projected <= available;
  }

  /// Qatorga ruxsat etilgan eng katta miqdor — [sellByPack] bo‘yicha dona yoki
  /// pachkada. Ombordagi qoldiqdan boshqa qatorlar (desktopda boshqa sotuv
  /// oynalari ham) egallagan dona soni ayiriladi. Qoldiq bo‘lmasa 0.
  static num maxLineQuantity({
    required Product product,
    required List<CartItem> allItems,
    required CartItem line,
    bool? sellByPack,
  }) {
    final available = product.availableStockQuantity;
    if (available <= 0) return 0;
    final otherLines = projectedTotalPieces(
      allItems: allItems,
      product: product,
      replaceLine: line,
      replaceQuantity: 0,
      replaceSellByPack: sellByPack,
    );
    final remaining = available - otherLines;
    if (remaining <= 0) return 0;
    final byPack = (sellByPack ?? line.sellByPack) && product.canSellByPack;
    if (!byPack || product.quantityPerPack <= 0) return remaining;
    return remaining ~/ product.quantityPerPack;
  }

  static bool allowsLineQuantity({
    required Product product,
    required List<CartItem> allItems,
    required CartItem line,
    required num newQuantity,
    bool? sellByPack,
  }) {
    if (newQuantity <= 0) return true;
    final available = product.availableStockQuantity;
    if (available <= 0) return false;
    final projected = projectedTotalPieces(
      allItems: allItems,
      product: product,
      replaceLine: line,
      replaceQuantity: newQuantity,
      replaceSellByPack: sellByPack,
    );
    return projected <= available;
  }
}
