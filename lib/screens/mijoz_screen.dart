import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/input_formatters.dart';
import '../providers/clients_provider.dart';
import '../providers/sales_session_provider.dart';
import '../widgets/customer_debt_balance_badge.dart';
import '../widgets/ios_style_modals.dart';
import 'scanner_screen.dart' show showCompactScanner;
import 'yangi_mijoz_screen.dart';

class MijozScreen extends StatefulWidget {
  /// To'lov ekranidan: API qidiruv (POST /sales/customers), eski to'liq ekran UI.
  final bool forSalesPayment;

  const MijozScreen({super.key, this.forSalesPayment = false});

  @override
  State<MijozScreen> createState() => _MijozScreenState();
}

class _MijozScreenState extends State<MijozScreen> {
  static const int _pageSize = 20;
  final _searchController = TextEditingController();
  final _clients = ClientsProvider.instance;
  String _query = '';
  Map<String, int> _debtMap = {};
  int _visibleCount = _pageSize;
  List<Client> _apiResults = [];
  bool _apiLoading = false;
  Timer? _apiDebounce;

  bool get _useApiSearch => widget.forSalesPayment;

  @override
  void initState() {
    super.initState();
    if (!_useApiSearch) {
      _load();
    }
  }

  Future<void> _load({bool force = false}) async {
    await _clients.loadFromStorage(force: force);
    if (!mounted) return;
    _debtMap = ClientsProvider.quickDebtMap(_clients.items);
    _visibleCount = _pageSize;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _apiDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String v) {
    setState(() {
      _query = v;
      _visibleCount = _pageSize;
    });
    if (!_useApiSearch) return;
    _apiDebounce?.cancel();
    final q = v.trim();
    if (q.length < 2) {
      setState(() {
        _apiResults = [];
        _apiLoading = false;
      });
      return;
    }
    _apiDebounce = Timer(const Duration(milliseconds: 300), () async {
      setState(() => _apiLoading = true);
      final list = await SalesSessionProvider.instance.searchCustomers(q);
      if (!mounted) return;
      setState(() {
        _apiResults = list;
        _apiLoading = false;
      });
    });
  }

  List<Client> get _filtered => _useApiSearch ? _apiResults : _clients.search(_query);

  bool get _showEmptyHint {
    if (_useApiSearch) {
      return _query.trim().length < 2 && !_apiLoading;
    }
    return _filtered.isEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered;
    final visibleList = list.take(_visibleCount).toList();
    final hasMore = list.length > visibleList.length;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Mijoz'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    autofocus: _useApiSearch,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      hintText: 'Mijoz ismi yoki telefon raqami',
                      prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textSecondary),
                      suffixIcon: _apiLoading
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                              ),
                            )
                          : _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.close_rounded, size: 20),
                                  onPressed: () {
                                    _searchController.clear();
                                    _onSearchChanged('');
                                  },
                                )
                              : null,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _squareActionButton(
                  icon: Icons.qr_code_scanner_rounded,
                  onTap: _showScanner,
                ),
                const SizedBox(width: 8),
                _squareActionButton(
                  icon: Icons.add_rounded,
                  onTap: () => _showAddClient(context),
                ),
              ],
            ),
          ),
          Expanded(
            child: _showEmptyHint
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_rounded,
                            size: 80,
                            color: AppTheme.textSecondary.withValues(alpha: 0.4),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'Mijoz qidirish',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _useApiSearch
                                ? 'Kamida 2 ta belgi kiriting yoki yangi mijoz yarating'
                                : 'Mijoz nomi yoki raqamini kiriting yoki yangi mijoz yarating',
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppTheme.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: visibleList.length + (hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (hasMore && index == visibleList.length) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 6, bottom: 14),
                          child: Center(
                            child: OutlinedButton.icon(
                              onPressed: () => setState(() => _visibleCount += _pageSize),
                              icon: const Icon(Icons.expand_more_rounded),
                              label: const Text('Yana yuklash'),
                            ),
                          ),
                        );
                      }
                      final c = visibleList[index];
                      return _ClientCard(
                        client: c,
                        debt: _debtMap[c.id] ?? (c.dueAmount != null ? c.dueAmount!.round() : 0),
                        useApiBadge: _useApiSearch,
                        onDebtHistory: () => _showDebtHistory(context, c),
                        onTap: () => Navigator.pop(context, c),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _showDebtHistory(BuildContext context, Client client) async {
    final entries = await _clients.getDebtEntries(client.id);
    if (!context.mounted) return;
    IosStyleModals.showDraggableSheet<void>(
      context: context,
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      header: Column(
        children: [
          const SizedBox(height: 10),
          IosStyleModals.grabber(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${client.name} — qarz (chek bilan)',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Jami: ${formatThousands(entries.fold<int>(0, (s, e) => s + e.amount))} so'm",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      builder: (_, scrollController) => entries.isEmpty
          ? const Center(
              child: Text(
                "Qarz yozuvlari yo'q",
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            )
          : ListView.builder(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
              itemCount: entries.length,
              itemBuilder: (context, index) {
                final e = entries[index];
                DateTime? dt;
                try {
                  dt = DateTime.tryParse(e.dateTime);
                } catch (_) {}
                final dateStr = dt != null
                    ? '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}'
                    : e.dateTime;
                return ListTile(
                  leading: const Icon(Icons.receipt_rounded, color: AppTheme.primary),
                  title: Text(
                    "Chek #${e.receiptId.startsWith('POS') ? e.receiptId : 'POS${e.receiptId}'}",
                  ),
                  subtitle: Text(dateStr),
                  trailing: Text(
                    "${formatThousands(e.amount)} so'm",
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primary,
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _squareActionButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppTheme.primary,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(11),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }

  void _showScanner() {
    showCompactScanner(context, onResult: (barcode) {
      if (barcode == null || barcode.isEmpty || !mounted) return;
      final q = barcode.trim();
      _searchController.text = q;
      _searchController.selection = TextSelection.collapsed(offset: q.length);
      _onSearchChanged(q);
    });
  }

  Future<void> _showAddClient(BuildContext context) async {
    final client = await Navigator.push<Client>(
      context,
      MaterialPageRoute(builder: (_) => const YangiMijozScreen()),
    );
    if (client != null && mounted) Navigator.pop(context, client);
  }
}

class _ClientCard extends StatelessWidget {
  final Client client;
  final int debt;
  final bool useApiBadge;
  final VoidCallback onDebtHistory;
  final VoidCallback onTap;

  const _ClientCard({
    required this.client,
    required this.debt,
    required this.useApiBadge,
    required this.onDebtHistory,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final balanceInt = (client.balance ?? 0).round();
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: AppTheme.primaryLight,
          child: Icon(Icons.person_rounded, color: AppTheme.primary),
        ),
        title: Text(client.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (client.phone != null && client.phone!.isNotEmpty) Text(client.phone!),
            if (useApiBadge) ...[
              const SizedBox(height: 6),
              CustomerDebtBalanceBadge(client: client),
            ] else ...[
              if (debt > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Qarz: ${formatThousands(debt)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primary,
                    ),
                  ),
                ),
              if (balanceInt != 0)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    'Balans: ${formatThousands(balanceInt)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: balanceInt > 0 ? Colors.green.shade700 : Colors.red.shade700,
                    ),
                  ),
                ),
            ],
          ],
        ),
        trailing: !useApiBadge && debt > 0
            ? IconButton(
                icon: const Icon(Icons.receipt_long_rounded, color: AppTheme.primary),
                onPressed: onDebtHistory,
              )
            : null,
        onTap: onTap,
      ),
    );
  }
}
