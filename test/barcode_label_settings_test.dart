import 'package:alfapos_app/models/barcode_label_config.dart';
import 'package:alfapos_app/services/barcode_label_settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('loadDefaults uses standard 40x30 mm', () async {
    final cfg = await BarcodeLabelSettings.loadDefaults();
    expect(cfg.widthMm, BarcodeLabelConfig.defaultWidthMm);
    expect(cfg.heightMm, BarcodeLabelConfig.defaultHeightMm);
    expect(cfg.copies, BarcodeLabelConfig.defaultCopies);
    expect(cfg.template, BarcodeLabelTemplate.standard);
  });

  test('save persists template and shop name', () async {
    await BarcodeLabelSettings.save(
      const BarcodeLabelConfig(
        widthMm: 50,
        heightMm: 35,
        copies: 3,
        template: BarcodeLabelTemplate.shopName,
        shopName: 'Alfa market',
      ),
    );
    final cfg = await BarcodeLabelSettings.loadDefaults();
    expect(cfg.template, BarcodeLabelTemplate.shopName);
    expect(cfg.shopName, 'Alfa market');
    expect(cfg.copies, 3);
  });
}
