import 'package:flutter/material.dart';
import 'dart:convert';
import '../core/theme.dart';
import '../core/input_formatters.dart';
import '../services/api_service.dart';
import '../services/reports_repository.dart';
import '../widgets/app_dropdown.dart';
import 'api_chek_detail_screen.dart';
import '../widgets/ios_style_modals.dart';
import 'desktop/desktop_shell_scope.dart';
import '../widgets/throttled_refresh_indicator.dart';

/// API reports (reports/sales) — hisobotlar ekrani
class HisobotlarScreen extends StatefulWidget {
  const HisobotlarScreen({super.key});

  @override
  State<HisobotlarScreen> createState() => _HisobotlarScreenState();
}

class _HisobotlarScreenState extends State<HisobotlarScreen> with DesktopShellSyncMixin {
  DateTime _dateFrom = DateTime.now().subtract(const Duration(days: 30));
  DateTime _dateTo = DateTime.now();
  final TextEditingController _searchController = TextEditingController();
  String _searchValue = '';
  String _reportType = 'sales';
  String _paymentType = 'all';
  String _employee = 'all';
  final List<Map<String, String>> _typeOptions = const [
    {'value': 'sales', 'label': 'Sotuv'},
    {'value': 'receiving', 'label': 'Kirim'},
  ];
  List<Map<String, String>> _paymentTypeOptions = const [{'value': 'all', 'label': 'Barchasi'}];
  List<Map<String, String>> _employeeOptions = const [{'value': 'all', 'label': 'Barchasi'}];
  List<Map<String, dynamic>> _rows = [];
  bool _loading = false;
  bool _loadingFilters = false;
  String? _error;
  int _totalUzs = 0;
  Map<String, dynamic>? _lastSalesResponse;
  Map<String, dynamic>? _lastFilterResponse;
  Map<String, dynamic>? _lastSummaryResponse;
  Map<String, dynamic>? _lastPaymentTypesResponse;
  Map<String, dynamic>? _lastSalesRequestBody;
  Map<String, dynamic>? _lastSummaryRequestBody;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _toYmd(DateTime d) => d.toIso8601String().substring(0, 10);

  String _prettyPaymentLabel(String rawValue, String rawLabel) {
    final v = rawValue.trim().toLowerCase();
    if (v == 'all') return 'Hammasi';
    if (rawLabel.trim().isNotEmpty) return rawLabel.trim();
    if (v == 'cash' || v == 'naqd') return "Naqd pul";
    if (v == 'card' || v == 'karta') return 'Karta';
    if (v == 'click') return 'Click';
    if (v == 'payme') return 'Payme';
    return rawValue;
  }

  String _prettyEmployeeLabel(String rawValue, String rawLabel) {
    final label = rawLabel.trim();
    if (label.isNotEmpty) return label;
    return rawValue.trim().isEmpty ? 'Xodim' : rawValue;
  }

  List<Map<String, String>> _extractFilterOptions(dynamic raw, {required String fallbackLabelPrefix}) {
    if (raw is! List) return const [];
    final out = <Map<String, String>>[];
    for (final e in raw) {
      if (e is! Map) continue;
      final m = Map<String, dynamic>.from(e);
      final v = (m['value'] ?? m['id'] ?? m['key'] ?? m['code'] ?? m['name'] ?? '').toString().trim();
      if (v.isEmpty) continue;
      final rawLabel = (m['text'] ?? m['label'] ?? m['name'] ?? m['title'] ?? '$fallbackLabelPrefix $v').toString().trim();
      final label = fallbackLabelPrefix == 'Payment'
          ? _prettyPaymentLabel(v, rawLabel)
          : _prettyEmployeeLabel(v, rawLabel);
      out.add({'value': v, 'label': label});
    }
    return out;
  }

  Future<void> _loadFilters() async {
    setState(() => _loadingFilters = true);
    try {
      final res = await ReportsRepository.instance.getSalesFilter();
      _lastFilterResponse = res;
      final data = res['data'] is Map ? Map<String, dynamic>.from(res['data'] as Map) : res;
      final employeeRaw = data['employee'] ?? data['employees'] ?? data['user'] ?? data['users'];
      final paymentRes = await SalesApi.getPaymentTypes();
      _lastPaymentTypesResponse = paymentRes;
      final paymentData = paymentRes['data'] ?? paymentRes['payment_types'] ?? paymentRes;
      final paymentParsed = _extractFilterOptions(paymentData, fallbackLabelPrefix: 'Payment');
      final employeeParsed = _extractFilterOptions(employeeRaw, fallbackLabelPrefix: 'Employee');
      if (!mounted) return;
      setState(() {
        _paymentTypeOptions = [
          const {'value': 'all', 'label': 'Barchasi'},
          ...paymentParsed,
        ];
        _employeeOptions = [
          const {'value': 'all', 'label': 'Barchasi'},
          ...employeeParsed,
        ];
        if (!_paymentTypeOptions.any((e) => e['value'] == _paymentType)) _paymentType = 'all';
        if (!_employeeOptions.any((e) => e['value'] == _employee)) _employee = 'all';
      });
    } catch (_) {
      // Filter endpoint xato bersa, default "Barchasi" bilan davom etamiz.
    } finally {
      if (mounted) setState(() => _loadingFilters = false);
    }
  }

