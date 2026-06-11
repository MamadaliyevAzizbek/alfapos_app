import 'package:alfapos_app/services/product_catalog_sort_settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ProductCatalogSortSettings.sortMode.value = ProductCatalogSortMode.defaultOrder;
  });

  test('default sort mode is current order', () async {
    expect(await ProductCatalogSortSettings.getMode(), ProductCatalogSortMode.defaultOrder);
  });

  test('sort mode persists', () async {
    await ProductCatalogSortSettings.setMode(ProductCatalogSortMode.priceHighFirst);
    expect(await ProductCatalogSortSettings.getMode(), ProductCatalogSortMode.priceHighFirst);
    expect(ProductCatalogSortSettings.sortMode.value, ProductCatalogSortMode.priceHighFirst);
  });
}
