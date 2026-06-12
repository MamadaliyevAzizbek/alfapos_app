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

    for (final item in allItems) {
      if (!sameStockProduct(item.product, product)) continue;

      if (replaceLine != null && identical(item, replaceLine)) {
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
