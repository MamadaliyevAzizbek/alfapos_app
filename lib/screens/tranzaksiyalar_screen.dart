import 'package:flutter/material.dart';
import '../core/api_sync_throttle.dart';
import '../core/constants.dart';
import '../core/theme.dart';
import '../core/input_formatters.dart';
import '../services/api_service.dart';
import 'api_chek_detail_screen.dart';
import 'desktop/desktop_shell_scope.dart';

class TranzaksiyalarScreen extends StatefulWidget {
  final int tabIndex;
  final int currentIndex;

  const TranzaksiyalarScreen({super.key, this.tabIndex = 3, this.currentIndex = 0});

  @override
  State<TranzaksiyalarScreen> createState() => _TranzaksiyalarScreenState();
}

class _TranzaksiyalarScreenState extends State<TranzaksiyalarScreen> with DesktopShellSyncMixin {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  List<Map<String, dynamic>> _apiSales = [];
  bool _apiLoading = false;
  String? _apiError;

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
      _load(force: false);
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
  Future<void> onDesktopShellSync() => _load();

  /// POST /api/v1/reports/sales — so'nggi 30 kun yoki searchValue bo'lsa qidiruv
  Future<void> _loadApiSales({String? searchValue}) async {
    setState(() {
      _apiError = null;
      _apiLoading = true;
    });
    final now = DateTime.now();
    final to = now.toIso8601String().substring(0, 10);
    final from = now.subtract(const Duration(days: 30)).toIso8601String().substring(0, 10);

    Map<String, dynamic>? res;
    try {
      final body = ReportsApi.salesListBody(
        from: from,
        to: to,
        rowLimit: 200,
        rowOffset: 0,
        columnKey: 'id',
        columnSortedBy: 'DESC',
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
      final mapped = rows
          .where((e) => e is Map)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      // Faqat chek qatorlari; "Umumiy" jami qatorini olib tashlash
      _apiSales = mapped.where((m) {
        final id = m['invoice_id'] ?? m['order_id'] ?? m['id'];
        if (id == null) return false;
        final s = id.toString().trim().toLowerCase();
        return s.isNotEmpty && !s.contains('umumiy');
      }).toList();
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
          Padding(
            padding: const EdgeInsets.all(16),
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
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _filteredSales.length,
                      itemBuilder: (context, index) {
                        final sale = _filteredSales[index];
                        return _ApiSaleTile(
                          sale: sale,
                          onTap: () => _showApiSaleDetail(context, sale),
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
}

class _ApiSaleTile extends StatelessWidget {
  final Map<String, dynamic> sale;
  final VoidCallback onTap;

  const _ApiSaleTile({required this.sale, required this.onTap});

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

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.teal.shade50,
          child: Icon(Icons.cloud_done_rounded, color: Colors.teal.shade700, size: 22),
        ),
        title: Text(
          "Chek #${idStr.startsWith('POS') ? idStr : 'POS$idStr'}",
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text([if (dateStr.isNotEmpty) dateStr, if (customer.isNotEmpty) customer].join(' • ')),
        trailing: Text(
          "${formatThousands(totalInt)} UZS",
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: AppTheme.primary,
            fontSize: 15,
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}
