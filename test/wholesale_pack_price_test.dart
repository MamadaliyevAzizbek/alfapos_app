import 'package:alfapos_app/models/cart_item.dart';
import 'package:alfapos_app/models/product.dart';
import 'package:alfapos_app/utils/customer_group_discount.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ulgurji pachka — dona × miqdor, sotish narxiga tushmaydi', () {
    final product = Product(
      id: '1',
      name: 'Test',
      priceUzs: 8000,
      wholesalePriceUzs: 7000,
      quantityInPack: true,
      quantityPerPack: 20,
      sellPricePerPack: 8000,
    );
    expect(product.wholesalePackUnitPriceNum, 140000);

    final item = CartItem(product: product, quantity: 1, sellByPack: true);
    expect(
      CustomerGroupDiscount.catalogUnitPriceForItem(item, 'wholesale'),
      140000,
    );
  });
}
