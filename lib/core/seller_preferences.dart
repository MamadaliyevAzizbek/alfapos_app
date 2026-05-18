import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';

const String _keySellerName = 'alfapos_seller_name';
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

/// Login yoki ilova ochilganda chaqiring — chek va "Sotuvchi" qatori API dagi nom bilan to'ldiriladi.
Future<void> syncSellerNameFromApi() async {
  try {
    final res = await UserApi.getUser();
    await setSellerName(sellerDisplayNameFromUserResponse(res));
    await setCurrentUserId(userIdFromUserResponse(res));
  } catch (_) {
    // tarmoq / 401 — saqlangan yoki default "Sotuvchi" qoladi
  }
}
