import 'package:flutter/material.dart';
import '../core/api_sync_throttle.dart';
import '../core/constants.dart';
import '../core/seller_preferences.dart';
import '../core/theme.dart';
import '../core/input_formatters.dart';
import '../services/api_service.dart';
import '../utils/current_employee_sales_filter.dart';
import '../utils/invoice_edit_flow.dart';
import '../utils/invoice_edit_utils.dart';
import '../utils/platform_layout.dart';
import 'api_chek_detail_screen.dart';
import 'desktop/desktop_shell_scope.dart';
import '../widgets/throttled_refresh_indicator.dart';

class TranzaksiyalarScreen extends StatefulWidget {
  final int tabIndex;
  final int currentIndex;
  /// Desktop POS: faqat joriy login xodimining cheklari.
  final bool filterByCurrentEmployee;

  const TranzaksiyalarScreen({
    super.key,
    this.tabIndex = 3,
    this.currentIndex = 0,
    this.filterByCurrentEmployee = false,
  });

  @override
  State<TranzaksiyalarScreen> createState() => _TranzaksiyalarScreenState();
}

class _TranzaksiyalarScreenState extends State<TranzaksiyalarScreen> with DesktopShellSyncMixin {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  List<Map<String, dynamic>> _apiSales = [];
  bool _apiLoading = false;
  String? _apiError;
  int? _employeeFilterUserId;
  String _employeeFilterName = '';

  bool get _filterByEmployee =>
      widget.filterByCurrentEmployee || isDesktopPosLayout;

