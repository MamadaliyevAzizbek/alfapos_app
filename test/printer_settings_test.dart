import 'package:alfapos_app/services/printer_settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  test('cash drawer opens on print by default', () async {
    expect(await PrinterSettings.isCashDrawerOpenOnPrintEnabled(), isTrue);
  });

  test('cash drawer setting persists', () async {
    await PrinterSettings.setCashDrawerOpenOnPrintEnabled(false);
    expect(await PrinterSettings.isCashDrawerOpenOnPrintEnabled(), isFalse);
    await PrinterSettings.setCashDrawerPin(CashDrawerPin.pin5);
    expect(await PrinterSettings.cashDrawerPin(), CashDrawerPin.pin5);
  });
}
