import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Savat «Umumiy» qatorida foydani ko‘rsatish (F6 bilan yoqib/o‘chirish).
class SalesCartProfitDisplaySettings {
  SalesCartProfitDisplaySettings._();

  static const _key = 'sales_cart_profit_visible_v1';

  static final ValueNotifier<bool> visible = ValueNotifier(false);

  static Future<bool> getVisible() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? false;
  }

  static Future<void> setVisible(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
    visible.value = value;
  }

  static Future<void> toggle() async {
    await setVisible(!visible.value);
  }

  static Future<void> load() async {
    visible.value = await getVisible();
  }
}
