import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image/image.dart' as img;
import '../core/app_notify.dart';
import '../core/constants.dart';
import '../core/theme.dart';
import '../core/input_formatters.dart';
import '../core/seller_preferences.dart';
import '../models/cart_item.dart';
import '../models/product.dart';
import '../providers/products_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/clients_provider.dart';
import '../providers/sales_session_provider.dart';
import '../utils/platform_layout.dart';
import '../utils/sale_store_due_amount.dart';
import '../services/api_service.dart';
import '../core/api_client.dart';
import '../core/api_sync_throttle.dart';
import '../widgets/receipt_widget.dart';
import '../widgets/ios_style_modals.dart';
import 'mijoz_screen.dart';
import 'chergirma_screen.dart';
import '../models/chergirma_result.dart';
import '../utils/cart_payment_discount.dart';
import 'yangi_mijoz_screen.dart';
import 'tavsif_screen.dart';
import 'desktop/desktop_payment_screen.dart';
import '../models/receipt_design_config.dart';
import '../services/receipt_design_storage.dart';
import '../services/thermal_receipt_printer.dart';
import '../services/printer_settings.dart';
import '../utils/sales_payment_types.dart';
import '../utils/hold_cart_action.dart';
import '../utils/sale_store_response.dart';
import '../utils/sale_store_validation.dart';
import '../utils/customer_group_discount.dart';
import '../utils/cart_discount_percent.dart';
import '../widgets/mixed_payment_inline_card.dart';

class TranzaksiyaDetailScreen extends StatefulWidget {
  final List<CartItem> items;
  final int? initialDiscountPercent;
  final Client? initialClient;
  /// Pauzadan davom ettirilganda mavjud buyurtma.
  final int? initialOrderId;
  final String? initialInvoiceId;
  final bool useDesktopFullscreenLayout;
  /// Mobil savatchadan: mijoz tanlanganda savat narxlarini yangilash.
  final Future<void> Function(Client? client)? onCustomerChanged;

  const TranzaksiyaDetailScreen({
    super.key,
    required this.items,
    this.initialDiscountPercent,
    this.initialClient,
    this.initialOrderId,
    this.initialInvoiceId,
    this.useDesktopFullscreenLayout = false,
    this.onCustomerChanged,
  });

  @override
  State<TranzaksiyaDetailScreen> createState() => _TranzaksiyaDetailScreenState();
}

class _TranzaksiyaDetailScreenState extends State<TranzaksiyaDetailScreen> {
  bool _tabDetails = true;
  Client? _client;
  int? _discountPercent;
  int? _discountUzs;
  String _description = '';
  bool _mixedPayment = false;
  final Map<String, int> _paymentAmounts = {};
  /// API dan yuklangan to'lov turlari: [{id, name}]
  List<Map<String, dynamic>> _apiPaymentTypes = [];
  bool _paymentTypesLoading = true;
  bool _submittingPay = false;
  bool _desktopPaymentComplete = false;
  bool _printingReceipt = false;
  bool _printingPrecheck = false;
  bool _holdingCart = false;
  String? _completedReceiptId;
  int? _completedOrderId;
  String _completedSellerName = '';
  String? _completedClientName;
  String _sellerDisplayName = '';
  ReceiptDesignConfig _receiptDesign = ReceiptDesignConfig.defaults;
  String? _desktopSelectedPaymentKey;
  final _desktopPayAmountController = TextEditingController();
  /// Faqat chek oldindan ko'rinishi uchun (sotuv yopilguncha). Yopilgandan keyin chek ID har doim API dan (storeRes).
  String get _txId => '${DateTime.now().millisecondsSinceEpoch % 1000000000}';

  /// POST /sales/store javobidan chek ID.
  static String? _extractChekIdFromStoreResponse(Map<String, dynamic>? res) =>
      SaleStoreResponse.extractReceiptId(res);

  /// Agar store faqat id (raqam) qaytarsa, reports/sales dan shu id bo'yicha invoice_id ni olib modalda ro'yxat bilan bir xil ko'rsatamiz
  static Future<String?> _resolveInvoiceIdFromReports(String? rawId) async {
    if (rawId == null || rawId.isEmpty) return null;
    final trimmed = rawId.trim();
    final orderIdNum = int.tryParse(trimmed);
    if (orderIdNum == null) return trimmed;
    if (trimmed.toLowerCase().startsWith('pos')) return trimmed;
    try {
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final res = await ReportsApi.getSales(
        body: ReportsApi.salesListBody(
          from: today,
          to: today,
          rowLimit: 12,
          rowOffset: 0,
          columnKey: 'id',
          columnSortedBy: 'DESC',
        ),
      );
      final rows = res['datarows'] as List<dynamic>? ?? res['data'] as List<dynamic>? ?? [];
      for (final r in rows) {
        if (r is! Map) continue;
        final m = Map<String, dynamic>.from(r as Map);
        final id = m['id'] ?? m['order_id'];
        final idNum = id is int ? id : int.tryParse(id?.toString() ?? '');
        if (idNum == orderIdNum) {
          final invId = m['invoice_id'] ?? m['invoiceId'];
          if (invId != null) {
            final s = invId.toString().trim();
            if (s.isNotEmpty && !s.toLowerCase().contains('umumiy')) return s;
          }
          break;
        }
      }
    } catch (_) {}
    return trimmed;
  }

  int get _totalRaw => widget.items.fold<int>(0, (s, e) => s + e.total);

  int get _totalAfterDiscount {
    var t = _totalRaw;
    if (_discountPercent != null && _discountPercent! > 0) {
      t = t - (t * _discountPercent! ~/ 100);
    }
    if (_discountUzs != null && _discountUzs! > 0) {
      t = t - _discountUzs!;
    }
    return t.clamp(0, 0x7FFFFFFF);
  }

  int get _paidTotal =>
      _paymentAmounts.values.fold<int>(0, (s, e) => s + e);

  int get _remainingToPay => (_totalAfterDiscount - _paidTotal).clamp(0, 0x7FFFFFFF);
  int get _change => (_paidTotal - _totalAfterDiscount).clamp(0, 0x7FFFFFFF);
  int get _clientBalanceUzs {
    if (_client == null) return 0;
    final b = (_client!.balance ?? 0).toDouble();
    if (b <= 0) return 0;
    return b.round();
  }

  static String _paymentNameLower(Map<String, dynamic> e) =>
      (e['name'] ?? e['title'] ?? e['payment_method'] ?? '').toString().toLowerCase();

  static String _paymentTypeLower(Map<String, dynamic> e) =>
      (e['type'] ?? e['payment_type'] ?? '').toString().toLowerCase();

  /// To'lov paytida taminotchi balansi hech qachon ko'rinmaydi.
  static bool _isSupplierBalancePayment(Map<String, dynamic> e) {
    final name = _paymentNameLower(e);
    final type = _paymentTypeLower(e);
    return type == 'supplier_balance' ||
        name.contains('taminotchi') ||
        name.contains('ta\'minotchi') ||
        (name.contains('supplier') && name.contains('balans'));
  }

  static bool _isQarzPayment(Map<String, dynamic> e) {
    if (_isSupplierBalancePayment(e)) return false;
    final name = _paymentNameLower(e);
    final type = _paymentTypeLower(e);
    return name.contains('qarz') || type == 'credit' || type == 'debt' || type == 'qarz';
  }

