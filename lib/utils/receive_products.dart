import '../models/product.dart';

/// POST /receives/products javobini Product ro'yxatiga aylantirish.
class ReceiveProducts {
  ReceiveProducts._();

  /// Variant merge qilganda mahsulot nomi/sarlavhasi variant `title` bilan almashtirilmasin.
  static const _productIdentityKeys = [
    'title',
    'name',
    'product_name',
    'product_title',
    'productTitle',
    'description',
    'sku',
    'image',
    'image_url',
    'imageUrl',
    'product_image',
  ];

  static void _restoreProductIdentity(Map<String, dynamic> merged, Map<String, dynamic> product) {
    for (final key in _productIdentityKeys) {
      if (!product.containsKey(key)) continue;
      final v = product[key];
      if (v == null) continue;
      final s = v.toString().trim();
      if (s.isEmpty || s.startsWith('<')) continue;
      merged[key] = v;
    }
  }

  static List<Map<String, dynamic>> mergeProductsWithVariants(Map<String, dynamic> res) {
    final productsRaw = res['products'] ?? res['data'];
    List<dynamic> productsList = [];
    if (productsRaw is List<dynamic>) productsList = productsRaw;
    if (productsList.isEmpty) return [];

    final variantsRaw = res['variants'] ?? [];
    final variants = variantsRaw is List<dynamic>
        ? variantsRaw
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .where((m) => m.isNotEmpty)
            .toList()
        : <Map<String, dynamic>>[];

    final result = <Map<String, dynamic>>[];
    for (final p in productsList) {
      if (p is! Map) continue;
      final product = Map<String, dynamic>.from(p);
      final productId = product['productID'] ?? product['id'];
      if (productId == null) continue;
      final productIdInt = productId is int ? productId : int.tryParse(productId.toString());
      Map<String, dynamic>? variant;
      for (final v in variants) {
        final vid = v['product_id'] ?? v['productID'];
        if (vid == null) continue;
        final vInt = vid is int ? vid : int.tryParse(vid.toString());
        if (vInt == productIdInt) {
          variant = v;
          break;
        }
      }
      final merged = Map<String, dynamic>.from(product);
      if (variant != null) {
        final productId = product['productID'] ?? product['id'];
        final variantId = variant['id'] ?? variant['variantID'];
        merged.addAll(variant);
        if (productId != null) {
          merged['productID'] = productId;
          merged['id'] = productId;
        }
        if (variantId != null) merged['variantID'] = variantId;
        _restoreProductIdentity(merged, product);
        merged['quantity'] = variant['availableQuantity'];
        merged['variants'] = [variant];
      }
      result.add(merged);
    }
    return result;
  }

  static List<Product> productsFromApiResponse(Map<String, dynamic> res) {
    final rows = mergeProductsWithVariants(res);
    return rows
        .map((e) {
          try {
            return Product.fromApiJson(e);
          } catch (_) {
            return null;
          }
        })
        .whereType<Product>()
        .where((p) => p.id.isNotEmpty)
        .toList();
  }

  static Product? productFromBarcodeResult(dynamic raw) {
    if (raw is! Map) return null;
    final m = Map<String, dynamic>.from(raw);
    try {
      return Product.fromApiJson(m);
    } catch (_) {
      return null;
    }
  }
}
