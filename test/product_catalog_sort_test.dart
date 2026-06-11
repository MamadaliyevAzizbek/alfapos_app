import 'package:alfapos_app/models/product.dart';
import 'package:alfapos_app/services/product_catalog_sort_settings.dart';
import 'package:alfapos_app/utils/product_catalog_sort.dart';
import 'package:flutter_test/flutter_test.dart';

Product _p(String id, int price) => Product(
      id: id,
      name: 'P$id',
      priceUzs: price,
    );

void main() {
  test('default order keeps source sequence', () {
    final input = [_p('3', 300), _p('1', 100), _p('2', 200)];
    final out = ProductCatalogSort.apply(
      input,
      mode: ProductCatalogSortMode.defaultOrder,
    );
    expect(out.map((e) => e.id).toList(), ['3', '1', '2']);
  });

  test('newest first sorts by numeric id descending', () {
    final input = [_p('1', 100), _p('30', 200), _p('5', 50)];
    final out = ProductCatalogSort.apply(
      input,
      mode: ProductCatalogSortMode.newestFirst,
    );
    expect(out.map((e) => e.id).toList(), ['30', '5', '1']);
  });

  test('price low first sorts by sell price', () {
    final input = [_p('1', 5000), _p('2', 1000), _p('3', 3000)];
    final out = ProductCatalogSort.apply(
      input,
      mode: ProductCatalogSortMode.priceLowFirst,
    );
    expect(out.map((e) => e.priceUzs).toList(), [1000, 3000, 5000]);
  });

  test('price high first sorts descending', () {
    final input = [_p('1', 5000), _p('2', 1000), _p('3', 3000)];
    final out = ProductCatalogSort.apply(
      input,
      mode: ProductCatalogSortMode.priceHighFirst,
    );
    expect(out.map((e) => e.priceUzs).toList(), [5000, 3000, 1000]);
  });
}
