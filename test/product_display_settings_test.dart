import 'package:alfapos_app/services/product_display_settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ProductDisplaySettings.load();
  });

  test('default catalog grid columns is 4', () async {
    expect(await ProductDisplaySettings.getCatalogGridColumns(), 4);
    expect(ProductDisplaySettings.catalogGridColumns.value, 4);
  });

  test('catalog grid columns persists and clamps', () async {
    await ProductDisplaySettings.setCatalogGridColumns(6);
    expect(await ProductDisplaySettings.getCatalogGridColumns(), 6);
    expect(ProductDisplaySettings.catalogGridColumns.value, 6);

    await ProductDisplaySettings.setCatalogGridColumns(1);
    expect(ProductDisplaySettings.catalogGridColumns.value, 2);

    await ProductDisplaySettings.setCatalogGridColumns(20);
    expect(ProductDisplaySettings.catalogGridColumns.value, 8);
  });
}
