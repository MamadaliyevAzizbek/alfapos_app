import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Desktop sotuv bo‘limi interfeysi masshtabi (Filtr panelidagi +/-).
///
/// Sotuv layoutida **uniform zoom** (`wrapUniformZoom`): butun UI Transform.scale
/// bilan kattalashadi/kichrayadi — atrofda bo‘sh joy qolmaydi, TextField ishlaydi.
/// Overlay/filtr panelida `chromeScaled` ishlatiladi (zoom scope tashqarida).
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

  /// `wrapUniformZoom` ichida: `scaled()` bazaviy o‘lcham qaytaradi (Transform zooms).
  static bool _uniformZoomActive = false;

  static bool get canZoomIn => _levelIndex < levels.length - 1;

  static bool get canZoomOut => _levelIndex > 0;

  static String percentLabel([double? value]) {
    final v = value ?? scale.value;
    return '${(v * 100).round()}%';
  }

  /// 100% masshtabda matn biroz ixchamroq.
  static const double textBaseFactor = 0.88;

  /// Layout o‘lchamlari. Uniform zoom ichida — ko‘paytirilmaydi (Transform qiladi).
  static double scaled(double base, [double? value]) {
    if (value != null) return base * value;
    if (_uniformZoomActive) return base;
    return base * scale.value;
  }

  /// Filtr/dialog kabi Transform tashqarisidagi chrome — har doim zoom bilan.
  static double chromeScaled(double base, [double? value]) => base * (value ?? scale.value);

  /// Matn. Uniform zoom ichida Transform allaqachon kattalashtiradi.
  static TextScaler textScaler([double? zoom]) {
    if (_uniformZoomActive && zoom == null) {
      return TextScaler.linear(textBaseFactor);
    }
    return TextScaler.linear((zoom ?? scale.value) * textBaseFactor);
  }

  /// Navbar tugmalari, oyna chip va kategoriya/brend maydoni balandligi.
  static double navbarControlSize([double? value]) => scaled(48, value);

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

  /// Uniform zoomda ustun soni logical kenglikka qoladi (Transform zoom qiladi).
  static int catalogCrossAxisCount(int baseColumns, [double? value]) {
    if (_uniformZoomActive && value == null) return baseColumns.clamp(2, 12);
    final s = value ?? scale.value;
    return (baseColumns / s).round().clamp(2, 12);
  }

  /// Butun sotuv UI — brauzer zoom kabi; har doim oyna bo‘ylab to‘liq yoyiladi.
  ///
  /// `Transform.scale` (FittedBox emas): TextField fokus/hit-test ishonchli ishlaydi,
  /// kichraytirganda ham atrofda bo‘sh joy qolmaydi.
  static Widget wrapUniformZoom({required Widget child}) {
    return ValueListenableBuilder<double>(
      valueListenable: scale,
      builder: (context, zoom, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final h = constraints.maxHeight;
            if (!w.isFinite || !h.isFinite || w <= 0 || h <= 0) {
              return const SizedBox.shrink();
            }
            final logicalW = w / zoom;
            final logicalH = h / zoom;
            return SizedBox(
              width: w,
              height: h,
              child: ClipRect(
                child: OverflowBox(
                  alignment: Alignment.topLeft,
                  minWidth: logicalW,
                  maxWidth: logicalW,
                  minHeight: logicalH,
                  maxHeight: logicalH,
                  child: Transform.scale(
                    scale: zoom,
                    alignment: Alignment.topLeft,
                    filterQuality: FilterQuality.medium,
                    child: SizedBox(
                      width: logicalW,
                      height: logicalH,
                      child: MediaQuery(
                        data: MediaQuery.of(context).copyWith(
                          size: Size(logicalW, logicalH),
                          textScaler: const TextScaler.linear(textBaseFactor),
                        ),
                        child: _UniformZoomScope(child: child),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
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

/// `scaled()` ni bazaviy qilish uchun scope (Transform zoom bilan birga).
class _UniformZoomScope extends StatefulWidget {
  final Widget child;

  const _UniformZoomScope({required this.child});

  @override
  State<_UniformZoomScope> createState() => _UniformZoomScopeState();
}

class _UniformZoomScopeState extends State<_UniformZoomScope> {
  @override
  void initState() {
    super.initState();
    SalesUiScaleSettings._uniformZoomActive = true;
  }

  @override
  void dispose() {
    SalesUiScaleSettings._uniformZoomActive = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SalesUiScaleSettings._uniformZoomActive = true;
    return widget.child;
  }
}
