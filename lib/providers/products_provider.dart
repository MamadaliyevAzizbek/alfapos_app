import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../core/api_client.dart';
import '../core/api_sync_throttle.dart';
import '../models/product.dart';
import '../services/api_service.dart';
import '../services/product_catalog_storage.dart';
import '../utils/barcode_validation.dart';
import '../utils/product_web_store_body.dart';
import 'categories_provider.dart';

class ProductsProvider extends ChangeNotifier {
  ProductsProvider._() {
    _items = [];
  }
  static final ProductsProvider _instance = ProductsProvider._();
  static ProductsProvider get instance => _instance;

  List<Product> _items = [];
  final _controller = StreamController<List<Product>>.broadcast();
  bool _loaded = false;
  String? _loadError;
  Map<String, dynamic>? _lastRawProducts;
  /// supporting-data dan unit_id -> to'liq nom (birlik); yangi mahsulot qo'shishda dropdown uchun
  Map<int, String>? _unitIdToName;
  /// unit_id -> qisqartma (short_name); barcha joyda mahsulot ko'rsatilganda shu ishlatiladi
  Map<int, String>? _unitIdToShortName;
  /// Oxirgi GET /products/supporting-data (filialni qayta so'ramaslik uchun)
  Map<String, dynamic>? _supportingDataRaw;
  /// Birinchi marta aniqlangan default filial (har safar API chaqirmaslik uchun)
  bool _defaultBranchResolved = false;
  int? _cachedDefaultBranchId;
  /// Serverga ketma-ket yuborish (navbat).
  bool _syncDrainActive = false;

  List<Product> get items => List.unmodifiable(_items);
  Stream<List<Product>> get stream => _controller.stream;
  bool get isLoaded => _loaded;
  String? get loadError => _loadError;
  Map<String, dynamic>? get lastRawProducts => _lastRawProducts;

  /// Avval diskdan (tez), keyin ixtiyoriy API dan yangilash (fon).
  Future<void> loadFromStorage({bool refreshInBackground = true}) async {
    final cached = await ProductCatalogStorage.loadCatalog();
    if (cached.isNotEmpty) {
      _items = cached;
      _loaded = true;
      _controller.add(items);
      notifyListeners();
    }
    if (refreshInBackground) {
      unawaited(_refreshCatalogFromApi());
    }
    unawaited(_drainSyncQueue());
  }

  Future<void> _refreshCatalogFromApi() async {
    await ApiSyncThrottle.runIfDue(
      'products_full_catalog',
      const Duration(minutes: 15),
      () async {
        try {
          await loadFromApi();
        } catch (_) {}
      },
    );
  }

  Future<void> _persistCatalog() => ProductCatalogStorage.saveCatalog(_items);

  static bool _isLocalOnlyProductId(String id) =>
      id.startsWith('local_') || int.tryParse(id) == null;

  Future<void> _enqueueSync(Product product, {required bool isCreate, bool deleteImage = false}) async {
    final queue = await ProductCatalogStorage.loadSyncQueue();
    final idx = queue.indexWhere((j) => j.productId == product.id);
    if (idx >= 0) {
      final prev = queue[idx];
      final stillLocal = _isLocalOnlyProductId(product.id);
      queue[idx] = ProductSyncJob(
        jobId: prev.jobId,
        productId: product.id,
        isCreate: prev.isCreate || isCreate || stillLocal,
        deleteImage: deleteImage || prev.deleteImage,
      );
    } else {
      queue.add(ProductSyncJob(
        jobId: '${DateTime.now().millisecondsSinceEpoch}',
        productId: product.id,
        isCreate: isCreate || _isLocalOnlyProductId(product.id),
        deleteImage: deleteImage,
      ));
    }
    await ProductCatalogStorage.saveSyncQueue(queue);
  }

  /// Darhol lokal katalogga yozadi; serverga fon rejimida yuboradi.
  Future<void> saveProductLocalFirst(
    Product product, {
    required bool isCreate,
    bool deleteImage = false,
  }) async {
    if (!_loaded || _items.isEmpty) {
      final cached = await ProductCatalogStorage.loadCatalog();
      if (cached.isNotEmpty) {
        _items = cached;
        _loaded = true;
      }
    }
    _assertBarcodesUnique(product);
    _upsertCachedProduct(product);
    await _persistCatalog();
    await _enqueueSync(product, isCreate: isCreate, deleteImage: deleteImage);
    unawaited(_drainSyncQueue());
  }

