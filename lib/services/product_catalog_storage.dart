import '../models/product.dart';
import 'company_cache_store.dart';

/// Mahalliy mahsulot katalogi (kompaniya keshi).
class ProductCatalogStorage {
  ProductCatalogStorage._();

  static Future<void> saveCatalog(List<Product> products) async {
    await CompanyCacheStore.writeJson(
      CompanyCacheStore.productCatalog,
      products.map((p) => p.toJson()).toList(),
    );
  }

  static Future<List<Product>> loadCatalog() async {
    final decoded = await CompanyCacheStore.readJson(CompanyCacheStore.productCatalog);
    if (decoded is! List) return [];
    try {
      return decoded
          .whereType<Map>()
          .map((e) => Product.fromJson(Map<String, dynamic>.from(e)))
          .where((p) => p.id.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveSyncMeta(ProductCatalogSyncMeta meta) async {
    await CompanyCacheStore.writeJson(CompanyCacheStore.productCatalogMeta, meta.toJson());
  }

  static Future<ProductCatalogSyncMeta?> loadSyncMeta() async {
    final decoded = await CompanyCacheStore.readJson(CompanyCacheStore.productCatalogMeta);
    if (decoded is! Map) return null;
    try {
      return ProductCatalogSyncMeta.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearSyncMeta() async {
    await CompanyCacheStore.remove(CompanyCacheStore.productCatalogMeta);
  }

  static Future<void> clearAll() async {
    await CompanyCacheStore.remove(CompanyCacheStore.productCatalog);
    await CompanyCacheStore.remove(CompanyCacheStore.productCatalogMeta);
    await CompanyCacheStore.remove(CompanyCacheStore.productSyncQueueLegacy);
  }
}

/// Serverdagi katalog o‘zgarganini arzon aniqlash (count + totalQuantity + namuna).
class ProductCatalogSyncMeta {
  final int count;
  final String totalQuantity;
  final String sampleFingerprint;
  final DateTime savedAt;

  const ProductCatalogSyncMeta({
    required this.count,
    required this.totalQuantity,
    required this.sampleFingerprint,
    required this.savedAt,
  });

  bool matches(ProductCatalogSyncMeta other) =>
      count == other.count &&
      totalQuantity == other.totalQuantity &&
      sampleFingerprint == other.sampleFingerprint;

  Map<String, dynamic> toJson() => {
        'count': count,
        'totalQuantity': totalQuantity,
        'sampleFingerprint': sampleFingerprint,
        'savedAt': savedAt.toIso8601String(),
      };

  factory ProductCatalogSyncMeta.fromJson(Map<String, dynamic> json) {
    return ProductCatalogSyncMeta(
      count: (json['count'] as num?)?.toInt() ?? 0,
      totalQuantity: json['totalQuantity']?.toString() ?? '',
      sampleFingerprint: json['sampleFingerprint']?.toString() ?? '',
      savedAt: DateTime.tryParse(json['savedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  /// API birinchi sahifasidan fingerprint.
  static ProductCatalogSyncMeta fromApiPage(Map<String, dynamic> res, List<dynamic> rows) {
    final count = (res['count'] as num?)?.toInt() ?? rows.length;
    final totalQuantity = (res['totalQuantity'] ?? res['total_quantity'] ?? '').toString();
    final sample = rows.take(30).map((e) {
      if (e is! Map) return '';
      final m = Map<String, dynamic>.from(e);
      final id = (m['productID'] ?? m['product_id'] ?? m['id'] ?? '').toString();
      final qty = (m['product_quantity'] ?? m['quantity'] ?? m['qty'] ?? '').toString();
      final price = (m['selling_price'] ?? m['sell_price'] ?? m['price'] ?? '').toString();
      return '$id:$qty:$price';
    }).join('|');
    return ProductCatalogSyncMeta(
      count: count,
      totalQuantity: totalQuantity,
      sampleFingerprint: sample,
      savedAt: DateTime.now(),
    );
  }
}
