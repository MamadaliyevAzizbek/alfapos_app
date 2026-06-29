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

  test('secondary printer setting persists', () async {
    expect(await PrinterSettings.isSecondaryPrinterEnabled(), isFalse);
    await PrinterSettings.setSecondaryPrinterEnabled(true);
    await PrinterSettings.setSecondaryPrinterName('Kitchen XP-80');
    expect(await PrinterSettings.isSecondaryPrinterEnabled(), isTrue);
    expect(await PrinterSettings.secondaryPrinterName(), 'Kitchen XP-80');
    expect(
      await PrinterSettings.activePrinterNames(),
      isEmpty,
    );
    await PrinterSettings.setSelectedPrinterName('Kassa XP-80');
    expect(
      await PrinterSettings.activePrinterNames(),
      ['Kassa XP-80', 'Kitchen XP-80'],
    );
    await PrinterSettings.setSecondaryPrinterEnabled(false);
    expect(
      await PrinterSettings.activePrinterNames(),
      ['Kassa XP-80'],
    );
  });
}
