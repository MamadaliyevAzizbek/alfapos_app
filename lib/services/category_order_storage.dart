import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/auth_storage.dart';

/// Kategoriyalar tartibi (sotuv va restoran rejimi uchun).
class CategoryOrderStorage {
  CategoryOrderStorage._();

  static const _keyBase = 'category_custom_order_v1';

  static Future<String> _storageKey() => companyStorageKey(_keyBase);

  static Future<List<String>> getOrderedIds() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(await _storageKey());
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveOrderedIds(List<String> ids) async {
    final cleaned = <String>[];
    for (final id in ids) {
      final v = id.trim();
      if (v.isEmpty || cleaned.contains(v)) continue;
      cleaned.add(v);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(await _storageKey(), jsonEncode(cleaned));
  }

  /// Yangi kategoriyalar oxiriga qo‘shiladi, o‘chirilganlar olib tashlanadi.
  static Future<List<String>> mergeWithCategoryIds(List<String> categoryIds) async {
    final known = categoryIds.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();
    final saved = await getOrderedIds();
    final merged = <String>[];
    for (final id in saved) {
      if (known.contains(id)) merged.add(id);
    }
    for (final id in known) {
      if (!merged.contains(id)) merged.add(id);
    }
    if (!_sameIds(saved, merged)) {
      await saveOrderedIds(merged);
    }
    return merged;
  }

  static bool _sameIds(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
