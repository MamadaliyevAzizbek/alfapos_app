import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';

const String _keySellerName = 'alfapos_seller_name';
const String _keySellerPhone = 'alfapos_seller_phone';
const String _keyUserId = 'alfapos_user_id';

/// Faqat UI (chek, tranzaksiya) — `/user` dan yangilanadi.
Future<String> getSellerName() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(_keySellerName) ?? 'Sotuvchi';
}

Future<void> setSellerName(String name) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_keySellerName, name.trim().isEmpty ? 'Sotuvchi' : name.trim());
}

Future<String?> getSellerPhone() async {
  final prefs = await SharedPreferences.getInstance();
  final s = prefs.getString(_keySellerPhone)?.trim();
  return (s == null || s.isEmpty) ? null : s;
}

Future<void> setSellerPhone(String? phone) async {
  final prefs = await SharedPreferences.getInstance();
  final p = phone?.trim() ?? '';
  if (p.isEmpty) {
    await prefs.remove(_keySellerPhone);
  } else {
    await prefs.setString(_keySellerPhone, p);
  }
}

String sellerPhoneFromUserResponse(Map<String, dynamic> res) {
  final data = res['success'] is Map
      ? Map<String, dynamic>.from(res['success'] as Map)
      : (res['data'] is Map ? Map<String, dynamic>.from(res['data'] as Map) : Map<String, dynamic>.from(res));
  for (final k in ['phone', 'phone_number', 'phoneNumber', 'mobile', 'tel']) {
    final v = data[k]?.toString().trim();
    if (v != null && v.isNotEmpty) return v;
  }
  return '';
}

int? userIdFromUserResponse(Map<String, dynamic> res) {
  final data = res['success'] is Map
      ? Map<String, dynamic>.from(res['success'] as Map)
      : (res['data'] is Map ? Map<String, dynamic>.from(res['data'] as Map) : Map<String, dynamic>.from(res));
  final id = data['id'] ?? data['user_id'] ?? data['userId'];
  if (id is int) return id;
  return int.tryParse(id?.toString() ?? '');
}

Future<int?> getCurrentUserId() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getInt(_keyUserId);
  if (raw != null && raw > 0) return raw;
  return null;
}

Future<void> setCurrentUserId(int? id) async {
  final prefs = await SharedPreferences.getInstance();
  if (id == null || id <= 0) {
    await prefs.remove(_keyUserId);
  } else {
    await prefs.setInt(_keyUserId, id);
  }
}

Future<void> clearUserProfileCache() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_keySellerName);
  await prefs.remove(_keySellerPhone);
  await prefs.remove(_keyUserId);
  await prefs.remove(_keyUserSyncedAt);
}

/// GET /user javobidan ko'rinadigan ism (first_name + last_name, name yoki email).
String sellerDisplayNameFromUserResponse(Map<String, dynamic> res) {
  final data = res['success'] is Map
      ? Map<String, dynamic>.from(res['success'] as Map)
      : (res['data'] is Map ? Map<String, dynamic>.from(res['data'] as Map) : Map<String, dynamic>.from(res));
  final first = (data['first_name'] ?? data['firstName'] ?? '').toString().trim();
  final last = (data['last_name'] ?? data['lastName'] ?? '').toString().trim();
  final combined = '$first $last'.trim();
  if (combined.isNotEmpty) return combined;
  final name = data['name']?.toString().trim();
  if (name != null && name.isNotEmpty) return name;
  final email = data['email']?.toString().trim();
  if (email != null && email.isNotEmpty) return email;
  return 'Sotuvchi';
}

const String _keyUserSyncedAt = 'alfapos_user_synced_at_ms';

/// Login yoki ilova ochilganda — keshda ism bo‘lsa har 6 soatda bir marta / [force] da.
Future<void> syncSellerNameFromApi({bool force = false}) async {
  if (!force) {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(_keyUserSyncedAt);
    if (ms != null) {
      final last = DateTime.fromMillisecondsSinceEpoch(ms);
      if (DateTime.now().difference(last) < const Duration(hours: 6)) return;
    }
    final cached = prefs.getString(_keySellerName);
    if (cached != null && cached.isNotEmpty && cached != 'Sotuvchi') return;
  }
  try {
    final res = await UserApi.getUser();
    await setSellerName(sellerDisplayNameFromUserResponse(res));
    final phone = sellerPhoneFromUserResponse(res);
    if (phone.isNotEmpty) await setSellerPhone(phone);
    await setCurrentUserId(userIdFromUserResponse(res));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyUserSyncedAt, DateTime.now().millisecondsSinceEpoch);
  } catch (_) {
    // tarmoq / 401 — saqlangan yoki default "Sotuvchi" qoladi
  }
}
