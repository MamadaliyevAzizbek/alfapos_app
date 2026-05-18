import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/product.dart';

/// Mahalliy mahsulot katalogi va serverga yuborish navbati.
class ProductCatalogStorage {
  ProductCatalogStorage._();

  static const _catalogKey = 'alfapos_product_catalog_v1';
  static const _queueKey = 'alfapos_product_sync_queue_v1';

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
