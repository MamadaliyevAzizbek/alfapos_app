import 'package:alfapos_app/services/receipt_font_settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ReceiptFontSettings.notifier.value = ReceiptFontId.arial;
  });

  test('default receipt font is Arial', () async {
    expect(await ReceiptFontSettings.getSelectedFont(), ReceiptFontId.arial);
  });

  test('receipt font setting persists', () async {
    await ReceiptFontSettings.setSelectedFont(ReceiptFontId.tahoma);
    expect(await ReceiptFontSettings.getSelectedFont(), ReceiptFontId.tahoma);
    expect(ReceiptFontSettings.notifier.value, ReceiptFontId.tahoma);
  });

  test('fromStorageKey falls back for unknown value', () {
    expect(
      ReceiptFontId.fromStorageKey('unknown'),
      ReceiptFontId.arial,
    );
  });

  test('legacy google font keys map to Arial', () {
    expect(
      ReceiptFontId.fromStorageKey('noto_sans'),
      ReceiptFontId.arial,
    );
  });
}
