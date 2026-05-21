import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/receipt_design_config.dart';

/// Chek dizayni va logo faylini saqlash.
class ReceiptDesignStorage {
  ReceiptDesignStorage._();

  static const _prefsKey = 'receipt_design_config_v1';
  static const _logoFileName = 'receipt_logo.png';

  static ReceiptDesignConfig? _cache;

  static Future<ReceiptDesignConfig> load() async {
    if (_cache != null) return _cache!;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) {
      _cache = ReceiptDesignConfig.defaults;
      return _cache!;
    }
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      _cache = ReceiptDesignConfig.fromJson(map);
      return _cache!;
    } catch (_) {
      _cache = ReceiptDesignConfig.defaults;
      return _cache!;
    }
  }

  static Future<void> save(ReceiptDesignConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(config.toJson()));
    _cache = config;
  }

  static void invalidateCache() => _cache = null;

  static Future<String> logoDirectory() async {
    final dir = await getApplicationSupportDirectory();
    final sub = Directory('${dir.path}/receipt');
    if (!await sub.exists()) await sub.create(recursive: true);
    return sub.path;
  }

  static Future<String> defaultLogoPath() async {
    return '${await logoDirectory()}/$_logoFileName';
  }

  /// Tanlangan fayldan logo nusxalash.
  static Future<ReceiptDesignConfig> saveLogoFromPath(
    ReceiptDesignConfig current,
    String sourcePath,
  ) async {
    final src = File(sourcePath);
    if (!await src.exists()) return current;
    final dest = await defaultLogoPath();
    await src.copy(dest);
    return current.copyWith(showLogo: true, logoFilePath: dest);
  }

  static Future<ReceiptDesignConfig> removeLogo(ReceiptDesignConfig current) async {
    final path = current.logoFilePath;
    if (path != null && path.isNotEmpty) {
      final f = File(path);
      if (await f.exists()) await f.delete();
    }
    return current.copyWith(showLogo: false, clearLogoPath: true);
  }

  static Future<String?> copyBundledDefaultLogoIfNeeded() async {
    final dest = await defaultLogoPath();
    final f = File(dest);
    if (await f.exists()) return dest;
    try {
      final bytes = await rootBundle.load('Untitled-1-03.png');
      await f.writeAsBytes(bytes.buffer.asUint8List());
      return dest;
    } catch (_) {
      try {
        final bytes = await rootBundle.load('assets/branding/alfapos_logo.png');
        await f.writeAsBytes(bytes.buffer.asUint8List());
        return dest;
      } catch (_) {
        return null;
      }
    }
  }

  static Future<bool> logoFileExists(String? path) async {
    if (path == null || path.isEmpty) return false;
    return File(path).exists();
  }
}
