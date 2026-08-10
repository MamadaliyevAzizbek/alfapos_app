import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/product.dart';

/// Mahalliy mahsulot katalogi va serverga yuborish navbati.
class ProductCatalogStorage {
  ProductCatalogStorage._();

  static const _catalogKey = 'alfapos_product_catalog_v1';
  static const _queueKey = 'alfapos_product_sync_queue_v1';
  static const _metaKey = 'alfapos_product_catalog_meta_v1';

  static Future<void> saveCatalog(List<Product> products) async {
    final prefs = await SharedPreferences.getInstance();
    final list = products.map((p) => p.toJson()).toList();
    await prefs.setString(_catalogKey, jsonEncode(list));
  }

  static Future<List<Product>> loadCatalog() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_catalogKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map>()
          .map((e) => Product.fromJson(Map<String, dynamic>.from(e)))
          .where((p) => p.id.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveSyncMeta(ProductCatalogSyncMeta meta) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_metaKey, jsonEncode(meta.toJson()));
  }

  static Future<ProductCatalogSyncMeta?> loadSyncMeta() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_metaKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw);
      if (map is! Map) return null;
      return ProductCatalogSyncMeta.fromJson(Map<String, dynamic>.from(map));
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearSyncMeta() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_metaKey);
  }

  static Future<void> saveSyncQueue(List<ProductSyncJob> jobs) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_queueKey, jsonEncode(jobs.map((j) => j.toJson()).toList()));
  }

  static Future<List<ProductSyncJob>> loadSyncQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_queueKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map>()
          .map((e) => ProductSyncJob.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return [];
    }
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

/// Orqa fonda serverga yuborish vazifasi.
class ProductSyncJob {
  final String jobId;
  final String productId;
  final bool isCreate;
  final bool deleteImage;

  const ProductSyncJob({
    required this.jobId,
    required this.productId,
    required this.isCreate,
    this.deleteImage = false,
  });

  Map<String, dynamic> toJson() => {
        'jobId': jobId,
        'productId': productId,
        'isCreate': isCreate,
        'deleteImage': deleteImage,
      };

  factory ProductSyncJob.fromJson(Map<String, dynamic> json) {
    return ProductSyncJob(
      jobId: json['jobId']?.toString() ?? '',
      productId: json['productId']?.toString() ?? '',
      isCreate: json['isCreate'] == true,
      deleteImage: json['deleteImage'] == true,
    );
  }
}
