import 'package:alfapos_app/models/product.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('unit Map dan short_name olinadi', () {
    final p = Product.fromApiJson({
      'productID': 1,
      'title': 'Marker',
      'selling_price': 18000,
      'product_quantity': 5,
      'unit': {
        'id': 293,
        'name': 'Dona',
        'short_name': 'шт',
      },
    });
    expect(p.unit, 'шт');
    expect(p.unitDisplayLabel, 'шт');
    expect(p.stockDisplayText, '5 шт');
  });

  test('xato saqlangan unit matni tozalanadi', () {
    final p = Product.fromJson({
      'id': '1',
      'name': 'Test',
      'priceUzs': 1000,
      'initialQuantity': 2,
      'unit': '{id: 293, company_id: 97, name: Dona, short_name: шт}',
      'quantityInfo': '2 {id: 293, company_id: 97, name: Dona, short_name: шт}',
    });
    expect(p.unitDisplayLabel, 'шт');
    expect(p.stockDisplayText, '2 шт');
    expect(p.quantityInfo.contains('company_id'), isFalse);
  });
}
