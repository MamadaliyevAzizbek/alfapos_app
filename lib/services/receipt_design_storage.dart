import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/receipt_design_config.dart';
import '../widgets/receipt_logo_image.dart';
import 'escpos_receipt_builder.dart';

/// Chek dizayni va logo faylini saqlash.
class ReceiptDesignStorage {
  ReceiptDesignStorage._();

  static const _prefsKey = 'receipt_design_config_v1';
  static const _logoFileName = 'receipt_logo.png';

  static ReceiptDesignConfig? _cache;

  static Future<ReceiptDesignConfig> load() async {
    if (_cache != null) return _cache!;
    return reload();
  }

  /// Keshsiz — chop etish va sozlamalar preview uchun.
  static Future<ReceiptDesignConfig> reload() async {
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

  /// Tanlangan fayldan logo saqlash (har safar yangi fayl).
  static Future<ReceiptDesignConfig> saveLogoFromPath(
    ReceiptDesignConfig current,
    String sourcePath,
  ) async {
    final src = File(sourcePath);
    if (!await src.exists()) {
      throw StateError('Logo fayli topilmadi: $sourcePath');
    }
    final bytes = await src.readAsBytes();
    if (bytes.isEmpty) {
      throw StateError('Logo fayli bo\'sh');
    }
    return saveLogoFromBytes(
      current,
      bytes,
      extension: _logoExtension(sourcePath),
    );
  }

  static Future<ReceiptDesignConfig> saveLogoFromBytes(
    ReceiptDesignConfig current,
    Uint8List bytes, {
    required String extension,
  }) async {
    if (bytes.isEmpty) {
      throw StateError('Logo fayli bo\'sh');
    }

    final previousPath = current.logoFilePath;
    final ext = extension.startsWith('.') ? extension : '.$extension';
    final dest =
        '${await logoDirectory()}/receipt_logo_${DateTime.now().millisecondsSinceEpoch}$ext';
    await File(dest).writeAsBytes(bytes, flush: true);
    await _deleteLogoFileIfNeeded(previousPath);

    ReceiptLogoImage.evictCache();
    EscPosReceiptBuilder.invalidateLogoCache();
    invalidateCache();
    final updated = current.copyWith(showLogo: true, logoFilePath: dest);
    await save(updated);
    return updated;
  }

  static Future<ReceiptDesignConfig> removeLogo(ReceiptDesignConfig current) async {
    await _deleteLogoFileIfNeeded(current.logoFilePath);
    ReceiptLogoImage.evictCache();
    return current.copyWith(showLogo: false, clearLogoPath: true);
  }

  static String _logoExtension(String path) {
    final dot = path.lastIndexOf('.');
    if (dot <= 0 || dot >= path.length - 1) return '.png';
    final ext = path.substring(dot).toLowerCase();
    const allowed = {'.png', '.jpg', '.jpeg', '.webp', '.gif', '.bmp'};
    return allowed.contains(ext) ? ext : '.png';
  }

  static Future<void> _deleteLogoFileIfNeeded(String? path) async {
    if (path == null || path.isEmpty) return;
    final f = File(path);
    if (await f.exists()) await f.delete();
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
