import 'dart:io';
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
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

  static const int uploadMaxSide = 1280;
  static const int uploadJpegQuality = 80;
  static const String normalizedSuffix = '_n.jpg';

  /// EXIF oriyentatsiyani pikselga yozadi va uzun tomonni [maxSide] gacha qisqartiradi.
  static img.Image bakeAndResizeForUpload(img.Image src, {int maxSide = uploadMaxSide}) {
    var out = img.bakeOrientation(src);
    final side = out.width > out.height ? out.width : out.height;
    if (side > maxSide) {
      out = img.copyResize(
        out,
        width: out.width >= out.height ? maxSide : null,
        height: out.height > out.width ? maxSide : null,
        interpolation: img.Interpolation.linear,
      );
    }
    return out;
  }

  /// Isolate/testda: JPEG/PNG baytlarni tik turgan, ixcham JPEG qiladi.
  static Uint8List? normalizeJpegBytesSync(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;
    final baked = bakeAndResizeForUpload(decoded);
    return Uint8List.fromList(img.encodeJpg(baked, quality: uploadJpegQuality));
  }

  static Future<Uint8List?> normalizeJpegBytes(Uint8List bytes) {
    return compute(normalizeJpegBytesSync, bytes);
  }

  static bool _isNormalizedPath(String path) {
    return path.replaceAll('\\', '/').toLowerCase().endsWith(normalizedSuffix);
  }

  static Future<String?> _writeNormalizedJpeg(Uint8List jpeg) async {
    final imagesDir = await _imagesDirectory();
    final dest = File('${imagesDir.path}/img_${DateTime.now().millisecondsSinceEpoch}$normalizedSuffix');
    await dest.writeAsBytes(jpeg, flush: true);
    return dest.path;
  }

  /// Kameradan kelgan yonboshi JPEG ni tiklab, yuklash uchun kichraytiradi.
  static Future<String?> persistNormalizedBytes(Uint8List bytes) async {
    final jpeg = await normalizeJpegBytes(bytes);
    if (jpeg == null) return null;
    return _writeNormalizedJpeg(jpeg);
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

  /// Galereya/kamera (XFile) — EXIF tiklanadi, JPEG qisqartiriladi.
  static Future<String?> persistFromXFile(XFile xFile) async {
    try {
      final bytes = await xFile.readAsBytes();
      if (bytes.isNotEmpty) {
        final normalized = await persistNormalizedBytes(bytes);
        if (normalized != null) return normalized;
      }
    } catch (_) {}
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
    if (_isNormalizedPath(resolved) && _isUnderAppImageDir(resolved)) return resolved;

    try {
      final bytes = await src.readAsBytes();
      if (bytes.isNotEmpty) {
        final normalized = await persistNormalizedBytes(bytes);
        if (normalized != null) return normalized;
      }
    } catch (_) {}

    if (_isUnderAppImageDir(resolved)) return resolved;
    final imagesDir = await _imagesDirectory();
    final safeExt = _extensionFromPath(resolved);
    final dest = File('${imagesDir.path}/img_${DateTime.now().millisecondsSinceEpoch}$safeExt');
    await src.copy(dest.path);
    return dest.path;
  }

  /// Serverga yuborishdan oldin: tik JPEG, kichik hajm.
  static Future<String?> prepareUploadPath(String? imageUrl) async {
    final local = resolveLocalPath(imageUrl);
    if (local == null) return null;
    final file = File(local);
    if (!await file.exists()) return null;
    if (_isNormalizedPath(local) && _isUnderAppImageDir(local)) return local;
    return persistLocalFile(local);
  }
}
