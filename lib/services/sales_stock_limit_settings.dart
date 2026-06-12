import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Sotuvda ombor miqdoridan ortiq sotmaslik (default yoqilgan).
class SalesStockLimitSettings {
  SalesStockLimitSettings._();

  static const _key = 'sales_enforce_stock_limit_v1';

  static final ValueNotifier<bool> enabled = ValueNotifier(true);

  static Future<bool> getEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? true;
  }

  static Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
    enabled.value = value;
  }

  static Future<void> load() async {
    enabled.value = await getEnabled();
  }
}
