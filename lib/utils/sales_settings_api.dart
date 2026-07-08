/// GET/POST /support/sales-settings — sotuv sozlamalari (NEGATIVE_STOCK_SALES_API.md).
class SalesSettingsApi {
  SalesSettingsApi._();

  static bool isTruthy(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is int) return value == 1;
    if (value is num) return value.toInt() == 1;
    final s = value.toString().trim().toLowerCase();
    return s == '1' || s == 'true' || s == 'yes';
  }

  static Map<String, dynamic> unwrapSettings(Map<String, dynamic> res) {
    final merged = <String, dynamic>{};
    void absorb(Map<String, dynamic> m) => merged.addAll(m);

    absorb(res);
    final data = res['data'];
    if (data is Map) absorb(Map<String, dynamic>.from(data));
    final settings = res['settings'];
    if (settings is Map) absorb(Map<String, dynamic>.from(settings));
    return merged;
  }

  static bool readBool(
    Map<String, dynamic> res,
    List<String> keys, {
    bool defaultValue = false,
  }) {
    final merged = unwrapSettings(res);
    for (final key in keys) {
      if (merged.containsKey(key)) return isTruthy(merged[key]);
    }
    return defaultValue;
  }

  /// `allowNegativeStockSales` — "1" bo'lsa manfiy ombor bilan sotish ruxsat.
  static bool parseAllowNegativeStockSales(Map<String, dynamic> res) {
    return readBool(res, const [
      'allowNegativeStockSales',
      'allow_negative_stock_sales',
    ]);
  }

  /// `outOfStock` — server ombor tekshiruvi yoqilgan.
  static bool parseOutOfStockCheckEnabled(Map<String, dynamic> res) {
    return readBool(
      res,
      const ['outOfStock', 'out_of_stock_products'],
      defaultValue: true,
    );
  }

  /// `stockWarningEnabled` — savatda ogohlantirish (faqat UI).
  static bool parseStockWarningEnabled(Map<String, dynamic> res) {
    return readBool(
      res,
      const ['stockWarningEnabled', 'stock_warning_enabled'],
      defaultValue: true,
    );
  }

  /// POST uchun mavjud sozlamalarni saqlab, kerakli maydonni yangilaydi.
  static Map<String, dynamic> prepareSaveBody(
    Map<String, dynamic> currentResponse, {
    bool? allowNegativeStockSales,
    bool? outOfStock,
    bool? stockWarningEnabled,
  }) {
    final body = Map<String, dynamic>.from(unwrapSettings(currentResponse));
    if (allowNegativeStockSales != null) {
      body['allowNegativeStockSales'] = allowNegativeStockSales ? '1' : '0';
    }
    if (outOfStock != null) {
      body['outOfStock'] = outOfStock ? '1' : '0';
    }
    if (stockWarningEnabled != null) {
      body['stockWarningEnabled'] = stockWarningEnabled ? '1' : '0';
    }
    return body;
  }
}
