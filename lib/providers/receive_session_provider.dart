import 'dart:async';

import 'package:flutter/foundation.dart';
import '../core/api_client.dart';
import '../models/product.dart';
import '../models/receive_cart_item.dart';
import '../models/receive_supplier.dart';
import '../core/api_pacing.dart';
import '../services/api_service.dart';
import '../utils/receive_payment_types.dart';
import '../utils/receive_products.dart';
import '../utils/receive_store_body.dart';

class ReceiveSessionProvider extends ChangeNotifier {
  ReceiveSessionProvider._();
  static final ReceiveSessionProvider instance = ReceiveSessionProvider._();

  final List<ReceiveCartItem> _cart = [];
  List<ReceiveSupplier> suppliers = [];
  List<Map<String, dynamic>> paymentTypes = [];
  int? branchId;
  double usdExchangeRate = 1;
  ReceiveSupplier? selectedSupplier;
  Map<String, dynamic>? selectedPaymentType;
  DateTime selectedDate = DateTime.now();
  String comment = '';
  int deliveryCostUzs = 0;
  int? editOrderId;
  String? editReason;

  bool initLoading = false;
  String? initError;

  int _notifyPauseDepth = 0;
  bool _notifyPending = false;

  List<ReceiveCartItem> get cart => List.unmodifiable(_cart);

  /// Modal yopilayotganda boshqa ekranlarda setState chaqilmasin.
  void pauseNotify() => _notifyPauseDepth++;

  void resumeNotify() {
    if (_notifyPauseDepth <= 0) return;
    _notifyPauseDepth--;
    if (_notifyPauseDepth == 0 && _notifyPending) {
      _notifyPending = false;
      super.notifyListeners();
    }
  }

  @override
  void notifyListeners() {
    if (_notifyPauseDepth > 0) {
      _notifyPending = true;
      return;
    }
    super.notifyListeners();
  }

  int get cartCount => _cart.length;
  int get cartTotalUzs => _cart.fold<int>(0, (s, e) => s + e.lineTotalUzs);

  void resetForAccountChange() {
    _cart.clear();
    suppliers = [];
    paymentTypes = [];
    branchId = null;
    usdExchangeRate = 1;
    selectedSupplier = null;
    selectedPaymentType = null;
    selectedDate = DateTime.now();
    comment = '';
    deliveryCostUzs = 0;
    editOrderId = null;
    editReason = null;
    initLoading = false;
    initError = null;
    notifyListeners();
  }

  void clearCart() {
    _cart.clear();
    notifyListeners();
  }

  void setSupplier(ReceiveSupplier? s) {
    selectedSupplier = s;
    notifyListeners();
  }

  void setPaymentType(Map<String, dynamic>? p) {
    selectedPaymentType = p;
    notifyListeners();
  }

  void setDate(DateTime d) {
    selectedDate = d;
    notifyListeners();
  }

  void setComment(String v) {
    comment = v;
    notifyListeners();
  }

  void setDeliveryCost(int v) {
    deliveryCostUzs = v;
    notifyListeners();
  }

  void addToCart(Product product, {num quantity = 1}) {
    final i = _cart.indexWhere((e) => e.product.id == product.id);
    if (i >= 0) {
      _cart[i].quantity += quantity;
    } else {
      _cart.add(ReceiveCartItem(product: product, quantity: quantity));
    }
    notifyListeners();
  }

  void updateCartItem(
    ReceiveCartItem item, {
    num? quantity,
    int? purchasePriceUzs,
    int? sellPriceUzs,
  }) {
    final i = _cart.indexOf(item);
    if (i < 0) return;
    _applyCartItemEdits(_cart[i], quantity: quantity, purchasePriceUzs: purchasePriceUzs, sellPriceUzs: sellPriceUzs);
    notifyListeners();
  }

  void updateCartItemByProductId(
    String productId, {
    num? quantity,
    int? purchasePriceUzs,
    int? sellPriceUzs,
  }) {
    final i = _cart.indexWhere((e) => e.product.id == productId);
    if (i < 0) return;
    _applyCartItemEdits(_cart[i], quantity: quantity, purchasePriceUzs: purchasePriceUzs, sellPriceUzs: sellPriceUzs);
    notifyListeners();
  }

  void _applyCartItemEdits(
    ReceiveCartItem item, {
    num? quantity,
    int? purchasePriceUzs,
    int? sellPriceUzs,
  }) {
    if (quantity != null) item.quantity = quantity;
    if (purchasePriceUzs != null) item.purchasePriceUzs = purchasePriceUzs;
    if (sellPriceUzs != null) item.sellPriceUzs = sellPriceUzs;
    if (item.quantity <= 0) _cart.remove(item);
  }

  void removeFromCart(ReceiveCartItem item) {
    _cart.remove(item);
    notifyListeners();
  }

