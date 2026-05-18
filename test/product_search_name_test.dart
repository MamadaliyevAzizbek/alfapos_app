import 'package:alfapos_app/models/product.dart';
import 'package:alfapos_app/utils/product_search.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final catalog = [
    const Product(id: '1', name: 'Fanta 0.5', priceUzs: 5000),
    const Product(id: '2', name: 'Coca-Cola 1.5L', priceUzs: 8000),
    const Product(id: '3', name: 'Non 123', priceUzs: 3000),
  ];

  test('finds by partial name with numbers', () {
    expect(filterProductsByQuery(catalog, 'fanta').map((p) => p.id), ['1']);
    expect(filterProductsByQuery(catalog, '0.5').map((p) => p.id), ['1']);
    expect(filterProductsByQuery(catalog, 'coca 1.5').map((p) => p.id), ['2']);
    expect(filterProductsByQuery(catalog, '123').map((p) => p.id), ['3']);
  });

  test('short numeric query is not treated as barcode-only', () {
    expect(looksLikeBarcodeInput('123'), isFalse);
    expect(looksLikeBarcodeInput('fanta'), isFalse);
    expect(looksLikeBarcodeInput('4601234567890'), isTrue);
  });
}
