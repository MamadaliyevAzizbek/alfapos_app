import 'package:alfapos_app/services/printer_settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PrinterSettings.setSelectedPrinterName(null);
    await PrinterSettings.setSecondaryPrinterEnabled(false);
    await PrinterSettings.setSecondaryPrinterName(null);
    await PrinterSettings.setBarcodeLabelPrinterName(null);
  });

  test('cash drawer opens on print by default', () async {
    expect(await PrinterSettings.isCashDrawerOpenOnPrintEnabled(), isTrue);
  });

  test('cash drawer setting persists', () async {
    await PrinterSettings.setCashDrawerOpenOnPrintEnabled(false);
    expect(await PrinterSettings.isCashDrawerOpenOnPrintEnabled(), isFalse);
    await PrinterSettings.setCashDrawerPin(CashDrawerPin.pin5);
    expect(await PrinterSettings.cashDrawerPin(), CashDrawerPin.pin5);
    await PrinterSettings.setCashDrawerPrinterTarget(CashDrawerPrinterTarget.secondary);
    expect(await PrinterSettings.cashDrawerPrinterTarget(), CashDrawerPrinterTarget.secondary);
  });

  test('cash drawer printer resolves from active printers', () async {
    await PrinterSettings.setSelectedPrinterName('Kassa XP-80');
    await PrinterSettings.setSecondaryPrinterEnabled(true);
    await PrinterSettings.setSecondaryPrinterName('Oshxona XP-80');
    await PrinterSettings.setCashDrawerPrinterTarget(CashDrawerPrinterTarget.primary);
    expect(
      await PrinterSettings.cashDrawerPrinterName(['Kassa XP-80', 'Oshxona XP-80']),
      'Kassa XP-80',
    );
    await PrinterSettings.setCashDrawerPrinterTarget(CashDrawerPrinterTarget.secondary);
    expect(
      await PrinterSettings.cashDrawerPrinterName(['Kassa XP-80', 'Oshxona XP-80']),
      'Oshxona XP-80',
    );
  });

  test('secondary printer setting persists', () async {
    await PrinterSettings.setSecondaryPrinterEnabled(false);
    await PrinterSettings.setSecondaryPrinterName(null);
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

  test('barcode label printer is separate from receipt printer', () async {
    await PrinterSettings.setSelectedPrinterName('Kassa XP-80');
    expect(await PrinterSettings.barcodeLabelPrinterName(), isNull);

    await PrinterSettings.setBarcodeLabelPrinterName('Xprinter_XP_365B');
    expect(await PrinterSettings.barcodeLabelPrinterName(), 'Xprinter_XP_365B');
    expect(await PrinterSettings.selectedPrinterName(), 'Kassa XP-80');

    await PrinterSettings.setBarcodeLabelPrinterName(null);
    expect(await PrinterSettings.barcodeLabelPrinterName(), isNull);
    expect(await PrinterSettings.selectedPrinterName(), 'Kassa XP-80');
  });
}
