import 'package:alfapos_app/models/product.dart';
import 'package:alfapos_app/services/product_catalog_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('catalog round-trip via storage', () async {
    const p = Product(
      id: 'local_123',
      name: 'Test',
      priceUzs: 1000,
      quantityInfo: '0 dona',
    );
    await ProductCatalogStorage.saveCatalog([p]);
    final loaded = await ProductCatalogStorage.loadCatalog();
    expect(loaded.length, 1);
    expect(loaded.single.id, 'local_123');
    expect(loaded.single.name, 'Test');
    expect(loaded.single.priceUzs, 1000);
  });

  test('sync meta round-trip', () async {
    final meta = ProductCatalogSyncMeta(
      count: 2,
      totalQuantity: '10',
      sampleFingerprint: 'a:1:2',
      savedAt: DateTime.utc(2026, 1, 1),
    );
    await ProductCatalogStorage.saveSyncMeta(meta);
    final loaded = await ProductCatalogStorage.loadSyncMeta();
    expect(loaded, isNotNull);
    expect(loaded!.matches(meta), isTrue);
  });
}
