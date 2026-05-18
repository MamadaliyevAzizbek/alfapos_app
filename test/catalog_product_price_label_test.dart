import 'package:alfapos_app/models/product.dart';
import 'package:alfapos_app/utils/catalog_product_price_label.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const product = Product(
    id: '1',
    name: 'Test',
    priceUzs: 22000,
    sellingPriceCurrency: 'uzs',
  );

  test('default: faqat so\'m, dollar qavsda yo\'q', () {
    final label = CatalogProductPriceLabel.primary(
      product,
      usdRate: 12600,
      showUsdEquivalent: false,
    );
    expect(label, '22 000 so\'m');
    expect(label.contains('\$'), false);
  });

  test('filtr yoqilganda: dollar qavsda', () {
    final label = CatalogProductPriceLabel.primary(
      product,
      usdRate: 12600,
      showUsdEquivalent: true,
    );
    expect(label.contains('\$'), true);
    expect(label, contains('22 000'));
  });
}
