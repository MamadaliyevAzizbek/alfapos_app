import 'package:alfapos_app/models/cart_item.dart';
import 'package:alfapos_app/models/product.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fractional unit price keeps line and cart total', () {
    final item = CartItem(
      product: Product(id: '1', name: 'Granula', priceUzs: 21997, variantId: 1),
      quantity: 1,
      salePriceOverride: 0.678,
      priceLocked: true,
    );
    expect(item.total, 0.678);
    expect(item.lineSubtotal, 0.678);
  });

  test('fractional qty multiplies without rounding to 1', () {
    final item = CartItem(
      product: Product(id: '1', name: 'Granula', priceUzs: 21997, variantId: 1),
      quantity: 2,
      salePriceOverride: 0.678,
      priceLocked: true,
    );
    expect(item.total, 1.356);
  });
}