  Future<void> loadInit() async {
    initLoading = true;
    initError = null;
    notifyListeners();
    try {
      final suppliersRes = await ContactsApi.getSuppliers();
      await ApiPacing.staggerPause();
      final paymentRes = await ReceivesApi.getPaymentTypes();
      await ApiPacing.staggerPause();
      final branchesRes = await ReceivesApi.getBranches();
      await ApiPacing.staggerPause();
      final currenciesRes = await ReceivesApi.getCurrencies();

      suppliers = ReceiveSupplier.listFromResponse(suppliersRes);
      paymentTypes = ReceivePaymentTypes.parseAndFilter(paymentRes);
      if (paymentTypes.isNotEmpty) {
        selectedPaymentType = paymentTypes.first;
      }
      branchId = _parseDefaultBranchId(branchesRes);
      if (branchId != null) {
        try {
          await ReceivesApi.setBranch(branchId: branchId!);
        } catch (_) {}
      }
      usdExchangeRate = _parseUsdRate(currenciesRes);
      initError = null;
    } catch (e) {
      initError = e.toString();
    } finally {
      initLoading = false;
      notifyListeners();
    }
  }

  Future<List<Product>> searchProducts(String query) async {
    final q = query.trim();
    if (q.isEmpty) return [];
    final res = await ReceivesApi.getReceivesProducts(body: {
      'orderType': 'receiving',
      'searchValue': q,
      'rowLimit': 50,
      'offset': 0,
      if (branchId != null) 'currentBranch': branchId,
    });
    return ReceiveProducts.productsFromApiResponse(res);
  }

  Future<Product?> findByBarcode(String barcode) async {
    final q = barcode.trim();
    if (q.isEmpty) return null;
    try {
      final res = await ReceivesApi.barcodeSearch(
        searchValue: q,
        branchId: branchId,
      );
      final br = res['barcodeResultValue'];
      final fromBarcode = ReceiveProducts.productFromBarcodeResult(br);
      if (fromBarcode != null) return fromBarcode;
    } catch (_) {}
    final list = await searchProducts(q);
    if (list.length == 1) return list.single;
    return null;
  }

  Future<Map<String, dynamic>> submitReceive() async {
    if (selectedSupplier == null) {
      throw ApiException('Yetkazib beruvchini tanlang', 400);
    }
    if (_cart.isEmpty) {
      throw ApiException('Savat bo\'sh', 400);
    }
    final payment = selectedPaymentType ?? (paymentTypes.isNotEmpty ? paymentTypes.first : null);
    if (payment == null) {
      throw ApiException('To\'lov turini tanlang', 400);
    }
    final total = cartTotalUzs;
    final dateStr = _formatDate(selectedDate);
    final timeStr = '${selectedDate.hour.toString().padLeft(2, '0')}:'
        '${selectedDate.minute.toString().padLeft(2, '0')}:'
        '${selectedDate.second.toString().padLeft(2, '0')}';
    final note = ReceiveStoreBody.buildSalesNote(
      comment: comment,
      deliveryCostUzs: deliveryCostUzs > 0 ? deliveryCostUzs : null,
    );
    final body = ReceiveStoreBody.build(
      supplierId: selectedSupplier!.id,
      cart: _cart,
      paymentType: payment,
      grandTotalUzs: total,
      date: dateStr,
      time: timeStr,
      salesNote: note.isEmpty ? null : note,
      editOrderId: editOrderId,
      editReason: editReason,
      usdRate: usdExchangeRate,
    );
    final res = await ReceivesApi.storeReceive(body);
    _cart.clear();
    editOrderId = null;
    editReason = null;
    notifyListeners();
    return res;
  }

  static String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static int? _parseDefaultBranchId(Map<String, dynamic> res) {
    List<dynamic>? list = res['branches'] as List?;
    list ??= res['data'] as List?;
    if (list == null || list.isEmpty) return null;
    final first = list.first;
    if (first is! Map) return null;
    final m = Map<String, dynamic>.from(first);
    final id = m['value'] ?? m['id'] ?? m['branchID'];
    if (id is int) return id;
    return int.tryParse(id?.toString() ?? '');
  }

  static double _parseUsdRate(Map<String, dynamic> res) {
    final list = res['currencies'] ?? res['data'] ?? res;
    if (list is! List) return 1;
    for (final e in list) {
      if (e is! Map) continue;
      final m = Map<String, dynamic>.from(e);
      final code = (m['code'] ?? m['currency_code'] ?? '').toString().toUpperCase();
      if (code == 'USD') {
        final rate = m['exchange_rate'] ?? m['rate'];
        if (rate is num && rate > 0) return rate.toDouble();
        final parsed = double.tryParse(rate?.toString() ?? '');
        if (parsed != null && parsed > 0) return parsed;
      }
    }
    return 1;
  }
}