  Future<void> _drainSyncQueue() async {
    if (_syncDrainActive) return;
    _syncDrainActive = true;
    try {
      await _ensureUnitsLoaded();
      while (true) {
        final queue = await ProductCatalogStorage.loadSyncQueue();
        if (queue.isEmpty) break;
        final job = queue.first;
        final product = getProductById(job.productId);
        if (product == null) {
          queue.removeAt(0);
          await ProductCatalogStorage.saveSyncQueue(queue);
          continue;
        }
        try {
          // Navbatdagi mahsulot ham dublikat bo‘lsa serverga yuborilmaydi.
          _assertBarcodesUnique(product);
          if (job.isCreate || _isLocalOnlyProductId(product.id)) {
            await _syncCreateToServer(product);
          } else {
            await _syncUpdateToServer(product, deleteImage: job.deleteImage);
          }
          queue.removeAt(0);
          await ProductCatalogStorage.saveSyncQueue(queue);
          await _persistCatalog();
        } on ApiException catch (e) {
          if (e.statusCode == 422) {
            queue.removeAt(0);
            await ProductCatalogStorage.saveSyncQueue(queue);
            assert(() {
              // ignore: avoid_print
              print('Sync navbat: dublikat shtrix kod — serverga yuborilmadi (${product.id})');
              return true;
            }());
            continue;
          }
          break;
        } catch (_) {
          break;
        }
      }
    } finally {
      _syncDrainActive = false;
    }
  }

  /// Yangi/tahrirlashdan oldin: dublikat shtrix kod bo'lmasligi.
  Future<String?> validateProductBarcodes(Product product) async {
    if (!_loaded || _items.isEmpty) {
      final cached = await ProductCatalogStorage.loadCatalog();
      if (cached.isNotEmpty) {
        _items = cached;
        _loaded = true;
      }
    }
    return BarcodeValidation.validateForSave(
      barcodes: BarcodeValidation.collectFromProduct(product),
      catalog: _items,
      excludeProductId: product.id,
    );
  }

  void _assertBarcodesUnique(Product product) {
    final msg = BarcodeValidation.validateForSave(
      barcodes: BarcodeValidation.collectFromProduct(product),
      catalog: _items,
      excludeProductId: product.id,
    );
    if (msg != null) throw ApiException(msg, 422);
  }

  /// Shtrix kod bo'yicha bitta mahsulot (lokal katalog, keyin sales/products API).
  Future<Product?> findProductByBarcode(String query) async {
    final q = query.trim();
    if (q.isEmpty) return null;

    if (!_loaded || _items.isEmpty) {
      final cached = await ProductCatalogStorage.loadCatalog();
      if (cached.isNotEmpty) {
        _items = cached;
        _loaded = true;
      }
    }

    final local = _items.where((p) => p.matchesBarcode(q)).toList();
    if (local.length == 1) return local.single;

    try {
      await _ensureUnitsLoaded();
      final res = await SalesApi.getSalesProducts(body: {
        'searchValue': q,
        'rowLimit': 50,
        'offset': 0,
        'orderType': 'sales',
      });
      final fromApi = _productFromSalesBarcodeResponse(res, q);
      if (fromApi != null) {
        _upsertCachedProduct(fromApi);
        return fromApi;
      }
    } catch (_) {}

    return null;
  }

  void _upsertCachedProduct(Product product) {
    final i = _items.indexWhere((p) => p.id == product.id);
    if (i >= 0) {
      _items[i] = product;
    } else {
      _items.add(product);
    }
    _controller.add(items);
    notifyListeners();
  }

  /// Sinxronlash tugmasi: navbatdagi create/edit serverga.
  Future<void> flushPendingSyncToServer() => _drainSyncQueue();

