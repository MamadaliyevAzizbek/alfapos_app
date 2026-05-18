import 'package:alfapos_app/models/cart_item.dart';
import 'package:alfapos_app/models/product.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Product product({int price = 500000, int packPrice = 400000}) {
    return Product(
      id: '1',
      name: 'Test',
      priceUzs: price,
      quantityInPack: true,
      quantityPerPack: 10,
      sellPricePerPack: packPrice,
    );
  }

  test('salesStoreLinePricing uses catalog price and line discount when overridden', () {
    final item = CartItem(
      product: product(),
      quantity: 2,
      sellByPack: true,
      salePriceOverride: 350000,
    );
    final p = item.salesStoreLinePricing;
    expect(p.catalogUnitPrice, 400000);
    expect(p.lineTotal, 700000);
    expect(p.lineDiscount, 100000);
  });

  test('salesStoreLinePricing no discount without override', () {
    final item = CartItem(product: product(), quantity: 1, sellByPack: false);
    final p = item.salesStoreLinePricing;
    expect(p.catalogUnitPrice, 500000);
    expect(p.lineTotal, 500000);
    expect(p.lineDiscount, 0);
  });
}
