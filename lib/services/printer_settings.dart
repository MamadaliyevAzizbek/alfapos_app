import 'package:shared_preferences/shared_preferences.dart';

import 'thermal_receipt_printer.dart';

/// Naqd pul yig‘ish qutisi (cash drawer) ulangan port.
enum CashDrawerPin {
  pin2,
  pin5,
}

/// Naqd qutisi qaysi printerga ulangan (DK/RJ port).
enum CashDrawerPrinterTarget {
  primary,
  secondary,
}

/// Termal printer sozlamalari (SharedPreferences).
class PrinterSettings {
  PrinterSettings._();

  static const _autoPrintKey = 'thermal_auto_print_v1';
  static const _cashDrawerKey = 'thermal_cash_drawer_open_v1';
  static const _cashDrawerPinKey = 'thermal_cash_drawer_pin_v1';
  static const _secondaryPrinterEnabledKey = 'thermal_secondary_printer_enabled_v1';
  static const _secondaryPrinterNameKey = 'thermal_secondary_printer_name_v1';
  static const _cashDrawerPrinterTargetKey = 'thermal_cash_drawer_printer_target_v1';
  static bool? _autoPrintCache;
  static bool? _cashDrawerCache;
  static CashDrawerPin? _cashDrawerPinCache;
  static CashDrawerPrinterTarget? _cashDrawerPrinterTargetCache;
  static String? _printerNameCache;
  static bool? _secondaryPrinterEnabledCache;
  static String? _secondaryPrinterNameCache;

  /// To'lov oynasi ochilganda — keyingi chop etish SharedPreferences kutmaydi.
  static Future<void> preload() async {
    final prefs = await SharedPreferences.getInstance();
    _autoPrintCache = prefs.getBool(_autoPrintKey) ?? true;
    _cashDrawerCache = prefs.getBool(_cashDrawerKey) ?? true;
    _cashDrawerPinCache = _parseCashDrawerPin(prefs.getString(_cashDrawerPinKey));
    _cashDrawerPrinterTargetCache =
        _parseCashDrawerPrinterTarget(prefs.getString(_cashDrawerPrinterTargetKey));
    _printerNameCache = prefs.getString('thermal_printer_name_v1')?.trim();
    if (_printerNameCache != null && _printerNameCache!.isEmpty) {
      _printerNameCache = null;
    }
    _secondaryPrinterEnabledCache = prefs.getBool(_secondaryPrinterEnabledKey) ?? false;
    _secondaryPrinterNameCache = prefs.getString(_secondaryPrinterNameKey)?.trim();
    if (_secondaryPrinterNameCache != null && _secondaryPrinterNameCache!.isEmpty) {
      _secondaryPrinterNameCache = null;
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

  static Future<bool> isSecondaryPrinterEnabled() async {
    if (_secondaryPrinterEnabledCache != null) return _secondaryPrinterEnabledCache!;
    final prefs = await SharedPreferences.getInstance();
    _secondaryPrinterEnabledCache = prefs.getBool(_secondaryPrinterEnabledKey) ?? false;
    return _secondaryPrinterEnabledCache!;
  }

  static Future<void> setSecondaryPrinterEnabled(bool value) async {
    _secondaryPrinterEnabledCache = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_secondaryPrinterEnabledKey, value);
  }

  static Future<String?> secondaryPrinterName() async {
    final cached = _secondaryPrinterNameCache?.trim();
    if (cached != null && cached.isNotEmpty) return cached;
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_secondaryPrinterNameKey)?.trim();
    if (name == null || name.isEmpty) return null;
    _secondaryPrinterNameCache = name;
    return name;
  }

  static Future<void> setSecondaryPrinterName(String? name) async {
    if (name == null || name.trim().isEmpty) {
      _secondaryPrinterNameCache = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_secondaryPrinterNameKey);
    } else {
      _secondaryPrinterNameCache = name.trim();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_secondaryPrinterNameKey, name.trim());
    }
  }

  /// Asosiy va (yoqilgan bo‘lsa) qo‘shimcha printer nomlari.
  static Future<List<String>> activePrinterNames() async {
    final primary = (await selectedPrinterName())?.trim();
    if (primary == null || primary.isEmpty) return const [];

    final names = <String>[primary];
    if (!await isSecondaryPrinterEnabled()) return names;

    final secondary = (await secondaryPrinterName())?.trim();
    if (secondary == null || secondary.isEmpty || secondary == primary) return names;

    names.add(secondary);
    return names;
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

  /// Naqd qutisi qaysi printerda ochiladi (qo‘shimcha printer yoqilganda).
  static Future<CashDrawerPrinterTarget> cashDrawerPrinterTarget() async {
    if (_cashDrawerPrinterTargetCache != null) return _cashDrawerPrinterTargetCache!;
    final prefs = await SharedPreferences.getInstance();
    _cashDrawerPrinterTargetCache =
        _parseCashDrawerPrinterTarget(prefs.getString(_cashDrawerPrinterTargetKey));
    return _cashDrawerPrinterTargetCache!;
  }

  static Future<void> setCashDrawerPrinterTarget(CashDrawerPrinterTarget target) async {
    _cashDrawerPrinterTargetCache = target;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _cashDrawerPrinterTargetKey,
      target == CashDrawerPrinterTarget.secondary ? 'secondary' : 'primary',
    );
  }

  /// [activePrinterNames] ro‘yxatidan naqd qutisi ochiladigan printerni tanlash.
  static Future<String?> cashDrawerPrinterName(List<String> activePrinterNames) async {
    if (activePrinterNames.isEmpty) return null;
    final target = await cashDrawerPrinterTarget();
    if (target == CashDrawerPrinterTarget.secondary && activePrinterNames.length > 1) {
      return activePrinterNames[1];
    }
    return activePrinterNames.first;
  }

  static CashDrawerPin _parseCashDrawerPin(String? raw) {
    if (raw?.trim().toLowerCase() == 'pin5') return CashDrawerPin.pin5;
    return CashDrawerPin.pin2;
  }

  static CashDrawerPrinterTarget _parseCashDrawerPrinterTarget(String? raw) {
    if (raw?.trim().toLowerCase() == 'secondary') {
      return CashDrawerPrinterTarget.secondary;
    }
    return CashDrawerPrinterTarget.primary;
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