  Product? _productFromSalesBarcodeResponse(Map<String, dynamic> res, String query) {
    final productsRaw = res['products'] as List<dynamic>? ?? [];
    final variantsRaw = res['variants'] as List<dynamic>? ?? [];
    final matches = <Product>[];

    Product? tryBuild(Map<String, dynamic> prodMap, Map<String, dynamic>? variantMap) {
      final merged = Map<String, dynamic>.from(prodMap);
      if (variantMap != null) {
        merged['variants'] = [variantMap];
      }
      try {
        final p = Product.fromApiJson(
          merged,
          unitIdToName: _unitIdToName,
          unitIdToShortName: _unitIdToShortName,
        );
        if (p.id.isNotEmpty && p.matchesBarcode(query)) return p;
      } catch (_) {}
      return null;
    }

    final prodById = <String, Map<String, dynamic>>{};
    for (final e in productsRaw) {
      if (e is! Map) continue;
      final m = Map<String, dynamic>.from(e);
      final id = m['productID'] ?? m['id'];
      if (id != null) prodById[id.toString()] = m;
    }

    for (final v in variantsRaw) {
      if (v is! Map) continue;
      final vMap = Map<String, dynamic>.from(v);
      final pid = vMap['product_id'] ?? vMap['productID'];
      Map<String, dynamic>? prodMap;
      if (pid != null) prodMap = prodById[pid.toString()];
      prodMap ??= productsRaw.length == 1 && productsRaw.first is Map
          ? Map<String, dynamic>.from(productsRaw.first as Map)
          : null;
      if (prodMap == null) continue;
      final p = tryBuild(prodMap, vMap);
      if (p != null) matches.add(p);
    }

    for (final e in productsRaw) {
      if (e is! Map) continue;
      final p = tryBuild(Map<String, dynamic>.from(e), null);
      if (p != null) matches.add(p);
    }

    if (matches.isEmpty) return null;
    if (matches.length == 1) return matches.first;
    final ids = matches.map((p) => p.id).toSet();
    return ids.length == 1 ? matches.first : null;
  }

  /// Supporting-data dan birlik ro'yxatini yuklaydi: to'liq nom va qisqartma (short_name)
  Future<void> _ensureUnitsLoaded() async {
    if (_unitIdToName != null && _unitIdToName!.isNotEmpty) return;
    try {
      final res = await ProductsApi.getSupportingData();
      _supportingDataRaw = res;
      final raw = res['units'] as List<dynamic>? ?? res['data']?['units'] as List<dynamic>? ?? [];
      final nameMap = <int, String>{};
      final shortMap = <int, String>{};
      for (final e in raw) {
        if (e is! Map) continue;
        final m = Map<String, dynamic>.from(e as Map);
        final id = m['id'];
        if (id == null) continue;
        final idInt = id is int ? id : int.tryParse(id.toString());
        if (idInt == null) continue;
        final name = m['name'] ?? m['shortname'] ?? m['title'] ?? m['short_name'] ?? m['unit_name'] ?? id.toString();
        nameMap[idInt] = name.toString().trim();
        final shortName = m['short_name'] ?? m['shortname'] ?? m['abbreviation'] ?? m['name'] ?? m['unit_name'] ?? name;
        shortMap[idInt] = shortName.toString().trim();
      }
      _unitIdToName = nameMap.isEmpty ? null : nameMap;
      _unitIdToShortName = shortMap.isEmpty ? null : shortMap;
    } catch (_) {
      _unitIdToName = null;
      _unitIdToShortName = null;
    }
  }

  /// Keshlangan birliklar bo'yicha id; bo'lmasa API dan (kamdan-kam)
  Future<int> _resolveUnitIdForProduct(String unitName) async {
    await _ensureUnitsLoaded();
    final u = unitName.trim().toLowerCase();
    if (_unitIdToName != null && _unitIdToName!.isNotEmpty) {
      for (final entry in _unitIdToName!.entries) {
        final name = entry.value.toLowerCase();
        final short = (_unitIdToShortName?[entry.key] ?? '').toLowerCase();
        if (name == u || name.contains(u) || u.contains(name)) {
          return entry.key;
        }
        if (short.isNotEmpty && (short == u || u.contains(short) || short.contains(u))) {
          return entry.key;
        }
      }
      return _unitIdToName!.keys.first;
    }
    return _resolveUnitIdFromApi(unitName);
  }

