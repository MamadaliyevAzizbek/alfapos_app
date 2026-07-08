import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import '../utils/sales_settings_api.dart';

/// Sotuvda ombor chegarasi — faqat server `allowNegativeStockSales` dan olinadi.
class SalesStockLimitSettings {
  SalesStockLimitSettings._();

  static const _cacheKeyAllowNegative = 'allow_negative_stock_sales_v1';
  static const _legacyKeyEnforce = 'sales_enforce_stock_limit_v1';

  /// Manfiy ombor bilan sotish ruxsat (`allowNegativeStockSales === "1"`).
  static final ValueNotifier<bool> allowNegative = ValueNotifier(false);

  /// Ombor chegarasini qo'llash (`!allowNegative`).
  static final ValueNotifier<bool> enabled = ValueNotifier(true);

  static bool get stockWarningEnabled => _stockWarningEnabled;
  static bool _stockWarningEnabled = true;

  static void _applyLocal({
    required bool allowNegativeStockSales,
    bool? stockWarning,
  }) {
    allowNegative.value = allowNegativeStockSales;
    enabled.value = !allowNegativeStockSales;
    if (stockWarning != null) _stockWarningEnabled = stockWarning;
  }

  /// Eski lokal kesh — API ustun; bir martalik tozalash.
  static Future<void> _clearLegacyCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKeyAllowNegative);
    await prefs.remove(_legacyKeyEnforce);
  }

  static Future<void> syncFromSettingsMap(Map<String, dynamic> res) async {
    final allow = SalesSettingsApi.parseAllowNegativeStockSales(res);
    final warning = SalesSettingsApi.parseStockWarningEnabled(res);
    _applyLocal(allowNegativeStockSales: allow, stockWarning: warning);
    await _clearLegacyCache();
  }

  /// GET /support/sales-settings — faqat serverdan.
  static Future<void> load() async {
    try {
      final res = await SalesApi.getSalesSettings();
      await syncFromSettingsMap(res);
    } catch (_) {
      _applyLocal(allowNegativeStockSales: false);
    }
  }
}
