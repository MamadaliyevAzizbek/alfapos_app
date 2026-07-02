import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Desktop sotuv bo‘limi interfeysi masshtabi (Filtr panelidagi +/-).
class SalesUiScaleSettings {
  SalesUiScaleSettings._();

  static const _key = 'sales_ui_scale_level_v1';

  /// 75% … 150%, 10% ga yaqin qadamlar.
  static const List<double> levels = [
    0.75,
    0.85,
    0.90,
    1.00,
    1.10,
    1.20,
    1.30,
    1.40,
    1.50,
  ];

  static const int defaultLevelIndex = 3;

  static final ValueNotifier<double> scale = ValueNotifier(levels[defaultLevelIndex]);

  static int _levelIndex = defaultLevelIndex;

  static bool get canZoomIn => _levelIndex < levels.length - 1;

  static bool get canZoomOut => _levelIndex > 0;

  static String percentLabel([double? value]) {
    final v = value ?? scale.value;
    return '${(v * 100).round()}%';
  }

  /// 100% masshtabda matn biroz ixchamroq; zoom bilan birga o‘lchashadi.
  static const double textBaseFactor = 0.88;

  /// UI o‘lchamlari (padding, balandlik, shrift bazasi).
  static double scaled(double base, [double? value]) => base * (value ?? scale.value);

  static TextScaler textScaler([double? zoom]) {
    return TextScaler.linear((zoom ?? scale.value) * textBaseFactor);
  }

  /// Navbar tugmalari, oyna chip va kategoriya/brend maydoni balandligi.
  static double navbarControlSize([double? value]) => scaled(56, value);

  /// Navbar ichidagi ikonka (matnli tugmalar).
  static double navbarIconSize([double? value]) => scaled(20, value);

  /// Navbar oyna «+» va dropdown strelkasi.
  static double navbarAccentIconSize([double? value]) => scaled(28, value);

  /// Navbar chip raqam va dropdown matni.
  static double navbarChipFontSize([double? value]) => scaled(17, value);

  /// Navbar label shrifti (Kategoriya, Brend).
  static double navbarLabelFontSize([double? value]) => scaled(12, value);

  /// Navbar tugmalar orasidagi masofa.
  static double navbarGap([double? value]) => scaled(8, value);

  /// Masshtab kichrayganda ko‘proq ustun, kattalashganda kamroq ustun.
  static int catalogCrossAxisCount(int baseColumns, [double? value]) {
    final s = value ?? scale.value;
    return (baseColumns / s).round().clamp(2, 12);
  }

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _levelIndex = prefs.getInt(_key) ?? defaultLevelIndex;
    _levelIndex = _levelIndex.clamp(0, levels.length - 1);
    scale.value = levels[_levelIndex];
  }

  static Future<void> zoomIn() async {
    if (!canZoomIn) return;
    await _setLevelIndex(_levelIndex + 1);
  }

  static Future<void> zoomOut() async {
    if (!canZoomOut) return;
    await _setLevelIndex(_levelIndex - 1);
  }

  static Future<void> _setLevelIndex(int index) async {
    _levelIndex = index.clamp(0, levels.length - 1);
    scale.value = levels[_levelIndex];
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, _levelIndex);
  }
}
