import 'package:alfapos_app/models/cart_item.dart';
import 'package:alfapos_app/models/product.dart';
import 'package:alfapos_app/utils/cart_discount_percent.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('+20 increases line unit price', () {
    final item = CartItem(
      product: Product(id: '1', name: 'A', priceUzs: 200000),
      quantity: 1,
    );
    CartDiscountPercent.initNewItem(item);
    CartDiscountPercent.applyToItem(item, 20);
    expect(item.unitPriceDisplay, 240000);
    expect(item.total, 240000);
  });

  test('-20 decreases line unit price', () {
    final item = CartItem(
      product: Product(id: '1', name: 'A', priceUzs: 200000),
      quantity: 1,
    );
    CartDiscountPercent.initNewItem(item);
    CartDiscountPercent.applyToItem(item, -20);
    expect(item.unitPriceDisplay, 160000);
    expect(item.total, 160000);
  });

  test('+12 rounds unit price up to 1000', () {
    final item = CartItem(
      product: Product(id: '1', name: 'taft', priceUzs: 30000),
      quantity: 1,
      salePriceOverride: 33600,
    );
    item.unitPriceBaseForCartPercent = 33600;
    CartDiscountPercent.applyToItem(item, 12);
    // 33 600 × 1.12 = 37 632 → 38 000
    expect(item.unitPriceDisplay, 38000);
  });

  test('percent 0 restores catalog price', () {
    final item = CartItem(
      product: Product(id: '1', name: 'A', priceUzs: 200000),
      quantity: 1,
    );
    CartDiscountPercent.initNewItem(item);
    CartDiscountPercent.applyToItem(item, 20);
    CartDiscountPercent.applyToItem(item, 0);
    expect(item.salePriceOverride, isNull);
    expect(item.total, 200000);
  });

  test('roundPercentPrice + yuqoriga, - pastga', () {
    expect(CartDiscountPercent.roundPercentPrice(37632, 12), 38000);
    expect(CartDiscountPercent.roundPercentPrice(13500, -10), 13000);
    expect(CartDiscountPercent.roundPercentPrice(1050, 5), 2000);
    expect(CartDiscountPercent.roundPercentPrice(240000, 20), 240000);
  });
}
