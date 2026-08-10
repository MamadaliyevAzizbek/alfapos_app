import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_notify.dart';
import '../core/input_formatters.dart';
import '../core/seller_preferences.dart';
import '../core/theme.dart';
import '../providers/cash_register_shift_provider.dart';
import '../services/api_service.dart';
import '../utils/cash_register_utils.dart';
import '../utils/platform_layout.dart';
import '../widgets/app_dropdown.dart';
import 'api_chek_detail_screen.dart';
import 'desktop/quick_cash_dialogs.dart';
import '../widgets/throttled_refresh_indicator.dart';

Future<void> openRegisterLogFullReport(
  BuildContext context, {
  int? registerLogId,
  int initialTabIndex = 0,
  bool filterByCurrentEmployee = false,
}) async {
  final logId = registerLogId ?? CashRegisterShiftProvider.instance.registerLogId;
  if (logId == null) {
    AppNotify.warning(context, 'Smena topilmadi');
    return;
  }
  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      fullscreenDialog: isDesktopPosLayout,
      builder: (_) => RegisterLogFullReportScreen(
        registerLogId: logId,
        initialTabIndex: initialTabIndex,
        filterByCurrentEmployee: filterByCurrentEmployee,
      ),
    ),
  );
}

/// Kassa smena to'liq hisoboti — REGISTER_LOGS_API.md (web registerLogDetail.vue ekvivalenti).
class RegisterLogFullReportScreen extends StatefulWidget {
  final int registerLogId;
  final int initialTabIndex;
  /// Sotuv bo'limidagi «Sotish ro'yxati» — faqat joriy login xodimining cheklari.
  final bool filterByCurrentEmployee;

  const RegisterLogFullReportScreen({
    super.key,
    required this.registerLogId,
    this.initialTabIndex = 0,
    this.filterByCurrentEmployee = false,
  });

  @override
  State<RegisterLogFullReportScreen> createState() => _RegisterLogFullReportScreenState();
}