  static bool _isClientBalancePaymentType(Map<String, dynamic> e) {
    if (_isSupplierBalancePayment(e) || _isQarzPayment(e)) return false;
    final name = _paymentNameLower(e);
    final type = _paymentTypeLower(e);
    if (type == 'customer_balance') return true;
    if (name.contains('mijoz') && (name.contains('balans') || name.contains('balance'))) return true;
    return type == 'balance' && name.contains('mijoz');
  }

  static bool _isCustomerRelatedPayment(Map<String, dynamic> e) =>
      _isQarzPayment(e) || _isClientBalancePaymentType(e);

  bool _shouldShowPaymentType(Map<String, dynamic> e) {
    if (_isSupplierBalancePayment(e)) return false;
    if (_isQarzPayment(e)) return _client != null;
    if (_isClientBalancePaymentType(e)) return _client != null && _clientBalanceUzs > 0;
    return true;
  }

  bool _isClientBalancePaymentById(String paymentId) {
    for (final e in _apiPaymentTypes) {
      final id = (e['id'] is int ? e['id'] as int : int.tryParse(e['id']?.toString() ?? '0') ?? 0).toString();
      if (id == paymentId) return _isClientBalancePaymentType(e);
    }
    return false;
  }

  void _pruneHiddenPaymentAmounts() {
    final allowed = _paymentList.map((e) => e.key).toSet();
    _paymentAmounts.removeWhere((k, _) => !allowed.contains(k));
    if (_desktopSelectedPaymentKey != null && !allowed.contains(_desktopSelectedPaymentKey)) {
      _desktopSelectedPaymentKey = null;
    }
  }

  /// To'lov turlari — API dan; mijoz/qarz/balans qoidalari bilan filtrlangan.
  List<MapEntry<String, String>> get _paymentList {
    return _apiPaymentTypes
        .where(_shouldShowPaymentType)
        .map((e) {
          final id = (e['id'] is int ? e['id'] as int : int.tryParse(e['id']?.toString() ?? '0') ?? 0).toString();
          final name = (e['name'] ?? e['title'] ?? e['payment_method'] ?? id).toString();
          return MapEntry(id, name);
        })
        .toList();
  }

  /// Desktop tugmalar: mijoz balansi bo'lsa "Mijoz balansi (200 000)".
  List<MapEntry<String, String>> get _paymentListDisplay {
    return _paymentList.map((e) {
      if (_isClientBalancePaymentById(e.key) && _clientBalanceUzs > 0) {
        final base = e.value.trim();
        if (base.contains('(')) return e;
        return MapEntry(e.key, '$base (${_fmt(_clientBalanceUzs)})');
      }
      return e;
    }).toList();
  }

  void _closeDesktopPayment() {
    if (_submittingPay || !mounted) return;
    final nav = Navigator.of(context);
    if (nav.canPop()) nav.pop();
  }

  void _finishDesktopPaymentFlow() {
    final rid = _completedReceiptId;
    if (rid == null || !mounted) return;
    final label = rid.startsWith('POS') ? rid : 'POS$rid';
    Navigator.of(context).pop(label);
  }

  Future<void> _pauseAndHoldCart() async {
    if (widget.useDesktopFullscreenLayout || _holdingCart) return;
    setState(() => _holdingCart = true);
    final ok = await HoldCartAction.savePausedCart(
      context: context,
      cartItems: widget.items,
      subTotal: _totalRaw,
      grandTotal: _totalAfterDiscount,
      customerId: _client != null ? int.tryParse(_client!.id) : null,
      orderId: widget.initialOrderId,
      invoiceId: widget.initialInvoiceId,
      discountPercent: widget.useDesktopFullscreenLayout
          ? (_discountPercent ?? 0)
          : SalesSessionProvider.instance.cartDiscountPercent,
    );
    if (!mounted) return;
    setState(() => _holdingCart = false);
    if (ok) Navigator.pop(context, 'held');
  }

  Future<void> _printPrecheckReceipt() async {
    if (_printingPrecheck || _printingReceipt || widget.items.isEmpty) return;
    setState(() => _printingPrecheck = true);
    try {
      final sellerPhone = await getSellerPhone();
      final receiptWidget = _buildPrecheckReceiptWidget(
        DateTime.now(),
        sellerPhone: sellerPhone,
      );
      final directOnly = await PrinterSettings.isPrinterReady();
      final result = await ThermalReceiptPrinter.printLocalReceipt(
        receiptWidget.toThermalPrintLines(),
        directOnly: directOnly,
      );
      if (!mounted) return;
      if (result.ok) {
        AppNotify.success(context, result.message);
      } else {
        AppNotify.warning(context, result.message);
      }
    } catch (e) {
      if (mounted) AppNotify.error(context, 'Chop etish xatosi: $e');
    } finally {
      if (mounted) setState(() => _printingPrecheck = false);
    }
  }

  Future<void> _printThermalReceipt({bool silent = false}) async {
    final rid = _completedReceiptId;
    if (rid == null || _printingReceipt) return;
    setState(() => _printingReceipt = true);
    try {
      final sellerPhone = await getSellerPhone();
      final receiptWidget = _buildReceiptWidget(
        DateTime.now(),
        sellerName: _completedSellerName.isNotEmpty ? _completedSellerName : _sellerDisplayName,
        sellerPhone: sellerPhone,
        clientName: _completedClientName ?? _client?.name,
        receiptId: rid,
      );
      final localLines = receiptWidget.toThermalPrintLines();
      final directOnly = await PrinterSettings.isPrinterReady();
      final result = await ThermalReceiptPrinter.printLocalReceipt(
        localLines,
        directOnly: directOnly,
      );
      if (!mounted) return;
      if (result.ok) {
        if (!silent) AppNotify.success(context, result.message);
      } else {
        AppNotify.warning(context, result.message);
      }
    } catch (e) {
      if (mounted) AppNotify.error(context, 'Chop etish xatosi: $e');
    } finally {
      if (mounted) setState(() => _printingReceipt = false);
    }
  }

  void _applyPaymentTypes(List<Map<String, dynamic>> list) {
    if (!mounted) return;
    setState(() {
      _apiPaymentTypes = list;
      _paymentTypesLoading = false;
    });
    _syncDesktopPaymentSelection();
  }

  Future<void> _loadPaymentTypes() async {
    final cached = normalizeSalesPaymentTypes(SalesSessionProvider.instance.paymentTypes);
    if (cached.isNotEmpty) {
      _applyPaymentTypes(cached);
      unawaited(_refreshPaymentTypesFromApi());
      return;
    }

    if (mounted) setState(() => _paymentTypesLoading = true);
    await _refreshPaymentTypesFromApi();
  }

