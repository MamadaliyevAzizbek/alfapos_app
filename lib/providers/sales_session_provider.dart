import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/api_client.dart';
import '../core/api_pacing.dart';
import '../core/auth_storage.dart';
import '../models/cart_item.dart';
import '../services/product_catalog_storage.dart';
import '../services/sales_session_storage.dart';
import '../models/product.dart';
import '../providers/clients_provider.dart';
import '../services/api_service.dart';
import '../providers/categories_provider.dart';
import '../providers/products_provider.dart';
import '../utils/filter_options_parser.dart';
import '../utils/product_search.dart';
import '../utils/barcode_product_lookup.dart';
import '../utils/sales_products.dart';
import '../utils/hold_orders_response.dart';
import '../utils/sales_payment_types.dart';
import '../utils/sales_store_body.dart';
import '../utils/cash_register_utils.dart';
import 'cash_register_shift_provider.dart';

/// Desktop sotuv sessiyasi — MOBILE_SALES_API_UZ.md init va mahsulotlar.
class SalesSessionProvider extends ChangeNotifier {
  SalesSessionProvider._();
  static final SalesSessionProvider instance = SalesSessionProvider._();

  bool initLoading = false;
  String? initError;

  int? branchId;
  String branchName = '';
  int? cashRegisterId;
  int? registerLogId;
  String cashRegisterName = 'Main Cash Register';
  bool isCashRegisterBranch = false;
  List<Map<String, dynamic>> cashRegisters = [];

  List<Map<String, dynamic>> categories = [];
  List<Map<String, dynamic>> brands = [];
  List<Map<String, dynamic>> paymentTypes = [];
  double usdRate = 1;

  String? categoryId;
  String? brandId;
  String? _filterListsCompanyId;
  bool hideZeroStock = false;
  /// Ulgurji narxda sotish (kelish bilan bir vaqtda yoqilmaydi).
  bool sellAtWholesalePrice = false;
  /// Kelish narxida sotish.
  bool sellAtPurchasePrice = false;
  /// Katalog kartochkasida kelish narxini ko'rsatish.
  bool showPurchasePrice = false;
  /// Katalogda qavs ichida dollar ekvivalenti ($…) — default o‘chiq.
  bool showUsdEquivalent = false;

  List<Product> salesProducts = [];
  bool productsLoading = false;
  String? productsError;
  int _offset = 0;
  bool hasMoreProducts = true;
  String _lastSearch = '';

  /// Oxirgi server qidiruvi (bo'sh = to'liq katalog).
  String get lastSearch => _lastSearch;

  int cartDiscountPercent = 0;

  bool _holdCartInFlight = false;
  bool get holdCartInFlight => _holdCartInFlight;

  bool _backgroundSyncInFlight = false;
  bool get backgroundSyncInFlight => _backgroundSyncInFlight;

  /// Mahsulotlar bo‘limi yangilanganda sotuv kartochkalaridagi miqdorni moslashtirish.
  void applyCatalogStock() {
    if (salesProducts.isEmpty) return;
    salesProducts = ProductsProvider.instance.withCatalogStockAll(salesProducts);
    notifyListeners();
  }

  /// Diskdan sessiyani tiklash (server kutmasdan katalog ko‘rsatish).
  Future<bool> bootstrapFromLocal() async {
    final meta = await SalesSessionStorage.loadMeta();
    final cid = (await getCompanyId())?.trim() ?? '';
    final metaCid = (meta['companyId'] ?? '').toString().trim();
    if (cid.isNotEmpty && metaCid.isNotEmpty && cid != metaCid) {
      categories = [];
      brands = [];
      _filterListsCompanyId = null;
    } else {
      _applyMetaFromStorage(meta);
      if (cid.isNotEmpty) _filterListsCompanyId = cid;
    }

    // Avval mahsulotlar katalogi (to‘g‘ri ombor), eski sotuv keshi faqat zaxira.
    var products = ProductsProvider.instance.items;
    if (products.isEmpty) {
      products = await ProductCatalogStorage.loadCatalog();
    }
    if (products.isEmpty) {
      products = await SalesSessionStorage.loadProducts();
    }
    if (products.isEmpty) return false;

    salesProducts = ProductsProvider.instance.withCatalogStockAll(products);
    _offset = salesProducts.length;
    hasMoreProducts = true;
    productsError = null;
    notifyListeners();
    return true;
  }

