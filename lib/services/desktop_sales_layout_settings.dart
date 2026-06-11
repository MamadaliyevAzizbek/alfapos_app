import 'package:shared_preferences/shared_preferences.dart';

/// Desktop sotuv bo‘limi ko‘rinishi: do‘kon yoki restoran.
enum DesktopSalesLayoutMode {
  standard,
  restaurant,
}

class DesktopSalesLayoutSettings {
  DesktopSalesLayoutSettings._();

  static const _key = 'desktop_sales_layout_mode_v1';

  static Future<DesktopSalesLayoutMode> getMode() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key)?.trim();
    if (raw == 'restaurant') return DesktopSalesLayoutMode.restaurant;
    return DesktopSalesLayoutMode.standard;
  }

  static Future<void> setMode(DesktopSalesLayoutMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      mode == DesktopSalesLayoutMode.restaurant ? 'restaurant' : 'standard',
    );
  }

  static String modeLabel(DesktopSalesLayoutMode mode) {
    switch (mode) {
      case DesktopSalesLayoutMode.standard:
        return "Do'kon";
      case DesktopSalesLayoutMode.restaurant:
        return 'Restoran';
    }
  }
}
