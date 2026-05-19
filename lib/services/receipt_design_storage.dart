import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/receipt_design_config.dart';

/// Rasm tanlash natijasi.
class ReceiptImagePickResult {
  final String? path;
  final String? error;
  final bool cancelled;

  const ReceiptImagePickResult({this.path, this.error, this.cancelled = false});

  bool get ok => path != null && path!.isNotEmpty;
}

/// Chek dizaynini mahalliy saqlash (SharedPreferences + rasmlar papkasi).
class ReceiptDesignStorage {
  ReceiptDesignStorage._();

  static const _prefsKey = 'receipt_design_config_v1';
  static ReceiptDesignConfig? _cache;

  static Future<ReceiptDesignConfig> load() async {
    if (_cache != null) return _cache!;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) {
      _cache = ReceiptDesignConfig.presetTableColumns();
      return _cache!;
    }
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      _cache = ReceiptDesignConfig.fromJson(map);
      await _pruneMissingFiles(_cache!);
      return _cache!;
    } catch (_) {
      _cache = ReceiptDesignConfig.presetTableColumns();
      return _cache!;
    }
  }

  static Future<void> save(ReceiptDesignConfig config) async {
    _cache = config;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(config.toJson()));
  }

  static Future<Directory> _designDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/receipt_design');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static Future<ReceiptImagePickResult> pickAndSaveLogo() => _pickImage('logo');

  static Future<ReceiptImagePickResult> pickAndSaveFooterImage() => _pickImage('footer');

  static bool get _useNativeFileDialog =>
      !kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux);

  static Future<ReceiptImagePickResult> _pickImage(String prefix) async {
    try {
      String? srcPath;

      if (_useNativeFileDialog) {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          allowMultiple: false,
          dialogTitle: prefix == 'logo' ? 'Logo rasmini tanlang' : 'Pastki rasmni tanlang',
          withData: false,
          withReadStream: false,
        );
        if (result == null) {
          return const ReceiptImagePickResult(cancelled: true);
        }
        if (result.files.isEmpty) {
          return const ReceiptImagePickResult(cancelled: true);
        }
        srcPath = result.files.single.path;
        if (srcPath == null || srcPath.isEmpty) {
          return const ReceiptImagePickResult(
            error: 'Fayl yo\'li topilmadi. macOS da ilovani qayta ishga tushiring.',
          );
        }
      } else {
        final picker = ImagePicker();
        final file = await picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 800,
          maxHeight: 800,
          imageQuality: 92,
        );
        if (file == null) {
          return const ReceiptImagePickResult(cancelled: true);
        }
        srcPath = file.path;
      }

      final src = File(srcPath);
      if (!await src.exists()) {
        return const ReceiptImagePickResult(error: 'Tanlangan fayl topilmadi');
      }

      final dir = await _designDir();
      final ext = _safeExt(srcPath);
      final dest = File('${dir.path}/${prefix}_${DateTime.now().millisecondsSinceEpoch}.$ext');
      await src.copy(dest.path);
      return ReceiptImagePickResult(path: dest.path);
    } catch (e, st) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('[ReceiptDesignStorage] pickImage: $e\n$st');
      }
      return ReceiptImagePickResult(error: 'Rasm tanlab bo\'lmadi: $e');
    }
  }

  static String _safeExt(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'jpg';
    if (lower.endsWith('.webp')) return 'webp';
    if (lower.endsWith('.gif')) return 'gif';
    return 'png';
  }

  static Future<void> _pruneMissingFiles(ReceiptDesignConfig config) async {
    for (final p in [config.logoPath, config.footerImagePath]) {
      if (p == null || p.isEmpty) continue;
      final f = File(p);
      if (!await f.exists()) {
        _cache = config.copyWith(
          clearLogo: p == config.logoPath,
          clearFooterImage: p == config.footerImagePath,
        );
        await save(_cache!);
      }
    }
  }

  static void invalidateCache() => _cache = null;
}
