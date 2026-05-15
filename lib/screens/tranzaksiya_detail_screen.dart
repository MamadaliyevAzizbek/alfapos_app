import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
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
import '../services/api_service.dart';
import '../core/api_client.dart';
import '../widgets/receipt_widget.dart';
import '../widgets/ios_style_modals.dart';
import 'mijoz_screen.dart';
import 'chergirma_screen.dart';
import 'tavsif_screen.dart';

class TranzaksiyaDetailScreen extends StatefulWidget {
  final List<CartItem> items;

  const TranzaksiyaDetailScreen({super.key, required this.items});

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
  String _sellerDisplayName = '';
  /// Faqat chek oldindan ko'rinishi uchun (sotuv yopilguncha). Yopilgandan keyin chek ID har doim API dan (storeRes).
  String get _txId => '${DateTime.now().millisecondsSinceEpoch % 1000000000}';

  /// POST /sales/store javobidan chek ID — root, data, order ichidan; invoice_id / order_id (ro'yxat bilan bir xil)
  static String? _extractChekIdFromStoreResponse(Map<String, dynamic>? res) {
    if (res == null) return null;
    final keys = ['invoice_id', 'order_id', 'invoiceId', 'orderId', 'orderID', 'id'];
    for (final map in [res, res['data'] is Map ? res['data'] as Map<String, dynamic> : null, res['order'] is Map ? res['order'] as Map<String, dynamic> : null]) {
      if (map == null) continue;
      for (final k in keys) {
        final v = map[k];
        if (v == null) continue;
        final s = v.toString().trim();
        if (s.isNotEmpty) return s;
      }
    }
    return null;
  }

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

  /// Mijoz tanlanganda ko'rsatiladigan to'lov turlari: qarz, mijoz balansi (API dagi kabi)
  static bool _isCustomerRelatedPayment(Map<String, dynamic> e) {
    final name = (e['name'] ?? e['title'] ?? e['payment_method'] ?? '').toString().toLowerCase();
    final type = (e['type'] ?? e['payment_type'] ?? '').toString().toLowerCase();
    return name.contains('qarz') || name.contains('balans') || name.contains('balance') ||
        name.contains('debt') || name.contains('credit') ||
        type == 'credit' || type == 'debt' || type == 'qarz';
  }

  bool _isClientBalancePaymentById(String paymentId) {
    for (final e in _apiPaymentTypes) {
      final id = (e['id'] is int ? e['id'] as int : int.tryParse(e['id']?.toString() ?? '0') ?? 0).toString();
      if (id != paymentId) continue;
      final name = (e['name'] ?? e['title'] ?? e['payment_method'] ?? '').toString().toLowerCase();
      final type = (e['type'] ?? e['payment_type'] ?? '').toString().toLowerCase();
      return name.contains('balans') || name.contains('balance') || type == 'balance';
    }
    return false;
  }

  /// To'lov turlari — API dan; mijoz tanlanmaganida qarz va mijoz balansi ko'rinmaydi
  List<MapEntry<String, String>> get _paymentList {
    final list = _apiPaymentTypes
        .where((e) => _client != null || !_isCustomerRelatedPayment(e))
        .map((e) {
          final id = (e['id'] is int ? e['id'] as int : int.tryParse(e['id']?.toString() ?? '0') ?? 0).toString();
          final name = (e['name'] ?? e['title'] ?? e['payment_method'] ?? id).toString();
          return MapEntry(id, name);
        })
        .toList();
    return list;
  }

