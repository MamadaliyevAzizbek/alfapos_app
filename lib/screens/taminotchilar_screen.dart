import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_notify.dart';
import '../core/constants.dart';
import '../core/input_formatters.dart';
import '../core/theme.dart';
import '../models/supplier.dart';
import '../services/api_service.dart';
import '../widgets/ios_style_modals.dart';
import '../widgets/throttled_refresh_indicator.dart';
import 'taminotchi_detail_screen.dart';
import 'taminotchi_form_screen.dart';

/// Taminotchilar ro‘yxati — POST /api/v1/contacts/suppliers.
class TaminotchilarScreen extends StatefulWidget {
  const TaminotchilarScreen({super.key});

  @override
  State<TaminotchilarScreen> createState() => _TaminotchilarScreenState();
}

class _TaminotchilarScreenState extends State<TaminotchilarScreen> {
  static const int _pageSize = 40;

  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  Timer? _searchDebounce;

  int _requestSeq = 0;
  bool _loading = true;
  bool _querying = false;
  bool _loadingMore = false;
  bool _hasMore = false;
  bool _hasSearchText = false;
  String? _error;
  String _appliedQuery = '';
  List<Supplier> _items = [];
  SupplierListTotals _totals = const SupplierListTotals();

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    _searchCtrl.addListener(() {
      final has = _searchCtrl.text.isNotEmpty;
      if (has != _hasSearchText) setState(() => _hasSearchText = has);
    });
    _load();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _scrollCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetch({bool more = false}) async {
    final seq = ++_requestSeq;
    final query = _searchCtrl.text.trim();
    final res = await ContactsApi.getSuppliers(body: {
      'columnKey': 'id',
      'columnSortedBy': 'DESC',
      'rowOffset': more ? _items.length : 0,
      'rowLimit': _pageSize,
      'filtersData': <dynamic>[],
      'searchValue': query,
      'reqType': '',
    });
    if (seq != _requestSeq || !mounted) return;

    final page = Supplier.listFromResponse(res);
    final totals = SupplierListTotals.fromResponse(res);
    final items = more ? <Supplier>[..._items, ...page] : page;

    _items = items;
    _totals = totals;
    _appliedQuery = query;
    _hasMore = page.length >= _pageSize &&
        (totals.count <= 0 || items.length < totals.count);
  }

