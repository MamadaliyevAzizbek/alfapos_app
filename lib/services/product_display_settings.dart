import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Mahsulot kartochkalari ko‘rinishi (SKU, desktop ustunlar soni).
class ProductDisplaySettings {
  ProductDisplaySettings._();

  static const _skuKey = 'product_show_sku_in_title_v1';
  static const _gridColumnsKey = 'desktop_catalog_grid_columns_v1';

  static const int defaultCatalogGridColumns = 4;
  static const int minCatalogGridColumns = 2;
  static const int maxCatalogGridColumns = 8;

  /// Joriy qiymat (UI yangilanishi uchun).
  static final ValueNotifier<bool> showSkuInTitle = ValueNotifier(false);

  /// Desktop sotuv katalogida 1 qatordagi kartochkalar soni.
  static final ValueNotifier<int> catalogGridColumns =
      ValueNotifier(defaultCatalogGridColumns);

  static int clampCatalogGridColumns(int value) =>
      value.clamp(minCatalogGridColumns, maxCatalogGridColumns);

  static Future<bool> getShowSkuInTitle() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_skuKey) ?? false;
  }

  static Future<void> setShowSkuInTitle(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_skuKey, value);
    showSkuInTitle.value = value;
  }

  static Future<int> getCatalogGridColumns() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getInt(_gridColumnsKey);
    if (raw == null) return defaultCatalogGridColumns;
    return clampCatalogGridColumns(raw);
  }

  static Future<void> setCatalogGridColumns(int value) async {
    final clamped = clampCatalogGridColumns(value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_gridColumnsKey, clamped);
    catalogGridColumns.value = clamped;
  }

  static Future<void> load() async {
    showSkuInTitle.value = await getShowSkuInTitle();
    catalogGridColumns.value = await getCatalogGridColumns();
  }
}
