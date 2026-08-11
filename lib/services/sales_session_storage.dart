import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/auth_storage.dart';
import '../models/product.dart';

/// Sotuv sessiyasi: faqat POS meta (filial, to‘lov, kategoriya). Mahsulotlar ProductsProvider da.
class SalesSessionStorage {
  SalesSessionStorage._();

  static const _productsKeyBase = 'alfapos_sales_products_v1';
  static const _metaKeyBase = 'alfapos_sales_meta_v1';

  static Future<void> saveProducts(List<Product> products) async {
    if (products.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final list = products.map((p) => p.toJson()).toList();
    await prefs.setString(await companyStorageKey(_productsKeyBase), jsonEncode(list));
  }

  static Future<List<Product>> loadProducts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(await companyStorageKey(_productsKeyBase));
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map>()
          .map((e) => Product.fromJson(Map<String, dynamic>.from(e)))
          .where((p) => p.id.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveMeta(Map<String, dynamic> meta) async {
    final prefs = await SharedPreferences.getInstance();
    final cid = await getCompanyId();
    final payload = Map<String, dynamic>.from(meta);
    if (cid != null && cid.isNotEmpty) payload['companyId'] = cid;
    await prefs.setString(await companyStorageKey(_metaKeyBase), jsonEncode(payload));
  }

  static Future<Map<String, dynamic>> loadMeta() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(await companyStorageKey(_metaKeyBase));
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return {};
  }
}