  void _applyMetaFromStorage(Map<String, dynamic> meta) {
    final bid = meta['branchId'];
    if (bid != null) {
      branchId = bid is int ? bid : int.tryParse(bid.toString());
    }
    branchName = (meta['branchName'] ?? branchName).toString();
    final rate = meta['usdRate'];
    if (rate is num) usdRate = rate.toDouble();

    final pt = meta['paymentTypes'];
    if (pt is List) {
      paymentTypes = pt.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    final cat = meta['categories'];
    if (cat is List) {
      categories = cat.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    final br = meta['brands'];
    if (br is List) {
      brands = br.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
  }

  Future<void> _persistSessionSnapshot() async {
    if (salesProducts.isNotEmpty) {
      await SalesSessionStorage.saveProducts(salesProducts);
    }
    await SalesSessionStorage.saveMeta({
      'branchId': branchId,
      'branchName': branchName,
      'usdRate': usdRate,
      'paymentTypes': paymentTypes,
      'categories': categories,
      'brands': brands,
    });
  }

  /// [localFirst]: avval kesh, keyin fon rejimida asta-sekin server.
  Future<void> init({bool localFirst = false}) async {
    if (initLoading) return;
    initLoading = true;
    initError = null;
    notifyListeners();

    if (localFirst && await bootstrapFromLocal()) {
      initLoading = false;
      notifyListeners();
      unawaited(syncFromServerInBackground());
      return;
    }

    try {
      await _initFromServerSequential();
    } on ApiException catch (e) {
      initError = e.message;
    } catch (e) {
      initError = 'Sotuv yuklanmadi';
      assert(() {
        // ignore: avoid_print
        print('SalesSessionProvider.init: $e');
        return true;
      }());
    } finally {
      initLoading = false;
      notifyListeners();
    }
  }

  /// Serverga ketma-ket, pauza bilan (parallel emas).
  Future<void> _initFromServerSequential() async {
    await _loadBranchesAndSetDefault();
    await ApiPacing.staggerPause();
    await _loadCashRegisters();
    await ApiPacing.staggerPause();
    await _loadPaymentTypes();
    await ApiPacing.staggerPause();
    await _loadCurrencies();
    await ApiPacing.staggerPause();
    await _loadFilterLists(force: true);
    await ApiPacing.staggerPause();
    await loadProducts(reset: true);
    await _persistSessionSnapshot();
  }

  /// Keshdan keyin yoki «Sinxronlash» dan keyin asta serverni yangilash.
  Future<void> syncFromServerInBackground() async {
    if (_backgroundSyncInFlight) return;
    _backgroundSyncInFlight = true;
    notifyListeners();
    try {
      await ApiPacing.staggerPause(const Duration(seconds: 1));
      initError = null;
      await _initFromServerSequential();
      if (initError == null && productsError == null) {
        unawaited(syncRemainingProductsInBackground());
      }
    } on ApiException catch (e) {
      initError = e.message;
    } catch (_) {
      initError = 'Sotuv yuklanmadi';
    } finally {
      _backgroundSyncInFlight = false;
      notifyListeners();
    }
  }

  Future<void> _loadBranchesAndSetDefault() async {
    final res = await SalesApi.getBranches();
    final parsed = _parseFirstBranchFromApiResponse(res);
    if (parsed == null) {
      branchId = null;
      branchName = 'Filial';
      throw ApiException('Filiallar ro\'yxati bo\'sh yoki noto\'g\'ri formatda');
    }
    branchId = parsed.$1;
    branchName = parsed.$2;
    await SalesApi.setBranch(branchID: branchId!, orderType: 'sales');
  }

  /// GET /sales/branches — `{ text, value }` yoki `{ id, name }`.
  static (int, String)? _parseFirstBranchFromApiResponse(Map<String, dynamic> res) {
    List<dynamic>? list = res['branches'] as List<dynamic>?;
    list ??= res['data'] as List<dynamic>?;
    if (res['data'] is Map<String, dynamic>) {
      final dm = res['data'] as Map<String, dynamic>;
      list ??= dm['branches'] as List<dynamic>? ?? dm['data'] as List<dynamic>?;
    }
    if (list == null || list.isEmpty) return null;
    final first = list.first;
    if (first is! Map) return null;
    final m = Map<String, dynamic>.from(first);
    final idRaw = m['value'] ?? m['id'] ?? m['branchID'] ?? m['branch_id'];
    if (idRaw == null) return null;
    final id = idRaw is int ? idRaw : int.tryParse(idRaw.toString());
    if (id == null) return null;
    final name = (m['text'] ?? m['name'] ?? m['title'] ?? 'Filial').toString();
    return (id, name);
  }

  Future<void> _loadPaymentTypes() async {
    final res = await SalesApi.getPaymentTypes();
    paymentTypes = parseSalesPaymentTypesResponse(res);
  }

  /// To'lov oynasi ochilishidan oldin — sessiyada kesh bo'lsa API chaqirilmaydi.
  Future<void> ensurePaymentTypesLoaded() async {
    if (paymentTypes.isNotEmpty) return;
    await _loadPaymentTypes();
    notifyListeners();
  }

  Future<void> _loadCurrencies() async {
    try {
      final res = await SalesApi.getCurrencies();
      final raw = res['currencies'] ?? res['data'] ?? res;
      if (raw is List) {
        for (final c in raw) {
          if (c is! Map) continue;
          final code = (c['code'] ?? c['name'] ?? '').toString().toUpperCase();
          if (code.contains('USD')) {
            final r = c['exchange_rate'] ?? c['rate'];
            usdRate = r is num ? r.toDouble() : double.tryParse(r?.toString() ?? '') ?? 1;
            break;
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _ensureFilterListsCompany({bool force = false}) async {
    final cid = (await getCompanyId())?.trim();
    if (force || (_filterListsCompanyId != null && cid != null && cid != _filterListsCompanyId)) {
      categories = [];
      brands = [];
      await CategoriesProvider.instance.resetForCompanyChange();
    }
    _filterListsCompanyId = cid;
  }

  /// Boshqa kompaniyaga kirganda filtrlarni tozalash (login dan keyin).
  Future<void> resetFilterListsForCompanyChange() async {
    categoryId = null;
    brandId = null;
    _filterListsCompanyId = null;
    categories = [];
    brands = [];
    await CategoriesProvider.instance.resetForCompanyChange();
    notifyListeners();
  }

  Future<void> _loadFilterLists({bool force = false}) async {
    await _ensureFilterListsCompany(force: force);
    categories = await _fetchCategoryOptions(force: force);
    brands = await _fetchBrandOptions(force: force);
    notifyListeners();
  }

  /// Filtr dialogi / navbar — serverdan joriy kompaniya bo‘yicha.
  Future<void> reloadFilterLists() async {
    await _loadFilterLists(force: true);
  }

  Future<List<Map<String, dynamic>>> _fetchCategoryOptions({bool force = false}) async {
    if (!force && categories.isNotEmpty) return categories;

    final cid = (await getCompanyId())?.trim();
    var list = <Map<String, dynamic>>[];
    try {
      list = FilterOptionsParser.parseIdNameList(await ProductsApi.postCategoriesList());
    } catch (_) {}

    if (list.isEmpty) {
      await CategoriesProvider.instance.resetForCompanyChange();
      await CategoriesProvider.instance.loadFromApiIfStale(force: force);
      list = _filterIdNameByCompany(CategoriesProvider.instance.idNameOptions, cid);
    }
    if (list.isEmpty) {
      try {
        await CategoriesProvider.instance.loadFromApi();
        list = _filterIdNameByCompany(CategoriesProvider.instance.idNameOptions, cid);
      } catch (_) {}
    }
    return list;
  }

  List<Map<String, dynamic>> _filterIdNameByCompany(
    List<Map<String, dynamic>> list,
    String? companyId,
  ) {
    final cid = companyId?.trim();
    if (cid == null || cid.isEmpty) return list;
    return list.where((e) {
      final rowCid = (e['company_id'] ?? e['companyId'])?.toString().trim();
      if (rowCid == null || rowCid.isEmpty) return true;
      return rowCid == cid;
    }).toList();
  }

  Future<List<Map<String, dynamic>>> _fetchBrandOptions({bool force = false}) async {
    if (!force && brands.isNotEmpty) return brands;

    Future<List<Map<String, dynamic>>> trySource(
      Future<Map<String, dynamic>> req, {
      bool brandsOnly = false,
    }) async {
      try {
        final res = await req;
        return brandsOnly
            ? FilterOptionsParser.parseBrandsFromResponse(res)
            : FilterOptionsParser.parseIdNameList(res);
      } catch (_) {
        return [];
      }
    }

    for (final list in [
      await trySource(ProductsApi.postBrandsList()),
      await trySource(ProductsApi.getBrands()),
      await trySource(ProductsApi.getFilterOptions(), brandsOnly: true),
      await trySource(ProductsApi.getSupportingData(), brandsOnly: true),
    ]) {
      if (list.isNotEmpty) return list;
    }
    return [];
  }

  /// 0 qoldiq filtri qo'llangan katalog.
  List<Product> get catalogProductsVisible {
    if (!hideZeroStock) return salesProducts;
    return salesProducts.where((p) => p.hasStock).toList();
  }

  Future<void> _loadCashRegisters() async {
    final shift = CashRegisterShiftProvider.instance;
    if (shift.registers.isEmpty) {
      await shift.loadRegisters();
    }
    cashRegisters = List<Map<String, dynamic>>.from(shift.registers);
    syncFromShift();
    if (cashRegisters.isNotEmpty && !isShiftOpenForSales) {
      isCashRegisterBranch = true;
      cashRegisterId = null;
      registerLogId = null;
      cashRegisterName = cashRegisterDisplayTitle(cashRegisters.first);
      return;
    }
    if (cashRegisters.isEmpty) {
      cashRegisterId = null;
      registerLogId = null;
      cashRegisterName = branchName.isNotEmpty ? branchName : 'Main Cash Register';
      isCashRegisterBranch = false;
    }
  }

  bool get isShiftOpenForSales =>
      registerLogId != null && cashRegisterId != null;

  void syncFromShift() {
    final shift = CashRegisterShiftProvider.instance;
    cashRegisters = List<Map<String, dynamic>>.from(shift.registers);
    if (shift.isShiftOpen) {
      if (shift.activeRegister != null) {
        _applyCashRegister(shift.activeRegister!);
      }
      registerLogId = shift.registerLogId ?? registerLogId;
      cashRegisterId = shift.cashRegisterId ?? cashRegisterId;
      cashRegisterName = shift.cashRegisterTitle.isNotEmpty
          ? shift.cashRegisterTitle
          : cashRegisterName;
      isCashRegisterBranch = true;
    }
  }

  void _applyCashRegister(Map<String, dynamic> cr) {
    final id = cr['id'] ?? cr['cash_register_id'];
    cashRegisterId = id is int ? id : int.tryParse(id?.toString() ?? '');
    registerLogId = cashRegisterIsOpen(cr) ? cashRegisterLogId(cr) : null;
    cashRegisterName = cashRegisterDisplayTitle(cr);
  }

  void selectCashRegister(Map<String, dynamic> cr) {
    CashRegisterShiftProvider.instance.selectRegister(cr);
    _applyCashRegister(cr);
    isCashRegisterBranch = true;
    notifyListeners();
  }

  Future<void> loadMoreProducts() => loadProducts(reset: false);

  /// Qolgan sahifalarni fon rejimida, pauza bilan yuklash (server yukini kamaytirish).
  Future<void> syncRemainingProductsInBackground() async {
    if (_backgroundSyncInFlight || productsLoading) return;
    var guard = 0;
    while (hasMoreProducts && guard < 50) {
      guard++;
      await loadProducts(reset: false);
      if (productsError != null) break;
      if (hasMoreProducts) await ApiPacing.staggerPause(ApiPacing.productPageStep);
    }
    await _persistSessionSnapshot();
  }

  @Deprecated('Use syncRemainingProductsInBackground')
  Future<void> ensureAllProductsLoaded() => syncRemainingProductsInBackground();

  void setSearchQuery(String value) {
    _lastSearch = value.trim();
  }

  Future<void> loadProducts({bool reset = false, String? searchValue}) async {
    if (productsLoading) return;
    if (reset) {
      _offset = 0;
      hasMoreProducts = true;
      if (searchValue != null) _lastSearch = searchValue.trim();
    }
    if (!hasMoreProducts && !reset) return;

    final countBefore = salesProducts.length;
    productsLoading = true;
    productsError = null;
    notifyListeners();

    try {
      final body = <String, dynamic>{
        'orderType': 'sales',
        'currentBranch': branchId ?? 1,
        'searchValue': _lastSearch,
        'rowLimit': 40,
        'offset': _offset,
        'categoryId': categoryId ?? '',
        'brandId': brandId ?? '',
      };
      final res = await SalesApi.getSalesProducts(body: body);
      var page = SalesProducts.fromSalesResponse(res);
      page = ProductsProvider.instance.withCatalogStockAll(page);
      if (reset) {
        salesProducts = page;
      } else {
        final seen = salesProducts.map((p) => p.id).toSet();
        salesProducts = [...salesProducts, ...page.where((p) => !seen.contains(p.id))];
      }
      _offset += page.length;
      hasMoreProducts = page.length >= 40;

      final isBarcodeQuery = looksLikeBarcodeInput(_lastSearch);
      final auto = SalesProducts.pickAutoAddBarcode(
        res,
        allowSingleResult: isBarcodeQuery,
      );
      if (auto != null && _lastSearch.isNotEmpty && isBarcodeQuery) {
        _pendingBarcodeProduct = auto;
      }
      applyCatalogStock();
      if (salesProducts.isNotEmpty) {
        unawaited(_persistSessionSnapshot());
      }
    } on ApiException catch (e) {
      productsError = e.message;
      if (reset && countBefore == 0) salesProducts = [];
    } catch (_) {
      productsError = 'Mahsulotlar yuklanmadi';
      if (reset && countBefore == 0) salesProducts = [];
    } finally {
      productsLoading = false;
      notifyListeners();
    }
  }

  Product? _pendingBarcodeProduct;
  Product? takePendingBarcodeProduct() {
    final p = _pendingBarcodeProduct;
    _pendingBarcodeProduct = null;
    return p;
  }

  Future<Product?> findByBarcode(String code) async {
    final q = code.trim();
    if (q.isEmpty) return null;

    final unified = await BarcodeProductLookup.resolve(
      query: q,
      salesScreenProducts: salesProducts,
      branchId: branchId ?? 1,
    );
    if (unified != null) {
      _upsertSalesProduct(unified);
      return unified;
    }

    _lastSearch = q;
    await loadProducts(reset: true, searchValue: q);
    final pending = takePendingBarcodeProduct();
    if (pending != null) return pending;

    return BarcodeProductLookup.resolve(
      query: q,
      salesScreenProducts: salesProducts,
      branchId: branchId ?? 1,
    );
  }

  void _upsertSalesProduct(Product product) {
    final i = salesProducts.indexWhere((p) => p.id == product.id);
    if (i >= 0) {
      salesProducts[i] = product;
    } else {
      salesProducts.insert(0, product);
    }
    notifyListeners();
  }

  void setCategoryFilter(String? id) {
    categoryId = id;
    loadProducts(reset: true);
  }

  void setBrandFilter(String? id) {
    brandId = id;
    loadProducts(reset: true);
  }

  void setCartDiscountPercent(int percent) {
    cartDiscountPercent = percent.clamp(-100, 100);
    notifyListeners();
  }

  void setHideZeroStock(bool value) {
    hideZeroStock = value;
    notifyListeners();
  }

  void setShowPurchasePrice(bool value) {
    showPurchasePrice = value;
    notifyListeners();
  }

  /// `purchase` | `wholesale` | null (oddiy sotish narxi).
  String? get activeSellPriceType {
    if (sellAtPurchasePrice) return 'purchase';
    if (sellAtWholesalePrice) return 'wholesale';
    return null;
  }

  void setSellAtWholesalePrice(bool value) {
    sellAtWholesalePrice = value;
    if (value) sellAtPurchasePrice = false;
    notifyListeners();
  }

  void setSellAtPurchasePrice(bool value) {
    sellAtPurchasePrice = value;
    if (value) sellAtWholesalePrice = false;
    notifyListeners();
  }

  void applySalesFilters({
    String? category,
    String? brand,
    required bool hideZero,
    required bool sellWholesale,
    required bool sellPurchase,
    required bool showPurchaseOnCards,
    required bool showUsdOnCards,
  }) {
    categoryId = category;
    brandId = brand;
    hideZeroStock = hideZero;
    sellAtWholesalePrice = sellWholesale;
    sellAtPurchasePrice = sellPurchase;
    if (sellWholesale) sellAtPurchasePrice = false;
    if (sellPurchase) sellAtWholesalePrice = false;
    showPurchasePrice = showPurchaseOnCards;
    showUsdEquivalent = showUsdOnCards;
    notifyListeners();
  }

  void clearSalesFilters() {
    applySalesFilters(
      category: null,
      brand: null,
      hideZero: false,
      sellWholesale: false,
      sellPurchase: false,
      showPurchaseOnCards: false,
      showUsdOnCards: false,
    );
  }

  /// +20 → jami 20% oshadi, -20 → jami 20% kamayadi.
  int applyDiscountToTotal(int rawTotal) {
    if (cartDiscountPercent == 0) return rawTotal;
    return (rawTotal * (100 + cartDiscountPercent) / 100).round();
  }

  Future<List<Client>> searchCustomers(String query) async {
    final q = query.trim();
    if (q.isEmpty) return [];
    try {
      final res = await SalesApi.searchCustomers(searchValue: q);
      final raw = res['customers'] ?? res['data'] ?? res['datarows'] ?? res;
      if (raw is! List) return [];
      return raw
          .whereType<Map>()
          .map((e) {
            try {
              return Client.fromApiJson(Map<String, dynamic>.from(e));
            } catch (_) {
              return null;
            }
          })
          .whereType<Client>()
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> holdCart({
    required List<CartItem> cartItems,
    required int subTotal,
    required int grandTotal,
    int? customerId,
    int? orderId,
    String? invoiceId,
  }) async {
    if (_holdCartInFlight) return null;
    _holdCartInFlight = true;
    notifyListeners();
    try {
      return await _holdCartImpl(
        cartItems: cartItems,
        subTotal: subTotal,
        grandTotal: grandTotal,
        customerId: customerId,
        orderId: orderId,
        invoiceId: invoiceId,
      );
    } finally {
      _holdCartInFlight = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>?> _holdCartImpl({
    required List<CartItem> cartItems,
    required int subTotal,
    required int grandTotal,
    int? customerId,
    int? orderId,
    String? invoiceId,
  }) async {
    syncFromShift();
    final shift = CashRegisterShiftProvider.instance;
    if (shift.requiresCashRegister && !isShiftOpenForSales) {
      throw ApiException('Kassa smenasi ochiq emas. Avval smenani oching.');
    }
    for (final item in cartItems) {
      final pid = int.tryParse(item.product.id) ?? 0;
      if (pid <= 0) {
        throw ApiException(
          'Mahsulot ID topilmadi: «${item.product.name}». Katalogni yangilang yoki mahsulotni qayta qo‘shing.',
        );
      }
    }
    final body = SalesStoreBody.build(
      items: cartItems,
      subTotal: subTotal,
      grandTotal: grandTotal,
      status: 'hold',
      discountPercent: cartDiscountPercent,
      customerId: customerId,
      cashRegisterId: cashRegisterId,
      registerLogId: registerLogId ?? shift.registerLogId,
      isCashRegisterBranch: isCashRegisterBranch,
      branchId: branchId,
      orderId: orderId,
      invoiceId: invoiceId,
    );
    assert(() {
      // ignore: avoid_print
      print('[holdCart] POST /sales/store body keys=${body.keys.toList()} '
          'register_log_id=${body['register_log_id']} cashRagisterId=${body['cashRagisterId']} '
          'cart=${(body['cart'] as List?)?.length} grandTotal=${body['grandTotal']}');
      return true;
    }());
    return SalesApi.storeSale(body);
  }

  /// Pauzadan ochib sotilgan buyurtmalar — hold ro'yxatida qayta ko'rinmasin.
  final Set<int> _completedHoldOrderIds = {};

  Future<List<Map<String, dynamic>>>? _holdOrdersFetchInFlight;
  DateTime? _holdOrdersFetchedAt;
  List<Map<String, dynamic>> _holdOrdersCache = [];
  static const _holdOrdersMinInterval = Duration(seconds: 12);

  Future<List<Map<String, dynamic>>> fetchHoldOrders({bool force = false}) async {
    if (!force &&
        _holdOrdersFetchedAt != null &&
        DateTime.now().difference(_holdOrdersFetchedAt!) < _holdOrdersMinInterval) {
      return _holdOrdersCache;
    }

    if (_holdOrdersFetchInFlight != null) {
      return _holdOrdersFetchInFlight!;
    }

    _holdOrdersFetchInFlight = _fetchHoldOrdersImpl();
    try {
      return await _holdOrdersFetchInFlight!;
    } finally {
      _holdOrdersFetchInFlight = null;
    }
  }

  Future<List<Map<String, dynamic>>> _fetchHoldOrdersImpl() async {
    try {
      final res = await SalesApi.getHoldOrders();
      final list = HoldOrdersResponse.parseList(res);
      final filtered = list.where((h) {
        final id = HoldOrdersResponse.resolveOrderId(h);
        return id == null || !_completedHoldOrderIds.contains(id);
      }).toList();
      _holdOrdersCache = filtered;
      _holdOrdersFetchedAt = DateTime.now();
      assert(() {
        if (kDebugMode) {
          debugPrint('[fetchHoldOrders] parsed=${filtered.length} '
              '(raw=${list.length}, hidden=${_completedHoldOrderIds.length})');
        }
        return true;
      }());
      return filtered;
    } catch (e) {
      assert(() {
        // ignore: avoid_print
        print('[fetchHoldOrders] $e');
        return true;
      }());
    }
    return _holdOrdersCache;
  }

  /// To'lovdan keyin hold holatini yopish (saqlangan buyurtmalar ro'yxatidan chiqarish).
  Future<void> completeHoldOrderAfterSale({
    required int orderId,
    String? invoiceId,
  }) async {
    _completedHoldOrderIds.add(orderId);
    _holdOrdersFetchedAt = null;
    final inv = (invoiceId ?? '').trim();
    try {
      await SalesApi.updateHoldStatus({
        'orderID': orderId,
        'order_id': orderId,
        'invoice_id': inv,
        'status': 'done',
      });
    } catch (_) {}
  }

  Future<void> sendDailySummary() async {
    await SalesApi.sendTelegramDailySummary();
  }

  Future<void> cancelHoldOrder(Map<String, dynamic> hold) async {
    final orderId = HoldOrdersResponse.resolveOrderId(hold);
    final invoiceId = (hold['invoice_id'] ?? hold['invoiceId'] ?? '').toString();
    if (orderId == null) return;
    try {
      await SalesApi.updateHoldStatus({
        'orderID': orderId,
        'invoice_id': invoiceId,
        'status': 'cancelled',
      });
    } catch (_) {
      await SalesApi.cancelSale(orderId);
    }
  }
}
