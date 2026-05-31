import 'package:alfapos_app/models/product.dart';
import 'package:alfapos_app/utils/product_catalog_filter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('filters by category id and brand id', () {
    const a = Product(
      id: '1',
      name: 'Non',
      priceUzs: 5000,
      category: 'Nonlar',
      categoryId: '2',
      brandId: '5',
      brand: 'Akfa',
    );
    const b = Product(
      id: '2',
      name: 'Suv',
      priceUzs: 3000,
      categoryId: '3',
      brandId: '6',
    );

    final byCat = ProductCatalogFilter.apply(
      const [a, b],
      categoryId: '2',
      categories: const [
        {'id': '2', 'name': 'Nonlar'},
      ],
    );
    expect(byCat.map((p) => p.id).toList(), ['1']);

    final byBrand = ProductCatalogFilter.apply(
      const [a, b],
      brandId: '6',
      brands: const [
        {'id': '6', 'name': 'Brend B'},
      ],
    );
    expect(byBrand.map((p) => p.id).toList(), ['2']);
  });
}