  Future<void> _refreshPaymentTypesFromApi() async {
    try {
      final res = await SalesApi.getPaymentTypes();
      final list = parseSalesPaymentTypesResponse(res);
      if (list.isNotEmpty) {
        SalesSessionProvider.instance.paymentTypes =
            list.map((e) => Map<String, dynamic>.from(e)).toList();
      }
      if (!mounted) return;
      if (list.isNotEmpty) {
        _applyPaymentTypes(list);
      } else {
        setState(() => _paymentTypesLoading = false);
      }
    } catch (_) {
      if (mounted && _apiPaymentTypes.isEmpty) {
        setState(() {
          _apiPaymentTypes = [];
          _paymentTypesLoading = false;
        });
      } else if (mounted) {
        setState(() => _paymentTypesLoading = false);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    // Savatdagi foiz allaqachon qator chegirmali narxida; qayta qo'llanmaydi.
    _client = widget.initialClient;
    _loadPaymentTypes();
    _loadSellerDisplayName();
    unawaited(_loadReceiptDesign());
  }

  Future<void> _loadReceiptDesign() async {
    final d = await ReceiptDesignStorage.load();
    if (mounted) setState(() => _receiptDesign = d);
  }

  @override
  void dispose() {
    _desktopPayAmountController.dispose();
    super.dispose();
  }

  void _syncDesktopPaymentSelection() {
    if (!widget.useDesktopFullscreenLayout || _paymentList.isEmpty || _mixedPayment) return;
    _pruneHiddenPaymentAmounts();
    if (_desktopSelectedPaymentKey == null) {
      for (final e in _paymentList) {
        final n = e.value.toLowerCase();
        if (n.contains('naqd') || n.contains('cash')) {
          _desktopSelectedPaymentKey = e.key;
          break;
        }
      }
      _desktopSelectedPaymentKey ??= _paymentList.first.key;
    }
    final key = _desktopSelectedPaymentKey!;
    if ((_paymentAmounts[key] ?? 0) == 0) {
      _paymentAmounts[key] = _totalAfterDiscount;
    }
    final text = _fmt(_paymentAmounts[key] ?? _totalAfterDiscount);
    if (_desktopPayAmountController.text != text) {
      _desktopPayAmountController.text = text;
    }
  }

  void _selectDesktopPayment(String key) {
    setState(() {
      _desktopSelectedPaymentKey = key;
      _paymentAmounts
        ..clear()
        ..[key] = _totalAfterDiscount;
      _desktopPayAmountController.text = _fmt(_totalAfterDiscount);
    });
  }

  void _onDesktopAmountChanged(String raw) {
    final key = _desktopSelectedPaymentKey;
    if (key == null) return;
    _applyPaymentAmountInput(key, raw);
  }

  void _onMixedPaymentAmountChanged(String key, String raw) {
    _applyPaymentAmountInput(key, raw);
  }

  void _applyPaymentAmountInput(String key, String raw) {
    final digits = raw.replaceAll(RegExp(r'[^\d]'), '');
    var amount = int.tryParse(digits) ?? 0;
    if (_isClientBalancePaymentById(key) && amount > _clientBalanceUzs) {
      amount = _clientBalanceUzs;
    }
    setState(() {
      if (amount > 0) {
        _paymentAmounts[key] = amount;
      } else {
        _paymentAmounts.remove(key);
      }
    });
  }

  int _desktopDebtAmount() {
    final allocated = _getAllocatedPaymentAmounts();
    return _getQarzAmountFromAllocated(allocated);
  }

  Future<void> _loadSellerDisplayName() async {
    final name = await getSellerName();
    if (mounted) setState(() => _sellerDisplayName = name);
    unawaited(syncSellerNameFromApi().then((_) async {
      if (!mounted) return;
      final fresh = await getSellerName();
      if (mounted) setState(() => _sellerDisplayName = fresh);
    }));
  }

  /// Mijoz olib tashlanganda qarz / mijoz balansi to'lov summalarini tozalash
  void _clearCustomerRelatedPayments() {
    for (final e in _apiPaymentTypes) {
      if (_isCustomerRelatedPayment(e)) {
        final id = (e['id'] is int ? e['id'] as int : int.tryParse(e['id']?.toString() ?? '0') ?? 0).toString();
        _paymentAmounts.remove(id);
      }
    }
  }

  /// Chekda ko'rsatiladigan summalar: faqat yetishmayotgan summa (ortiqcha qaytim bo'lmaydi)
  Map<String, int> _getAllocatedPaymentAmounts() {
    final out = <String, int>{};
    int remaining = _totalAfterDiscount;
    for (final e in _paymentList) {
      final key = e.key;
      final entered = _paymentAmounts[key] ?? 0;
      if (entered <= 0 || remaining <= 0) continue;
      final take = entered > remaining ? remaining : entered;
      out[key] = take;
      remaining -= take;
    }
    return out;
  }

  static String _fmt(int n) => formatThousands(n);

  @override
  Widget build(BuildContext context) {
    if (widget.useDesktopFullscreenLayout) {
      final sess = SalesSessionProvider.instance;
      final store = sess.branchName.isNotEmpty ? sess.branchName : 'Alfa market';

      final allocated = _getAllocatedPaymentAmounts();
      final allocatedPayments = _paymentList
          .where((e) => (allocated[e.key] ?? 0) > 0)
          .map((e) => MapEntry(e.value, allocated[e.key]!))
          .toList();
      return PopScope(
        canPop: !_submittingPay && !_printingReceipt && !_printingPrecheck,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop || _submittingPay || _printingReceipt || _printingPrecheck) return;
          if (_desktopPaymentComplete) {
            _finishDesktopPaymentFlow();
          } else {
            _closeDesktopPayment();
          }
        },
        child: DesktopPaymentLayout(
          items: widget.items,
          client: _client,
          totalRaw: _totalRaw,
          totalAfterDiscount: _totalAfterDiscount,
          sellerName: _sellerDisplayName.isNotEmpty ? _sellerDisplayName : 'Sotuvchi',
          storeName: store,
          description: _description,
          onDescriptionChanged: (v) => setState(() => _description = v),
          paymentTypesLoading: _paymentTypesLoading,
          paymentList: _paymentListDisplay,
          paymentAmounts: Map<String, int>.from(_paymentAmounts),
          mixedPayment: _mixedPayment,
          onMixedPaymentChanged: (v) {
            setState(() {
              _mixedPayment = v;
              _paymentAmounts.clear();
            });
            if (!v) _syncDesktopPaymentSelection();
          },
          selectedPaymentKey: _desktopSelectedPaymentKey,
          onPaymentKeySelected: _selectDesktopPayment,
          onPaymentMethodTap: (key, title) => _showPaymentMethodDialog(title, key),
          onMixedPaymentAmountChanged: _onMixedPaymentAmountChanged,
          onClearPayment: (key) => setState(() => _paymentAmounts.remove(key)),
          amountController: _desktopPayAmountController,
          onAmountChanged: _onDesktopAmountChanged,
          remainingToPay: _remainingToPay,
          changeAmount: _change,
          clientBalanceUzs: _clientBalanceUzs,
          canComplete: _remainingToPay == 0 && _paymentList.isNotEmpty,
          submitting: _submittingPay,
          paymentComplete: _desktopPaymentComplete,
          printing: _printingReceipt,
          printingPrecheck: _printingPrecheck,
          onComplete: _doPay,
          onClose: () {
            if (_desktopPaymentComplete) {
              _finishDesktopPaymentFlow();
            } else {
              _closeDesktopPayment();
            }
          },
          onPrint: _printThermalReceipt,
          onPrintPrecheck: _printPrecheckReceipt,
          debtAmount: _desktopDebtAmount(),
          allocatedPayments: allocatedPayments,
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Yangi chek'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: _tabChip(Strings.tafsilotlar, _tabDetails),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _tabChip(Strings.tolov, !_tabDetails),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _tabDetails ? _buildDetails() : _buildPayment(),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.divider),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 12,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!_tabDetails) ...[
                        Text(
                          _remainingToPay == 0
                              ? "To'lash uchun: 0 UZS"
                              : "To'lash uchun: ${_fmt(_remainingToPay)} UZS",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: _remainingToPay == 0 ? Colors.green : Colors.red,
                          ),
                        ),
                        if (_change > 0) ...[
                          const SizedBox(height: 6),
                          Text(
                            "Qaytim: ${_fmt(_change)} UZS",
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.green,
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                      ],
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _holdingCart || widget.items.isEmpty || _submittingPay
                                  ? null
                                  : _pauseAndHoldCart,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: AppTheme.primary,
                                disabledBackgroundColor: const Color(0xFFF0F2F5),
                                disabledForegroundColor: AppTheme.textSecondary,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: const BorderSide(color: AppTheme.primary, width: 1.5),
                                ),
                              ),
                              icon: _holdingCart
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                                    )
                                  : const Icon(Icons.pause_circle_outline_rounded, size: 22),
                              label: Text(_holdingCart ? 'Saqlanmoqda...' : Strings.toxtatish),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _submittingPay
                                  ? null
                                  : (_tabDetails
                                      ? () => setState(() => _tabDetails = false)
                                      : (_remainingToPay == 0 ? () => _doPay() : null)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: _submittingPay && !_tabDetails
                                  ? const SizedBox(
                                      height: 22,
                                      width: 22,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : Text(_tabDetails ? "To'lovga o'tish" : "To'lash"),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabChip(String label, bool selected) {
    return Material(
      color: selected ? AppTheme.primaryLight : AppTheme.cardBg,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: () => setState(() => _tabDetails = label == Strings.tafsilotlar),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: selected ? AppTheme.primary : AppTheme.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  int get _cartDiscountPercentDisplay =>
      SalesSessionProvider.instance.cartDiscountPercent;

  String? get _mobileChergirmaSubtitle {
    final pct = _cartDiscountPercentDisplay;
    if (pct != 0) return '$pct%';
    final catalog = CartDiscountPercent.catalogLinesTotal(widget.items);
    final discount = catalog - _totalRaw;
    if (discount > 0) return '${_fmt(discount)} so\'m';
    return null;
  }

  Future<void> _applyCartDiscountPercent(int percent) {
    final sales = SalesSessionProvider.instance;
    final old = sales.cartDiscountPercent;
    sales.setCartDiscountPercent(percent);
    for (final item in widget.items) {
      var base = item.unitPriceBaseForCartPercent;
      if (base == null) {
        final line = item.unitPriceForLine;
        base = old != 0 ? line / ((100 + old) / 100) : line;
        item.unitPriceBaseForCartPercent = base;
      }
      CartDiscountPercent.applyToItem(item, percent);
    }
    if (mounted) {
      setState(() {});
      if (!_mixedPayment && _paymentAmounts.length == 1) {
        final key = _paymentAmounts.keys.first;
        _paymentAmounts[key] = _totalAfterDiscount;
      }
    }
    return Future.value();
  }

  Future<void> _openChergirmaScreen() async {
    final r = await Navigator.push<ChergirmaResult>(
      context,
      MaterialPageRoute(
        builder: (_) => ChergirmaScreen(
          totalUzs: _totalRaw,
          distributeToCartLines: !widget.useDesktopFullscreenLayout,
        ),
      ),
    );
    if (r != null && mounted) {
      await _applyChergirmaResult(r);
    }
  }

  Future<void> _applyChergirmaResult(ChergirmaResult r) async {
    if (widget.useDesktopFullscreenLayout) {
      final map = r.legacyMap;
      setState(() {
        _discountPercent = map['percent'];
        _discountUzs = map['uzs'];
        if (!_mixedPayment && _paymentAmounts.length == 1) {
          final key = _paymentAmounts.keys.first;
          _paymentAmounts[key] = _totalAfterDiscount;
        }
      });
      return;
    }

    switch (r.mode) {
      case ChergirmaMode.clear:
        SalesSessionProvider.instance.setCartDiscountPercent(0);
        for (final item in widget.items) {
          CartDiscountPercent.applyToItem(item, 0);
        }
        setState(() {
          _discountPercent = null;
          _discountUzs = null;
        });
        break;
      case ChergirmaMode.percent:
        setState(() {
          _discountPercent = null;
          _discountUzs = null;
        });
        await _applyCartDiscountPercent(r.value);
        break;
      case ChergirmaMode.discountUzs:
        final cartTotal = widget.items.fold<int>(0, (s, e) => s + e.total);
        _applyPaymentDiscountToCart(cartTotal - r.value);
        break;
      case ChergirmaMode.customerPays:
        _applyPaymentDiscountToCart(r.value);
        break;
    }
  }

  void _applyPaymentDiscountToCart(int amountPaidUzs) {
    SalesSessionProvider.instance.setCartDiscountPercent(0);
    CartPaymentDiscount.applyCustomerPayment(widget.items, amountPaidUzs);
    for (final item in widget.items) {
      CartProvider.instance.updateSalePriceOverride(item, item.salePriceOverride);
    }
    setState(() {
      _discountPercent = null;
      _discountUzs = null;
      if (!_mixedPayment && _paymentAmounts.length == 1) {
        final key = _paymentAmounts.keys.first;
        _paymentAmounts[key] = _totalAfterDiscount;
      }
    });
  }

  Future<void> _applyPaymentCustomer(Client client) async {
    Client? effective = client;
    final idNum = int.tryParse(client.id);
    if (idNum != null) {
      try {
        final res = await ContactsApi.getCustomer(idNum);
        final raw = res['customer'] ?? res['data'] ?? res;
        if (raw is Map) {
          effective = Client.fromApiJson(Map<String, dynamic>.from(raw));
        }
      } catch (_) {}
    }
    if (!mounted) return;
    final groups = await ClientsProvider.instance.fetchCustomerGroups();
    if (!mounted) return;
    CustomerGroupDiscount.applyCustomerPricingToCart(
      widget.items,
      effective,
      groups: groups,
    );
    CartDiscountPercent.afterCustomerPricing(
      widget.items,
      SalesSessionProvider.instance.cartDiscountPercent,
    );
    setState(() {
      _client = effective;
      _pruneHiddenPaymentAmounts();
    });
    await widget.onCustomerChanged?.call(effective);
    _syncDesktopPaymentSelection();
    if (!_mixedPayment && _paymentAmounts.length == 1) {
      final key = _paymentAmounts.keys.first;
      _paymentAmounts[key] = _totalAfterDiscount;
    }
  }

  Widget _buildDetails() {
    return Column(
      children: [
        _DetailRow(
          icon: Icons.person_rounded,
          title: Strings.mijoz,
          subtitle: _client?.name,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_client != null)
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20, color: Colors.red),
                  onPressed: () async {
                    CustomerGroupDiscount.applyCustomerPricingToCart(widget.items, null);
                    CartDiscountPercent.afterCustomerPricing(
                      widget.items,
                      SalesSessionProvider.instance.cartDiscountPercent,
                    );
                    setState(() {
                      _client = null;
                      _clearCustomerRelatedPayments();
                      _pruneHiddenPaymentAmounts();
                    });
                    await widget.onCustomerChanged?.call(null);
                    _syncDesktopPaymentSelection();
                  },
                  tooltip: "Mijozni olib tashlash",
                ),
              TextButton(
                onPressed: () async {
                  final c = await Navigator.push<Client>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MijozScreen(
                        forSalesPayment: !widget.useDesktopFullscreenLayout,
                      ),
                    ),
                  );
                  if (c != null && mounted) await _applyPaymentCustomer(c);
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _client == null ? Strings.qoShish : 'O\'zgartirish',
                      style: const TextStyle(color: AppTheme.primary),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppTheme.primary),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _DetailRow(
          icon: Icons.point_of_sale_rounded,
          title: Strings.sotuvchi,
          subtitle: _sellerDisplayName.isEmpty ? null : _sellerDisplayName,
          trailing: const SizedBox.shrink(),
        ),
        const SizedBox(height: 12),
        _DetailRow(
          icon: Icons.percent_rounded,
          title: Strings.chergirma,
          subtitle: widget.useDesktopFullscreenLayout
              ? (_discountPercent != null
                  ? '$_discountPercent%'
                  : _discountUzs != null
                      ? '${_fmt(_discountUzs!)} UZS'
                      : null)
              : _mobileChergirmaSubtitle,
          trailing: TextButton(
            onPressed: _openChergirmaScreen,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(Strings.qoShish, style: TextStyle(color: AppTheme.primary)),
                Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppTheme.primary),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _DetailRow(
          icon: Icons.description_rounded,
          title: Strings.tavsif,
          subtitle: _description.isEmpty ? null : _description,
          trailing: TextButton(
            onPressed: () async {
              final d = await Navigator.push<String>(
                context,
                MaterialPageRoute(
                  builder: (_) => TavsifScreen(initial: _description.isEmpty ? null : _description),
                ),
              );
              if (d != null && mounted) setState(() => _description = d);
            },
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(Strings.qoShish, style: TextStyle(color: AppTheme.primary)),
                Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppTheme.primary),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildPayment() {
    if (_paymentTypesLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(color: AppTheme.primary),
        ),
      );
    }
    if (_apiPaymentTypes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "To'lov turlari API dan yuklanmadi",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: _loadPaymentTypes,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Qayta urinish'),
              ),
            ],
          ),
        ),
      );
    }
    const iosGreen = Color(0xFF34C759);
    return Column(
      children: [
        const SizedBox(height: 12),
        Text(
          _fmt(_totalAfterDiscount),
          style: const TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.8,
            color: Color(0xFF000000),
            height: 1.05,
          ),
        ),
        Text(
          'UZS',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.2,
            color: Colors.black.withValues(alpha: 0.45),
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF2F2F7),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Aralash to'lov",
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF000000),
                ),
              ),
              CupertinoSwitch(
                value: _mixedPayment,
                activeTrackColor: iosGreen,
                onChanged: (v) {
                  setState(() {
                    _mixedPayment = v;
                    _paymentAmounts.clear();
                  });
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.12,
          children: _paymentList.map((e) {
            final key = e.key;
            final amount = _paymentAmounts[key] ?? 0;
            final selected = amount > 0;
            final isBalancePayment = _isClientBalancePaymentById(key);
            if (_mixedPayment) {
              return MixedPaymentInlineCard(
                title: e.value,
                icon: iconForPaymentName(e.value),
                amount: amount,
                balanceUzs: (isBalancePayment && _client != null) ? _clientBalanceUzs : null,
                onAmountChanged: (raw) => _onMixedPaymentAmountChanged(key, raw),
              );
            }
            return _PaymentMethodCard(
              title: e.value,
              icon: iconForPaymentName(e.value),
              selected: selected,
              amount: amount,
              balanceAmountUzs: (isBalancePayment && _client != null) ? _clientBalanceUzs : null,
              onTap: () {
                final cap = isBalancePayment ? _clientBalanceUzs : _totalAfterDiscount;
                final chosen = _totalAfterDiscount > cap ? cap : _totalAfterDiscount;
                setState(() {
                  _paymentAmounts
                    ..clear()
                    ..[key] = chosen;
                });
                if (isBalancePayment && _totalAfterDiscount > cap && mounted) {
                  AppNotify.warning(
                    context,
                    "Mijoz balansidan ko'p to'lab bo'lmaydi. Maksimum: ${_fmt(cap)} UZS",
                  );
                }
              },
              onRemove: null,
            );
          }          ).toList(),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  void _showPaymentMethodDialog(String title, String key) {
    if (widget.useDesktopFullscreenLayout) {
      _showDesktopPaymentAmountDialog(title, key);
      return;
    }
    final isBalancePayment = _isClientBalancePaymentById(key);
    final toPay = _mixedPayment ? _remainingToPay : _totalAfterDiscount;
    final maxAllowed = isBalancePayment ? (_clientBalanceUzs < toPay ? _clientBalanceUzs : toPay) : null;
    final controller = TextEditingController();
    if (!_mixedPayment && _paymentAmounts.containsKey(key) && (_paymentAmounts[key] ?? 0) > 0) {
      controller.text = _fmt(_paymentAmounts[key]!);
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final bottomInset = MediaQuery.viewInsetsOf(ctx).bottom;
        final screenH = MediaQuery.sizeOf(ctx).height;
        final maxSheetH = (screenH - bottomInset - 12).clamp(280.0, screenH * 0.92);
        return Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: StatefulBuilder(
              builder: (ctx, setDialogState) {
                final basisRaw = toPay == 0 ? _totalAfterDiscount : toPay;
                final basis = maxAllowed != null && maxAllowed < basisRaw ? maxAllowed : basisRaw;
                return Material(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  clipBehavior: Clip.antiAlias,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: maxSheetH),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Flexible(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                          Center(
                            child: Container(
                              width: 40,
                              height: 5,
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFD1D5DB),
                                borderRadius: BorderRadius.circular(100),
                              ),
                            ),
                          ),
                          Text(
                            title,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "To'lash uchun: ${_fmt(toPay)} UZS",
                            style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                          ),
                          if (isBalancePayment && _client != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text.rich(
                                TextSpan(
                                  style: const TextStyle(fontSize: 13, height: 1.25),
                                  children: [
                                    TextSpan(
                                      text: 'Mijoz balansi: ',
                                      style: TextStyle(color: Colors.black.withValues(alpha: 0.45)),
                                    ),
                                    TextSpan(
                                      text: '${_fmt(_clientBalanceUzs)} UZS',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF34C759),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          if (maxAllowed != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                "Kiritish mumkin maksimum: ${_fmt(maxAllowed)} UZS",
                                style: const TextStyle(fontSize: 12, color: Colors.redAccent),
                              ),
                            ),
                          if (_mixedPayment)
                            const Padding(
                              padding: EdgeInsets.only(top: 4),
                              child: Text(
                                "Ko'proq kiritsangiz — qaytim hisoblanadi.",
                                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                              ),
                            ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: controller,
                            keyboardType: TextInputType.number,
                            inputFormatters: [ThousandsInputFormatter()],
                            scrollPadding: const EdgeInsets.only(bottom: 120),
                            onChanged: (_) => setDialogState(() {}),
                            decoration: InputDecoration(
                              labelText: "Summa",
                              suffixText: 'UZS',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: AppTheme.primary, width: 2),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _presetChip(
                                '${_fmt((basis * 0.25).round())} UZS',
                                () {
                                  controller.text = _fmt((basis * 0.25).round());
                                  setDialogState(() {});
                                },
                              ),
                              _presetChip(
                                '${_fmt((basis * 0.5).round())} UZS',
                                () {
                                  controller.text = _fmt((basis * 0.5).round());
                                  setDialogState(() {});
                                },
                              ),
                              _presetChip(
                                '${_fmt(basis)} UZS',
                                () {
                                  controller.text = _fmt(basis);
                                  setDialogState(() {});
                                },
                              ),
                            ],
                          ),
                              ],
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                          child: IosStyleModals.sheetPillCancelSaveRow(
                            cancelLabel: Strings.qaytish,
                            saveLabel: Strings.qoShish,
                            onCancel: () => Navigator.pop(ctx),
                            onSave: () {
                              final v = parseFormattedSum(controller.text);
                              if (v != null && v >= 0) {
                                if (maxAllowed != null && v > maxAllowed) {
                                  AppNotify.warning(
                                    context,
                                    "Mijoz balansidan ko'p kiritib bo'lmaydi (max: ${_fmt(maxAllowed)} UZS)",
                                  );
                                  return;
                                }
                                setState(() {
                                  if (!_mixedPayment) _paymentAmounts.clear();
                                  _paymentAmounts[key] = v;
                                });
                                Navigator.pop(ctx);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _showDesktopPaymentAmountDialog(String title, String key) {
    if (!_mixedPayment) {
      _selectDesktopPayment(key);
      return;
    }
    final isBalancePayment = _isClientBalancePaymentById(key);
    final toPay = _mixedPayment ? _remainingToPay : _totalAfterDiscount;
    final maxAllowed = isBalancePayment ? (_clientBalanceUzs < toPay ? _clientBalanceUzs : toPay) : null;
    final controller = TextEditingController();
    if (_paymentAmounts.containsKey(key) && (_paymentAmounts[key] ?? 0) > 0) {
      controller.text = _fmt(_paymentAmounts[key]!);
    }
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final basisRaw = toPay == 0 ? _totalAfterDiscount : toPay;
            final basis = maxAllowed != null && maxAllowed < basisRaw ? maxAllowed : basisRaw;
            return AlertDialog(
              title: Text(title),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "To'lash uchun: ${_fmt(toPay)} UZS",
                      style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                    ),
                    if (isBalancePayment && _client != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Mijoz balansi: ${_fmt(_clientBalanceUzs)} UZS',
                          style: const TextStyle(fontSize: 13, color: Color(0xFF2E7D32)),
                        ),
                      ),
                    if (maxAllowed != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          "Maksimum: ${_fmt(maxAllowed)} UZS",
                          style: const TextStyle(fontSize: 12, color: Colors.redAccent),
                        ),
                      ),
                    if (_mixedPayment)
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text(
                          "Ko'proq kiritsangiz — qaytim hisoblanadi.",
                          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                      ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: controller,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      inputFormatters: [ThousandsInputFormatter()],
                      onChanged: (_) => setDialogState(() {}),
                      decoration: InputDecoration(
                        labelText: 'Summa',
                        suffixText: 'UZS',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _presetChip('25%', () {
                          controller.text = _fmt((basis * 0.25).round());
                          setDialogState(() {});
                        }),
                        _presetChip('50%', () {
                          controller.text = _fmt((basis * 0.5).round());
                          setDialogState(() {});
                        }),
                        _presetChip("To'liq", () {
                          controller.text = _fmt(basis);
                          setDialogState(() {});
                        }),
                      ],
                    ),
                  ],
                ),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  ),
                  child: const Text(Strings.qaytish, style: TextStyle(fontSize: 16)),
                ),
                FilledButton(
                  onPressed: () {
                    final v = parseFormattedSum(controller.text);
                    if (v != null && v >= 0) {
                      if (maxAllowed != null && v > maxAllowed) {
                        AppNotify.warning(
                          context,
                          "Mijoz balansidan ko'p kiritib bo'lmaydi (max: ${_fmt(maxAllowed)} UZS)",
                        );
                        return;
                      }
                      setState(() {
                        if (!_mixedPayment) _paymentAmounts.clear();
                        _paymentAmounts[key] = v;
                      });
                      Navigator.pop(ctx);
                    }
                  },
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(120, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  ),
                  child: const Text(Strings.qoShish, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ],
            );
          },
        );
      },
    ).then((_) => controller.dispose());
  }

  Widget _presetChip(String label, VoidCallback onTap) {
    return Material(
      color: AppTheme.cardBg,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.primary,
            ),
          ),
        ),
      ),
    );
  }

  String? _paymentTypeForApi(Map<String, dynamic> e) {
    if (_isQarzPayment(e)) return 'credit';
    if (_isClientBalancePaymentType(e)) return 'customer_balance';
    final name = _paymentNameLower(e);
    if (name.contains('naqd') || name.contains('cash') || name.contains('naqd pul')) {
      return 'cash';
    }
    final type = _paymentTypeLower(e);
    if (type == 'cash') return 'cash';
    return null;
  }

  /// API dagi to'lov turi bo'yicha qarz summasi (faqat «Qarz» to'lov qatori).
  int _getQarzAmountFromAllocated(Map<String, int> allocated) {
    var sum = 0;
    for (final e in _apiPaymentTypes) {
      if (!_isQarzPayment(e)) continue;
      final id = (e['id'] is int ? e['id'] as int : int.tryParse(e['id']?.toString() ?? '0') ?? 0).toString();
      sum += allocated[id] ?? 0;
    }
    return sum;
  }

  /// Mijoz balansidan to'langan summa.
  int _getClientBalanceAmountFromAllocated(Map<String, int> allocated) {
    var sum = 0;
    for (final e in _apiPaymentTypes) {
      if (!_isClientBalancePaymentType(e)) continue;
      final id = (e['id'] is int ? e['id'] as int : int.tryParse(e['id']?.toString() ?? '0') ?? 0).toString();
      sum += allocated[id] ?? 0;
    }
    return sum;
  }

  int _computeStoreDueAmount(Map<String, int> allocated) => computeStoreDueAmount(
        grandTotal: _totalAfterDiscount,
        paymentTypes: _apiPaymentTypes,
        allocated: allocated,
        isQarzPayment: _isQarzPayment,
      );

  List<Map<String, dynamic>> _buildPaymentsForStore(Map<String, int> allocated) {
    return allocated.entries.map((entry) {
      final id = int.tryParse(entry.key) ?? 1;
      final meta = _apiPaymentTypes.cast<Map<String, dynamic>?>().firstWhere(
        (e) {
          if (e == null) return false;
          final pid = (e['id'] is int ? e['id'] as int : int.tryParse(e['id']?.toString() ?? '0') ?? 0).toString();
          return pid == entry.key;
        },
        orElse: () => null,
      );
      final row = <String, dynamic>{
        'paymentID': id,
        'paid': entry.value,
      };
      final pt = meta != null ? _paymentTypeForApi(meta) : null;
      if (pt != null) row['paymentType'] = pt;
      return row;
    }).toList();
  }

  /// Sotuvdan keyin: katalog yangilash. Balans va qarz /sales/store + payments orqali serverda.
  Future<void> _postSaleSideEffects() async {
    ApiSyncThrottle.invalidate('transactions_sales_list');
    try {
      await ProductsProvider.instance.loadFromStorage(refreshInBackground: true);
    } catch (_) {}
  }

  Future<void> _doPay() async {
    final allocated = _getAllocatedPaymentAmounts();
    if (allocated.isEmpty) return;
    try {
      SaleStoreValidation.validateCart(widget.items);
      SaleStoreValidation.validateCashShift();
      await SaleStoreValidation.ensureBranchOnServer();
    } on ApiException catch (e) {
      if (mounted) AppNotify.error(context, e.message);
      return;
    }
    setState(() => _submittingPay = true);
    final qarzAmount = _computeStoreDueAmount(allocated);
    int totalCostUzs = 0;
    for (final item in widget.items) {
      final p = item.product;
      if (item.sellByPack && p.canSellByPack && p.costPricePerPack != null) {
        totalCostUzs += (p.costPricePerPack! * item.quantity).round();
      } else {
        totalCostUzs += ((p.costPriceUzs ?? 0) * item.quantity).round();
      }
    }
    final discountUzs = _totalRaw - _totalAfterDiscount;
    final paymentsApi = _buildPaymentsForStore(allocated);
    final cart = widget.items.map((item) {
      final p = item.product;
      final productId = int.tryParse(p.id) ?? 0;
      final isPack = item.sellByPack && p.canSellByPack;
      final linePricing = item.salesStoreLinePricing;
      final variantId = p.variantId ?? 1;
      return {
        'productID': productId,
        'variantID': variantId,
        'quantity': item.quantity,
        // Katalog narxi — backend mahsulot bazasidagi narxni shu maydondan yangilaydi
        'price': linePricing.catalogUnitPrice,
        'productTitle': p.name,
        'variantTitle': 'default_variant',
        'orderType': 'sales',
        'discount': linePricing.lineDiscount,
        'taxID': null,
        'calculatedPrice': linePricing.lineTotal,
        'cartItemNote': '',
        if (isPack) 'isPackage': true,
        if (isPack) 'unitsPerPackage': p.quantityPerPack,
      };
    }).toList();
    final body = {
      'orderType': 'sales',
      'salesOrReceivingType': 'customer',
      'status': 'done',
      'subTotal': _totalRaw,
      'tax': 0,
      'discount': discountUzs,
      'grandTotal': _totalAfterDiscount,
      'dueAmount': qarzAmount,
      'profit': _totalAfterDiscount - totalCostUzs,
      'cart': cart,
      'payments': paymentsApi,
      'customer': _client != null ? {'id': int.tryParse(_client!.id) ?? 0} : null,
    };
    final sess = SalesSessionProvider.instance;
    sess.syncFromShift();
    if (sess.cashRegisterId != null) {
      body['cashRagisterId'] = sess.cashRegisterId;
      body['isCashRegisterBranch'] = sess.isCashRegisterBranch;
    }
    if (sess.registerLogId != null) {
      body['register_log_id'] = sess.registerLogId;
    }
    if (sess.branchId != null) body['selectedBranchID'] = sess.branchId;
    if (widget.initialOrderId != null) body['orderID'] = widget.initialOrderId;
    if (widget.initialInvoiceId != null && widget.initialInvoiceId!.isNotEmpty) {
      body['invoice_id'] = widget.initialInvoiceId;
    }
    Map<String, dynamic>? storeRes;
    try {
      storeRes = await SalesApi.storeSale(body);
    } on ApiException catch (e) {
      if (mounted) {
        AppNotify.error(context, 'API xatosi: ${e.message}');
      }
      if (mounted) setState(() => _submittingPay = false);
      return;
    } catch (e) {
      if (mounted) {
        AppNotify.error(context, 'Sotuv yuborilmadi: $e');
      }
      if (mounted) setState(() => _submittingPay = false);
      return;
    }
    // Chek ID — darhol ko'rsatamiz; POS formatini reports dan keyinroq yangilash mumkin (bloklamaydi).
    var receiptId = _extractChekIdFromStoreResponse(storeRes);
    if (receiptId != null && receiptId.isNotEmpty) {
      final rawId = receiptId;
      unawaited(_resolveInvoiceIdFromReports(rawId).then((resolved) {
        if (resolved == null || resolved.isEmpty || !mounted) return;
        setState(() => _completedReceiptId = resolved);
      }));
    }
    if (receiptId == null || receiptId.isEmpty) {
      if (mounted) {
        AppNotify.error(
          context,
          "API chek ID qaytarmadi. Sotuv serverda saqlanmagan bo'lishi mumkin.",
        );
      }
      if (mounted) setState(() => _submittingPay = false);
      return;
    }

    final rid = receiptId!;
    final orderId = ThermalReceiptPrinter.orderIdFromStoreResponse(storeRes);
    CartProvider.instance.clear();
    final sellerName = await getSellerName();
    final clientName = _client?.name;
    if (!mounted) return;
    setState(() {
      _submittingPay = false;
      if (widget.useDesktopFullscreenLayout) {
        _desktopPaymentComplete = true;
        _completedReceiptId = rid;
        _completedOrderId = orderId;
        _completedSellerName = sellerName;
        _completedClientName = clientName;
      }
    });
    if (widget.useDesktopFullscreenLayout) {
      final autoPrint = await PrinterSettings.isAutoPrintEnabled();
      final ready = await PrinterSettings.isPrinterReady();
      if (autoPrint && ready) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) unawaited(_printThermalReceipt(silent: true));
        });
      }
    }
    _showSuccessDialog(sellerName: sellerName, clientName: clientName, receiptId: rid);
    unawaited(_postSaleSideEffects());
    final resumedHoldId = widget.initialOrderId;
    if (resumedHoldId != null) {
      unawaited(
        SalesSessionProvider.instance.completeHoldOrderAfterSale(
          orderId: resumedHoldId,
          invoiceId: widget.initialInvoiceId,
        ),
      );
    }
  }

  String get _receiptBranchName =>
      SalesSessionProvider.instance.branchName.trim();

  ReceiptWidget _buildPrecheckReceiptWidget(
    DateTime at, {
    String? sellerPhone,
  }) {
    final productRows = widget.items.map((item) {
      final p = item.product;
      final unitLabel = item.sellByPack ? 'pachka' : Product.unitDisplayShort(p.unit);
      return ReceiptRow(
        productName: p.name,
        quantityStr: '${item.quantity} $unitLabel',
        price: item.unitPriceDisplay,
        sum: item.total,
      );
    }).toList();
    final discountUzs = _totalRaw - _totalAfterDiscount;
    return ReceiptWidget(
      dateTime: at,
      receiptNumber: '—',
      sellerName: _sellerDisplayName.isNotEmpty ? _sellerDisplayName : 'Sotuvchi',
      sellerPhone: sellerPhone,
      branchName: _receiptBranchName,
      clientName: _client?.name,
      clientPhone: _client?.phone,
      clientAddress: _client?.address,
      description: _description,
      productRows: productRows,
      paymentRows: const [],
      discount: discountUzs,
      totalSum: _totalAfterDiscount,
      isPrecheck: true,
      design: _receiptDesign,
    );
  }

  ReceiptWidget _buildReceiptWidget(
    DateTime at, {
    String sellerName = 'Sotuvchi',
    String? sellerPhone,
    String? clientName,
    String? receiptId,
  }) {
    final posNumber = receiptId ?? _txId;
    final productRows = widget.items.map((item) {
      final p = item.product;
      final unitLabel = item.sellByPack ? 'pachka' : Product.unitDisplayShort(p.unit);
      final unitPrice = item.unitPriceDisplay;
      return ReceiptRow(
        productName: p.name,
        quantityStr: '${item.quantity} $unitLabel',
        price: unitPrice,
        sum: item.total,
      );
    }).toList();
    final allocated = _getAllocatedPaymentAmounts();
    final paymentRows = allocated.entries.map((e) {
      final label = _paymentList.firstWhere((m) => m.key == e.key, orElse: () => MapEntry(e.key, e.key)).value;
      return ReceiptPaymentRow(
        methodName: label,
        sum: e.value,
      );
    }).toList();
    final discountUzs = _totalRaw - _totalAfterDiscount;
    return ReceiptWidget(
      dateTime: at,
      receiptNumber: posNumber.startsWith('POS') ? posNumber : 'POS$posNumber',
      sellerName: sellerName,
      sellerPhone: sellerPhone,
      branchName: _receiptBranchName,
      clientName: clientName ?? _client?.name,
      clientPhone: _client?.phone,
      clientAddress: _client?.address,
      description: _description,
      productRows: productRows,
      paymentRows: paymentRows,
      discount: discountUzs,
      totalSum: _totalAfterDiscount,
      barcodeData: posNumber,
      design: _receiptDesign,
    );
  }

  void _showSuccessDialog({required String sellerName, String? clientName, required String receiptId}) {
    final posLabel = receiptId.startsWith('POS') ? receiptId : 'POS$receiptId';
    if (widget.useDesktopFullscreenLayout) {
      return;
    }
    final receiptWidget = _buildReceiptWidget(DateTime.now(), sellerName: sellerName, clientName: clientName, receiptId: receiptId);
    IosStyleModals.showPopupPanel<void>(
      context: context,
      barrierDismissible: false,
      child: Builder(
        builder: (dialogCtx) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.green,
                  child: Icon(Icons.check_rounded, color: Colors.white, size: 48),
                ),
                const SizedBox(height: 20),
                Text(
                  "Tranzaksiya #$posLabel muvaffaqiyatli bo'ldi!",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: _ReceiptActionButton(
                        icon: Icons.download_rounded,
                        label: "Chekni yuklash",
                        onPressed: () => _captureReceiptAndSave(dialogCtx, receiptWidget, share: false, receiptId: receiptId),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ReceiptActionButton(
                        icon: Icons.share_rounded,
                        label: "Chekni ulashish",
                        onPressed: () => _captureReceiptAndSave(dialogCtx, receiptWidget, share: true, receiptId: receiptId),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () {
                      Navigator.pop(dialogCtx);
                      if (mounted) Navigator.of(context).pop(receiptId);
                    },
                    child: const Text("Davom etish"),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _captureReceiptAndSave(BuildContext dialogContext, ReceiptWidget receiptWidget, {required bool share, String? receiptId}) async {
    final id = receiptId ?? _txId;
    final controller = ScreenshotController();
    final pngBytes = await controller.captureFromWidget(
      receiptWidget,
      context: context,
      pixelRatio: 3,
      delay: const Duration(milliseconds: 80),
      targetSize: const Size(360, 640),
    );
    if (!dialogContext.mounted) return;
    final decoded = img.decodeImage(pngBytes);
    if (decoded == null) return;
    final jpgBytes = img.encodeJpg(decoded, quality: 92);
    final bytes = Uint8List.fromList(jpgBytes);
    final safeFileName = 'chek_${id.replaceAll(RegExp(r'[^\w\-]'), '_')}.jpg';
    final posLabel = id.startsWith('POS') ? id : 'POS$id';

    if (!share) {
      try {
        // Faqat yozish (add-only): to'liq galereya o'qish ruxsati talab qilinmaydi (App Store / Play policy).
        if (!await Gal.hasAccess(toAlbum: false)) {
          final granted = await Gal.requestAccess(toAlbum: false);
          if (!granted) {
            if (dialogContext.mounted) {
              AppNotify.warning(dialogContext, "Galereyaga yozish uchun ruxsat berilmadi");
            }
            return;
          }
        }
        await Gal.putImageBytes(bytes, name: safeFileName);
        if (dialogContext.mounted) {
          AppNotify.success(dialogContext, "Chek galereyaga saqlandi");
        }
      } catch (e) {
        if (dialogContext.mounted) {
          AppNotify.error(dialogContext, "Saqlanmadi: $e");
        }
      }
      return;
    }

    if (!dialogContext.mounted) return;
    final tempDir = await getTemporaryDirectory();
    final tmpFile = File('${tempDir.path}/$safeFileName');
    await tmpFile.writeAsBytes(bytes);

    if (!dialogContext.mounted) return;
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile(
            tmpFile.path,
            mimeType: 'image/jpeg',
            name: safeFileName,
          ),
        ],
        title: 'Tranzaksiya $posLabel cheki',
      ),
    );
  }
}

class _ReceiptActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _ReceiptActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.grey.shade200,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 24, color: Colors.grey.shade800),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.grey.shade800),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