  static Future<int> _resolveUnitIdFromApi(String unitName) async {
    try {
      final res = await ProductsApi.getSupportingData();
      final units = res['units'] as List<dynamic>? ?? res['data']?['units'] as List<dynamic>? ?? [];
      final un = unitName.trim().toLowerCase();
      for (final e in units) {
        if (e is! Map) continue;
        final m = Map<String, dynamic>.from(e as Map);
        final name = (m['name'] ?? m['shortname'] ?? m['title'] ?? '').toString().toLowerCase();
        final shortName = (m['short_name'] ?? m['unit_name'] ?? '').toString().toLowerCase();
        if (name == un || name.contains(un) || un.contains(name) || (shortName.isNotEmpty && (shortName == un || un.contains(shortName)))) {
          final id = m['id'];
          if (id != null) return id is int ? id : int.tryParse(id.toString()) ?? 1;
        }
      }
      if (units.isNotEmpty && units.first is Map) {
        final firstId = (units.first as Map)['id'];
        if (firstId != null) return firstId is int ? firstId : int.tryParse(firstId.toString()) ?? 1;
      }
    } catch (_) {}
    return 1;
  }

  static int? _parseBranchIdFromSupportingMap(Map<String, dynamic> res) {
    List<dynamic>? branches = res['branches'] as List<dynamic>?;
    branches ??= (res['data'] is Map) ? (res['data'] as Map<String, dynamic>)['branches'] as List<dynamic>? : null;
    if (branches == null) return null;
    for (final e in branches) {
      if (e is! Map) continue;
      final m = Map<String, dynamic>.from(e as Map);
      final id = m['id'] ?? m['value'] ?? m['branch_id'] ?? m['branchID'];
      if (id != null) {
        final n = id is int ? id : int.tryParse(id.toString());
        if (n != null) return n;
      }
    }
    return null;
  }

  static int? _parseBranchIdFromSalesResponse(Map<String, dynamic> res) {
    List<dynamic>? list = res['data'] as List<dynamic>?;
    list ??= res['branches'] as List<dynamic>?;
    if (res['data'] is Map<String, dynamic>) {
      final dm = res['data'] as Map<String, dynamic>;
      list ??= dm['branches'] as List<dynamic>? ?? dm['data'] as List<dynamic>?;
    }
    if (list == null || list.isEmpty || list.first is! Map) return null;
    final m = Map<String, dynamic>.from(list.first as Map);
    final id = m['value'] ?? m['id'] ?? m['branchID'] ?? m['branch_id'];
    if (id == null) return null;
    return id is int ? id : int.tryParse(id.toString());
  }

  /// MOBILE_API_DOCS.md: `branch_id` — bir marta aniqlab keshlanadi.
  Future<int?> _getDefaultBranchId() async {
    if (_defaultBranchResolved) return _cachedDefaultBranchId;
    try {
      await _ensureUnitsLoaded();
      final res = _supportingDataRaw;
      if (res != null) {
        final b = _parseBranchIdFromSupportingMap(res);
        if (b != null) {
          _cachedDefaultBranchId = b;
          _defaultBranchResolved = true;
          return b;
        }
      }
    } catch (_) {}
    try {
      final res = await SalesApi.getBranches();
      final b = _parseBranchIdFromSalesResponse(res);
      _cachedDefaultBranchId = b;
      _defaultBranchResolved = true;
      return b;
    } catch (_) {
      _defaultBranchResolved = true;
      return null;
    }
  }

