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

  test('sync queue round-trip', () async {
    const job = ProductSyncJob(
      jobId: '1',
      productId: 'local_123',
      isCreate: true,
    );
    await ProductCatalogStorage.saveSyncQueue([job]);
    final loaded = await ProductCatalogStorage.loadSyncQueue();
    expect(loaded.length, 1);
    expect(loaded.single.productId, 'local_123');
    expect(loaded.single.isCreate, isTrue);
  });
}
