import 'package:alfapos_app/models/receipt_design_config.dart';
import 'package:alfapos_app/services/receipt_font_settings.dart';
import 'package:alfapos_app/services/thermal_receipt_image_builder.dart';
import 'package:alfapos_app/utils/thermal_receipt_large_text.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ReceiptFontSettings.setSelectedFont(ReceiptFontId.arial);
  });

  test('buildReceipt produces ESC/POS bytes with Uzbek text', () async {
    final lines = [
      '^AlfaPOS',
      'Do\'kon — printer testi',
      'Mahsulot: O\'zbekiston noni',
      ThermalReceiptLargeText.line('42'),
      'Jami: 125 000 so\'m',
    ];

    final bytes = await ThermalReceiptImageBuilder.buildReceipt(
      lines: lines,
      design: ReceiptDesignConfig.defaults.copyWith(showLogo: false),
    );

    expect(bytes, isNotEmpty);
    expect(bytes.length, greaterThan(100));
  });
}
