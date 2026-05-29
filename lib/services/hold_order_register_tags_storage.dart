import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/auth_storage.dart';

/// Hold buyurtma qaysi kassada to'xtatilgan — xodim boshqa kassaga o'tsa ham o'zgarmaydi.
class HoldOrderRegisterTagsStorage {
  HoldOrderRegisterTagsStorage._();

  static const _keyBase = 'alfapos_hold_register_tags_v1';

  static Future<String> _storageKey() => companyStorageKey(_keyBase);

  static Future<Map<int, ({int? cashRegisterId, int? registerLogId})>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(await _storageKey());
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      final out = <int, ({int? cashRegisterId, int? registerLogId})>{};
      decoded.forEach((key, value) {
        final orderId = int.tryParse(key.toString());
        if (orderId == null || orderId <= 0) return;
        if (value is! Map) return;
        final m = Map<String, dynamic>.from(value);
        out[orderId] = (
          cashRegisterId: _parseId(m['cashRegisterId'] ?? m['cash_register_id']),
          registerLogId: _parseId(m['registerLogId'] ?? m['register_log_id']),
        );
      });
      return out;
    } catch (_) {
      return {};
    }
  }

  static Future<void> save(Map<int, ({int? cashRegisterId, int? registerLogId})> tags) async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _storageKey();
    if (tags.isEmpty) {
      await prefs.remove(key);
      return;
    }
    final payload = <String, dynamic>{};
    for (final e in tags.entries) {
      payload['${e.key}'] = {
        if (e.value.cashRegisterId != null) 'cashRegisterId': e.value.cashRegisterId,
        if (e.value.registerLogId != null) 'registerLogId': e.value.registerLogId,
      };
    }
    await prefs.setString(key, jsonEncode(payload));
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(await _storageKey());
  }

  static int? _parseId(dynamic v) {
    if (v == null) return null;
    if (v is int) return v > 0 ? v : null;
    return int.tryParse(v.toString());
  }
}
