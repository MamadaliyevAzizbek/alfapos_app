import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../core/api_client.dart';
import '../core/api_pacing.dart';
import '../core/api_sync_throttle.dart';
import '../models/product.dart';
import '../services/api_service.dart';
import '../services/product_catalog_storage.dart';
import '../services/product_catalog_sales_bridge.dart';
import '../utils/barcode_validation.dart';
import '../utils/product_image_upload.dart';
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
  /// Parallel loadFromApi bo‘lmasin (429 oldini olish).
  Future<void>? _loadFromApiInFlight;
  /// Bir vaqtda faqat bitta yangi mahsulot POST (UI race / qayta bosishdan himoya).
  bool _serverCreateInFlight = false;

  List<Product> get items => List.unmodifiable(_items);
  Stream<List<Product>> get stream => _controller.stream;
  bool get isLoaded => _loaded;
  String? get loadError => _loadError;
  Map<String, dynamic>? get lastRawProducts => _lastRawProducts;

  void resetForAccountChange() {
    _items = [];
    _loaded = false;
    _loadError = null;
    _lastRawProducts = null;
    _unitIdToName = null;
    _unitIdToShortName = null;
    _supportingDataRaw = null;
    _defaultBranchResolved = false;
    _cachedDefaultBranchId = null;
    _controller.add(items);
    notifyListeners();
    unawaited(ProductCatalogStorage.clearAll());
  }

  Future<void> clearSyncFingerprint() => ProductCatalogStorage.clearSyncMeta();

  /// Diskdan tez — tarmoq yo‘q.
  Future<void> warmFromCache() async {
    final cached = await ProductCatalogStorage.loadCatalog();
    if (cached.isNotEmpty) {
      _items = cached;
      _loaded = true;
      _controller.add(items);
      notifyListeners();
    }
  }

  /// Avval diskdan (tez), keyin ixtiyoriy API dan yangilash (fon).
  Future<void> loadFromStorage({bool refreshInBackground = true}) async {
    await warmFromCache();
    if (refreshInBackground) {
      unawaited(_refreshCatalogFromApi());
    }
  }

  /// Barcha mahsulotlar yuklanganiga ishonch hosil qilish (sahifalab).
  Future<void> ensureFullCatalogLoaded({bool force = false}) async {
    if (force) {
      ApiSyncThrottle.invalidate('products_full_catalog');
      await loadFromApi(force: true);
      return;
    }
    if (_items.isEmpty || !_loaded) {
      await loadFromApi();
      return;
    }
    await _refreshCatalogFromApi();
  }

  /// Serverdan katalog (force=true — fingerprint va throttle o‘tkaziladi).
  Future<void> refreshFromServer({bool force = false}) async {
    if (force) {
      ApiSyncThrottle.invalidate('products_full_catalog');
      await ProductCatalogStorage.clearSyncMeta();
      await loadFromApi(force: true);
      return;
    }
    await _refreshCatalogFromApi();
  }

  Future<void> _refreshCatalogFromApi() async {
    await ApiSyncThrottle.runIfDue(
      'products_full_catalog',
      const Duration(minutes: 15),
      () async {
        try {
          // force=false: avval fingerprint — o‘zgarmasa to‘liq paging yo‘q.
          await loadFromApi(force: false);
        } catch (_) {}
      },
    );
  }

  Future<void> _persistCatalog({bool invalidateSyncMeta = true}) async {
    await ProductCatalogStorage.saveCatalog(_items);
    // Lokal CRUD dan keyin fingerprint eskirgan — keyingi sync tekshiradi.
    if (invalidateSyncMeta) {
      await ProductCatalogStorage.clearSyncMeta();
    }
  }

  static bool _isLocalOnlyProductId(String id) =>
      id.startsWith('local_') || int.tryParse(id) == null;

  /// UI: avval serverga saqlash; muvaffaqiyatdan keyin lokal katalog yangilanadi.
  Future<Product> saveProductToServer(
    Product product, {
    required bool isCreate,
    bool deleteImage = false,
  }) async {
    final creating = isCreate || _isLocalOnlyProductId(product.id);
    if (creating) {
      if (_serverCreateInFlight) {
        throw ApiException(
          'Mahsulot allaqachon saqlanmoqda. Biroz kuting.',
          429,
        );
      }
      _serverCreateInFlight = true;
    }
    try {
      if (!_loaded || _items.isEmpty) {
        final cached = await ProductCatalogStorage.loadCatalog();
        if (cached.isNotEmpty) {
          _items = cached;
          _loaded = true;
        }
      }
      _assertBarcodesUnique(product);
      var toSave = product;
      final persistedImage = await ProductImageUpload.prepareUploadPath(product.imageUrl);
      if (persistedImage != null) {
        toSave = _withImageUrl(product, persistedImage);
      }

      final Product result;
      if (creating) {
        result = await _syncCreateToServer(toSave);
      } else {
        final idNum = int.tryParse(toSave.id);
        if (idNum == null || _isLocalOnlyProductId(toSave.id)) {
          throw ApiException(
            'Mahsulot serverda ro\'yxatdan o\'tmagan. Avval qayta saqlang yoki sinxronlang.',
            400,
          );
        }
        await _syncUpdateToServer(toSave, deleteImage: deleteImage);
        result = getProductById(toSave.id) ?? toSave;
      }

      await _persistCatalog();
      unawaited(ProductCatalogSalesBridge.afterProductSaved(result));
      return result;
    } finally {
      if (creating) _serverCreateInFlight = false;
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
    if (_defaultBranchResolved && _cachedDefaultBranchId != null) {
      return _cachedDefaultBranchId;
    }
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
      if (b != null) {
        _cachedDefaultBranchId = b;
        _defaultBranchResolved = true;
        return b;
      }
    } catch (_) {}
    return _cachedDefaultBranchId;
  }

  static int? _productIdFromStoreResponse(Map<String, dynamic> res) {
    final data = res['data'] ?? res['product'];
    if (data is Map) {
      final id = data['id'] ?? data['productID'] ?? data['product_id'];
      if (id is int && id > 0) return id;
      final n = int.tryParse(id?.toString() ?? '');
      if (n != null && n > 0) return n;
    }
    final top = res['id'] ?? res['productID'] ?? res['product_id'];
    if (top is int && top > 0) return top;
    return int.tryParse(top?.toString() ?? '');
  }

  static String? _apiMessageFromResponse(Map<String, dynamic> res) {
    final m = res['message'] ?? res['error'];
    if (m != null && m.toString().trim().isNotEmpty) return m.toString().trim();
    return null;
  }

  static bool _apiResponseIndicatesSuccess(Map<String, dynamic> res) {
    final success = res['success'];
    if (success == true || success == 1 || success == 'true') return true;
    final msg = _apiMessageFromResponse(res);
    if (msg != null && ApiClient.isSuccessLikeMessage(msg)) return true;
    return _productIdFromStoreResponse(res) != null;
  }

  Future<Product?> _findProductOnServerByBarcode(String? barcode, {String? name}) async {
    final code = barcode?.trim();
    final title = name?.trim().toLowerCase();
    if ((code == null || code.isEmpty) && (title == null || title.isEmpty)) {
      return null;
    }
    try {
      await _ensureUnitsLoaded();
      final res = await ProductsApi.getProductsList(body: {
        'rowLimit': 100,
        'rowOffset': 0,
        if (code != null && code.isNotEmpty) 'searchValue': code,
      });
      for (final row in _extractList(res)) {
        if (row is! Map) continue;
        try {
          var p = Product.fromApiJson(
            Map<String, dynamic>.from(row),
            unitIdToName: _unitIdToName,
            unitIdToShortName: _unitIdToShortName,
          );
          if (code != null && code.isNotEmpty && p.barcode?.trim() == code) return p;
          if (title != null && title.isNotEmpty && p.name.trim().toLowerCase() == title) {
            return p;
          }
        } catch (_) {}
      }
    } catch (_) {}
    return null;
  }

  Future<Product?> _hydrateProductAfterSave(
    Map<String, dynamic> res, {
    required Product draft,
  }) async {
    var merged = _mergeProductFromApiResponse(res, quantityHint: draft);
    final serverId = _productIdFromStoreResponse(res);
    if (merged == null && serverId != null) {
      try {
        final fresh = await ProductsApi.getProduct(serverId);
        merged = _mergeProductFromApiResponse(fresh, quantityHint: draft);
      } catch (_) {}
    }
    if (merged == null) {
      merged = await _findProductOnServerByBarcode(draft.barcode, name: draft.name);
    }
    if (merged != null) {
      final fromRes = _imagePathFromApiResponse(res);
      if (fromRes != null) {
        merged = _withImageUrl(merged, fromRes);
      } else if (draft.imageUrl != null && ProductImageUpload.resolveLocalPath(draft.imageUrl) != null) {
        merged = _withImageUrl(merged, draft.imageUrl!);
      }
    }
    return merged;
  }

  Product _productWithServerId(Product draft, int serverId) {
    return Product(
      id: serverId.toString(),
      name: draft.name,
      imageUrl: draft.imageUrl,
      sku: draft.sku,
      variantId: draft.variantId,
      barcode: draft.barcode,
      additionalBarcodes: draft.additionalBarcodes,
      priceUzs: draft.priceUzs,
      costPriceUzs: draft.costPriceUzs,
      sellingPriceCurrency: draft.sellingPriceCurrency,
      purchasePriceCurrency: draft.purchasePriceCurrency,
      sellingPriceApi: draft.sellingPriceApi,
      purchasePriceApi: draft.purchasePriceApi,
      quantityInfo: draft.quantityInfo,
      unit: draft.unit,
      category: draft.category,
      description: draft.description,
      quantityInPack: draft.quantityInPack,
      quantityPerPack: draft.quantityPerPack,
      costPricePerPack: draft.costPricePerPack,
      sellPricePerPack: draft.sellPricePerPack,
      wholesalePriceUzs: draft.wholesalePriceUzs,
      wholesalePriceCurrency: draft.wholesalePriceCurrency,
      wholesalePriceApi: draft.wholesalePriceApi,
      reorderLevel: draft.reorderLevel,
      initialQuantity: draft.initialQuantity,
    );
  }

  /// POST create / edit javobidan bitta qatorni ro'yxatga qo'shish — to'liq 5000 qatorni qayta yuklamaslik.
  Product? _mergeProductFromApiResponse(Map<String, dynamic> response, {Product? quantityHint}) {
    var raw = response['data'] ?? response['product'];
    if (raw is! Map) {
      final success = response['success'];
      if (success is Map) raw = success;
    }
    if (raw is! Map) {
      final id = _productIdFromStoreResponse(response);
      if (id == null) return null;
      raw = <String, dynamic>{'id': id, 'productID': id};
    }
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

  static Product _withImageUrl(Product p, String imageUrl) {
    return Product(
      id: p.id,
      name: p.name,
      imageUrl: imageUrl,
      sku: p.sku,
      variantId: p.variantId,
      barcode: p.barcode,
      additionalBarcodes: p.additionalBarcodes,
      priceUzs: p.priceUzs,
      costPriceUzs: p.costPriceUzs,
      sellingPriceCurrency: p.sellingPriceCurrency,
      purchasePriceCurrency: p.purchasePriceCurrency,
      sellingPriceApi: p.sellingPriceApi,
      purchasePriceApi: p.purchasePriceApi,
      quantityInfo: p.quantityInfo,
      unit: p.unit,
      category: p.category,
      categoryId: p.categoryId,
      brandId: p.brandId,
      brand: p.brand,
      description: p.description,
      quantityInPack: p.quantityInPack,
      quantityPerPack: p.quantityPerPack,
      costPricePerPack: p.costPricePerPack,
      sellPricePerPack: p.sellPricePerPack,
      wholesalePriceUzs: p.wholesalePriceUzs,
      wholesalePriceCurrency: p.wholesalePriceCurrency,
      wholesalePriceApi: p.wholesalePriceApi,
      reorderLevel: p.reorderLevel,
      initialQuantity: p.initialQuantity,
    );
  }

  static String? _imagePathFromApiResponse(Map<String, dynamic> res) {
    final data = res['data'] ?? res['product'];
    if (data is Map) {
      final img = Product.imageUrlFromApiMap(Map<String, dynamic>.from(data));
      if (img != null && img.trim().isNotEmpty) return img.trim();
    }
    final top = Product.imageUrlFromApiMap(res);
    if (top != null && top.trim().isNotEmpty) return top.trim();
    return null;
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

  Future<void> loadFromApi({bool force = false}) async {
    final existing = _loadFromApiInFlight;
    if (existing != null) return existing;
    final future = _loadFromApiBody(force: force);
    _loadFromApiInFlight = future;
    try {
      await future;
    } finally {
      if (identical(_loadFromApiInFlight, future)) {
        _loadFromApiInFlight = null;
      }
    }
  }

  Future<void> _loadFromApiBody({bool force = false}) async {
    _loadError = null;
    try {
      await _ensureUnitsLoaded();
      final previousById = {for (final p in _items) p.id: p};
      const pageSize = 500;
      var offset = 0;
      var guard = 0;
      final allRows = <dynamic>[];

      // 1-sahifa: o‘zgarish bo‘lmasa qolgan sahifalarni umuman so‘ramaymiz.
      final firstRes = await ProductsApi.getProductsList(body: {
        'rowLimit': pageSize,
        'rowOffset': 0,
      });
      _lastRawProducts = firstRes;
      final firstRows = _extractList(firstRes);
      final remoteMeta = ProductCatalogSyncMeta.fromApiPage(firstRes, firstRows);
      final localMeta = await ProductCatalogStorage.loadSyncMeta();

      if (!force &&
          _items.isNotEmpty &&
          localMeta != null &&
          localMeta.matches(remoteMeta)) {
        // force=false: serverda count/qty/namuna o‘zgarmagan — to‘liq paging yo‘q.
        _loaded = true;
        await ProductCatalogStorage.saveSyncMeta(
          ProductCatalogSyncMeta(
            count: localMeta.count,
            totalQuantity: localMeta.totalQuantity,
            sampleFingerprint: localMeta.sampleFingerprint,
            savedAt: DateTime.now(),
          ),
        );
        return;
      }

      allRows.addAll(firstRows);
      offset = firstRows.length;
      if (firstRows.length >= pageSize) {
        while (guard < 500) {
          guard++;
          await ApiPacing.staggerPause(ApiPacing.productPageStep);
          final res = await ProductsApi.getProductsList(body: {
            'rowLimit': pageSize,
            'rowOffset': offset,
          });
          final rows = _extractList(res);
          if (rows.isEmpty) break;
          allRows.addAll(rows);
          offset += rows.length;
          if (rows.length < pageSize) break;
        }
      }

      _items = allRows
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
      await ProductCatalogStorage.saveCatalog(_items);
      await ProductCatalogStorage.saveSyncMeta(remoteMeta);
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
    await saveProductToServer(product, isCreate: true);
  }

  Future<Product> _syncCreateToServer(Product product) async {
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
      if (branchId == null && product.initialQuantity > 0) {
        throw ApiException(
          'Boshlang\'ich miqdor uchun filial kerak. Kassa smenasini oching yoki filialni tanlang.',
          400,
        );
      }
      final body = ProductWebStoreBody.build(
        product,
        unitId: unitId,
        categoryId: categoryId,
        branchId: branchId,
        isCreate: true,
      );
      final uploadPath = await ProductImageUpload.prepareUploadPath(product.imageUrl);
      final useMultipart = uploadPath != null;

      assert(() {
        // ignore: avoid_print
        print('=== POST /api/v1/products/store (yangi mahsulot) ===');
        // ignore: avoid_print
        print('Body: $body rasm: $uploadPath multipart: $useMultipart');
        return true;
      }());
      Map<String, dynamic> res;
      try {
        res = await ProductsApi.storeProduct(
          body,
          localImagePath: useMultipart ? uploadPath : null,
          imageHintProduct: product,
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
          // Birinchi urinish serverda yaratilgan bo'lishi mumkin — qayta POST dublikat qiladi.
          final already = await _findProductOnServerByBarcode(product.barcode, name: product.name);
          if (already != null) {
            res = {'data': {'id': int.tryParse(already.id) ?? already.id, 'productID': already.id}};
          } else {
            res = await ProductsApi.storeProduct(
              body,
              localImagePath: useMultipart ? uploadPath : null,
              imageHintProduct: product,
            );
          }
        } else {
          rethrow;
        }
      }
      var merged = await _hydrateProductAfterSave(res, draft: product);
      final serverId = _productIdFromStoreResponse(res);
      _items.removeWhere((e) => e.id == oldId);
      if (merged == null) {
        if (_apiResponseIndicatesSuccess(res) && serverId != null) {
          merged = _productWithServerId(product, serverId);
        } else if (_apiResponseIndicatesSuccess(res)) {
          merged = await _findProductOnServerByBarcode(product.barcode, name: product.name);
        }
      }
      if (merged == null) {
        final msg = _apiMessageFromResponse(res);
        throw ApiException(
          msg ?? 'Server mahsulotni saqlamadi yoki javob noto\'g\'ri formatda.',
          500,
        );
      }
      Product result = merged;
      final idNum = int.tryParse(result.id);
      if (idNum == null || idNum <= 0 || _isLocalOnlyProductId(result.id)) {
        throw ApiException(
          'Mahsulot serverda saqlanmadi (ID topilmadi).',
          500,
        );
      }
      final fromRes = _imagePathFromApiResponse(res);
      if (fromRes != null) {
        result = _withImageUrl(result, fromRes);
      }
      if (result.imageUrl == null || result.imageUrl!.trim().isEmpty || useMultipart) {
        try {
          final fresh = await ProductsApi.getProduct(idNum);
          final hydrated = _mergeProductFromApiResponse(fresh, quantityHint: product);
          if (hydrated != null) result = hydrated;
        } catch (_) {}
      }
      _upsertCachedProduct(result);
      await _persistCatalog();
      return result;
    } catch (_) {
      rethrow;
    }
  }

  Future<void> updateProduct(Product product, {bool deleteImage = false}) async {
    await saveProductToServer(product, isCreate: false, deleteImage: deleteImage);
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
      final uploadPath = await ProductImageUpload.prepareUploadPath(product.imageUrl);
      final useMultipart = uploadPath != null;

      assert(() {
        // ignore: avoid_print
        print('=== POST /api/v1/products/$idNum/edit (tahrirlash) ===');
        // ignore: avoid_print
        print('Body: $body rasm: $uploadPath multipart: $useMultipart');
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
      var merged = await _hydrateProductAfterSave(response, draft: product);
      if (merged == null && _apiResponseIndicatesSuccess(response)) {
        merged = _productWithServerId(product, idNum);
      }
      if (merged == null) {
        _upsertCachedProduct(product);
        await _persistCatalog();
      } else {
        _upsertCachedProduct(merged);
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

  /// Sotuv API sahifasini yagona katalogga qo‘shadi (yo‘q mahsulotlar).
  void mergeSalesOverlay(Iterable<Product> salesProducts) {
    var changed = false;
    for (final sales in salesProducts) {
      if (sales.id.isEmpty) continue;
      if (getProductById(sales.id) != null) continue;
      _items.add(sales);
      changed = true;
    }
    if (!changed) return;
    _loaded = true;
    _controller.add(items);
    notifyListeners();
    unawaited(_persistCatalog(invalidateSyncMeta: false));
  }

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

  /// O'chirilgan mahsulot va shu shtrix kod(lar)ga ega barcha qoldiq/dublikat yozuvlar.
  Set<String> _purgeCatalogEntriesForRemovedProduct(Product removed) {
    final removedIds = <String>{};
    _items.removeWhere((e) {
      if (!BarcodeValidation.catalogEntryConflictsWithRemoved(e, removed)) {
        return false;
      }
      removedIds.add(e.id);
      return true;
    });
    return removedIds;
  }

  Future<void> removeProduct(Product product) async {
    final idNum = int.tryParse(product.id);
    final isServerId = idNum != null && idNum > 0 && !_isLocalOnlyProductId(product.id);
    if (isServerId) {
      try {
        await ProductsApi.deleteProduct(idNum);
      } on ApiException catch (e) {
        if (e.statusCode != 404) rethrow;
      }
    } else if (!_isLocalOnlyProductId(product.id)) {
      return;
    }

    _purgeCatalogEntriesForRemovedProduct(product);
    await _persistCatalog();
    ApiSyncThrottle.invalidate('products_full_catalog');
    unawaited(ProductCatalogSalesBridge.afterProductRemoved(product));
    _controller.add(items);
    notifyListeners();
  }

  void dispose() {
    _controller.close();
  }
}
