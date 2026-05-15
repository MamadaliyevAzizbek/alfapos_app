import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../core/api_client.dart';
import '../models/product.dart';
import '../services/api_service.dart';
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
  /// Ikki marta tez "Saqlash" bosilganda takroriy POST oldini olish
  bool _productMutationInFlight = false;

  List<Product> get items => List.unmodifiable(_items);
  Stream<List<Product>> get stream => _controller.stream;
  bool get isLoaded => _loaded;
  String? get loadError => _loadError;
  Map<String, dynamic>? get lastRawProducts => _lastRawProducts;

  /// Lokal saqlash yo'q — faqat API dan yuklash (eski chaqiriqlar uchun nom).
  Future<void> loadFromStorage() async => loadFromApi();

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
  bool _tryMergeProductFromApiResponse(Map<String, dynamic> response, {Product? quantityHint}) {
    final raw = response['data'] ?? response['product'];
    if (raw is! Map) return false;
    final map = Map<String, dynamic>.from(raw as Map);
    if (quantityHint != null && quantityHint.initialQuantity > 0) {
      if (map['product_quantity'] == null && map['quantity'] == null) {
        map['product_quantity'] = quantityHint.initialQuantity;
        map['quantity'] = quantityHint.initialQuantity;
      }
    }
    try {
      final p = Product.fromApiJson(
        map,
        unitIdToName: _unitIdToName,
        unitIdToShortName: _unitIdToShortName,
      );
      if (p.id.isEmpty) return false;
      _items.removeWhere((e) => e.id == p.id);
      _items.insert(0, p);
      _controller.add(items);
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// HTTP URL emas, diskdagi fayl bo‘lsa multipart `image` uchun yo‘l.
  static String? _localImagePathForUpload(String? imageUrl) {
    if (imageUrl == null || imageUrl.trim().isEmpty) return null;
    final t = imageUrl.trim();
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
      _items = rows
          .map((e) {
            try {
              return Product.fromApiJson(
                Map<String, dynamic>.from(e as Map),
                unitIdToName: _unitIdToName,
                unitIdToShortName: _unitIdToShortName,
              );
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
    } on ApiException catch (e) {
      _loadError = e.message;
      _loaded = true;
      _items = [];
      _controller.add(items);
      notifyListeners();
    } catch (e, st) {
      _loadError = 'Mahsulotlar yuklanmadi';
      _loaded = true;
      _items = [];
      _controller.add(items);
      notifyListeners();
      assert(() {
        // ignore: avoid_print
        print('ProductsProvider.loadFromApi error: $e\n$st');
        return true;
      }());
    }
  }

  Future<void> addProduct(Product product) async {
    if (_productMutationInFlight) {
      throw ApiException('Saqlash davom etmoqda, iltimos kuting', 409);
    }
    _productMutationInFlight = true;
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
      final sellPrice = product.priceUzs is int ? product.priceUzs : int.tryParse(product.priceUzs.toString()) ?? 0;
      final quantity = product.initialQuantity is int ? product.initialQuantity : int.tryParse(product.initialQuantity.toString()) ?? 0;
      // MOBILE_API_DOCS.md §4 Products: name, type, category, unit, barcode, receivingPrice,
      // purchasePriceCurrency, sallingPrice, sellingPriceCurrency, quantity, branch_id; rasm: multipart yoki image_base64
      final sellNum = product.sellingPriceApi ?? sellPrice;
      final body = <String, dynamic>{
        'name': productName,
        'type': 0,
        'unit': unitId,
        'taxID': 'no-tax',
        'sallingPrice': sellNum,
        'sellingPriceCurrency': product.sellingPriceCurrency.toLowerCase(),
        'purchasePriceCurrency': product.purchasePriceCurrency.toLowerCase(),
        'selling_price': sellNum,
        'barcode': product.barcode?.trim() ?? '',
        'sku': product.sku?.trim() ?? '',
        'description': product.description?.trim() ?? '',
      };
      if (quantity > 0) body['quantity'] = quantity;
      num? recv;
      if (product.purchasePriceApi != null) {
        recv = product.purchasePriceApi;
      } else {
        final costUzs = product.costPriceUzs != null && product.costPriceUzs! > 0
            ? (product.costPriceUzs is int ? product.costPriceUzs! : int.tryParse(product.costPriceUzs.toString()) ?? 0)
            : null;
        recv = costUzs;
      }
      if (recv != null && recv != 0) {
        body['receivingPrice'] = recv;
        body['receiving_price'] = recv;
        body['purchase_price'] = recv;
      }
      if (categoryId != null) body['category'] = categoryId;
      final branchId = await _getDefaultBranchId();
      if (branchId != null) body['branch_id'] = branchId;
      // API: additionalBarcodes — qo'shimcha shtrix kodlar (1 yoki undan ortiq, massiv)
      if (product.additionalBarcodes != null && product.additionalBarcodes!.isNotEmpty) {
        final list = product.additionalBarcodes!.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
        if (list.isNotEmpty) body['additionalBarcodes'] = list;
      }
      // API 1.2: pachka — faqat units_per_package > 1 bo'lsa; package_selling_price, package_purchase_price
      if (product.quantityInPack && product.quantityPerPack > 1) {
        body['units_per_package'] = product.quantityPerPack;
        body['unitsPerPackage'] = product.quantityPerPack;
        if (product.sellPricePerPack != null && product.sellPricePerPack! > 0) {
          body['package_selling_price'] = product.sellPricePerPack;
          body['packageSellingPrice'] = product.sellPricePerPack;
        }
        if (product.costPricePerPack != null && product.costPricePerPack! > 0) {
          body['package_purchase_price'] = product.costPricePerPack;
          body['packagePurchasePrice'] = product.costPricePerPack;
        }
      }
      final uploadPath = _localImagePathForUpload(product.imageUrl);
      final useMultipart =
          uploadPath != null && await File(uploadPath).exists();

      assert(() {
        // ignore: avoid_print
        print('=== POST /api/v1/products (yangi mahsulot) ===');
        // ignore: avoid_print
        print('Body: $body multipart: $useMultipart');
        return true;
      }());
      Map<String, dynamic> res;
      try {
        res = await ProductsApi.createProduct(
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
          res = await ProductsApi.createProduct(
            {'data': body},
            localImagePath: useMultipart ? uploadPath : null,
          );
        } else {
          rethrow;
        }
      }
      if (!_tryMergeProductFromApiResponse(res, quantityHint: product)) {
        await loadFromApi();
      }
    } catch (_) {
      rethrow;
    } finally {
      _productMutationInFlight = false;
    }
  }

  Future<void> updateProduct(Product product) async {
    if (_productMutationInFlight) {
      throw ApiException('Saqlash davom etmoqda, iltimos kuting', 409);
    }
    _productMutationInFlight = true;
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
      // Tahrirlashda miqdor yuborilmaydi — API da o'zgartirilmaydi
      final sellNum = product.sellingPriceApi ?? product.priceUzs;
      final body = <String, dynamic>{
        'name': product.name.trim(),
        'title': product.name.trim(),
        'sallingPrice': sellNum,
        'sell_price': sellNum,
        'sellingPriceCurrency': product.sellingPriceCurrency.toLowerCase(),
        'purchasePriceCurrency': product.purchasePriceCurrency.toLowerCase(),
        // Dona kelish narxi (alohida) — backend turli nomlar qabul qiladi
        if (product.purchasePriceApi != null || product.costPriceUzs != null)
          'purchase_price': product.purchasePriceApi ?? product.costPriceUzs,
        if (product.purchasePriceApi != null || product.costPriceUzs != null)
          'receivingPrice': product.purchasePriceApi ?? product.costPriceUzs,
        if (product.purchasePriceApi != null || product.costPriceUzs != null)
          'receiving_price': product.purchasePriceApi ?? product.costPriceUzs,
        'sku': product.sku?.trim() ?? '',
        'barcode': product.barcode?.trim() ?? '',
        'unit': unitId,
        'unit_id': unitId,
        'description': product.description?.trim() ?? '',
        'reorder': product.reorderLevel,
        'reorderLevel': product.reorderLevel,
      };
      if (categoryId != null) {
        body['category_id'] = categoryId;
        body['category'] = categoryId;
      }
      // API 1.2: pachka — faqat units_per_package > 1 bo'lsa
      if (product.quantityInPack && product.quantityPerPack > 1) {
        body['units_per_package'] = product.quantityPerPack;
        body['unitsPerPackage'] = product.quantityPerPack;
        if (product.sellPricePerPack != null && product.sellPricePerPack! > 0) {
          body['package_selling_price'] = product.sellPricePerPack;
          body['packageSellingPrice'] = product.sellPricePerPack;
        }
        if (product.costPricePerPack != null && product.costPricePerPack! > 0) {
          body['package_purchase_price'] = product.costPricePerPack;
          body['packagePurchasePrice'] = product.costPricePerPack;
        }
      }
      if (product.additionalBarcodes != null && product.additionalBarcodes!.isNotEmpty) {
        final list = product.additionalBarcodes!.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
        if (list.isNotEmpty) body['additionalBarcodes'] = list;
      }
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
      final response = await ProductsApi.updateProduct(
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
      if (!_tryMergeProductFromApiResponse(response, quantityHint: null)) {
        await loadFromApi();
      }
    } catch (_) {
      rethrow;
    } finally {
      _productMutationInFlight = false;
    }
  }

  Product? getProductById(String id) {
    try {
      return _items.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
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
