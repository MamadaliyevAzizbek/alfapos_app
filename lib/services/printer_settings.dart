import 'package:shared_preferences/shared_preferences.dart';

import 'thermal_receipt_printer.dart';

/// Naqd pul yig‘ish qutisi (cash drawer) ulangan port.
enum CashDrawerPin {
  pin2,
  pin5,
}

/// Termal printer sozlamalari (SharedPreferences).
class PrinterSettings {
  PrinterSettings._();

  static const _autoPrintKey = 'thermal_auto_print_v1';
  static const _cashDrawerKey = 'thermal_cash_drawer_open_v1';
  static const _cashDrawerPinKey = 'thermal_cash_drawer_pin_v1';
  static bool? _autoPrintCache;
  static bool? _cashDrawerCache;
  static CashDrawerPin? _cashDrawerPinCache;
  static String? _printerNameCache;

  /// To'lov oynasi ochilganda — keyingi chop etish SharedPreferences kutmaydi.
  static Future<void> preload() async {
    final prefs = await SharedPreferences.getInstance();
    _autoPrintCache = prefs.getBool(_autoPrintKey) ?? true;
    _cashDrawerCache = prefs.getBool(_cashDrawerKey) ?? true;
    _cashDrawerPinCache = _parseCashDrawerPin(prefs.getString(_cashDrawerPinKey));
    _printerNameCache = prefs.getString('thermal_printer_name_v1')?.trim();
    if (_printerNameCache != null && _printerNameCache!.isEmpty) {
      _printerNameCache = null;
    }
    await ThermalReceiptPrinter.warmup();
  }

  static Future<String?> selectedPrinterName() => ThermalReceiptPrinter.savedPrinterName();

  static Future<void> setSelectedPrinterName(String? name) async {
    if (name == null || name.trim().isEmpty) {
      _printerNameCache = null;
      await ThermalReceiptPrinter.clearSavedPrinter();
    } else {
      _printerNameCache = name.trim();
      await ThermalReceiptPrinter.rememberPrinterName(name.trim());
    }
  }

  static Future<bool> isAutoPrintEnabled() async {
    if (_autoPrintCache != null) return _autoPrintCache!;
    final prefs = await SharedPreferences.getInstance();
    _autoPrintCache = prefs.getBool(_autoPrintKey) ?? true;
    return _autoPrintCache!;
  }

  static Future<void> setAutoPrintEnabled(bool value) async {
    _autoPrintCache = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoPrintKey, value);
  }

  /// Chek chop etilganda naqd qutisini ochish (printerga ulangan bo‘lsa).
  static Future<bool> isCashDrawerOpenOnPrintEnabled() async {
    if (_cashDrawerCache != null) return _cashDrawerCache!;
    final prefs = await SharedPreferences.getInstance();
    _cashDrawerCache = prefs.getBool(_cashDrawerKey) ?? true;
    return _cashDrawerCache!;
  }

  static Future<void> setCashDrawerOpenOnPrintEnabled(bool value) async {
    _cashDrawerCache = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_cashDrawerKey, value);
  }

  static Future<CashDrawerPin> cashDrawerPin() async {
    if (_cashDrawerPinCache != null) return _cashDrawerPinCache!;
    final prefs = await SharedPreferences.getInstance();
    _cashDrawerPinCache = _parseCashDrawerPin(prefs.getString(_cashDrawerPinKey));
    return _cashDrawerPinCache!;
  }

  static Future<void> setCashDrawerPin(CashDrawerPin pin) async {
    _cashDrawerPinCache = pin;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _cashDrawerPinKey,
      pin == CashDrawerPin.pin5 ? 'pin5' : 'pin2',
    );
  }

  static CashDrawerPin _parseCashDrawerPin(String? raw) {
    if (raw?.trim().toLowerCase() == 'pin5') return CashDrawerPin.pin5;
    return CashDrawerPin.pin2;
  }

  static Future<bool> isPrinterReady() async {
    final cached = _printerNameCache?.trim();
    if (cached != null && cached.isNotEmpty) return true;
    final name = await selectedPrinterName();
    _printerNameCache = name;
    return name != null && name.isNotEmpty;
  }

  static Future<List<String>> discoverPrinters() => ThermalReceiptPrinter.discoverPrinterNames();

  static Future<ThermalPrintResult> testPrint() => ThermalReceiptPrinter.printTestReceipt();
}
