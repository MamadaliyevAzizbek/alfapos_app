import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/auth_storage.dart';
import 'product_image_upload.dart';

/// Kategoriya rasmlari — kompaniya bo‘yicha mahalliy (restoran POS kartochkalari).
class CategoryImageStorage {
  CategoryImageStorage._();

  static const _keyBase = 'alfapos_category_images_v1';
  static const _subdir = 'category_images';

  static Future<Directory> _imagesDirectory() async {
    final dir = await getApplicationDocumentsDirectory();
    final imagesDir = Directory('${dir.path}/$_subdir');
    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }
    return imagesDir;
  }

  static Future<Map<String, String>> loadMap() async {
    final prefs = await SharedPreferences.getInstance();
    final key = await companyStorageKey(_keyBase);
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return decoded.map((k, v) => MapEntry(k.toString(), v.toString()));
      }
    } catch (_) {}
    return {};
  }

  static Future<void> _saveMap(Map<String, String> map) async {
    final prefs = await SharedPreferences.getInstance();
    final key = await companyStorageKey(_keyBase);
    await prefs.setString(key, jsonEncode(map));
  }

  static String _safeCategoryFileName(String categoryId) {
    return categoryId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
  }

  static Future<String?> persistForCategory(String categoryId, String sourcePath) async {
    final resolved = ProductImageUpload.resolveLocalPath(sourcePath);
    if (resolved == null) return null;
    final src = File(resolved);
    if (!await src.exists()) return null;

    final imagesDir = await _imagesDirectory();
    final ext = _extensionFromPath(resolved);
    final dest = File(
      '${imagesDir.path}/cat_${_safeCategoryFileName(categoryId)}_${DateTime.now().millisecondsSinceEpoch}$ext',
    );
    await src.copy(dest.path);
    return dest.path;
  }

  static String _extensionFromPath(String path, {String fallback = '.jpg'}) {
    final dot = path.lastIndexOf('.');
    if (dot <= 0 || dot >= path.length - 1) return fallback;
    final ext = path.substring(dot).toLowerCase();
    return RegExp(r'^\.(jpe?g|png|webp|gif)$').hasMatch(ext) ? ext : fallback;
  }

  static Future<void> _deleteFile(String? path) async {
    if (path == null || path.trim().isEmpty) return;
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  static Future<void> setImage(String categoryId, String? localPath) async {
    final id = categoryId.trim();
    if (id.isEmpty) return;
    final map = await loadMap();
    if (localPath == null || localPath.trim().isEmpty) {
      final old = map.remove(id);
      await _deleteFile(old);
      await _saveMap(map);
      return;
    }

    final persisted = await persistForCategory(id, localPath);
    if (persisted == null) return;
    final old = map[id];
    if (old != null && old != persisted) await _deleteFile(old);
    map[id] = persisted;
    await _saveMap(map);
  }

  static Future<void> removeImage(String categoryId) => setImage(categoryId, null);
}
