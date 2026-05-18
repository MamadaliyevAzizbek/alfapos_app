import 'package:shared_preferences/shared_preferences.dart';

import 'thermal_receipt_printer.dart';

/// Termal printer sozlamalari (SharedPreferences).
class PrinterSettings {
  PrinterSettings._();

  static const _autoPrintKey = 'thermal_auto_print_v1';

  static Future<String?> selectedPrinterName() => ThermalReceiptPrinter.savedPrinterName();

  static Future<void> setSelectedPrinterName(String? name) async {
    if (name == null || name.trim().isEmpty) {
      await ThermalReceiptPrinter.clearSavedPrinter();
    } else {
      await ThermalReceiptPrinter.rememberPrinterName(name.trim());
    }
  }

  static Future<bool> isAutoPrintEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoPrintKey) ?? true;
  }

  static Future<void> setAutoPrintEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoPrintKey, value);
  }

  static Future<bool> isPrinterReady() async {
    final name = await selectedPrinterName();
    return name != null && name.isNotEmpty;
  }

  static Future<List<String>> discoverPrinters() => ThermalReceiptPrinter.discoverPrinterNames();

  static Future<ThermalPrintResult> testPrint() => ThermalReceiptPrinter.printTestReceipt();
}
