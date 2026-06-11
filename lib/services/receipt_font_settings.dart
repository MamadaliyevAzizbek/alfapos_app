import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Chekda tanlanadigan shriftlar (tizimda o‘rnatilgan oilalar).
enum ReceiptFontId {
  arial('arial', 'Arial'),
  systemUi('system_ui', 'Tizim shrifti'),
  courierNew('courier_new', 'Courier New'),
  tahoma('tahoma', 'Tahoma'),
  verdana('verdana', 'Verdana'),
  timesNewRoman('times_new_roman', 'Times New Roman'),
  calibri('calibri', 'Calibri'),
  georgia('georgia', 'Georgia');

  const ReceiptFontId(this.storageKey, this.label);

  final String storageKey;
  final String label;

  static ReceiptFontId fromStorageKey(String? raw) {
    if (raw == null || raw.isEmpty) return ReceiptFontId.arial;
    for (final f in values) {
      if (f.storageKey == raw) return f;
    }
    // Eski saqlangan google_fonts kalitlari → Arial.
    return ReceiptFontId.arial;
  }
}

/// Chek shrifti — tanlangan oila saqlanadi va chop etish/preview da ishlatiladi.
class ReceiptFontSettings {
  ReceiptFontSettings._();

  static const _prefsKey = 'receipt_font_v1';
  static ReceiptFontId? _cache;
  static final ValueNotifier<ReceiptFontId> notifier =
      ValueNotifier(ReceiptFontId.arial);

  static List<ReceiptFontId> get choices => ReceiptFontId.values;

  static Future<void> preload() async {
    final font = await getSelectedFont();
    notifier.value = font;
  }

  static Future<ReceiptFontId> getSelectedFont() async {
    if (_cache != null) return _cache!;
    final prefs = await SharedPreferences.getInstance();
    _cache = ReceiptFontId.fromStorageKey(prefs.getString(_prefsKey));
    notifier.value = _cache!;
    return _cache!;
  }

  static Future<void> setSelectedFont(ReceiptFontId font) async {
    _cache = font;
    notifier.value = font;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, font.storageKey);
  }

  static TextStyle style({
    required ReceiptFontId font,
    double fontSize = 12,
    FontWeight fontWeight = FontWeight.w500,
    Color color = Colors.black,
    double height = 1.35,
  }) {
    return TextStyle(
      fontFamily: familyFor(font),
      fontFamilyFallback: fallbacksFor(font),
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
    );
  }

  static String? familyFor(ReceiptFontId font) {
    return switch (font) {
      ReceiptFontId.arial => 'Arial',
      ReceiptFontId.systemUi => Platform.isWindows
          ? 'Segoe UI'
          : (Platform.isMacOS ? '.AppleSystemUIFont' : 'Roboto'),
      ReceiptFontId.courierNew => 'Courier New',
      ReceiptFontId.tahoma => 'Tahoma',
      ReceiptFontId.verdana => 'Verdana',
      ReceiptFontId.timesNewRoman => 'Times New Roman',
      ReceiptFontId.calibri => 'Calibri',
      ReceiptFontId.georgia => 'Georgia',
    };
  }

  static List<String> fallbacksFor(ReceiptFontId font) {
    if (font == ReceiptFontId.courierNew) {
      return const ['Courier', 'monospace'];
    }
    return const ['Helvetica Neue', 'Arial', 'sans-serif'];
  }

  /// Tizim shriftlari darhol mavjud — alohida yuklash shart emas.
  static Future<void> ensureFontLoaded(ReceiptFontId font) async {}
}
