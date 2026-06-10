import 'package:alfapos_app/services/desktop_sales_layout_settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  test('default mode is standard', () async {
    expect(await DesktopSalesLayoutSettings.getMode(), DesktopSalesLayoutMode.standard);
  });

  test('restaurant mode persists', () async {
    await DesktopSalesLayoutSettings.setMode(DesktopSalesLayoutMode.restaurant);
    expect(await DesktopSalesLayoutSettings.getMode(), DesktopSalesLayoutMode.restaurant);
    await DesktopSalesLayoutSettings.setMode(DesktopSalesLayoutMode.standard);
    expect(await DesktopSalesLayoutSettings.getMode(), DesktopSalesLayoutMode.standard);
  });
}
