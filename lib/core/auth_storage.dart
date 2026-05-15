import 'package:shared_preferences/shared_preferences.dart';

/// Faqat sessiya (token, companyId) — biznes ma'lumoti emas. Barcha tranzaksiya/mijoz/mahsulot ma'lumotlari API da.
const String _keyToken = 'alfapos_api_token';
const String _keyCompanyId = 'alfapos_api_company_id';
const String _keyLoggedIn = 'alfapos_logged_in';
const String _keyLoginEmail = 'alfapos_login_email';

Future<void> saveAuth({required String token, required String companyId, String? email}) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_keyToken, token);
  await prefs.setString(_keyCompanyId, companyId);
  await prefs.setBool(_keyLoggedIn, true);
  if (email != null) await prefs.setString(_keyLoginEmail, email);
}

Future<void> clearAuth() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_keyToken);
  await prefs.remove(_keyCompanyId);
  await prefs.remove(_keyLoggedIn);
  await prefs.remove(_keyLoginEmail);
}

/// Barcha lokal ma'lumotlarni tozalash: SharedPreferences dagi barcha kalitlar (token, login, sotuvchi ismi va b.).
/// Chiqish va login ekraniga qaytish uchun clearAllLocalData() dan keyin logout chaqiring.
Future<void> clearAllLocalData() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.clear();
}

Future<String?> getToken() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(_keyToken);
}

Future<String?> getCompanyId() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(_keyCompanyId);
}

/// Token saqlangan va bo'sh emas bo'lsa — avtomatik kirish (dastur qayta ochilganda ham).
Future<bool> isLoggedIn() async {
  final token = await getToken();
  return token != null && token.trim().isNotEmpty;
}
