import 'package:alfapos_app/models/cart_item.dart';
import 'package:alfapos_app/models/product.dart';
import 'package:alfapos_app/utils/product_weight.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Product product({int sell = 11000}) => Product(
        id: '1',
        name: 'GRANULA',
        priceUzs: sell,
      );

  test('applyTargetSum keeps 50000 with rounded 4.545 kg', () {
    final item = CartItem(product: product(), quantity: 1);
    item.applyTargetSum(50000);
    expect(item.quantity, 4.545);
    expect((item.unitPriceDisplay * item.quantity).round(), 49995);
    expect(item.total, 50000);
    expect(item.lineTotalOverride, 50000);
  });

  test('same displayed qty commit must not imply clearing override', () {
    final item = CartItem(product: product(), quantity: 4.545)
      ..lineTotalOverride = 50000;
    final displayed = ProductWeight.formatQuantity(item.quantity);
    final parsed = num.parse(displayed);
    expect(ProductWeight.formatQuantity(parsed), displayed);
    // Blur commit faqat miqdor o‘zgaganda clear qiladi.
    expect(item.total, 50000);
  });

  test('clearLineTotalOverride restores qty*price total', () {
    final item = CartItem(product: product(), quantity: 4.545)
      ..lineTotalOverride = 50000;
    item.clearLineTotalOverride();
    expect(item.total, 49995);
  });
}
