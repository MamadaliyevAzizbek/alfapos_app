import 'package:alfapos_app/services/sales_ui_scale_settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SalesUiScaleSettings.load();
  });

  test('default scale is 100%', () async {
    expect(SalesUiScaleSettings.scale.value, 1.0);
    expect(SalesUiScaleSettings.percentLabel(), '100%');
  });

  test('zoom in and out change scale', () async {
    expect(SalesUiScaleSettings.canZoomOut, true);
    expect(SalesUiScaleSettings.canZoomIn, true);

    await SalesUiScaleSettings.zoomIn();
    expect(SalesUiScaleSettings.scale.value, 1.10);
    expect(SalesUiScaleSettings.percentLabel(), '110%');

    await SalesUiScaleSettings.zoomOut();
    expect(SalesUiScaleSettings.scale.value, 1.0);
  });

  test('catalog cross axis count responds to scale', () {
    expect(SalesUiScaleSettings.catalogCrossAxisCount(4, 1.0), 4);
    expect(SalesUiScaleSettings.catalogCrossAxisCount(4, 0.75), 5);
    expect(SalesUiScaleSettings.catalogCrossAxisCount(4, 1.5), 3);
  });

  test('scale level persists', () async {
    while (SalesUiScaleSettings.canZoomIn) {
      await SalesUiScaleSettings.zoomIn();
    }
    expect(SalesUiScaleSettings.scale.value, 1.50);

    await SalesUiScaleSettings.load();
    expect(SalesUiScaleSettings.scale.value, 1.50);
  });
}