  Map<String, dynamic> _salesRequestBody({required String from, required String to}) {
    final body = ReportsRepository.salesListBody(
      from: from,
      to: to,
      rowLimit: 200,
      rowOffset: 0,
      columnKey: 'id',
      columnSortedBy: 'DESC',
      searchValue: _searchValue.trim(),
    );
    body['reqType'] = _reportType;
    final filters = List<Map<String, dynamic>>.from((body['filtersData'] as List<dynamic>? ?? const []));
    if (_paymentType.trim().isNotEmpty && _paymentType.toLowerCase() != 'all') {
      filters.add({'key': 'payment_type', 'value': _paymentType});
    }
    if (_employee.trim().isNotEmpty && _employee.toLowerCase() != 'all') {
      filters.add({'key': 'employee', 'value': _employee});
    }
    body['filtersData'] = filters;
    return body;
  }

  @override
  Future<void> onDesktopShellSync() async {
    await _loadFilters();
    await _load();
  }

  /// MOBILE_API.md bo‘yicha: POST /api/v1/reports/sales, body: filtersData, rowLimit, rowOffset
  Future<void> _load() async {
    setState(() {
      _error = null;
      _loading = true;
      _rows = [];
      _totalUzs = 0;
    });
    final from = _toYmd(_dateFrom);
    final to = _toYmd(_dateTo);

    Map<String, dynamic>? res;
    Map<String, dynamic>? summaryRes;
    try {
      final salesBody = _salesRequestBody(from: from, to: to);
      final summaryBody = ReportsRepository.salesSummaryBody(
        from: from,
        to: to,
        rowLimit: 200,
        rowOffset: 0,
        columnKey: 'id',
        columnSortedBy: 'DESC',
        searchValue: _searchValue.trim(),
      );
      summaryBody['reqType'] = _reportType;
      final summaryFilters = List<Map<String, dynamic>>.from((summaryBody['filtersData'] as List<dynamic>? ?? const []));
      if (_paymentType.trim().isNotEmpty && _paymentType.toLowerCase() != 'all') {
        summaryFilters.add({'key': 'payment_type', 'value': _paymentType});
      }
      if (_employee.trim().isNotEmpty && _employee.toLowerCase() != 'all') {
        summaryFilters.add({'key': 'employee', 'value': _employee});
      }
      summaryBody['filtersData'] = summaryFilters;
      _lastSalesRequestBody = Map<String, dynamic>.from(salesBody);
      _lastSummaryRequestBody = Map<String, dynamic>.from(summaryBody);
      res = await ReportsRepository.instance.getSales(body: salesBody);
      summaryRes = await ReportsRepository.instance.getSalesSummary(
        body: summaryBody,
      );
      _lastSalesResponse = res;
      _lastSummaryResponse = summaryRes;
    } catch (_) {
      res = null;
      summaryRes = null;
    }

    if (!mounted) return;
    if (res == null) {
      setState(() {
        _loading = false;
        _error = "API dan hisobot yuklanmadi";
      });
      return;
    }

    // Javob: datarows, count (MOBILE_API.md)
    List<dynamic> list = res['datarows'] as List<dynamic>? ?? res['data'] as List<dynamic>? ?? [];
    if (list.isEmpty && res['data'] is Map) {
      final inner = res['data'] as Map;
      list = inner['datarows'] as List<dynamic>? ?? inner['rows'] as List<dynamic>? ?? [];
    }

    final allRows = list
        .where((e) => e is Map)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    // Faqat chek qatorlari (invoice_id / order_id / id bor); "Umumiy" jami qatorini olib tashlash
    final rows = allRows.where((m) {
      final id = m['invoice_id'] ?? m['order_id'] ?? m['id'];
      if (id == null) return false;
      final s = id.toString().trim().toLowerCase();
      if (s.isEmpty || s.contains('umumiy')) return false;
      return true;
    }).toList();

    // Agar filter endpoint payment type qaytarmasa, ro'yxatdan usullarni yig'ib dropdownni to'ldiramiz.
    if (_paymentTypeOptions.length <= 1 && rows.isNotEmpty) {
      final seen = <String>{'all'};
      final dynamicOptions = <Map<String, String>>[const {'value': 'all', 'label': 'Hammasi'}];
      for (final r in rows) {
        final raw = (r['payment_method'] ?? r['payment_type'] ?? r['method'] ?? '').toString().trim();
        if (raw.isEmpty) continue;
        final v = raw.toLowerCase();
        if (seen.contains(v)) continue;
        seen.add(v);
        dynamicOptions.add({'value': v, 'label': _prettyPaymentLabel(v, raw)});
      }
      _paymentTypeOptions = dynamicOptions;
    }

    int total = 0;
    for (final r in rows) {
      total += parseAmountFromApi(r['total'] ?? r['grand_total'] ?? r['total_amount'] ?? r['sum']);
    }
    if (summaryRes != null) {
      final maybeTotal = parseAmountFromApi(
        summaryRes['grand_total'] ??
            summaryRes['total'] ??
            summaryRes['sum'] ??
            (summaryRes['data'] is Map ? (summaryRes['data'] as Map)['total'] : null),
      );
      if (maybeTotal > 0) total = maybeTotal;
    }

    setState(() {
      _rows = rows;
      _totalUzs = total;
      _loading = false;
      _error = null;
    });
  }

