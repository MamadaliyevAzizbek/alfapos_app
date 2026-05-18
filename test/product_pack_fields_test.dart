import 'package:flutter_test/flutter_test.dart';
import 'package:alfapos_app/models/product.dart';

void main() {
  test('fromApiJson reads pack fields from variant', () {
    final p = Product.fromApiJson({
      'id': 1,
      'title': 'Test',
      'selling_price': 70000,
      'variants': [
        {
          'id': 10,
          'bar_code': '123',
          'units_per_package': 20,
          'package_selling_price': '8000',
          'package_purchase_price': '500',
        },
      ],
    });
    expect(p.quantityInPack, true);
    expect(p.quantityPerPack, 20);
    expect(p.sellPricePerPack, 8000);
    expect(p.costPricePerPack, 500);
    expect(p.variantId, 10);
  });
}
