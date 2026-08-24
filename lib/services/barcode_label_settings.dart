import 'package:shared_preferences/shared_preferences.dart';

import '../models/barcode_label_config.dart';

/// Oxirgi ishlatilgan yorliq sozlamalari.
class BarcodeLabelSettings {
  BarcodeLabelSettings._();

  static const _widthKey = 'barcode_label_width_mm_v1';
  static const _heightKey = 'barcode_label_height_mm_v1';
  static const _copiesKey = 'barcode_label_copies_v1';
  static const _templateKey = 'barcode_label_template_v1';
  static const _shopNameKey = 'barcode_label_shop_name_v1';

  static Future<BarcodeLabelConfig> loadDefaults() async {
    final prefs = await SharedPreferences.getInstance();
    return BarcodeLabelConfig(
      widthMm: prefs.getDouble(_widthKey) ?? BarcodeLabelConfig.defaultWidthMm,
      heightMm: prefs.getDouble(_heightKey) ?? BarcodeLabelConfig.defaultHeightMm,
      copies: prefs.getInt(_copiesKey) ?? BarcodeLabelConfig.defaultCopies,
      template: _parseTemplate(prefs.getString(_templateKey)),
      shopName: prefs.getString(_shopNameKey) ?? '',
    ).normalized();
  }

  static Future<void> save(BarcodeLabelConfig config) async {
    final c = config.normalized();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_widthKey, c.widthMm);
    await prefs.setDouble(_heightKey, c.heightMm);
    await prefs.setInt(_copiesKey, c.copies);
    await prefs.setString(_templateKey, c.template.name);
    await prefs.setString(_shopNameKey, c.shopName);
  }

  static BarcodeLabelTemplate _parseTemplate(String? raw) {
    if (raw == BarcodeLabelTemplate.shopName.name) {
      return BarcodeLabelTemplate.shopName;
    }
    return BarcodeLabelTemplate.standard;
  }
}
