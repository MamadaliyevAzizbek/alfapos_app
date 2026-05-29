import 'api_config.dart';

/// API dan kelgan mahsulot rasm yo'lini to'liq URL ga aylantirish.
class ProductImageUtils {
  ProductImageUtils._();

  /// Boshqa POS dagi mahalliy disk yo'li (Windows/macOS) — URL ga aylantirilmaydi.
  static bool isLocalFilePath(String? raw) {
    if (raw == null) return false;
    var t = raw.trim();
    if (t.isEmpty) return false;
    if (t.startsWith('file://')) return true;
    if (RegExp(r'^[a-zA-Z]:[\\/]').hasMatch(t)) return true;
    if (t.contains('\\')) return true;
    final norm = t.replaceAll('\\', '/').toLowerCase();
    if (norm.contains('/product_images/')) return true;
    if (t.startsWith('/') && !t.startsWith('//')) {
      if (!norm.startsWith('/uploads/') &&
          !norm.startsWith('/storage/') &&
          !norm.startsWith('/public/')) {
        return true;
      }
    }
    return false;
  }

  static String resolveToUrl(String? raw) {
    var t = (raw ?? '').trim();
    if (t.isEmpty || t == 'null' || t == 'undefined') return '';
    if (t.startsWith('//')) return 'https:$t';
    if (t.startsWith('http://app.alfapos.uz')) {
      t = t.replaceFirst('http://', 'https://');
    }
    if (t.startsWith('http://nasiyapos.uz')) {
      t = t.replaceFirst('http://', 'https://');
    }
    if (t.startsWith('https://') || t.startsWith('http://')) return t;

    if (isLocalFilePath(t)) {
      final parts = t.split(RegExp(r'[/\\]'));
      final fileName = parts.isNotEmpty ? parts.last.trim() : '';
      if (fileName.isNotEmpty && !fileName.contains(':')) {
        return resolveToUrl(fileName);
      }
      return '';
    }

    if (t.startsWith('public/')) {
      t = t.replaceFirst('public/', 'storage/');
    }
    if (t.startsWith('storage/') || t.startsWith('uploads/')) {
      return Uri.parse(ApiConfig.baseUrl).resolve('/$t').toString();
    }
    final base = Uri.parse(ApiConfig.baseUrl);
    if (t.startsWith('/')) {
      return base.resolve(t).toString();
    }
    // API ba'zan faqat fayl nomini yuboradi: "product_123.png" (slash yo'q)
    if (!t.contains('/') && !t.contains('\\')) {
      final lower = t.toLowerCase();
      if (lower == 'non.jpg' ||
          lower.startsWith('no_ima') ||
          lower.contains('no-image') ||
          lower == 'placeholder.jpg' ||
          lower == 'no_image.jpg') {
        return '';
      }
      return base.resolve('/uploads/products/$t').toString();
    }
    return base.resolve('/$t').toString();
  }
}