IconData iconForPaymentName(String name) {
  final n = name.toLowerCase();
  if (n.contains('naqd') || n.contains('cash')) return Icons.payments_rounded;
  if (n.contains('karta') || n.contains('terminal') || n.contains('uzcard') || n.contains('humo')) return Icons.credit_card_rounded;
  if (n.contains('payme') || n.contains('wallet')) return Icons.account_balance_wallet_rounded;
  if (n.contains('qarz') || n.contains('credit')) return Icons.receipt_long_rounded;
  if (n.contains('balans') || n.contains('balance')) return Icons.account_balance_wallet_rounded;
  return Icons.payments_rounded;
}

class _PaymentMethodCard extends StatelessWidget {
  static const Color _iosGreen = Color(0xFF34C759);
  static const Color _iosBlue = Color(0xFF007AFF);

  final String title;
  final IconData icon;
  final bool selected;
  final int amount;
  /// Mijoz balansi kartasi: summani yashil rangda ko'rsatish uchun.
  final int? balanceAmountUzs;
  final VoidCallback onTap;
  final VoidCallback? onRemove;

  const _PaymentMethodCard({
    required this.title,
    required this.icon,
    required this.selected,
    required this.amount,
    this.balanceAmountUzs,
    required this.onTap,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final isBalance = balanceAmountUzs != null;
    final bg = selected
        ? (isBalance ? const Color(0xFFE8F8ED) : const Color(0xFFEFF6FF))
        : Colors.white;
    final border = selected
        ? (isBalance ? const Color(0xFF7FD99A) : const Color(0xFF8EC2FF))
        : const Color(0xFFE5E5EA);
    const titleColor = Color(0xFF000000);
    final iconColor = selected
        ? (isBalance ? _iosGreen : _iosBlue)
        : (isBalance ? _iosGreen : _iosBlue);
    final iconBg = selected
        ? (isBalance ? const Color(0xFFD4F4DD) : const Color(0xFFDCEBFF))
        : (isBalance ? const Color(0xFFE8F8ED) : const Color(0xFFEAF3FF));
    final chipColor = isBalance ? _iosGreen : _iosBlue;
    final chipBg = chipColor.withValues(alpha: 0.12);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: border, width: selected ? 1.25 : 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: selected ? 0.07 : 0.04),
                blurRadius: selected ? 16 : 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(10, 12, 10, 8),
          child: Stack(
            children: [
              Align(
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: iconBg,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, size: 22, color: iconColor),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        letterSpacing: -0.3,
                        color: titleColor,
                      ),
                    ),
                    if (balanceAmountUzs != null) ...[
                      const SizedBox(height: 4),
                      Text.rich(
                        TextSpan(
                          style: const TextStyle(fontSize: 12, height: 1.2),
                          children: [
                            TextSpan(
                              text: 'Balans: ',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: Colors.black.withValues(alpha: 0.45),
                              ),
                            ),
                            TextSpan(
                              text: '${formatThousands(balanceAmountUzs!)} UZS',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: _iosGreen,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                      ),
                    ],
                    const SizedBox(height: 4),
                    if (selected)
                      Container(
                        margin: const EdgeInsets.only(top: 2),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: chipBg,
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          '${formatThousands(amount)} UZS',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: chipColor,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (onRemove != null)
                Align(
                  alignment: Alignment.topRight,
                  child: InkWell(
                    onTap: onRemove,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFF3B30),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close_rounded, size: 16, color: Colors.white),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget trailing;

  const _DetailRow({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primary, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimary,
                  ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty)
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.primary,
                    ),
                  ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}