  String _dateStr(DateTime d) {
    return "${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}";
  }

  void _showApiDebugDialog() {
    final payload = <String, dynamic>{
      'filters_request_preview': {
        'from': _toYmd(_dateFrom),
        'to': _toYmd(_dateTo),
        'report_type': _reportType,
        'searchValue': _searchValue,
        'payment_type': _paymentType,
        'employee': _employee,
      },
      'sales_request_body': _lastSalesRequestBody ?? {'note': 'Hali yuborilmagan'},
      'sales_summary_request_body': _lastSummaryRequestBody ?? {'note': 'Hali yuborilmagan'},
      'sales_filter_response': _lastFilterResponse ?? {'note': 'Hali yuklanmagan'},
      'sales_payment_types_response': _lastPaymentTypesResponse ?? {'note': 'Hali yuklanmagan'},
      'sales_response': _lastSalesResponse ?? {'note': 'Hali yuklanmagan'},
      'sales_summary_response': _lastSummaryResponse ?? {'note': 'Hali yuklanmagan'},
    };
    final pretty = const JsonEncoder.withIndent('  ').convert(payload);
    if (!mounted) return;
    IosStyleModals.showSheet<void>(
      context: context,
      isScrollControlled: true,
      showGrabber: true,
      child: Builder(
        builder: (ctx) => SizedBox(
          height: MediaQuery.sizeOf(ctx).height * 0.75,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Text("Hisobotlar API javobi", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
              ),
              const Divider(height: 1),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: SelectableText(
                    pretty,
                    style: const TextStyle(fontSize: 12, height: 1.35),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("Yopish"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// MOBILE_API.md: POST /api/v1/reports/sales/invoice-details/{id} — chek batafsil (to'liq ekran).
  /// API xato bersa ham ro'yxatdagi chek ma'lumotlari (sale) bilan ekran ochiladi.
  Future<void> _showInvoiceDetail(BuildContext context, Map<String, dynamic> sale) async {
    final orderId = getOrderIdFromSale(sale);
    if (orderId == null) return;
    Map<String, dynamic> detail = {};
    String? loadError;
    try {
      detail = await ReportsRepository.instance.getInvoiceDetails(orderId);
    } catch (e) {
      loadError = e.toString().replaceFirst('Exception: ', '');
      try {
        final now = DateTime.now();
        final to = now.toIso8601String().substring(0, 10);
        final from = now.subtract(const Duration(days: 30)).toIso8601String().substring(0, 10);
        final invoice = (sale['invoice_id'] ?? sale['order_id'] ?? sale['id'] ?? '').toString();
        detail = await ReportsRepository.instance.getSalesAllDetails(
          body: ReportsRepository.salesAllDetailsBody(
            from: from,
            to: to,
            rowLimit: 200,
            rowOffset: 0,
            searchValue: invoice,
          ),
        );
      } catch (_) {
        detail = {};
      }
    }
    if (!context.mounted) return;
    final returned = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ApiChekDetailScreen(sale: sale, invoiceDetail: detail, invoiceLoadError: loadError),
      ),
    );
    if (returned == true && mounted) _load();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadFilters();
      await _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hisobotlar'),
        actions: [
          IconButton(
            tooltip: 'API javobi',
            onPressed: _showApiDebugDialog,
            icon: const Icon(Icons.data_object_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _DateChip(
                        label: '${_dateStr(_dateFrom)} - ${_dateStr(_dateTo)}',
                        onTap: () async {
                          final from = await showDatePicker(
                            context: context,
                            initialDate: _dateFrom,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (from == null || !mounted) return;
                          setState(() => _dateFrom = from);
                          final to = await showDatePicker(
                            context: context,
                            initialDate: _dateTo.isBefore(_dateFrom) ? _dateFrom : _dateTo,
                            firstDate: _dateFrom,
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (to != null && mounted) {
                            setState(() => _dateTo = to);
                          }
                          _load();
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _searchValue = v),
                  onSubmitted: (_) => _load(),
                  decoration: InputDecoration(
                    hintText: "Qidirish",
                    prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.primary),
                    suffixIcon: _searchValue.trim().isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchValue = '');
                              _load();
                            },
                            icon: const Icon(Icons.clear_rounded),
                          ),
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _FilterDropdown(
                        label: "Turi",
                        value: _reportType,
                        loading: _loadingFilters,
                        options: _typeOptions,
                        onChanged: (v) {
                          setState(() => _reportType = v);
                          _load();
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _FilterDropdown(
                        label: "To'lov usuli",
                        value: _paymentType,
                        loading: _loadingFilters,
                        options: _paymentTypeOptions,
                        onChanged: (v) {
                          setState(() => _paymentType = v);
                          _load();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: Colors.orange.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(fontSize: 13, color: Colors.orange.shade900),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_loading && _rows.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
            )
          else ...[
            if (_rows.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLight.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Jami (${_rows.length} ta)",
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        "${formatThousands(_totalUzs)} UZS",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: ThrottledRefreshIndicator(
                onRefresh: _load,
                child: _rows.isEmpty && !_loading
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(height: MediaQuery.sizeOf(context).height * 0.2),
                          Icon(
                            Icons.assessment_rounded,
                            size: 64,
                            color: AppTheme.textSecondary.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _error == null ? "Bu davr uchun savdolar yo'q" : "Pastga tortib yangilang",
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 15,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      )
                    : ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _rows.length,
                        itemBuilder: (context, index) {
                          final sale = _rows[index];
                          return _ReportSaleTile(
                            sale: sale,
                            onTap: () => _showInvoiceDetail(context, sale),
                          );
                        },
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _DateChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.cardBg,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.calendar_today_rounded, size: 20, color: AppTheme.primary),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  final String label;
  final String value;
  final bool loading;
  final List<Map<String, String>> options;
  final ValueChanged<String> onChanged;

  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.loading,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AppDropdownField<String>(
      label: label,
      value: options.any((e) => e['value'] == value) ? value : options.first['value'],
      variant: AppDropdownVariant.compact,
      enabled: !loading,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      items: options
          .map(
            (e) => appDropdownItem(
              value: e['value']!,
              label: e['label'] ?? e['value'] ?? '',
            ),
          )
          .toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}

class _ReportSaleTile extends StatelessWidget {
  final Map<String, dynamic> sale;
  final VoidCallback? onTap;

  const _ReportSaleTile({required this.sale, this.onTap});

  @override
  Widget build(BuildContext context) {
    // MOBILE_API.md: har qatorda invoice_id, customer, total (string "20000.00" yoki son)
    final id = sale['invoice_id'] ?? sale['order_id'] ?? sale['id'] ?? '—';
    final idStr = id.toString();
    final totalInt = parseAmountFromApi(sale['total'] ?? sale['grand_total'] ?? sale['total_amount'] ?? sale['sum']);
    String customer = '';
    final c = sale['customer'];
    if (c is String) {
      customer = c;
    } else if (c is Map) {
      customer = (c['name'] ?? c['first_name'] ?? c['last_name'] ?? '').toString().trim();
      if (customer.isEmpty && (c['first_name'] != null || c['last_name'] != null)) {
        customer = '${c['first_name'] ?? ''} ${c['last_name'] ?? ''}'.trim();
      }
    }
    final dateRaw = sale['created_at'] ?? sale['date'] ?? sale['invoice_date'] ?? sale['order_date'] ?? '';
    final dateStr = dateRaw.toString().length >= 10 ? dateRaw.toString().substring(0, 10) : '';
    final method = (sale['payment_method'] ?? sale['payment_type'] ?? sale['method'] ?? sale['usul'] ?? '').toString().trim();
    final paidBy = (sale['paid_by'] ?? sale['to_lov_amalga_oshirgan'] ?? sale['payer'] ?? customer).toString().trim();
    final user = (sale['created_by'] ?? sale['employee'] ?? sale['user_name'] ?? '').toString().trim();
    final details = <String>[
      if (dateStr.isNotEmpty) 'Sana: $dateStr',
      if (method.isNotEmpty) "Usul: $method",
      if (paidBy.isNotEmpty) "To'lov qilgan: $paidBy",
      if (user.isNotEmpty) 'Foydalanuvchi: $user',
    ];

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.teal.shade50,
          child: Icon(Icons.receipt_long_rounded, color: Colors.teal.shade700, size: 22),
        ),
        title: Text(
          "Chek #$idStr",
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          details.join('  •  '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Text(
          "${formatThousands(totalInt)} UZS",
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: AppTheme.primary,
            fontSize: 14,
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}
