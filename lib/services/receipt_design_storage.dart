import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/receipt_design_config.dart';
import '../utils/thermal_receipt_logo_fit.dart';
import '../widgets/receipt_logo_image.dart';
import 'escpos_receipt_builder.dart';

/// Chek dizayni va logo faylini saqlash.
class ReceiptDesignStorage {
  ReceiptDesignStorage._();

  static const _prefsKey = 'receipt_design_config_v1';
  static const _logoFileName = 'receipt_logo.png';
  static const bundledDefaultLogoAsset = 'Untitled-1-08.png';
  static const _defaultLogoVersionKey = 'receipt_default_logo_version';
  static const _defaultLogoVersion = 4;
  static const _userDisabledLogoKey = 'receipt_logo_user_disabled_v1';

  static ReceiptDesignConfig? _cache;

  static Future<ReceiptDesignConfig> load() async {
    if (_cache != null) return _ensureDefaultLogo(_cache!);
    return reload();
  }

  /// Keshsiz — chop etish va sozlamalar preview uchun.
  static Future<ReceiptDesignConfig> reload() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) {
      _cache = ReceiptDesignConfig.defaults;
      return _ensureDefaultLogo(_cache!);
    }
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      _cache = ReceiptDesignConfig.fromJson(map);
      return _ensureDefaultLogo(_cache!);
    } catch (_) {
      _cache = ReceiptDesignConfig.defaults;
      return _ensureDefaultLogo(_cache!);
    }
  }

  static bool _isUserPickedLogo(String? path) {
    if (path == null || path.isEmpty) return false;
    final name = path.split(RegExp(r'[/\\]')).last;
    return name.startsWith('receipt_logo_') && name != _logoFileName;
  }

  static Future<bool> _isLogoUserDisabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_userDisabledLogoKey) ?? false;
  }

  static Future<void> _setLogoUserDisabled(bool disabled) async {
    final prefs = await SharedPreferences.getInstance();
    if (disabled) {
      await prefs.setBool(_userDisabledLogoKey, true);
    } else {
      await prefs.remove(_userDisabledLogoKey);
    }
  }

  /// O‘rnatilganda / yangilanishda default logo (foydalanuvchi o‘chirmagan bo‘lsa).
  static Future<ReceiptDesignConfig> _ensureDefaultLogo(
    ReceiptDesignConfig current,
  ) async {
    if (await _isLogoUserDisabled()) {
      return current.copyWith(showLogo: false);
    }
    if (_isUserPickedLogo(current.logoFilePath) &&
        await logoFileExists(current.logoFilePath)) {
      if (current.showLogo) return current;
      final on = current.copyWith(showLogo: true);
      await save(on);
      return on;
    }
    final path = await copyBundledDefaultLogoIfNeeded();
    if (path == null) return current.copyWith(showLogo: true);
    if (current.showLogo && current.logoFilePath == path) return current;
    final updated = current.copyWith(showLogo: true, logoFilePath: path);
    await save(updated);
    return updated;
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
    final prepared = ThermalReceiptLogoFit.preparePngBytes(bytes);
    final outBytes = prepared ?? bytes;
    final destExt = prepared != null ? '.png' : ext;
    final dest =
        '${await logoDirectory()}/receipt_logo_${DateTime.now().millisecondsSinceEpoch}$destExt';
    await File(dest).writeAsBytes(outBytes, flush: true);
    await _deleteLogoFileIfNeeded(previousPath);

    ReceiptLogoImage.evictCache();
    EscPosReceiptBuilder.invalidateLogoCache();
    invalidateCache();
    await _setLogoUserDisabled(false);
    final updated = current.copyWith(showLogo: true, logoFilePath: dest);
    await save(updated);
    return updated;
  }

  static Future<ReceiptDesignConfig> removeLogo(ReceiptDesignConfig current) async {
    await _deleteLogoFileIfNeeded(current.logoFilePath);
    ReceiptLogoImage.evictCache();
    EscPosReceiptBuilder.invalidateLogoCache();
    await _setLogoUserDisabled(true);
    return current.copyWith(showLogo: false, clearLogoPath: true);
  }

  static Future<ReceiptDesignConfig> setShowLogo(
    ReceiptDesignConfig current,
    bool show,
  ) async {
    if (!show) {
      await _setLogoUserDisabled(true);
      final updated = current.copyWith(showLogo: false);
      await save(updated);
      return updated;
    }
    await _setLogoUserDisabled(false);
    return _ensureDefaultLogo(current.copyWith(showLogo: true));
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

  /// Chop etishdan oldin: default logo fayli bor va yoqilgan bo‘lsin.
  static Future<ReceiptDesignConfig> prepareForPrint(
    ReceiptDesignConfig? incoming,
  ) async {
    if (await _isLogoUserDisabled()) {
      debugPrint('[ChekLogo] o‘chirilgan (user)');
      final cfg = incoming ?? await load();
      return cfg.copyWith(showLogo: false);
    }
    var cfg = incoming ?? await load();
    if (_isUserPickedLogo(cfg.logoFilePath) &&
        await logoFileExists(cfg.logoFilePath)) {
      final on = cfg.copyWith(showLogo: true);
      debugPrint('[ChekLogo] custom ${on.logoFilePath}');
      return on;
    }
    final missing = !await logoFileExists(cfg.logoFilePath);
    final path = await copyBundledDefaultLogoIfNeeded(force: missing);
    if (path == null) {
      debugPrint('[ChekLogo] bundled logo yozilmadi');
      return cfg.copyWith(showLogo: true);
    }
    final updated = cfg.copyWith(showLogo: true, logoFilePath: path);
    await save(updated);
    debugPrint('[ChekLogo] tayyor path=$path exists=true');
    return updated;
  }

  static Future<String?> copyBundledDefaultLogoIfNeeded({bool force = false}) async {
    final dest = await defaultLogoPath();
    final f = File(dest);
    final prefs = await SharedPreferences.getInstance();
    final version = prefs.getInt(_defaultLogoVersionKey) ?? 0;
    if (!force && await f.exists() && version >= _defaultLogoVersion) return dest;
    try {
      final bytes = await rootBundle.load(bundledDefaultLogoAsset);
      final raw = bytes.buffer.asUint8List();
      final prepared = ThermalReceiptLogoFit.preparePngBytes(raw) ?? raw;
      await f.writeAsBytes(prepared, flush: true);
      await prefs.setInt(_defaultLogoVersionKey, _defaultLogoVersion);
      ReceiptLogoImage.evictCache();
      EscPosReceiptBuilder.invalidateLogoCache();
      debugPrint('[ChekLogo] bundled yozildi $dest (${prepared.length} b)');
      return dest;
    } catch (e) {
      debugPrint('[ChekLogo] Untitled-1-08 yuklanmadi: $e');
      try {
        final bytes = await rootBundle.load('assets/branding/alfapos_logo.png');
        final raw = bytes.buffer.asUint8List();
        final prepared = ThermalReceiptLogoFit.preparePngBytes(raw) ?? raw;
        await f.writeAsBytes(prepared, flush: true);
        return dest;
      } catch (e2) {
        debugPrint('[ChekLogo] fallback ham yo‘q: $e2');
        return await f.exists() ? dest : null;
      }
    }
  }

  static Future<bool> logoFileExists(String? path) async {
    if (path == null || path.isEmpty) return false;
    return File(path).exists();
  }
}
