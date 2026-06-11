import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Mahsulot kartochkalarida nomdan keyin SKU ko‘rsatish.
class ProductDisplaySettings {
  ProductDisplaySettings._();

  static const _key = 'product_show_sku_in_title_v1';

  /// Joriy qiymat (UI yangilanishi uchun).
  static final ValueNotifier<bool> showSkuInTitle = ValueNotifier(false);

  static Future<bool> getShowSkuInTitle() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? false;
  }

  static Future<void> setShowSkuInTitle(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
    showSkuInTitle.value = value;
  }

  static Future<void> load() async {
    showSkuInTitle.value = await getShowSkuInTitle();
  }
}
