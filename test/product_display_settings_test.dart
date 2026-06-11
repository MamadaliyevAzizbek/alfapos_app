import 'package:alfapos_app/services/product_display_settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ProductDisplaySettings.showSkuInTitle.value = false;
  });

  test('SKU in title is off by default', () async {
    expect(await ProductDisplaySettings.getShowSkuInTitle(), isFalse);
  });

  test('SKU setting persists', () async {
    await ProductDisplaySettings.setShowSkuInTitle(true);
    expect(await ProductDisplaySettings.getShowSkuInTitle(), isTrue);
    expect(ProductDisplaySettings.showSkuInTitle.value, isTrue);
    await ProductDisplaySettings.load();
    expect(ProductDisplaySettings.showSkuInTitle.value, isTrue);
  });
}
