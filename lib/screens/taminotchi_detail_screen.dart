import 'dart:async';

import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/app_notify.dart';
import '../core/constants.dart';
import '../core/input_formatters.dart';
import '../core/theme.dart';
import '../models/supplier.dart';
import '../services/api_service.dart';
import '../utils/customer_bulk_payment.dart';
import '../utils/supplier_balance_transaction.dart';
import '../utils/supplier_delivery_row.dart';
import '../widgets/ios_style_modals.dart';
import '../widgets/throttled_refresh_indicator.dart';
import 'api_chek_detail_screen.dart';
import 'taminotchi_form_screen.dart';

/// Taminotchi tafsiloti: yetkazib berish yozuvlari + balans tarixi.
class TaminotchiDetailScreen extends StatefulWidget {
  const TaminotchiDetailScreen({
    super.key,
    required this.supplier,
    this.openPaymentOnStart = false,
  });

  final Supplier supplier;
  final bool openPaymentOnStart;

  @override
  State<TaminotchiDetailScreen> createState() => _TaminotchiDetailScreenState();
}

class _TaminotchiDetailScreenState extends State<TaminotchiDetailScreen>
    with SingleTickerProviderStateMixin {
  static const int _pageSize = 30;
  static const _debtRed = Color(0xFFDC2626);
  static const _balanceGreen = Color(0xFF16A34A);

  late Supplier _supplier;
  late TabController _tabs;
  bool _changed = false;
  bool _openedPaymentOnStart = false;
  bool _payingDebt = false;

  bool _loading = true;
  bool _deliveryLoading = false;
  bool _deliveryLoadingMore = false;
  bool _deliveryHasMore = true;
  int _deliveryOffset = 0;
  List<SupplierDeliveryRow> _deliveryRows = [];
  num _deliveryTotalDebt = 0;

  bool _balanceLoading = false;
  List<Map<String, dynamic>> _balanceRows = [];
  List<Map<String, dynamic>> _paymentTypes = [];

  @override
  void initState() {
    super.initState();
    _supplier = widget.supplier;
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(_onTabChanged);
    _load();
  }

  @override
  void dispose() {
    _tabs.removeListener(_onTabChanged);
    _tabs.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabs.indexIsChanging) return;
    if (_tabs.index == 1 && _balanceRows.isEmpty && !_balanceLoading) {
      _loadBalanceHistory();
    }
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      try {
        final profile = await ContactsApi.getSupplierProfile(_supplier.id);
        final loaded = Supplier.fromResponse(profile);
        if (loaded != null) _supplier = loaded;
      } catch (_) {
        final res = await ContactsApi.getSupplier(_supplier.id);
        final loaded = Supplier.fromResponse(res);
        if (loaded != null) {
          _supplier = loaded.copyWith(
            dueAmount:
                loaded.dueAmount > 0 ? loaded.dueAmount : _supplier.dueAmount,
            balance: loaded.balance,
          );
        }
      }
      await Future.wait([
        _loadDelivery(reset: true),
        _loadPaymentTypes(),
      ]);
    } catch (e) {
      if (mounted) AppNotify.error(context, '$e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
        _maybeOpenPaymentOnStart();
      }
    }
  }

  void _maybeOpenPaymentOnStart() {
    if (!widget.openPaymentOnStart ||
        _openedPaymentOnStart ||
        _supplier.dueAmount <= 0) {
      return;
    }
    _openedPaymentOnStart = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _showPayDebtDialog();
    });
  }

  Future<void> _loadPaymentTypes() async {
    try {
      final res = await ContactsApi.getPaymentList();
      _paymentTypes = CustomerBulkPayment.parsePaymentTypesResponse(res);
    } catch (_) {
      _paymentTypes = [];
    }
  }

  Future<void> _loadDelivery({required bool reset}) async {
    if (!reset && (_deliveryLoadingMore || !_deliveryHasMore)) return;

    if (reset) {
      _deliveryOffset = 0;
      _deliveryHasMore = true;
      _deliveryRows = [];
      if (mounted) setState(() => _deliveryLoading = true);
    } else {
      if (mounted) setState(() => _deliveryLoadingMore = true);
    }

    try {
      final res = await ContactsApi.getSupplierDeliveryReport(
        _supplier.id,
        body: {
          'columnKey': 'id',
          'columnSortedBy': 'DESC',
          'rowOffset': _deliveryOffset,
          'rowLimit': _pageSize,
          'filtersData': <dynamic>[],
          'searchValue': '',
          'reqType': '',
          'merge_supplier_debts': true,
        },
      );
      final page = SupplierDeliveryRow.listFromResponse(res);
      final totalDebt = res['totalDebt'] ?? res['total_debt'];
      if (totalDebt != null) {
        _deliveryTotalDebt = parseAmountFromApi(totalDebt);
        _supplier = _supplier.copyWith(dueAmount: _deliveryTotalDebt);
      }
      _deliveryRows = reset ? page : [..._deliveryRows, ...page];
      _deliveryOffset += page.length;
      _deliveryHasMore = page.length >= _pageSize;
    } catch (e) {
      if (reset) _deliveryRows = [];
      if (mounted) AppNotify.error(context, '$e');
    } finally {
      if (mounted) {
        setState(() {
          _deliveryLoading = false;
          _deliveryLoadingMore = false;
        });
      }
    }
  }

  Future<void> _loadBalanceHistory() async {
    if (mounted) setState(() => _balanceLoading = true);
    try {
      final res =
          await ContactsApi.getSupplierBalanceTransactions(_supplier.id);
      final raw = res['datarows'] ?? res['data'];
      if (raw is List) {
        _balanceRows = raw
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      } else {
        _balanceRows = [];
      }
      final totalBalance = res['totalBalance'] ?? res['total_balance'];
      if (totalBalance != null) {
        _supplier =
            _supplier.copyWith(balance: parseAmountFromApi(totalBalance));
      }
    } catch (e) {
      _balanceRows = [];
      if (mounted) AppNotify.error(context, '$e');
    } finally {
      if (mounted) setState(() => _balanceLoading = false);
    }
  }

  Future<void> _openEdit() async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => TaminotchiFormScreen(supplier: _supplier),
      ),
    );
    if (ok == true) {
      _changed = true;
      await _load();
    }
  }

  Future<void> _showAddBalanceDialog() async {
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Balans qo‘shish'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [ThousandsInputFormatter()],
              decoration: const InputDecoration(
                labelText: 'Summa',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(
                labelText: 'Izoh',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(Strings.bekorQilish),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(Strings.saqlash),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final amount = parseFormattedSum(amountCtrl.text) ?? 0;
    if (amount <= 0) {
      AppNotify.info(context, 'Summani kiriting');
      return;
    }
    try {
      final res = await ContactsApi.updateSupplierBalance(
        _supplier.id,
        amount: amount,
        type: 'add',
        description: descCtrl.text.trim(),
      );
      final bal = res['balance'];
      if (bal != null) {
        _supplier = _supplier.copyWith(balance: parseAmountFromApi(bal));
      }
      _changed = true;
      if (mounted) {
        AppNotify.success(context, 'Balans yangilandi');
        setState(() {});
        await _loadBalanceHistory();
      }
    } catch (e) {
      if (mounted) AppNotify.error(context, '$e');
    }
  }

  Future<void> _deleteBalanceTx(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tranzaksiyani o‘chirish'),
        content: const Text(
          'Balans qayta hisoblanadi. Davom etasizmi?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(Strings.bekorQilish),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('O‘chirish'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ContactsApi.deleteSupplierBalanceTransaction(id);
      _changed = true;
      if (mounted) {
        AppNotify.success(context, 'O‘chirildi');
        await _load();
        await _loadBalanceHistory();
      }
    } catch (e) {
      if (mounted) AppNotify.error(context, '$e');
    }
  }

  List<BulkDuePaymentMethod> _bulkPaymentMethods() {
    final options = <BulkDuePaymentMethod>[
      for (final e in _paymentTypes)
        if (!CustomerBulkPayment.isExcludedBulkPaymentType(e) &&
            CustomerBulkPayment.paymentTypeId(e) != null)
          BulkDuePaymentMethodId(
            CustomerBulkPayment.paymentTypeId(e)!,
            CustomerBulkPayment.paymentTypeLabel(e),
          ),
    ];
    if (_supplier.balance > 0) {
      options.add(const BulkDuePaymentMethodSupplierBalance());
    }
    return options;
  }

  Future<void> _showAddDebtDialog() async {
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Qarz qo‘shish'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [ThousandsInputFormatter()],
              decoration: const InputDecoration(
                labelText: 'Summa',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(
                labelText: 'Izoh',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(Strings.bekorQilish),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(Strings.saqlash),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final amount = parseFormattedSum(amountCtrl.text) ?? 0;
    if (amount <= 0) {
      AppNotify.info(context, 'Summani kiriting');
      return;
    }
    try {
      await ContactsApi.storeSupplierDebt(_supplier.id, {
        'amount': amount,
        'type': 'loan',
        'description': descCtrl.text.trim().isEmpty
            ? "Qo'shimcha qarz"
            : descCtrl.text.trim(),
      });
      _changed = true;
      if (mounted) {
        AppNotify.success(context, 'Qarz qo‘shildi');
        await _load();
      }
    } on ApiException catch (e) {
      if (mounted) AppNotify.error(context, e.message);
    } catch (e) {
      if (mounted) AppNotify.error(context, '$e');
    }
  }

  Future<void> _showPayDebtDialog() async {
    if (!mounted || _payingDebt) return;
    _payingDebt = true;

    final dialogShown = Completer<BuildContext>();
    showDialog<void>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (ctx) {
        if (!dialogShown.isCompleted) dialogShown.complete(ctx);
        return const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            ),
          ),
        );
      },
    );

    Map<String, dynamic>? dueRes;
    Object? loadError;
    try {
      dueRes = await ContactsApi.getSupplierDueOrders(_supplier.id);
      if (_paymentTypes.isEmpty) await _loadPaymentTypes();
    } catch (e) {
      loadError = e;
    }

    BuildContext? dialogCtx;
    try {
      dialogCtx = await dialogShown.future.timeout(
        const Duration(seconds: 2),
      );
    } catch (_) {}
    if (dialogCtx != null && dialogCtx.mounted) {
      Navigator.of(dialogCtx).pop();
    }
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) {
      _payingDebt = false;
      return;
    }

    try {
      if (loadError != null || dueRes == null) {
        AppNotify.error(
          context,
          'Ma\'lumot yuklanmadi${loadError != null ? ': $loadError' : ''}',
        );
        return;
      }

      final dueTotal = CustomerBulkPayment.totalDueFromDueOrdersResponse(dueRes);
      final dueCount = CustomerBulkPayment.dueOrdersCount(dueRes);
      if (dueTotal <= 0) {
        AppNotify.info(context, 'Qarzdorlik yo‘q');
        return;
      }

      final methods = _bulkPaymentMethods();
      if (methods.isEmpty) {
        AppNotify.error(context, 'To‘lov turlari yuklanmadi');
        return;
      }

      final controller = TextEditingController();
      var selected = methods.first;
      final maxPay = dueTotal.round();

      final result = await IosStyleModals.showSheet<Map<String, dynamic>>(
        context: context,
        isScrollControlled: true,
        showGrabber: true,
        child: Builder(
          builder: (ctx) => StatefulBuilder(
            builder: (ctx, setDialogState) => IosStyleModals.sheetKeyboardForm(
              context: ctx,
              onCancel: () => Navigator.of(ctx).pop(),
              onSave: () {
                final amount = parseFormattedSum(controller.text) ?? 0;
                if (amount <= 0) return;
                if (amount > maxPay) {
                  AppNotify.info(ctx, 'Summa qarzdan oshmasligi kerak');
                  return;
                }
                if (selected is BulkDuePaymentMethodSupplierBalance &&
                    amount > _supplier.balance.round()) {
                  AppNotify.info(ctx, 'Balans yetarli emas');
                  return;
                }
                Navigator.of(ctx).pop({
                  'amount': amount,
                  'paymentMethod': selected.apiValue,
                });
              },
              cancelLabel: Strings.bekorQilish,
              saveLabel: "To'lash",
              body: [
                const Text(
                  Strings.umumiyTolash,
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                ),
                const SizedBox(height: 8),
                Text(
                  'Jami qarz: ${formatThousands(dueTotal.round())}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                if (dueCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '$dueCount ta qarzdor qator (cheklar va jurnal)',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  inputFormatters: [ThousandsInputFormatter()],
                  decoration: const InputDecoration(
                    labelText: "To'lov summasi",
                    suffixText: 'UZS',
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  "To'lov turi",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                RadioGroup<BulkDuePaymentMethod>(
                  groupValue: selected,
                  onChanged: (v) {
                    if (v == null) return;
                    setDialogState(() => selected = v);
                  },
                  child: Column(
                    children: [
                      for (final m in methods)
                        RadioListTile<BulkDuePaymentMethod>(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(m.label),
                          value: m,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await WidgetsBinding.instance.endOfFrame;
      controller.dispose();

      final amount = result?['amount'] as int? ?? 0;
      final paymentMethod = result?['paymentMethod'];
      if (amount <= 0 || paymentMethod == null || !mounted) return;

      try {
        final res = await ContactsApi.supplierBulkDuePayment(
          _supplier.id,
          amount: amount,
          paymentMethod: paymentMethod,
        );
        _changed = true;
        if (!mounted) return;
        await _load();
        if (!mounted) return;
        final msg = (res['message'] ?? '').toString();
        AppNotify.success(
          context,
          msg.isNotEmpty ? msg : '${formatThousands(amount)} to‘landi',
        );
      } on ApiException catch (e) {
        if (mounted) AppNotify.error(context, e.message);
      } catch (e) {
        if (mounted) AppNotify.error(context, '$e');
      }
    } finally {
      _payingDebt = false;
    }
  }

  Future<void> _openReceivingChek(SupplierDeliveryRow row) async {
    final orderId = row.orderId;
    if (orderId == null) {
      AppNotify.warning(context, 'Chek ID aniqlanmadi');
      return;
    }
    Map<String, dynamic>? detail;
    String? loadError;
    try {
      detail = await ContactsApi.getSupplierReceiving(orderId);
    } catch (e) {
      loadError = e.toString();
      try {
        detail = await ReportsApi.getInvoiceDetails(orderId);
        loadError = null;
      } catch (_) {}
    }
    if (!mounted) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => ApiChekDetailScreen(
          sale: row.raw,
          invoiceDetail: detail ?? {},
          invoiceLoadError: loadError,
        ),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _deleteDeliveryRow(SupplierDeliveryRow row) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('O‘chirish'),
        content: Text(
          row.canDeleteBulk
              ? 'Umumiy to‘lov guruhini bekor qilasizmi?'
              : 'Jurnal yozuvini o‘chirasizmi?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(Strings.bekorQilish),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('O‘chirish'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      if (row.canDeleteBulk) {
        await ContactsApi.deleteSupplierBulkDuePayment(
          _supplier.id,
          bulkGroupId: row.bulkGroupId!,
        );
      } else if (row.canDeleteJournal) {
        await ContactsApi.deleteSupplierDebt(row.debtId!);
      }
      _changed = true;
      if (mounted) {
        AppNotify.success(context, 'O‘chirildi');
        await _load();
      }
    } on ApiException catch (e) {
      if (mounted) AppNotify.error(context, e.message);
    } catch (e) {
      if (mounted) AppNotify.error(context, '$e');
    }
  }

  void _pop() => Navigator.pop(context, _changed);

  static String _formatAmount(num n) => formatThousands(n.round());

  static const _primaryBlue = Color(0xFF0D6EFD);

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final route = ModalRoute.of(context);
        if (route != null && !route.isCurrent) return;
        _pop();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F8FF),
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: _pop,
          ),
          title: Text(_supplier.name),
          actions: [
            IconButton(
              tooltip: 'Tahrirlash',
              icon: const Icon(Icons.edit_rounded),
              onPressed: _openEdit,
            ),
          ],
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: TabBar(
                controller: _tabs,
                labelColor: AppTheme.primary,
                unselectedLabelColor: AppTheme.textSecondary,
                indicatorColor: AppTheme.primary,
                tabs: const [
                  Tab(text: 'Cheklar'),
                  Tab(text: 'Balans tarixi'),
                ],
              ),
            ),
            SizedBox(
              height: 2,
              child: _loading
                  ? const LinearProgressIndicator(
                      minHeight: 2,
                      color: AppTheme.primary,
                      backgroundColor: Colors.transparent,
                    )
                  : null,
            ),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _buildDeliveryTab(),
                  _buildBalanceTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryTab() {
    final s = _supplier;
    final phone = s.displayPhone;
    final company = s.company?.trim() ?? '';
    final address = s.address?.trim() ?? '';

    return ThrottledRefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0D6EFD), Color(0xFF4DA3FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0D6EFD).withValues(alpha: 0.28),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Taminotchi dashboard',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    s.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (phone != '—') ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(
                          Icons.phone_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          phone,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (company.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.business_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            company,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (address.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.location_on_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            address,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _metricCard(
                    title: 'Jami qarz',
                    value: _formatAmount(s.dueAmount),
                    valueColor: s.dueAmount > 0
                        ? Colors.red.shade700
                        : const Color(0xFF2D5B9A),
                    icon: Icons.receipt_long_rounded,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _metricCard(
                    title: 'Balans',
                    value: _formatAmount(s.balance),
                    valueColor: s.balance > 0
                        ? Colors.green.shade700
                        : (s.balance < 0
                            ? Colors.red.shade700
                            : const Color(0xFF2D5B9A)),
                    icon: Icons.account_balance_wallet_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildToolbar(),
            const SizedBox(height: 16),
            if (_deliveryLoading && _deliveryRows.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: CircularProgressIndicator(color: AppTheme.primary),
                ),
              )
            else if (_deliveryRows.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: Text(
                    'Yetkazib berish yozuvlari yo‘q',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
              )
            else ...[
              ..._deliveryRows.map(_deliveryChekTile),
              if (_deliveryHasMore)
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 8),
                  child: Center(
                    child: OutlinedButton.icon(
                      onPressed: _deliveryLoadingMore
                          ? null
                          : () => _loadDelivery(reset: false),
                      icon: _deliveryLoadingMore
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.expand_more_rounded),
                      label: Text(
                        _deliveryLoadingMore
                            ? 'Yuklanmoqda...'
                            : 'Yana yuklash',
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _deliveryChekTile(SupplierDeliveryRow row) {
    final invoice = row.invoiceId.trim();
    final title = row.canOpenCheck &&
            invoice.isNotEmpty &&
            invoice != '—' &&
            !invoice.startsWith('__standalone_debt__')
        ? 'Chek #$invoice'
        : (invoice.isNotEmpty && invoice != '—' ? 'Chek #$invoice' : row.title);
    final total = row.total > 0 ? row.total : row.amount;
    final due = row.amount;
    final subtitle = [
      if (row.dateDisplay.isNotEmpty && row.dateDisplay != '—') row.dateDisplay,
      if (total > 0) _formatAmount(total),
      if (row.typeLabel.isNotEmpty) row.typeLabel,
    ].join(' — ');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFE6F1FF),
          child: Icon(Icons.receipt_long_rounded, color: Color(0xFF0D6EFD)),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(subtitle),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (due > 0)
              Text(
                'Qoldiq: ${_formatAmount(due)}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.red,
                ),
              )
            else
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF5C8DFF),
              ),
            if (row.canDeleteJournal || row.canDeleteBulk)
              IconButton(
                tooltip: 'O‘chirish',
                visualDensity: VisualDensity.compact,
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  size: 20,
                  color: Color(0xFFDC2626),
                ),
                onPressed: () => _deleteDeliveryRow(row),
              ),
          ],
        ),
        onTap: row.canOpenCheck ? () => _openReceivingChek(row) : null,
      ),
    );
  }

  Widget _metricCard({
    required String title,
    required String value,
    required Color valueColor,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD6E8FF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 17, color: const Color(0xFF0D6EFD)),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDebtActionButton({
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
    required bool filled,
  }) {
    final shape =
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(28));
    return SizedBox(
      height: 44,
      child: filled
          ? FilledButton.icon(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                backgroundColor: _primaryBlue,
                foregroundColor: Colors.white,
                shape: shape,
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              icon: Icon(icon, size: 20),
              label: Text(label),
            )
          : OutlinedButton.icon(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: _debtRed,
                side: const BorderSide(color: _debtRed, width: 1.5),
                shape: shape,
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              icon: Icon(icon, size: 20),
              label: Text(label),
            ),
    );
  }

  Widget _buildToolbar() {
    final debtLabel = Text.rich(
      TextSpan(
        text: 'Umumiy qarzdorlik: ',
        style: const TextStyle(
          fontSize: 14,
          color: AppTheme.textSecondary,
        ),
        children: [
          TextSpan(
            text: _formatAmount(_supplier.dueAmount),
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: _debtRed,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          debtLabel,
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildDebtActionButton(
                  label: "Qarz qo'shish",
                  icon: Icons.add,
                  onPressed: _showAddDebtDialog,
                  filled: false,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildDebtActionButton(
                  label: Strings.umumiyTolash,
                  icon: Icons.credit_card_rounded,
                  onPressed:
                      _supplier.dueAmount > 0 ? _showPayDebtDialog : null,
                  filled: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceTab() {
    return ThrottledRefreshIndicator(
      onRefresh: _loadBalanceHistory,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _showAddBalanceDialog,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text("Balans qo'shish"),
              style: FilledButton.styleFrom(
                backgroundColor: _primaryBlue,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_balanceLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: CircularProgressIndicator(color: AppTheme.primary),
              ),
            )
          else if (_balanceRows.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  "Balans harakatlari yo'q",
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
            )
          else
            ..._balanceRows.map(_buildBalanceCard),
        ],
      ),
    );
  }

  Widget _buildBalanceCard(Map<String, dynamic> raw) {
    final row = SupplierBalanceTransactionRow(raw);
    final amountText =
        SupplierBalanceTransactionRow.formatSignedAmount(row.signedAmount);
    final amountColor = row.signedAmount < 0
        ? _debtRed
        : row.signedAmount > 0
            ? _balanceGreen
            : AppTheme.textPrimary;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        row.dateDisplay,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      amountText,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: amountColor,
                      ),
                    ),
                  ],
                ),
                if (row.description.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    row.description,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.textPrimary,
                      height: 1.3,
                    ),
                  ),
                ],
                if (row.createdBy.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.person_outline_rounded,
                        size: 14,
                        color: AppTheme.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          row.createdBy,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (row.id != null)
            IconButton(
              tooltip: "O'chirish",
              onPressed: () => _deleteBalanceTx(row.id!),
              visualDensity: VisualDensity.compact,
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: Color(0xFFDC2626),
                size: 20,
              ),
            ),
        ],
      ),
    );
  }
}