  /// POST create / edit javobidan bitta qatorni ro'yxatga qo'shish — to'liq 5000 qatorni qayta yuklamaslik.
  Product? _mergeProductFromApiResponse(Map<String, dynamic> response, {Product? quantityHint}) {
    final raw = response['data'] ?? response['product'];
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw as Map);
    if (quantityHint != null && quantityHint.initialQuantity > 0) {
      if (map['product_quantity'] == null && map['quantity'] == null) {
        map['product_quantity'] = quantityHint.initialQuantity;
        map['quantity'] = quantityHint.initialQuantity;
      }
    }
    try {
      var p = Product.fromApiJson(
        map,
        unitIdToName: _unitIdToName,
        unitIdToShortName: _unitIdToShortName,
      );
      if (quantityHint != null) {
        p = p.mergeWithLocalFallback(quantityHint);
      }
      if (p.id.isEmpty) return null;
      _items.removeWhere((e) => e.id == p.id);
      _items.insert(0, p);
      _controller.add(items);
      notifyListeners();
      unawaited(_persistCatalog());
      return p;
    } catch (_) {
      return null;
    }
  }

  /// Tahrirlashda variant ID (rasm ko'pincha variantga bog'langan).
  Future<int?> _resolveVariantIdForEdit(int productId, int? hint) async {
    if (hint != null && hint > 0) return hint;
    try {
      final res = await ProductsApi.getProduct(productId);
      final raw = res['data'] ?? res['product'] ?? res;
      if (raw is Map<String, dynamic>) {
        final p = Product.fromApiJson(
          Map<String, dynamic>.from(raw),
          unitIdToName: _unitIdToName,
          unitIdToShortName: _unitIdToShortName,
        );
        if (p.variantId != null && p.variantId! > 0) return p.variantId;
      }
    } catch (_) {}
    try {
      final res = await ProductsApi.getProductEditData(productId);
      final raw = res['data'] ?? res['product'] ?? res;
      if (raw is! Map) return hint;
      final m = Map<String, dynamic>.from(raw);
      final variants = m['variants'] as List<dynamic>?;
      if (variants != null && variants.isNotEmpty && variants.first is Map) {
        final id = variants.first['id'];
        final n = id is int ? id : int.tryParse(id?.toString() ?? '');
        if (n != null && n > 0) return n;
      }
      final vid = m['variantID'] ?? m['variant_id'];
      final n = vid is int ? vid : int.tryParse(vid?.toString() ?? '');
      if (n != null && n > 0) return n;
    } catch (_) {}
    return hint;
  }

  /// HTTP URL emas, diskdagi fayl bo‘lsa multipart `image` uchun yo‘l.
  static String? _localImagePathForUpload(String? imageUrl) {
    if (imageUrl == null || imageUrl.trim().isEmpty) return null;
    var t = imageUrl.trim();
    if (t.startsWith('file://')) t = t.substring(7);
    final lower = t.toLowerCase();
    if (lower.startsWith('http://') || lower.startsWith('https://')) return null;
    return t;
  }

  /// API javobidan ro'yxatni chiqarish (data/datarows/products — to'g'ridan-to'g'ri yoki data ichida)
  static List<dynamic> _extractList(Map<String, dynamic> res) {
    final raw = res['datarows'] ?? res['products'] ?? res['data'];
    if (raw is List<dynamic>) return raw;
    if (raw is Map<String, dynamic>) {
      final inner = raw['datarows'] ?? raw['products'] ?? raw['data'] ?? raw['items'];
      if (inner is List<dynamic>) return inner;
    }
    return [];
  }

  Future<void> loadFromApi() async {
    _loadError = null;
    try {
      await _ensureUnitsLoaded();
      final res = await ProductsApi.getProductsList(body: {
        'rowLimit': 5000,
        'rowOffset': 0,
      });
      _lastRawProducts = res;
      final rows = _extractList(res);
      final previousById = {for (final p in _items) p.id: p};
      _items = rows
          .map((e) {
            try {
              var p = Product.fromApiJson(
                Map<String, dynamic>.from(e as Map),
                unitIdToName: _unitIdToName,
                unitIdToShortName: _unitIdToShortName,
              );
              final prev = previousById[p.id];
              if (prev != null) {
                p = p.mergeWithLocalFallback(prev, preferServerStock: true);
              }
              return p;
            } catch (_) {
              return null;
            }
          })
          .whereType<Product>()
          .where((p) => p.id.isNotEmpty)
          .toList();
      _loaded = true;
      _controller.add(items);
      notifyListeners();
      unawaited(_persistCatalog());
    } on ApiException catch (e) {
      _loadError = e.message;
      _loaded = true;
      if (_items.isEmpty) {
        _controller.add(items);
        notifyListeners();
      }
    } catch (e, st) {
      _loadError = 'Mahsulotlar yuklanmadi';
      _loaded = true;
      if (_items.isEmpty) {
        _controller.add(items);
        notifyListeners();
      }
      assert(() {
        // ignore: avoid_print
        print('ProductsProvider.loadFromApi error: $e\n$st');
        return true;
      }());
    }
  }

  Future<void> addProduct(Product product) async {
    await saveProductLocalFirst(product, isCreate: true);
  }

  Future<void> _syncCreateToServer(Product product) async {
    final oldId = product.id;
    try {
      // category_id — API da son (id)
      int? categoryId;
      if (product.category != null && product.category!.trim().isNotEmpty) {
        categoryId = int.tryParse(product.category!.trim());
        if (categoryId == null) {
          categoryId = CategoriesProvider.instance.getCategoryIdByName(product.category);
        }
      }
      // unit — keshlangan supporting-data dan (qayta-qayta GET qilmaslik)
      final unitId = await _resolveUnitIdForProduct(product.unit ?? 'dona');
      final productName = product.name.trim();
      if (productName.isEmpty) throw ApiException('Mahsulot nomi kiritilishi shart', 400);
      final branchId = await _getDefaultBranchId();
      final body = ProductWebStoreBody.build(
        product,
        unitId: unitId,
        categoryId: categoryId,
        branchId: branchId,
        isCreate: true,
      );
      final uploadPath = _localImagePathForUpload(product.imageUrl);
      final useMultipart =
          uploadPath != null && await File(uploadPath).exists();

      assert(() {
        // ignore: avoid_print
        print('=== POST /api/v1/products/store (yangi mahsulot) ===');
        // ignore: avoid_print
        print('Body: $body multipart: $useMultipart');
        return true;
      }());
      Map<String, dynamic> res;
      try {
        res = await ProductsApi.storeProduct(
          body,
          localImagePath: useMultipart ? uploadPath : null,
        );
        assert(() {
          // ignore: avoid_print
          print('=== Yangi mahsulot javobi ===');
          // ignore: avoid_print
          print('Response: $res');
          return true;
        }());
      } on ApiException catch (e) {
        final msg = e.message.toLowerCase();
        if (msg.contains('name') || msg.contains('type') || msg.contains('unit') || msg.contains('required')) {
          res = await ProductsApi.storeProduct(
            body,
            localImagePath: useMultipart ? uploadPath : null,
          );
        } else {
          rethrow;
        }
      }
      var merged = _mergeProductFromApiResponse(res, quantityHint: product);
      _items.removeWhere((e) => e.id == oldId);
      if (merged == null) {
        _upsertCachedProduct(product);
        await _persistCatalog();
      } else {
        Product result = merged;
        final idNum = int.tryParse(result.id);
        if (idNum != null) {
          try {
            final fresh = await ProductsApi.getProduct(idNum);
            final hydrated = _mergeProductFromApiResponse(fresh, quantityHint: product);
            if (hydrated != null) result = hydrated;
          } catch (_) {}
        }
        if (result.id != oldId) {
          await _repointSyncJobs(oldId, result.id);
        }
      }
    } catch (_) {
      rethrow;
    }
  }

  Future<void> _repointSyncJobs(String oldId, String newId) async {
    final queue = await ProductCatalogStorage.loadSyncQueue();
    var changed = false;
    for (var i = 0; i < queue.length; i++) {
      final j = queue[i];
      if (j.productId == oldId) {
        queue[i] = ProductSyncJob(
          jobId: j.jobId,
          productId: newId,
          isCreate: j.isCreate,
          deleteImage: j.deleteImage,
        );
        changed = true;
      }
    }
    if (changed) await ProductCatalogStorage.saveSyncQueue(queue);
  }

  Future<void> updateProduct(Product product, {bool deleteImage = false}) async {
    await saveProductLocalFirst(product, isCreate: false, deleteImage: deleteImage);
  }

  Future<void> _syncUpdateToServer(Product product, {bool deleteImage = false}) async {
    try {
      final idNum = int.tryParse(product.id);
      if (idNum == null) return;
      // API edit: unit — id (supporting-data dan), category — id, sallingPrice, reorder, pachka maydonlari
      final unitId = await _resolveUnitIdForProduct(product.unit ?? 'dona');
      int? categoryId;
      if (product.category != null && product.category!.trim().isNotEmpty) {
        categoryId = int.tryParse(product.category!.trim());
        if (categoryId == null) categoryId = CategoriesProvider.instance.getCategoryIdByName(product.category);
      }
      final variantId = await _resolveVariantIdForEdit(idNum, product.variantId);
      final branchId = await _getDefaultBranchId();
      final body = ProductWebStoreBody.build(
        product,
        unitId: unitId,
        categoryId: categoryId,
        branchId: branchId,
        variantId: variantId,
        deleteImage: deleteImage,
        isCreate: false,
      );
      // Debug: yuborilayotgan ma'lumot va javob
      final uploadPath = _localImagePathForUpload(product.imageUrl);
      final useMultipart =
          uploadPath != null && await File(uploadPath).exists();

      assert(() {
        // ignore: avoid_print
        print('=== POST /api/v1/products/$idNum/edit (tahrirlash) ===');
        // ignore: avoid_print
        print('Body: $body multipart: $useMultipart');
        return true;
      }());
      var response = await ProductsApi.updateProduct(
        idNum,
        body,
        localImagePath: useMultipart ? uploadPath : null,
      );
      assert(() {
        // ignore: avoid_print
        print('=== Tahrirlash javobi ===');
        // ignore: avoid_print
        print('Response: $response');
        return true;
      }());
      var merged = _mergeProductFromApiResponse(response, quantityHint: product);
      if (merged == null || useMultipart || deleteImage) {
        try {
          final fresh = await ProductsApi.getProduct(idNum);
          final hydrated = _mergeProductFromApiResponse(fresh, quantityHint: product);
          if (hydrated != null) merged = hydrated;
        } catch (_) {}
      }
      if (merged == null) {
        _upsertCachedProduct(product);
        await _persistCatalog();
      }
    } catch (_) {
      rethrow;
    }
  }

  Product? getProductById(String id) {
    try {
      return _items.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Sotuv/kirim API mahsulotiga katalogdagi ombor miqdorini qo‘llaydi (GET /products aniqroq).
  Product withCatalogStock(Product fromSalesOrReceiveApi) {
    final catalog = getProductById(fromSalesOrReceiveApi.id);
    if (catalog == null) return fromSalesOrReceiveApi;
    return catalog.mergeWithLocalFallback(fromSalesOrReceiveApi, preferServerStock: true);
  }

  List<Product> withCatalogStockAll(Iterable<Product> products) =>
      products.map(withCatalogStock).toList();

  /// Katalogdan ochishdan oldin ulgurji narxni fon rejimida to'ldirish (ixtiyoriy).
  void prefetchProductForDetail(Product product) {
    if (product.hasWholesalePrice) return;
    unawaited(resolveProductForDetail(product));
  }

  /// «Mahsulot haqida»: katalog + server — fon rejimida to'ldirish.
  Future<Product> resolveProductForDetail(Product hint) async {
    final fromCache = getProductById(hint.id);
    var base = fromCache != null ? fromCache.mergeWithLocalFallback(hint) : hint;
    if (base.hasWholesalePrice) return base;

    final idNum = int.tryParse(hint.id);
    if (idNum == null) return base;

    await _ensureUnitsLoaded();
    Product? fromServer;
    try {
      final res = await ProductsApi.getProduct(idNum);
      final raw = res['data'] ?? res['product'] ?? res;
      if (raw is Map) {
        fromServer = Product.fromApiJson(
          Map<String, dynamic>.from(raw),
          unitIdToName: _unitIdToName,
          unitIdToShortName: _unitIdToShortName,
        );
      }
    } catch (_) {}

    if (fromServer == null || !fromServer.hasWholesalePrice) {
      try {
        final res = await ProductsApi.getProductEditData(idNum);
        final raw = res['data'] ?? res;
        if (raw is Map) {
          fromServer = Product.fromApiJson(
            Map<String, dynamic>.from(raw),
            unitIdToName: _unitIdToName,
            unitIdToShortName: _unitIdToShortName,
          );
        }
      } catch (_) {}
    }

    if (fromServer == null) return base;
    final merged = fromServer.mergeWithLocalFallback(base);
    _upsertCachedProduct(merged);
    return merged;
  }

  Future<void> removeProduct(Product product) async {
    final idNum = int.tryParse(product.id);
    if (idNum == null) return;
    await ProductsApi.deleteProduct(idNum);
    _items.removeWhere((e) => e.id == product.id);
    _controller.add(items);
    notifyListeners();
  }

  void dispose() {
    _controller.close();
  }
}
