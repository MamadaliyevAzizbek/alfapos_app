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

    test('allowsLineQuantity: nusxa ro‘yxatda miqdor ikki marta hisoblanmaydi', () {
      // Desktop sotuv oynasi snapshot'i `CartItem.copy()` saqlaydi — o'sha nusxa
      // o'zgartirilayotgan qator bilan `identical` bo'lmaydi.
      final p = _product(id: '1', stock: 10, packSize: 1);
      final line = CartItem(product: p, quantity: 6);
      final snapshot = [line.copy()];
      expect(
        CartStockLimit.allowsLineQuantity(
          product: p,
          allItems: snapshot,
          line: line,
          newQuantity: 7,
        ),
        isTrue,
      );
      expect(
        CartStockLimit.allowsLineQuantity(
          product: p,
          allItems: snapshot,
          line: line,
          newQuantity: 11,
        ),
        isFalse,
      );
    });

    test('allowsLineQuantity: boshqa oyna savati qo‘shilib hisoblanadi', () {
      final p = _product(id: '1', stock: 10, packSize: 1);
      final otherWindow = CartItem(product: p, quantity: 5);
      final line = CartItem(product: p, quantity: 3);
      final all = [otherWindow, line];
      expect(
        CartStockLimit.allowsLineQuantity(
          product: p,
          allItems: all,
          line: line,
          newQuantity: 5,
        ),
        isTrue,
      );
      expect(
        CartStockLimit.allowsLineQuantity(
          product: p,
          allItems: all,
          line: line,
          newQuantity: 6,
        ),
        isFalse,
      );
    });

    test('maxLineQuantity: ombor qoldig‘i qaytariladi', () {
      final p = _product(id: '1', stock: 3, packSize: 1);
      final line = CartItem(product: p, quantity: 3);
      expect(
        CartStockLimit.maxLineQuantity(product: p, allItems: [line], line: line),
        3,
      );
    });

    test('maxLineQuantity: boshqa qatorlar egallagani ayiriladi', () {
      final p = _product(id: '1', stock: 10, packSize: 1);
      final otherWindow = CartItem(product: p, quantity: 6);
      final line = CartItem(product: p, quantity: 3);
      expect(
        CartStockLimit.maxLineQuantity(
          product: p,
          allItems: [otherWindow, line],
          line: line,
        ),
        4,
      );
    });

    test('maxLineQuantity: pachkada sotilsa pachka soni qaytadi', () {
      final p = _product(id: '1', stock: 12, packSize: 5);
      final line = CartItem(product: p, quantity: 1, sellByPack: true);
      expect(
        CartStockLimit.maxLineQuantity(product: p, allItems: [line], line: line),
        2,
      );
    });

    test('maxLineQuantity: qoldiq tugagan bo‘lsa 0', () {
      final p = _product(id: '1', stock: 5, packSize: 1);
      final otherWindow = CartItem(product: p, quantity: 5);
      final line = CartItem(product: p, quantity: 1);
      expect(
        CartStockLimit.maxLineQuantity(
          product: p,
          allItems: [otherWindow, line],
          line: line,
        ),
        0,
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
