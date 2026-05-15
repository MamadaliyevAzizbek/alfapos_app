import 'api_config.dart';

/// API dan kelgan mahsulot rasm yo'lini to'liq URL ga aylantirish.
class ProductImageUtils {
  ProductImageUtils._();

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
