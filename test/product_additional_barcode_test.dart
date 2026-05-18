import 'package:flutter_test/flutter_test.dart';
import 'package:alfapos_app/models/product.dart';

void main() {
  test('additionalBarcodes obyektlardan bar_code ajratiladi', () {
    final p = Product.fromApiJson({
      'id': 1,
      'title': 'Test',
      'selling_price': 1000,
      'additional_barcodes': [
        {'id': 1844, 'company_id': 1, 'product_id': 10, 'bar_code': '9988776655443'},
        {'id': 1845, 'barcode': '4601234567890'},
      ],
    });
    expect(p.additionalBarcodes, ['9988776655443', '4601234567890']);
  });

  test('noto\'g\'ri map matni filtrlash', () {
    expect(
      Product.parseAdditionalBarcodes([
        '{id: 1844, company_id: 1, prod',
        '7788649878923',
      ]),
      ['7788649878923'],
    );
  });
}
