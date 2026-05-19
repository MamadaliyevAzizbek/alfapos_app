import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../core/desktop_runtime.dart';

/// Mahsulot rasmini diskda saqlash va POST /products/store|edit ga yuborish.
class ProductImageUpload {
  ProductImageUpload._();

  static const _subdir = 'product_images';

  /// `file://`, Windows yo'l — mahalliy fayl yo'li.
  static String? resolveLocalPath(String? imageUrl) {
    if (imageUrl == null || imageUrl.trim().isEmpty) return null;
    var t = imageUrl.trim();
    if (t.startsWith('file://')) {
      try {
        t = Uri.parse(t).toFilePath();
      } catch (_) {
        t = t.substring(7);
      }
    }
    final lower = t.toLowerCase();
    if (lower.startsWith('http://') || lower.startsWith('https://')) return null;
    return t;
  }

  static bool _isUnderAppImageDir(String path) {
    final norm = path.replaceAll('\\', '/').toLowerCase();
    return norm.contains('/$_subdir/');
  }

  static Future<Directory> _imagesDirectory() async {
    final dir = await getApplicationDocumentsDirectory();
    final imagesDir = Directory('${dir.path}/$_subdir');
    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }
    return imagesDir;
  }

  static String _extensionFromPath(String path, {String fallback = '.jpg'}) {
    final dot = path.lastIndexOf('.');
    if (dot <= 0 || dot >= path.length - 1) return fallback;
    final ext = path.substring(dot).toLowerCase();
    return RegExp(r'^\.(jpe?g|png|webp|gif)$').hasMatch(ext) ? ext : fallback;
  }

  /// Windows/macOS: tizim fayl tanlovchi (image_picker dan ishonchliroq).
  static Future<String?> pickDesktopImageFile() async {
    if (!isDesktopNative) return null;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: false,
      withReadStream: false,
    );
    if (result == null || result.files.isEmpty) return null;
    final path = result.files.single.path;
    if (path == null || path.trim().isEmpty) return null;
    return persistLocalFile(path);
  }

  /// Galereya/kamera (XFile) — mobil uchun eng ishonchli (`saveTo`).
  static Future<String?> persistFromXFile(XFile xFile) async {
    final imagesDir = await _imagesDirectory();
    final ext = _extensionFromPath(xFile.path);
    final dest = File('${imagesDir.path}/img_${DateTime.now().millisecondsSinceEpoch}$ext');
    try {
      await xFile.saveTo(dest.path);
      if (await dest.exists()) return dest.path;
    } catch (_) {}
    return persistLocalFile(xFile.path);
  }

  /// Tanlangan rasmni ilova papkasiga nusxalaydi (fon sync dan oldin yo'qolmasin).
  static Future<String?> persistLocalFile(String path) async {
    final resolved = resolveLocalPath(path);
    if (resolved == null) return null;
    final src = File(resolved);
    if (!await src.exists()) return null;
    if (_isUnderAppImageDir(resolved)) return resolved;

    final imagesDir = await _imagesDirectory();
    final safeExt = _extensionFromPath(resolved);
    final dest = File('${imagesDir.path}/img_${DateTime.now().millisecondsSinceEpoch}$safeExt');
    await src.copy(dest.path);
    return dest.path;
  }

  /// Serverga yuborishdan oldin: mavjud yo'l yoki nusxa.
  static Future<String?> prepareUploadPath(String? imageUrl) async {
    final local = resolveLocalPath(imageUrl);
    if (local == null) return null;
    final file = File(local);
    if (!await file.exists()) return null;
    if (_isUnderAppImageDir(local)) return local;
    return persistLocalFile(local);
  }
}
