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

  test('savat: dollar faqat ko\'rinish, so\'m qiymati o\'zgarmaydi', () {
    expect(
      CatalogProductPriceLabel.somWithOptionalUsd(2087250, usdRate: 12600),
      '2 087 250',
    );
    expect(
      CatalogProductPriceLabel.somWithOptionalUsd(
        2087250,
        usdRate: 12600,
        showUsdEquivalent: true,
      ),
      '2 087 250 (\$165.65)',
    );
    expect(
      CatalogProductPriceLabel.somWithOptionalUsd(
        1260000,
        usdRate: 12600,
        showUsdEquivalent: true,
      ),
      '1 260 000 (\$100)',
    );
  });

  test('splitSomUsd ajratadi dollar qismini', () {
    final parts = CatalogProductPriceLabel.splitSomUsd('2 299 000 (\$190)');
    expect(parts.som, '2 299 000');
    expect(parts.usd, '(\$190)');
    expect(CatalogProductPriceLabel.splitSomUsd('22 000 so\'m').usd, isNull);
  });

  test('pachkali mahsulotda dona sotish narxi (pachka emas)', () {
    const packProduct = Product(
      id: '2',
      name: 'Pachkali',
      priceUzs: 52833,
      quantityInPack: true,
      quantityPerPack: 6,
      sellPricePerPack: 317000,
    );
    final label = CatalogProductPriceLabel.primary(packProduct);
    expect(label, '52 833 so\'m');
    expect(label, isNot(contains('317')));
  });
}