class _RegisterLogFullReportScreenState extends State<RegisterLogFullReportScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  Map<String, dynamic>? _info;
  Map<String, dynamic>? _analytics;
  List<Map<String, dynamic>> _expenses = [];
  List<Map<String, dynamic>> _incomes = [];
  num _totalExpenses = 0;
  num _totalIncomes = 0;

  bool _loadingCore = true;
  String? _error;

  bool _salesLoaded = false;
  bool _salesLoading = false;
  List<Map<String, dynamic>> _salesRows = [];
  String _salesEmployee = 'all';
  String _salesPaymentType = 'all';
  List<Map<String, String>> _employeeOptions = const [{'value': 'all', 'label': 'Barchasi'}];
  List<Map<String, String>> _paymentOptions = const [{'value': 'all', 'label': 'Barchasi'}];

  int? _deletingExpenseId;
  int? _deletingIncomeId;

  int get _logId => widget.registerLogId;

  bool get _isOpen {
    final info = _info;
    if (info == null) return false;
    final status = (info['status'] ?? (info['log'] is Map ? (info['log'] as Map)['status'] : null) ?? '')
        .toString()
        .toLowerCase();
    return status == 'open';
  }

  @override
  void initState() {
    super.initState();
    final tabIndex = widget.initialTabIndex.clamp(0, 3);
    _tabs = TabController(length: 4, vsync: this, initialIndex: tabIndex);
    _tabs.addListener(_onTabChanged);
    if (tabIndex == 1) {
      unawaited(_loadSales());
    }
    unawaited(_loadCore());
  }

  @override
  void dispose() {
    _tabs.removeListener(_onTabChanged);
    _tabs.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabs.indexIsChanging) return;
    if (_tabs.index == 1 && !_salesLoaded && !_salesLoading) {
      unawaited(_loadSales());
    }
  }

  Future<void> _loadCore() async {
    setState(() {
      _loadingCore = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        RegisterLogsApi.getInfo(_logId),
        RegisterLogsApi.getAnalytics(_logId),
        RegisterLogsApi.getExpenses(_logId),
        RegisterLogsApi.getIncomes(_logId),
      ]);
      final info = apiResponseMap(results[0]);
      final analytics = apiResponseMap(results[1]);
      final expRes = apiResponseMap(results[2]);
      final incRes = apiResponseMap(results[3]);
      if (!mounted) return;
      setState(() {
        _info = info;
        _analytics = analytics;
        _expenses = parseApiList(expRes['expenses']);
        _totalExpenses = parseAmountFromApi(expRes['total']);
        _incomes = parseApiList(incRes['incomes']);
        _totalIncomes = parseAmountFromApi(incRes['total']);
        _loadingCore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loadingCore = false;
      });
    }
  }

  Future<String> _employeeFilterForCurrentUser(List<Map<String, String>> employeeOptions) async {
    await CashRegisterShiftProvider.instance.ensureCurrentUserId();
    final userId = CashRegisterShiftProvider.instance.currentUserId ?? await getCurrentUserId();
    if (userId != null) {
      final idStr = '$userId';
      if (employeeOptions.any((e) => e['value'] == idStr)) return idStr;
    }
    final sellerName = (await getSellerName()).trim();
    if (sellerName.isNotEmpty && sellerName != 'Sotuvchi') {
      final normalized = sellerName.toLowerCase();
      for (final e in employeeOptions) {
        final label = (e['label'] ?? '').trim().toLowerCase();
        if (label == normalized || label.contains(normalized)) {
          return e['value'] ?? 'all';
        }
      }
    }
    return 'all';
  }

  Future<void> _loadSales() async {
    setState(() => _salesLoading = true);
    try {
      final filterRes = await RegisterLogsApi.getSalesFilter(_logId);
      final filterData = filterRes['data'] is Map
          ? Map<String, dynamic>.from(filterRes['data'] as Map)
          : filterRes;
      final employees = _extractOptions(filterData['employee'], prefix: 'Xodim');
      final payments = _extractOptions(filterData['paymentTypes'], prefix: "To'lov");
      var employeeFilter = _salesEmployee;
      if (widget.filterByCurrentEmployee) {
        employeeFilter = await _employeeFilterForCurrentUser(employees);
      }
      final salesRes = await RegisterLogsApi.getSales(
        _logId,
        body: RegisterLogsApi.salesListBody(
          logId: _logId,
          employee: employeeFilter,
          paymentTypeId: _salesPaymentType,
        ),
      );
      final rows = _parseSalesRows(salesRes);
      if (!mounted) return;
      setState(() {
        _employeeOptions = employees;
        _paymentOptions = payments;
        if (widget.filterByCurrentEmployee) _salesEmployee = employeeFilter;
        _salesRows = rows;
        _salesLoaded = true;
        _salesLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _salesLoading = false);
      AppNotify.error(context, 'Sotuvlar yuklanmadi: $e');
    }
  }

  Future<void> _reloadSales() async {
    setState(() => _salesLoading = true);
    try {
      final salesRes = await RegisterLogsApi.getSales(
        _logId,
        body: RegisterLogsApi.salesListBody(
          logId: _logId,
          employee: _salesEmployee,
          paymentTypeId: _salesPaymentType,
        ),
      );
      if (!mounted) return;
      setState(() {
        _salesRows = _parseSalesRows(salesRes);
        _salesLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _salesLoading = false);
      AppNotify.error(context, 'Sotuvlar yuklanmadi: $e');
    }
  }

  List<Map<String, dynamic>> _parseSalesRows(Map<String, dynamic> res) {
    final list = res['datarows'] as List<dynamic>? ?? res['data'] as List<dynamic>? ?? [];
    return list
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .where((m) {
          final id = m['invoice_id'] ?? m['id'];
          if (id == null) return false;
          final s = id.toString().trim().toLowerCase();
          return s.isNotEmpty && s != 'jami' && !s.contains('umumiy');
        })
        .toList();
  }

  List<Map<String, String>> _extractOptions(dynamic raw, {required String prefix}) {
    final parsed = <Map<String, String>>[const {'value': 'all', 'label': 'Barchasi'}];
    if (raw is! List) return parsed;
    for (final e in raw) {
      if (e is! Map) continue;
      final m = Map<String, dynamic>.from(e);
      final v = (m['value'] ?? m['id'] ?? '').toString();
      if (v.isEmpty) continue;
      final label = (m['text'] ?? m['label'] ?? m['name'] ?? '$prefix $v').toString();
      parsed.add({'value': v, 'label': label});
    }
    return parsed;
  }

  Future<void> _deleteExpense(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xarajatni o\'chirish'),
        content: const Text('Bu xarajatni o\'chirmoqchimisiz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Bekor qilish')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('O\'chirish')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _deletingExpenseId = id);
    try {
      await ExpensesApi.deleteExpense(id);
      await _loadCore();
      unawaited(CashRegisterShiftProvider.instance.loadShiftDetail());
      if (mounted) AppNotify.success(context, 'Xarajat o\'chirildi');
    } catch (e) {
      if (mounted) AppNotify.error(context, e.toString());
    } finally {
      if (mounted) setState(() => _deletingExpenseId = null);
    }
  }

  Future<void> _deleteIncome(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Daromadni o\'chirish'),
        content: const Text('Bu daromadni o\'chirmoqchimisiz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Bekor qilish')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('O\'chirish')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _deletingIncomeId = id);
    try {
      await IncomesApi.deleteIncome(id);
      await _loadCore();
      unawaited(CashRegisterShiftProvider.instance.loadShiftDetail());
      if (mounted) AppNotify.success(context, 'Daromad o\'chirildi');
    } catch (e) {
      if (mounted) AppNotify.error(context, e.toString());
    } finally {
      if (mounted) setState(() => _deletingIncomeId = null);
    }
  }

  Future<void> _showInvoiceDetail(Map<String, dynamic> sale) async {
    final orderId = getOrderIdFromSale(sale);
    if (orderId == null) return;
    Map<String, dynamic> detail = {};
    String? loadError;
    try {
      detail = await ReportsApi.getInvoiceDetails(orderId);
    } catch (e) {
      loadError = e.toString().replaceFirst('Exception: ', '');
    }
    if (!mounted) return;
    final refreshed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ApiChekDetailScreen(sale: sale, invoiceDetail: detail, invoiceLoadError: loadError),
      ),
    );
    if (refreshed == true && mounted) {
      await _loadCore();
      if (_salesLoaded) await _reloadSales();
    }
  }

  Future<void> _addCash({required bool isIncome}) async {
    if (isIncome) {
      await showQuickIncomeDialog(context);
    } else {
      await showQuickExpenseDialog(context);
    }
    await _loadCore();
    unawaited(CashRegisterShiftProvider.instance.loadShiftDetail());
  }

  @override
  Widget build(BuildContext context) {
    final title = _info?['cash_register_title']?.toString();
    final subtitle = 'Smena #$_logId';

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title?.isNotEmpty == true ? title! : 'To\'liq hisobot', style: const TextStyle(fontSize: 18)),
            Text(subtitle, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400)),
          ],
        ),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Analitika'),
            Tab(text: 'Sotuvlar'),
            Tab(text: 'Xarajatlar'),
            Tab(text: 'Daromadlar'),
          ],
        ),
      ),
      body: _loadingCore && _info == null
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _error != null && _info == null
              ? _ErrorBody(
                  message: _error!,
                  onRetry: () async {
                    await _loadCore();
                    if (_salesLoaded) await _reloadSales();
                  },
                )
              : TabBarView(
                  controller: _tabs,
                  children: [
                    ThrottledRefreshIndicator(
                      onRefresh: () async {
                        await _loadCore();
                        if (_salesLoaded) await _reloadSales();
                      },
                      child: _AnalyticsTab(
                        info: _info ?? {},
                        analytics: _analytics ?? {},
                        expenses: _expenses,
                        incomes: _incomes,
                        totalExpenses: _totalExpenses,
                        totalIncomes: _totalIncomes,
                      ),
                    ),
                    ThrottledRefreshIndicator(
                      onRefresh: () async {
                        await _loadCore();
                        await _reloadSales();
                      },
                      child: _SalesTab(
                        loading: _salesLoading,
                        rows: _salesRows,
                        employee: _salesEmployee,
                        paymentType: _salesPaymentType,
                        employeeOptions: _employeeOptions,
                        paymentOptions: _paymentOptions,
                        onEmployeeChanged: (v) {
                          setState(() => _salesEmployee = v);
                          unawaited(_reloadSales());
                        },
                        onPaymentChanged: (v) {
                          setState(() => _salesPaymentType = v);
                          unawaited(_reloadSales());
                        },
                        onTapSale: _showInvoiceDetail,
                      ),
                    ),
                    ThrottledRefreshIndicator(
                      onRefresh: _loadCore,
                      child: _CashListTab(
                        isIncome: false,
                        rows: _expenses,
                        total: _totalExpenses,
                        canAdd: _isOpen,
                        deletingId: _deletingExpenseId,
                        onAdd: () => _addCash(isIncome: false),
                        onDelete: _deleteExpense,
                      ),
                    ),
                    ThrottledRefreshIndicator(
                      onRefresh: _loadCore,
                      child: _CashListTab(
                        isIncome: true,
                        rows: _incomes,
                        total: _totalIncomes,
                        canAdd: _isOpen,
                        deletingId: _deletingIncomeId,
                        onAdd: () => _addCash(isIncome: true),
                        onDelete: _deleteIncome,
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _ErrorBody({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ThrottledRefreshIndicator(
      onRefresh: onRetry,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 80),
          Icon(Icons.error_outline_rounded, size: 48, color: Colors.orange.shade700),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          const Text(
            'Pastga tortib yangilang',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _AnalyticsTab extends StatelessWidget {
  final Map<String, dynamic> info;
  final Map<String, dynamic> analytics;
  final List<Map<String, dynamic>> expenses;
  final List<Map<String, dynamic>> incomes;
  final num totalExpenses;
  final num totalIncomes;

  const _AnalyticsTab({
    required this.info,
    required this.analytics,
    required this.expenses,
    required this.incomes,
    required this.totalExpenses,
    required this.totalIncomes,
  });

  static bool _isHiddenPayment(String? name) {
    final v = (name ?? '').toLowerCase();
    if (v.contains('qarz') || v == 'credit') return true;
    if (v.contains('taminotchi') || (v.contains('supplier') && v.contains('balance'))) return true;
    if (v.contains('customer_balance') || (v.contains('mijoz') && v.contains('balans'))) return true;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final log = info['log'] is Map ? Map<String, dynamic>.from(info['log'] as Map) : <String, dynamic>{};
    final paymentTypes = parseApiList(analytics['payment_types'])
        .where((p) => !_isHiddenPayment((p['payment_method'] ?? p['name']).toString()))
        .toList();
    final currentAmounts = parseApiList(analytics['current_amount_by_payment_type'])
        .where((p) => !_isHiddenPayment((p['payment_method'] ?? p['name']).toString()))
        .toList();

    return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          _InfoCard(
            openedBy: (info['opened_by_name'] ?? '—').toString(),
            register: (info['cash_register_title'] ?? '—').toString(),
            openingTime: formatShiftDateTime(log['opening_time']),
            staff: (info['shift_staff_names'] ?? '').toString(),
            status: (info['status'] ?? log['status'] ?? 'open').toString(),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 720;
              final salesCard = _SummaryCard(
                title: 'Umumiy savdo',
                highlight: formatShiftMoney(analytics['total_payment'] ?? analytics['total_sales']),
                rows: [
                  ...paymentTypes.map((p) => (
                        (p['payment_method'] ?? p['name'] ?? '—').toString(),
                        formatShiftMoney(p['total_amount'] ?? p['amount']),
                      )),
                  ('Qaytarilgan summa', formatShiftMoney(analytics['shift_returns_total'])),
                  ('Cheklar soni', '${analytics['shift_orders_count'] ?? 0}'),
                  ('Umumiy og\'irlik (kg)', formatShiftWeight(analytics['shift_total_weight'])),
                  ('O\'rtacha chek', formatShiftMoney(analytics['shift_avg_check'])),
                ],
              );
              final currentCard = _SummaryCard(
                title: 'Jami bugungi hisobotlar',
                highlight: formatShiftMoney(analytics['total_current_amount']),
                rows: [
                  ...currentAmounts.map((p) => (
                        (p['payment_method'] ?? p['name'] ?? '—').toString(),
                        formatShiftMoney(p['total_amount'] ?? p['amount']),
                      )),
                  ('Kutilayotgan yopilish', formatShiftMoney(analytics['expected_amount'])),
                  ('Kassa kirim', formatShiftMoney(analytics['total_incomes'])),
                  ('Kassa chiqim', formatShiftMoney(analytics['total_expenses'])),
                ],
                tint: const Color(0xFFDCFCE7),
              );
              if (stacked) {
                return Column(
                  children: [
                    salesCard,
                    const SizedBox(height: 12),
                    currentCard,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: salesCard),
                  const SizedBox(width: 12),
                  Expanded(child: currentCard),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          _MiniTableSection(
            title: 'Daromadlar (kirimlar)',
            rows: incomes,
            total: totalIncomes,
            positive: true,
          ),
          const SizedBox(height: 12),
          _MiniTableSection(
            title: 'Xarajatlar (chiqimlar)',
            rows: expenses,
            total: totalExpenses,
            positive: false,
          ),
        ],
      );
  }
}

class _InfoCard extends StatelessWidget {
  final String openedBy;
  final String register;
  final String openingTime;
  final String staff;
  final String status;

  const _InfoCard({
    required this.openedBy,
    required this.register,
    required this.openingTime,
    required this.staff,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final open = status.toLowerCase() == 'open';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Wrap(
        spacing: 24,
        runSpacing: 12,
        children: [
          _chip('Ochgan', openedBy),
          _chip('Kassa', register),
          _chip('Ochilish', openingTime),
          _chip('Holat', open ? 'Ochiq' : 'Yopilgan'),
          if (staff.isNotEmpty) _chip('Smenada', staff),
        ],
      ),
    );
  }

  Widget _chip(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String highlight;
  final List<(String, String)> rows;
  final Color? tint;

  const _SummaryCard({
    required this.title,
    required this.highlight,
    required this.rows,
    this.tint,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: tint ?? const Color(0xFFE8F4FC),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(highlight, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 12),
          ...rows.map(
            (r) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(child: Text(r.$1, style: const TextStyle(fontSize: 13))),
                  Text(r.$2, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniTableSection extends StatelessWidget {
  final String title;
  final List<Map<String, dynamic>> rows;
  final num total;
  final bool positive;

  const _MiniTableSection({
    required this.title,
    required this.rows,
    required this.total,
    required this.positive,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 12),
          if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('Ma\'lumot yo\'q', style: TextStyle(color: AppTheme.textSecondary)),
            )
          else
            ...rows.map((r) {
              final amountColor = positive ? Colors.green.shade700 : Colors.red.shade700;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text((r['name'] ?? r['note'] ?? '—').toString(), style: const TextStyle(fontWeight: FontWeight.w600)),
                          Text(
                            '${r['payment_type_name'] ?? '—'} • ${formatShiftDateTime(r['created_at'])}',
                            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      formatShiftMoney(r['price']),
                      style: TextStyle(fontWeight: FontWeight.w700, color: amountColor),
                    ),
                  ],
                ),
              );
            }),
          const Divider(),
          Row(
            children: [
              const Expanded(child: Text('Jami', style: TextStyle(fontWeight: FontWeight.w800))),
              Text(
                formatShiftMoney(total),
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: positive ? Colors.green.shade700 : Colors.red.shade700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SalesTab extends StatelessWidget {
  final bool loading;
  final List<Map<String, dynamic>> rows;
  final String employee;
  final String paymentType;
  final List<Map<String, String>> employeeOptions;
  final List<Map<String, String>> paymentOptions;
  final ValueChanged<String> onEmployeeChanged;
  final ValueChanged<String> onPaymentChanged;
  final Future<void> Function(Map<String, dynamic> sale) onTapSale;

  const _SalesTab({
    required this.loading,
    required this.rows,
    required this.employee,
    required this.paymentType,
    required this.employeeOptions,
    required this.paymentOptions,
    required this.onEmployeeChanged,
    required this.onPaymentChanged,
    required this.onTapSale,
  });

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 520;

    Widget employeeField() => AppDropdownField<String>(
          label: 'Xodim',
          value: employeeOptions.any((e) => e['value'] == employee) ? employee : 'all',
          variant: AppDropdownVariant.compact,
          enabled: !loading,
          items: employeeOptions
              .map(
                (e) => appDropdownItem(
                  value: e['value']!,
                  label: e['label'] ?? e['value']!,
                ),
              )
              .toList(),
          onChanged: (v) => onEmployeeChanged(v ?? 'all'),
        );

    Widget paymentField() => AppDropdownField<String>(
          label: "To'lov turi",
          value: paymentOptions.any((e) => e['value'] == paymentType) ? paymentType : 'all',
          variant: AppDropdownVariant.compact,
          enabled: !loading,
          items: paymentOptions
              .map(
                (e) => appDropdownItem(
                  value: e['value']!,
                  label: e['label'] ?? e['value']!,
                ),
              )
              .toList(),
          onChanged: (v) => onPaymentChanged(v ?? 'all'),
        );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: narrow
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    employeeField(),
                    const SizedBox(height: 12),
                    paymentField(),
                  ],
                )
              : Row(
                  children: [
                    Expanded(child: employeeField()),
                    const SizedBox(width: 12),
                    Expanded(child: paymentField()),
                  ],
                ),
        ),
        if (loading)
          const Expanded(child: Center(child: CircularProgressIndicator(color: AppTheme.primary)))
        else if (rows.isEmpty)
          const Expanded(child: Center(child: Text('Sotuvlar topilmadi')))
        else
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: rows.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final sale = rows[i];
                final id = (sale['invoice_id'] ?? sale['id'] ?? '—').toString();
                final total = formatShiftMoney(sale['total'] ?? sale['paid_amount']);
                return Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => onTapSale(sale),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Chek #$id', style: const TextStyle(fontWeight: FontWeight.w700)),
                                Text(
                                  '${sale['customer'] ?? '—'} • ${sale['payment_type'] ?? '—'} • ${formatShiftDateTime(sale['date'])}',
                                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                ),
                                if ((sale['created_by'] ?? '').toString().isNotEmpty)
                                  Text('Sotgan: ${sale['created_by']}', style: const TextStyle(fontSize: 12)),
                              ],
                            ),
                          ),
                          Text(total, style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.primary)),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _CashListTab extends StatelessWidget {
  final bool isIncome;
  final List<Map<String, dynamic>> rows;
  final num total;
  final bool canAdd;
  final int? deletingId;
  final VoidCallback onAdd;
  final Future<void> Function(int id) onDelete;

  const _CashListTab({
    required this.isIncome,
    required this.rows,
    required this.total,
    required this.canAdd,
    required this.deletingId,
    required this.onAdd,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (canAdd)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded),
                label: Text(isIncome ? 'Daromad qo\'shish' : 'Xarajat qo\'shish'),
              ),
            ),
          ),
        Expanded(
          child: rows.isEmpty
              ? Center(child: Text(isIncome ? 'Daromadlar yo\'q' : 'Xarajatlar yo\'q'))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final row = rows[i];
                    final id = cashRegisterParseId(row['id']);
                    final busy = id != null && deletingId == id;
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.divider),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text((row['name'] ?? row['note'] ?? '—').toString(), style: const TextStyle(fontWeight: FontWeight.w700)),
                                Text(
                                  '${row[isIncome ? 'income_category_name' : 'expense_category_name'] ?? '—'} • ${row['payment_type_name'] ?? '—'}',
                                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                ),
                                Text(formatShiftDateTime(row['created_at']), style: const TextStyle(fontSize: 12)),
                              ],
                            ),
                          ),
                          Text(
                            formatShiftMoney(row['price']),
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: isIncome ? Colors.green.shade700 : Colors.red.shade700,
                            ),
                          ),
                          if (canAdd && id != null) ...[
                            const SizedBox(width: 8),
                            IconButton(
                              tooltip: 'O\'chirish',
                              onPressed: busy ? null : () => onDelete(id),
                              icon: busy
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : Icon(Icons.delete_outline_rounded, color: Colors.red.shade400),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Row(
            children: [
              const Expanded(child: Text('Jami', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
              Text(
                formatShiftMoney(total),
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: isIncome ? Colors.green.shade700 : Colors.red.shade700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}