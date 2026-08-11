import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/auth_storage.dart';

/// Kompaniya bo‘yicha JSON kesh (SharedPreferences).
class CompanyCacheStore {
  CompanyCacheStore._();

  static const productCatalog = 'alfapos_product_catalog_v1';
  static const productCatalogMeta = 'alfapos_product_catalog_meta_v1';
  static const productSyncQueueLegacy = 'alfapos_product_sync_queue_v1';
  static const salesProductsLegacy = 'alfapos_sales_products_v1';
  static const salesMeta = 'alfapos_sales_meta_v1';
  static const categories = 'alfapos_categories_v1';
  static const clients = 'alfapos_clients_v1';
  static const expenses = 'alfapos_expenses_v1';

  static Future<String> key(String baseKey) => companyStorageKey(baseKey);

  static Future<void> writeString(String baseKey, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(await key(baseKey), value);
  }

  static Future<String?> readString(String baseKey) async {
    final prefs = await SharedPreferences.getInstance();
    final scoped = prefs.getString(await key(baseKey));
    if (scoped != null && scoped.isNotEmpty) return scoped;
    final legacy = prefs.getString(baseKey);
    if (legacy == null || legacy.isEmpty) return null;
    await prefs.setString(await key(baseKey), legacy);
    return legacy;
  }

  static Future<void> writeJson(String baseKey, Object value) async {
    await writeString(baseKey, jsonEncode(value));
  }

  static Future<Object?> readJson(String baseKey) async {
    final raw = await readString(baseKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }

  static Future<void> remove(String baseKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(await key(baseKey));
    await prefs.remove(baseKey);
  }

  /// Logout / hisob almashinuvida biznes keshini tozalash.
  static Future<void> clearBusinessCaches() async {
    await remove(productCatalog);
    await remove(productCatalogMeta);
    await remove(productSyncQueueLegacy);
    await remove(salesProductsLegacy);
    await remove(salesMeta);
    await remove(categories);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('${await key(categories)}_at');
    await prefs.remove('${categories}_at');
    await remove(clients);
    await remove(expenses);
  }
}