  bool get _desktop => isDesktopPosLayout;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant TranzaksiyalarScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.tabIndex && widget.currentIndex == widget.tabIndex) {
      _load(force: true);
    }
  }

  /// Chek ID bo'yicha qidirish: POS10033, 10033 — invoice_id yoki id ga moslashtiradi
  static bool _chekMatchesSearch(Map<String, dynamic> sale, String query) {
    final q = query.trim().replaceFirst(RegExp(r'^POS', caseSensitive: false), '').trim();
    if (q.isEmpty) return true;
    final invId = (sale['invoice_id'] ?? sale['invoiceId'] ?? '').toString().trim();
    final orderId = (sale['order_id'] ?? sale['id'] ?? '').toString().trim();
    final invNorm = invId.replaceFirst(RegExp(r'^POS', caseSensitive: false), '').trim();
    final orderNorm = orderId.trim();
    if (invNorm.contains(q) || invId.toLowerCase().contains(query.trim().toLowerCase())) return true;
    if (orderNorm.contains(q) || orderId.contains(query.trim())) return true;
    return false;
  }

  List<Map<String, dynamic>> get _filteredSales {
    if (_searchQuery.trim().isEmpty) return _apiSales;
    return _apiSales.where((m) => _chekMatchesSearch(m, _searchQuery)).toList();
  }

  Future<void> _load({bool force = false}) async {
    if (!force &&
        !ApiSyncThrottle.shouldRun('transactions_sales_list', const Duration(minutes: 2))) {
      return;
    }
    if (!force) ApiSyncThrottle.markRan('transactions_sales_list');
    await _loadApiSales();
    if (!mounted) return;
    setState(() {});
  }

  @override
  Future<void> onDesktopShellSync() => _load(force: true);

  /// POST /api/v1/reports/sales — so'nggi 30 kun yoki searchValue bo'lsa qidiruv
  Future<void> _loadApiSales({String? searchValue}) async {
    setState(() {
      _apiError = null;
      _apiLoading = true;
    });
    final now = DateTime.now();
    final to = now.toIso8601String().substring(0, 10);
    final from = now.subtract(const Duration(days: 30)).toIso8601String().substring(0, 10);

    int? employeeId;
    String sellerName = '';
    if (_filterByEmployee) {
      employeeId = await CurrentEmployeeSalesFilter.resolveEmployeeFilterId();
      sellerName = (await getSellerName()).trim();
      _employeeFilterUserId = employeeId;
      _employeeFilterName = sellerName;
    }

    Map<String, dynamic>? res;
    try {
      final body = ReportsApi.salesListBody(
        from: from,
        to: to,
        rowLimit: 200,
        rowOffset: 0,
        columnKey: 'id',
        columnSortedBy: 'DESC',
        employeeId: employeeId,
      );
      if (searchValue != null && searchValue.trim().isNotEmpty) {
        body['searchValue'] = searchValue.trim();
      }
      res = await ReportsApi.getSales(body: body);
    } catch (e) {
      _apiError = e.toString();
      res = null;
    }

    if (res != null) {
      List<dynamic> rows = res['datarows'] as List<dynamic>? ?? res['data'] as List<dynamic>? ?? [];
      if (rows.isEmpty && res['data'] is Map) {
        final inner = res['data'] as Map;
        rows = inner['datarows'] as List<dynamic>? ?? inner['rows'] as List<dynamic>? ?? [];
      }
      var mapped = rows
          .where((e) => e is Map)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      mapped = mapped.where((m) {
        final id = m['invoice_id'] ?? m['order_id'] ?? m['id'];
        if (id == null) return false;
        final s = id.toString().trim().toLowerCase();
        return s.isNotEmpty && !s.contains('umumiy');
      }).toList();
      if (_filterByEmployee) {
        mapped = mapped
            .where((m) => CurrentEmployeeSalesFilter.saleBelongsToUser(
                  m,
                  userId: employeeId ?? _employeeFilterUserId,
                  sellerName: sellerName.isNotEmpty ? sellerName : _employeeFilterName,
                ))
            .toList();
      }
      _apiSales = mapped;
      _apiError = null;
    } else {
      _apiSales = [];
    }
    if (mounted) setState(() => _apiLoading = false);
  }

  int get _displayCount => _filteredSales.length;

  @override
  Widget build(BuildContext context) {
    final count = _displayCount;
    if (_desktop) return _buildDesktopScaffold(count);
    return _buildMobileScaffold(count);
  }

  Widget _buildDesktopScaffold(int count) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: AppTheme.divider)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: TextField(
                      controller: _searchController,
                      onChanged: (v) => setState(() => _searchQuery = v),
                      style: const TextStyle(fontSize: 15),
                      decoration: InputDecoration(
                        hintText: "Chek ID (POS10033 yoki 10033)",
                        prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.primary),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppTheme.divider),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppTheme.divider),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                if (count > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.primary.withValues(alpha: 0.25)),
                    ),
                    child: Text(
                      '$count ta chek',
                      style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.primary),
                    ),
                  ),
              ],
            ),
          ),
          if (_filterByEmployee)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blue.shade100),
                ),
                child: Row(
                  children: [
                    Icon(Icons.person_outline_rounded, color: Colors.blue.shade800, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _employeeFilterName.isNotEmpty && _employeeFilterName != 'Sotuvchi'
                            ? "Faqat sizning cheklaringiz: $_employeeFilterName"
                            : "Faqat sizning cheklaringiz",
                        style: TextStyle(fontSize: 13, color: Colors.blue.shade900, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_apiError != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  "API dan savdolar yuklanmadi. Sana yoki tarmoqni tekshiring.",
                  style: TextStyle(fontSize: 13, color: Colors.orange.shade900),
                ),
              ),
            ),
          Expanded(child: _buildDesktopTable()),
        ],
      ),
    );
  }

  Widget _buildDesktopTable() {
    final list = _filteredSales;
    if (_apiLoading && _apiSales.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    }
    if (list.isEmpty) {
      return Center(
        child: Text(
          _searchQuery.trim().isEmpty ? "Sotuvlar yo'q" : "«$_searchQuery» bo'yicha chek topilmadi",
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 15),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppTheme.divider),
          borderRadius: BorderRadius.circular(8),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Column(
            children: [
              Container(
                color: const Color(0xFFF8FAFC),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: const Row(
                  children: [
                    Expanded(flex: 2, child: Text('SANA', style: _thStyle)),
                    Expanded(flex: 3, child: Text('CHEK', style: _thStyle)),
                    Expanded(flex: 3, child: Text('MIJOZ', style: _thStyle)),
                    Expanded(
                      flex: 2,
                      child: Text('SUMMA', style: _thStyle, textAlign: TextAlign.end),
                    ),
                    SizedBox(
                      width: 72,
                      child: Text('AMAL', style: _thStyle, textAlign: TextAlign.center),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ThrottledRefreshIndicator(
                  onRefresh: () => _load(force: true),
                  child: ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (context, index) {
                      final sale = list[index];
                      return _DesktopSaleRow(
                        sale: sale,
                        index: index,
                        showEditButton: canShowInvoiceEditButton(sale),
                        showDateEditButton: canShowInvoiceDateEditButton(sale),
                        onTap: () => _showApiSaleDetail(context, sale),
                        onEdit: canShowInvoiceEditButton(sale)
                            ? () => _startEditSale(context, sale)
                            : null,
                        onEditDate: canShowInvoiceDateEditButton(sale)
                            ? () => _editSaleDate(context, sale)
                            : null,
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static const _thStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    color: AppTheme.textSecondary,
    letterSpacing: 0.4,
  );

  Widget _buildMobileScaffold(int count) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text(Strings.tranzaksiyalar),
            if (count > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.cardBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ],
        ),
      ),
      body: Column(
        children: [
          if (_filterByEmployee)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blue.shade100),
                ),
                child: Row(
                  children: [
                    Icon(Icons.person_outline_rounded, color: Colors.blue.shade800, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _employeeFilterName.isNotEmpty && _employeeFilterName != 'Sotuvchi'
                            ? "Faqat sizning cheklaringiz: $_employeeFilterName"
                            : "Faqat sizning cheklaringiz",
                        style: TextStyle(fontSize: 13, color: Colors.blue.shade900, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(16, _filterByEmployee ? 12 : 16, 16, 0),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: "Chek ID bo'yicha qidirish (masalan: POS10033 yoki 10033)",
                prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.primary, size: 22),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          if (_apiError != null)
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
                        "API dan savdolar yuklanmadi. Sana yoki tarmoqni tekshiring.",
                        style: TextStyle(fontSize: 12, color: Colors.orange.shade900),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_apiLoading && _apiSales.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
            ),
          Expanded(
            child: count == 0 && !_apiLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.receipt_long_rounded,
                          size: 80,
                          color: AppTheme.textSecondary.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          Strings.sotishYoq,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _searchQuery.trim().isEmpty
                              ? "Sotuvlar yo'q"
                              : "«$_searchQuery» bo'yicha chek topilmadi",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: AppTheme.textSecondary.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                  )
                : ThrottledRefreshIndicator(
                    onRefresh: () => _load(force: true),
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _filteredSales.length,
                      itemBuilder: (context, index) {
                        final sale = _filteredSales[index];
                        final showEdit = canShowInvoiceEditButton(sale);
                        final showDateEdit = canShowInvoiceDateEditButton(sale);
                        return _ApiSaleTile(
                          sale: sale,
                          showEditButton: showEdit,
                          showDateEditButton: showDateEdit,
                          onTap: () => _showApiSaleDetail(context, sale),
                          onEdit: showEdit ? () => _startEditSale(context, sale) : null,
                          onEditDate: showDateEdit ? () => _editSaleDate(context, sale) : null,
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  void _showApiSaleDetail(BuildContext context, Map<String, dynamic> sale) async {
    final orderId = getOrderIdFromSale(sale);
    if (orderId == null) return;
    Map<String, dynamic> detail = {};
    String? loadError;
    try {
      detail = await ReportsApi.getInvoiceDetails(orderId);
    } catch (e) {
      loadError = e.toString().replaceFirst('Exception: ', '');
      try {
        final now = DateTime.now();
        final to = now.toIso8601String().substring(0, 10);
        final from = now.subtract(const Duration(days: 30)).toIso8601String().substring(0, 10);
        final invoice = (sale['invoice_id'] ?? sale['order_id'] ?? sale['id'] ?? '').toString();
        detail = await ReportsApi.getSalesAllDetails(
          body: ReportsApi.salesAllDetailsBody(
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
    if (returned == true && mounted) _loadApiSales();
  }

  Future<void> _startEditSale(BuildContext context, Map<String, dynamic> sale) async {
    final ok = await InvoiceEditFlow.startFullEdit(context, sale);
    if (ok && mounted) {
      ApiSyncThrottle.invalidate('transactions_sales_list');
    }
  }

  Future<void> _editSaleDate(BuildContext context, Map<String, dynamic> sale) async {
    final ok = await InvoiceEditFlow.editSaleDate(context, sale);
    if (ok && mounted) {
      ApiSyncThrottle.invalidate('transactions_sales_list');
      await _loadApiSales();
      if (mounted) setState(() {});
    }
  }
}

class _DesktopSaleRow extends StatelessWidget {
  final Map<String, dynamic> sale;
  final int index;
  final VoidCallback onTap;
  final bool showEditButton;
  final bool showDateEditButton;
  final VoidCallback? onEdit;
  final VoidCallback? onEditDate;

  const _DesktopSaleRow({
    required this.sale,
    required this.index,
    required this.onTap,
    this.showEditButton = false,
    this.showDateEditButton = false,
    this.onEdit,
    this.onEditDate,
  });

  @override
  Widget build(BuildContext context) {
    final id = sale['order_id'] ?? sale['invoice_id'] ?? sale['id'] ?? '—';
    final idStr = id.toString();
    final chek = idStr.startsWith('POS') ? idStr : 'POS$idStr';
    final totalInt = parseAmountFromApi(sale['total'] ?? sale['grand_total'] ?? sale['total_amount'] ?? sale['sum']);
    String customer = '—';
    final c = sale['customer'];
    if (c is String && c.trim().isNotEmpty) {
      customer = c;
    } else if (c is Map) {
      final n = (c['name'] ?? c['first_name'] ?? '').toString().trim();
      if (n.isNotEmpty) customer = n;
    }
    final dateRaw = sale['created_at'] ?? sale['date'] ?? sale['invoice_date'] ?? sale['order_date'] ?? '';
    final dateStr = dateRaw.toString().length >= 10 ? dateRaw.toString().substring(0, 10) : '—';
    final bg = index.isEven ? Colors.white : const Color(0xFFFAFBFC);

    return Material(
      color: bg,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppTheme.divider)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(dateStr, style: const TextStyle(fontSize: 15, color: AppTheme.textSecondary)),
              ),
              Expanded(
                flex: 3,
                child: Text(chek, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  customer,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  '${formatThousands(totalInt)} UZS',
                  textAlign: TextAlign.end,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.primary),
                ),
              ),
              SizedBox(
                width: 72,
                child: Center(
                  child: (showEditButton || showDateEditButton)
                      ? PopupMenuButton<String>(
                          tooltip: 'Amallar',
                          icon: Icon(Icons.more_vert_rounded, color: Colors.grey.shade700, size: 22),
                          onSelected: (value) {
                            if (value == 'edit') onEdit?.call();
                            if (value == 'date') onEditDate?.call();
                          },
                          itemBuilder: (ctx) => [
                            if (showEditButton)
                              const PopupMenuItem(
                                value: 'edit',
                                child: Text('Chekni tahrirlash'),
                              ),
                            if (showDateEditButton)
                              const PopupMenuItem(
                                value: 'date',
                                child: Text('Sanani tahrirlash'),
                              ),
                          ],
                        )
                      : Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ApiSaleTile extends StatelessWidget {
  final Map<String, dynamic> sale;
  final VoidCallback onTap;
  final bool showEditButton;
  final bool showDateEditButton;
  final VoidCallback? onEdit;
  final VoidCallback? onEditDate;

  const _ApiSaleTile({
    required this.sale,
    required this.onTap,
    this.showEditButton = false,
    this.showDateEditButton = false,
    this.onEdit,
    this.onEditDate,
  });

  @override
  Widget build(BuildContext context) {
    final id = sale['order_id'] ?? sale['invoice_id'] ?? sale['id'] ?? '—';
    final idStr = id.toString();
    final totalInt = parseAmountFromApi(sale['total'] ?? sale['grand_total'] ?? sale['total_amount'] ?? sale['sum']);
    String customer = '';
    final c = sale['customer'];
    if (c is String) customer = c;
    else if (c is Map) customer = (c['name'] ?? c['first_name'] ?? '').toString();
    final dateRaw = sale['created_at'] ?? sale['date'] ?? sale['invoice_date'] ?? sale['order_date'] ?? '';
    final dateStr = dateRaw.toString().length >= 10 ? dateRaw.toString().substring(0, 10) : '';

    final isEdited = sale['is_invoice_edited'] == 1 ||
        sale['is_invoice_edited'] == true ||
        sale['is_invoice_edited'] == '1';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isEdited ? Colors.blue.shade50 : Colors.teal.shade50,
          child: Icon(
            isEdited ? Icons.edit_note_rounded : Icons.receipt_long_rounded,
            color: isEdited ? Colors.blue.shade700 : Colors.teal.shade700,
            size: 22,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                "Chek #${idStr.startsWith('POS') ? idStr : 'POS$idStr'}",
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            if (isEdited)
              Container(
                margin: const EdgeInsets.only(left: 6),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.blue.shade100),
                ),
                child: Text(
                  'Tahrir',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.blue.shade800),
                ),
              ),
          ],
        ),
        subtitle: Text([if (dateStr.isNotEmpty) dateStr, if (customer.isNotEmpty) customer].join(' • ')),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "${formatThousands(totalInt)} UZS",
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppTheme.primary,
                fontSize: 15,
              ),
            ),
            if (showEditButton || showDateEditButton) ...[
              const SizedBox(width: 4),
              PopupMenuButton<String>(
                tooltip: 'Amallar',
                icon: Icon(Icons.more_vert_rounded, color: Colors.grey.shade700, size: 22),
                onSelected: (value) {
                  if (value == 'edit') onEdit?.call();
                  if (value == 'date') onEditDate?.call();
                },
                itemBuilder: (ctx) => [
                  if (showEditButton)
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_rounded, size: 20),
                          SizedBox(width: 10),
                          Text('Chekni tahrirlash'),
                        ],
                      ),
                    ),
                  if (showDateEditButton)
                    const PopupMenuItem(
                      value: 'date',
                      child: Row(
                        children: [
                          Icon(Icons.calendar_month_rounded, size: 20),
                          SizedBox(width: 10),
                          Text('Sanani tahrirlash'),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}
