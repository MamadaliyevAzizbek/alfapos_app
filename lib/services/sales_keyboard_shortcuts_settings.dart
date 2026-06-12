import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Sotuv bo‘limi tezkor klavishlari (F-tugmalar).
enum SalesShortcutAction {
  focusCustomerSearch,
  focusProductSearch,
  focusLastCartQty,
  toggleShowPurchasePrice,
}

class SalesKeyboardShortcutsSettings {
  SalesKeyboardShortcutsSettings._();

  static const _prefix = 'sales_kb_shortcut_v1_';

  static const Map<SalesShortcutAction, String> defaults = {
    SalesShortcutAction.focusCustomerSearch: 'f2',
    SalesShortcutAction.focusProductSearch: 'f7',
    SalesShortcutAction.focusLastCartQty: 'f5',
    SalesShortcutAction.toggleShowPurchasePrice: 'f12',
  };

  static const List<String> allowedKeyIds = [
    'f1',
    'f2',
    'f3',
    'f4',
    'f5',
    'f6',
    'f7',
    'f8',
    'f9',
    'f10',
    'f11',
    'f12',
  ];

  /// Sozlamalar o‘zgarganda sotuv ekrani qayta yuklanadi.
  static final ValueNotifier<int> revision = ValueNotifier(0);

  static String label(SalesShortcutAction action) => switch (action) {
        SalesShortcutAction.focusCustomerSearch => 'Mijoz qidirish',
        SalesShortcutAction.focusProductSearch => 'Mahsulot qidirish',
        SalesShortcutAction.focusLastCartQty => 'Oxirgi mahsulot miqdori',
        SalesShortcutAction.toggleShowPurchasePrice => 'Kelish narxini ko‘rsatish',
      };

  static String formatKeyLabel(String keyId) => keyId.toUpperCase();

  static Future<Map<SalesShortcutAction, String>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final out = <SalesShortcutAction, String>{};
    for (final action in SalesShortcutAction.values) {
      final raw = prefs.getString('$_prefix${action.name}')?.trim().toLowerCase();
      out[action] = allowedKeyIds.contains(raw) ? raw! : defaults[action]!;
    }
    return out;
  }

  static Future<void> saveAll(Map<SalesShortcutAction, String> keys) async {
    final prefs = await SharedPreferences.getInstance();
    for (final action in SalesShortcutAction.values) {
      final raw = keys[action]?.trim().toLowerCase();
      final value = allowedKeyIds.contains(raw) ? raw! : defaults[action]!;
      await prefs.setString('$_prefix${action.name}', value);
    }
    revision.value++;
  }

  static Future<void> resetAll() async {
    await saveAll(defaults);
  }

  static bool hasDuplicateKeys(Map<SalesShortcutAction, String> keys) {
    final used = keys.values.map((e) => e.trim().toLowerCase()).toList();
    return used.toSet().length != used.length;
  }

  static LogicalKeyboardKey? parseKey(String raw) {
    return switch (raw.trim().toLowerCase()) {
      'f1' => LogicalKeyboardKey.f1,
      'f2' => LogicalKeyboardKey.f2,
      'f3' => LogicalKeyboardKey.f3,
      'f4' => LogicalKeyboardKey.f4,
      'f5' => LogicalKeyboardKey.f5,
      'f6' => LogicalKeyboardKey.f6,
      'f7' => LogicalKeyboardKey.f7,
      'f8' => LogicalKeyboardKey.f8,
      'f9' => LogicalKeyboardKey.f9,
      'f10' => LogicalKeyboardKey.f10,
      'f11' => LogicalKeyboardKey.f11,
      'f12' => LogicalKeyboardKey.f12,
      _ => null,
    };
  }

  static Map<ShortcutActivator, SalesShortcutAction> buildActivators(
    Map<SalesShortcutAction, String> keys,
  ) {
    final map = <ShortcutActivator, SalesShortcutAction>{};
    for (final entry in keys.entries) {
      final logical = parseKey(entry.value);
      if (logical != null) {
        map[SingleActivator(logical)] = entry.key;
      }
    }
    return map;
  }
}
