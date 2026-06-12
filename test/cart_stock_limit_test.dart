import 'package:alfapos_app/models/cart_item.dart';
import 'package:alfapos_app/models/product.dart';
import 'package:alfapos_app/utils/cart_stock_limit.dart';
import 'package:flutter_test/flutter_test.dart';

Product _product({required String id, int stock = 10, int packSize = 5}) {
  return Product(
    id: id,
    name: 'Test',
    priceUzs: 1000,
    initialQuantity: stock,
    quantityInPack: packSize > 1,
    quantityPerPack: packSize,
    sellPricePerPack: packSize > 1 ? 5000 : null,
  );
}

void main() {
  group('CartStockLimit', () {
    test('allowsAdd blocks when stock is zero', () {
      final p = _product(id: '1', stock: 0);
      expect(
        CartStockLimit.allowsAdd(product: p, allItems: const [], addQuantity: 1),
        isFalse,
      );
    });

    test('allowsAdd blocks exceeding available pieces', () {
      final p = _product(id: '1', stock: 10);
      final items = [CartItem(product: p, quantity: 9)];
      expect(
        CartStockLimit.allowsAdd(product: p, allItems: items, addQuantity: 2),
        isFalse,
      );
      expect(
        CartStockLimit.allowsAdd(product: p, allItems: items, addQuantity: 1),
        isTrue,
      );
    });

    test('allowsLineQuantity respects pack multiplier', () {
      final p = _product(id: '1', stock: 10, packSize: 5);
      final line = CartItem(product: p, quantity: 1, sellByPack: true);
      expect(
        CartStockLimit.allowsLineQuantity(
          product: p,
          allItems: [line],
          line: line,
          newQuantity: 3,
        ),
        isFalse,
      );
      expect(
        CartStockLimit.allowsLineQuantity(
          product: p,
          allItems: [line],
          line: line,
          newQuantity: 2,
        ),
        isTrue,
      );
    });
  });
}