  Future<void> _loadPaymentTypes() async {
    setState(() => _paymentTypesLoading = true);
    try {
      final res = await SalesApi.getPaymentTypes();
      List<Map<String, dynamic>> list = [];
      if (res is Map) {
        final data = res['data'] ?? res['payment_types'];
        if (data is List) {
          for (final e in data) {
            if (e is Map) {
              final m = Map<String, dynamic>.from(e);
              final id = m['id'] is int ? m['id'] as int : int.tryParse(m['id']?.toString() ?? '');
              if (id != null) list.add({'id': id, 'name': m['name'] ?? m['title'] ?? m['payment_method'] ?? '$id'});
            }
          }
        }
      }
      if (mounted) setState(() {
        _apiPaymentTypes = list;
        _paymentTypesLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() {
        _apiPaymentTypes = [];
        _paymentTypesLoading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _loadPaymentTypes();
    _loadSellerDisplayName();
  }

  Future<void> _loadSellerDisplayName() async {
    await syncSellerNameFromApi();
    if (!mounted) return;
    final name = await getSellerName();
    if (mounted) setState(() => _sellerDisplayName = name);
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
                            child: ElevatedButton(
                              onPressed: () => Navigator.pop(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(Strings.kechiktirish),
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
                  onPressed: () => setState(() {
                    _client = null;
                    _clearCustomerRelatedPayments();
                  }),
                  tooltip: "Mijozni olib tashlash",
                ),
              TextButton(
                onPressed: () async {
                  final c = await Navigator.push<Client>(
                    context,
                    MaterialPageRoute(builder: (_) => const MijozScreen()),
                  );
                  if (c != null) setState(() => _client = c);
                },
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(Strings.qoShish, style: TextStyle(color: AppTheme.primary)),
                    Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppTheme.primary),
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
          subtitle: _discountPercent != null
              ? '$_discountPercent%'
              : _discountUzs != null
                  ? '${_fmt(_discountUzs!)} UZS'
                  : null,
          trailing: TextButton(
            onPressed: () async {
              final r = await Navigator.push<Map<String, dynamic>>(
                context,
                MaterialPageRoute(
                  builder: (_) => ChergirmaScreen(totalUzs: _totalRaw),
                ),
              );
              if (r != null && mounted) {
                setState(() {
                  _discountPercent = r['percent'] as int?;
                  _discountUzs = r['uzs'] as int?;
                  // Agar aralash to'lov o'chirilgan va bitta to'lov turi tanlangan bo'lsa,
                  // chegirmadan keyingi yangi jami shu to'lov turiga qayta biriktiriladi.
                  if (!_mixedPayment && _paymentAmounts.length == 1) {
                    final key = _paymentAmounts.keys.first;
                    _paymentAmounts[key] = _totalAfterDiscount;
                  }
                });
              }
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
            return _PaymentMethodCard(
              title: e.value,
              icon: _iconForPaymentName(e.value),
              selected: selected,
              amount: amount,
              balanceAmountUzs: (isBalancePayment && _client != null) ? _clientBalanceUzs : null,
              onTap: () {
                if (!_mixedPayment) {
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
                  return;
                }
                _showPaymentMethodDialog(e.value, key);
              },
              onRemove: (_mixedPayment && selected)
                  ? () => setState(() => _paymentAmounts.remove(key))
                  : null,
            );
          }          ).toList(),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  void _showPaymentMethodDialog(String title, String key) {
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
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
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
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 13),
                                    side: const BorderSide(color: Color(0xFFD1D5DB)),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  child: const Text(Strings.qaytish),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: FilledButton(
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
                                    padding: const EdgeInsets.symmetric(vertical: 13),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  child: const Text(Strings.qoShish),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
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

  /// API dagi to'lov turi nomi bo'yicha qarz summasini hisoblash (qarz/credit)
  int _getQarzAmountFromAllocated(Map<String, int> allocated) {
    int sum = 0;
    for (final e in _apiPaymentTypes) {
      final id = (e['id'] is int ? e['id'] as int : int.tryParse(e['id']?.toString() ?? '0') ?? 0).toString();
      final name = (e['name'] ?? e['title'] ?? '').toString().toLowerCase();
      final type = (e['type'] ?? '').toString().toLowerCase();
      final isQarz = name.contains('qarz') || type == 'credit';
      if (isQarz) sum += allocated[id] ?? 0;
    }
    return sum;
  }

  /// API dagi to'lov turi nomi bo'yicha mijoz balansidan ishlatilgan summa
  int _getClientBalanceAmountFromAllocated(Map<String, int> allocated) {
    int sum = 0;
    for (final e in _apiPaymentTypes) {
      final id = (e['id'] is int ? e['id'] as int : int.tryParse(e['id']?.toString() ?? '0') ?? 0).toString();
      final name = (e['name'] ?? e['title'] ?? '').toString().toLowerCase();
      final type = (e['type'] ?? '').toString().toLowerCase();
      final isBalance = name.contains('balans') || name.contains('balance') || type == 'balance';
      if (isBalance) sum += allocated[id] ?? 0;
    }
    return sum;
  }

  /// Mahsulotlar va qarz — chek modali ochilgach fonda (tezlik uchun).
  Future<void> _postSaleSideEffects({
    required String receiptId,
    required int qarzAmount,
    required int balanceSpentAmount,
    Client? client,
  }) async {
    try {
      await ProductsProvider.instance.loadFromApi();
    } catch (_) {}
    if (client != null) {
      if (qarzAmount > 0) {
        try {
          await ClientsProvider.instance.addDebt(client.id, qarzAmount, receiptId);
        } catch (_) {}
      }
      if (balanceSpentAmount > 0) {
        try {
          final idNum = int.tryParse(client.id);
          if (idNum != null) {
            await ContactsApi.updateCustomerBalance(
              idNum,
              amount: balanceSpentAmount,
              type: 'subtract',
              description: 'Sotuv: $receiptId',
            );
          }
        } catch (_) {}
      }
    }
  }

  Future<void> _doPay() async {
    final allocated = _getAllocatedPaymentAmounts();
    if (allocated.isEmpty) return;
    setState(() => _submittingPay = true);
    final qarzAmount = _getQarzAmountFromAllocated(allocated);
    final balanceSpentAmount = _getClientBalanceAmountFromAllocated(allocated);
    int totalCostUzs = 0;
    for (final item in widget.items) {
      final p = item.product;
      if (item.sellByPack && p.quantityInPack && p.costPricePerPack != null) {
        totalCostUzs += (p.costPricePerPack! * item.quantity).round();
      } else {
        totalCostUzs += ((p.costPriceUzs ?? 0) * item.quantity).round();
      }
    }
    final discountUzs = _totalRaw - _totalAfterDiscount;
    final paymentsApi = allocated.entries.map((e) {
      final id = int.tryParse(e.key) ?? 1;
      return {'paymentID': id, 'paid': e.value};
    }).toList();
    final cart = widget.items.map((item) {
      final p = item.product;
      final productId = int.tryParse(p.id) ?? 0;
      final isPack = item.sellByPack && p.quantityInPack && p.quantityPerPack > 0;
      final price = item.unitPriceDisplay;
      final variantId = p.variantId ?? 1;
      return {
        'productID': productId,
        'variantID': variantId,
        'quantity': item.quantity,
        'price': price,
        'productTitle': p.name,
        'variantTitle': 'default_variant',
        'orderType': 'sales',
        'discount': 0,
        'taxID': null,
        'calculatedPrice': item.total,
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
    // Chek ID faqat API dan. Agar store faqat id (17246) qaytarsa, reports/sales dan invoice_id (POS10029) ni olib ro'yxat bilan bir xil ko'rsatamiz
    var receiptId = _extractChekIdFromStoreResponse(storeRes);
    if (receiptId != null && receiptId.isNotEmpty) {
      final resolved = await _resolveInvoiceIdFromReports(receiptId);
      if (resolved != null && resolved.isNotEmpty) receiptId = resolved;
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
    CartProvider.instance.clear();
    final sellerName = await getSellerName();
    final clientName = _client?.name;
    if (!mounted) return;
    setState(() => _submittingPay = false);
    _showSuccessDialog(sellerName: sellerName, clientName: clientName, receiptId: rid);
    unawaited(
      _postSaleSideEffects(
        receiptId: rid,
        qarzAmount: qarzAmount,
        balanceSpentAmount: balanceSpentAmount,
        client: _client,
      ),
    );
  }

  ReceiptWidget _buildReceiptWidget(DateTime at, {String sellerName = 'Sotuvchi', String? clientName, String? receiptId}) {
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
      clientName: clientName,
      description: _description,
      productRows: productRows,
      paymentRows: paymentRows,
      discount: discountUzs,
      totalSum: _totalAfterDiscount,
      barcodeData: posNumber,
    );
  }

  void _showSuccessDialog({required String sellerName, String? clientName, required String receiptId}) {
    final posLabel = receiptId.startsWith('POS') ? receiptId : 'POS$receiptId';
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
                      if (mounted) Navigator.of(context).pop();
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
        if (!await Gal.hasAccess(toAlbum: true)) {
          final granted = await Gal.requestAccess(toAlbum: true);
          if (!granted) {
            if (dialogContext.mounted) {
              AppNotify.warning(dialogContext, "Galereyaga yozish uchun ruxsat berilmadi");
            }
            return;
          }
        }
        await Gal.putImageBytes(bytes, name: safeFileName, album: 'AlfaPos');
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

IconData _iconForPaymentName(String name) {
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
