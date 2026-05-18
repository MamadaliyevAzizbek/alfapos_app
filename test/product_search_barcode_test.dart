import 'package:alfapos_app/models/product.dart';
import 'package:alfapos_app/utils/product_search.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final catalog = [
    Product(
      id: '1',
      name: 'Non 123',
      barcode: '4601234567890',
      priceUzs: 5000,
    ),
    Product(
      id: '2',
      name: 'Suv',
      barcode: '9988776655443',
      additionalBarcodes: ['1112223334445'],
      priceUzs: 3000,
    ),
  ];

  test('filterProductsByBarcodeQuery matches main and additional barcodes', () {
    expect(
      filterProductsByBarcodeQuery(catalog, '4601234567890').map((p) => p.id),
      ['1'],
    );
    expect(
      filterProductsByBarcodeQuery(catalog, '1112223334445').map((p) => p.id),
      ['2'],
    );
    expect(filterProductsByBarcodeQuery(catalog, 'not-a-barcode-xyz'), isEmpty);
  });
}
