import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/api_client.dart';
import '../models/cart_item.dart';
import '../models/product.dart';
import '../providers/clients_provider.dart';
import '../services/api_service.dart';
import '../providers/categories_provider.dart';
import '../utils/filter_options_parser.dart';
import '../utils/product_search.dart';
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
  bool hideZeroStock = false;
  /// Ulgurji narxda sotish (kelish bilan bir vaqtda yoqilmaydi).
  bool sellAtWholesalePrice = false;
  /// Kelish narxida sotish.
  bool sellAtPurchasePrice = false;
  /// Katalog kartochkasida kelish narxini ko'rsatish.
  bool showPurchasePrice = false;

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

  Future<void> init() async {
    if (initLoading) return;
    initLoading = true;
    initError = null;
    notifyListeners();
    try {
      await _loadBranchesAndSetDefault();
      await Future.wait([
        _loadPaymentTypes(),
        _loadCurrencies(),
        _loadFilterLists(),
        _loadCashRegisters(),
      ]);
      await loadProducts(reset: true);
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

  Future<void> _loadBranchesAndSetDefault() async {
    final res = await SalesApi.getBranches();
    final raw = res['branches'] ?? res['data'] ?? res;
    if (raw is! List || raw.isEmpty) {
      branchId = 1;
      branchName = 'Filial';
      return;
    }
    final first = Map<String, dynamic>.from(raw.first as Map);
    final id = first['id'] ?? first['branchID'];
    branchId = id is int ? id : int.tryParse(id?.toString() ?? '') ?? 1;
    branchName = (first['name'] ?? first['title'] ?? 'Filial').toString();
    await SalesApi.setBranch(branchID: branchId!, orderType: 'sales');
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

  Future<void> _loadFilterLists() async {
    categories = await _fetchCategoryOptions();
    brands = await _fetchBrandOptions();
  }

  /// Filtr dialogi ochilganda qayta yuklash.
  Future<void> reloadFilterLists() async {
    await _loadFilterLists();
    notifyListeners();
  }

  Future<List<Map<String, dynamic>>> _fetchCategoryOptions() async {
    var list = <Map<String, dynamic>>[];
    try {
      list = FilterOptionsParser.parseIdNameList(await ProductsApi.postCategoriesList());
    } catch (_) {}
    if (list.isEmpty) {
      try {
        list = FilterOptionsParser.parseIdNameList(await CategoriesApi.getCategories());
      } catch (_) {}
    }
    if (list.isEmpty) {
      try {
        await CategoriesProvider.instance.loadFromApi();
        list = CategoriesProvider.instance.idNameOptions;
      } catch (_) {}
    }
    if (list.isEmpty) {
      try {
        final support = await ProductsApi.getSupportingData();
        list = FilterOptionsParser.parseIdNameList(support['categories'] ?? support);
      } catch (_) {}
    }
    return list;
  }

  Future<List<Map<String, dynamic>>> _fetchBrandOptions() async {
    var list = <Map<String, dynamic>>[];
    try {
      list = FilterOptionsParser.parseIdNameList(await ProductsApi.postBrandsList());
    } catch (_) {}
    if (list.isEmpty) {
      try {
        final support = await ProductsApi.getSupportingData();
        list = FilterOptionsParser.parseIdNameList(support['brands'] ?? support);
      } catch (_) {}
    }
    return list;
  }

  /// 0 qoldiq filtri qo'llangan katalog.
  List<Product> get catalogProductsVisible {
    if (!hideZeroStock) return salesProducts;
    return salesProducts.where((p) => p.hasStock).toList();
  }

  Future<void> _loadCashRegisters() async {
    final shift = CashRegisterShiftProvider.instance;
    await shift.loadRegisters();
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

  /// Mahsulotlar bo'limidagi kabi to'liq katalogni yuklash (desktop qidiruv uchun).
  Future<void> ensureAllProductsLoaded() async {
    var guard = 0;
    while (hasMoreProducts && guard < 50) {
      guard++;
      await loadProducts(reset: false);
      if (productsError != null) break;
    }
  }

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
      final page = SalesProducts.fromSalesResponse(res);
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
    } on ApiException catch (e) {
      productsError = e.message;
      if (reset) salesProducts = [];
    } catch (_) {
      productsError = 'Mahsulotlar yuklanmadi';
      if (reset) salesProducts = [];
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
    try {
      final res = await SalesApi.barcodeSearch(
        searchValue: q,
        branchId: branchId ?? 1,
      );
      return SalesProducts.fromBarcodeResult(res);
    } catch (_) {
      _lastSearch = q;
      await loadProducts(reset: true, searchValue: q);
      return takePendingBarcodeProduct();
    }
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
  }) {
    categoryId = category;
    brandId = brand;
    hideZeroStock = hideZero;
    sellAtWholesalePrice = sellWholesale;
    sellAtPurchasePrice = sellPurchase;
    if (sellWholesale) sellAtPurchasePrice = false;
    if (sellPurchase) sellAtWholesalePrice = false;
    showPurchasePrice = showPurchaseOnCards;
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