  Future<void> _load() async {
    setState(() {
      if (_items.isEmpty) _loading = true;
      _querying = true;
      _error = null;
    });
    try {
      await _fetch();
    } catch (e) {
      _error = e.toString();
      if (_items.isEmpty) _items = [];
    }
    if (mounted) {
      setState(() {
        _loading = false;
        _querying = false;
      });
    }
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients || !_hasMore || _loadingMore || _querying) {
      return;
    }
    final pos = _scrollCtrl.position;
    if (pos.pixels >= pos.maxScrollExtent - 300) _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      await _fetch(more: true);
    } catch (e) {
      if (mounted) AppNotify.error(context, '$e');
    }
    if (mounted) setState(() => _loadingMore = false);
  }

  void _onSearchChanged(String _) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      if (_searchCtrl.text.trim() == _appliedQuery) return;
      _load();
    });
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    if (_searchCtrl.text.isEmpty && _appliedQuery.isEmpty) return;
    _searchCtrl.clear();
    _load();
  }

  Future<void> _openCreate() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const TaminotchiFormScreen()),
    );
    if (created == true && mounted) _load();
  }

  Future<void> _openDetail(Supplier supplier, {bool openPayment = false}) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => TaminotchiDetailScreen(
          supplier: supplier,
          openPaymentOnStart: openPayment,
        ),
      ),
    );
    if (changed == true && mounted) _load();
  }

  Future<void> _openEdit(Supplier supplier) async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => TaminotchiFormScreen(supplier: supplier),
      ),
    );
    if (ok == true && mounted) _load();
  }

  Future<void> _confirmDelete(Supplier s) async {
    final ok = await IosStyleModals.showSheet<bool>(
      context: context,
      showGrabber: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Taminotchini o‘chirish',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              '«${s.name}» ni o‘chirmoqchimisiz? '
              'Kirim yoki mahsulot bog‘langan bo‘lsa o‘chirib bo‘lmaydi.',
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('O‘chirish'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(Strings.bekorQilish),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ContactsApi.deleteSupplier(s.id);
      if (!mounted) return;
      AppNotify.success(context, 'Taminotchi o‘chirildi');
      _load();
    } catch (e) {
      if (mounted) AppNotify.error(context, '$e');
    }
  }

  void _showActionsSheet(Supplier s) {
    final hasDebt = s.dueAmount > 0;
    IosStyleModals.showSheet<void>(
      context: context,
      showGrabber: true,
      child: Builder(
        builder: (sheetContext) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Amallar',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            if (hasDebt)
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.credit_card_rounded,
                    color: Colors.blue.shade700,
                    size: 22,
                  ),
                ),
                title: const Text(Strings.umumiyTolash),
                titleTextStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _openDetail(s, openPayment: true);
                },
              ),
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.primaryLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.edit_rounded,
                  color: AppTheme.primary,
                  size: 22,
                ),
              ),
              title: const Text('Tahrirlash'),
              titleTextStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                _openEdit(s);
              },
            ),
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.red.shade700,
                  size: 22,
                ),
              ),
              title: Text(
                "O'chirish",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.red.shade700,
                ),
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                _confirmDelete(s);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  String _fmtAmount(num n) => formatThousands(n.round());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(Strings.taminotchilar),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: _headerStat(
                    'Umumiy qarzdorlik',
                    _fmtAmount(_totals.totalDebt),
                    Icons.receipt_long_outlined,
                    const Color(0xFFDC2626),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _headerStat(
                    'Umumiy balans',
                    _fmtAmount(_totals.totalBalance),
                    Icons.account_balance_wallet_outlined,
                    const Color(0xFF16A34A),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    textInputAction: TextInputAction.search,
                    onChanged: _onSearchChanged,
                    onSubmitted: (_) {
                      _searchDebounce?.cancel();
                      _load();
                    },
                    decoration: InputDecoration(
                      hintText: 'Taminotchi ismi yoki telefon',
                      isDense: true,
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: AppTheme.textSecondary,
                      ),
                      suffixIcon: _hasSearchText
                          ? IconButton(
                              icon: const Icon(Icons.close_rounded, size: 20),
                              onPressed: _clearSearch,
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppTheme.divider),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Tooltip(
                  message: Strings.yangiTaminotchi,
                  child: Material(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      onTap: _openCreate,
                      borderRadius: BorderRadius.circular(10),
                      child: const Padding(
                        padding: EdgeInsets.all(11),
                        child: Icon(
                          Icons.add_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 2,
            child: _querying && !_loading
                ? const LinearProgressIndicator(
                    minHeight: 2,
                    color: AppTheme.primary,
                    backgroundColor: Colors.transparent,
                  )
                : null,
          ),
          Expanded(
            child: ThrottledRefreshIndicator(
              onRefresh: _load,
              child: _buildBody(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 160),
          Center(child: CircularProgressIndicator(color: AppTheme.primary)),
        ],
      );
    }

    if (_error != null && _items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 80),
          Icon(
            Icons.error_outline_rounded,
            size: 56,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 16),
          Center(
            child: FilledButton(
              onPressed: _load,
              child: const Text('Qayta yuklash'),
            ),
          ),
        ],
      );
    }

    if (_items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 160),
          Center(
            child: Text(
              "Taminotchilar yo'q",
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      controller: _scrollCtrl,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: _items.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, i) {
        if (i >= _items.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: _loadingMore
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : OutlinedButton.icon(
                      onPressed: _loadMore,
                      icon: const Icon(Icons.expand_more_rounded),
                      label: const Text('Yana yuklash'),
                    ),
            ),
          );
        }
        final s = _items[i];
        return _mobileCard(s);
      },
    );
  }

  Widget _mobileCard(Supplier s) {
    final debt = s.dueAmount.round();
    final balance = s.balance.round();
    final subtitle = [
      if (s.displayPhone != '—') s.displayPhone,
      if ((s.company ?? '').trim().isNotEmpty) s.company!.trim(),
    ].join(' · ');
    final moneyLabel = debt > 0
        ? _fmtAmount(debt)
        : (balance != 0 ? _fmtAmount(balance) : null);
    final moneyColor =
        debt > 0 ? const Color(0xFFDC2626) : const Color(0xFF16A34A);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _openDetail(s),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
          child: SizedBox(
            height: 48,
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.local_shipping_rounded,
                    color: AppTheme.primary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          height: 1.15,
                        ),
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                            height: 1.15,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (moneyLabel != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    moneyLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: moneyColor,
                      fontSize: 13,
                    ),
                  ),
                ],
                SizedBox(
                  width: 32,
                  height: 32,
                  child: IconButton(
                    tooltip: 'Amallar',
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      Icons.more_vert_rounded,
                      color: Colors.grey.shade700,
                      size: 20,
                    ),
                    onPressed: () => _showActionsSheet(s),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _headerStat(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
