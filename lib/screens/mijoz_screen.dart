import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/input_formatters.dart';
import '../providers/clients_provider.dart';
import '../widgets/ios_style_modals.dart';
import 'yangi_mijoz_screen.dart';

class MijozScreen extends StatefulWidget {
  const MijozScreen({super.key});

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

  @override
  void initState() {
    super.initState();
    _load();
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
    _searchController.dispose();
    super.dispose();
  }

  List<Client> get _filtered => _clients.search(_query);

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
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() {
                _query = v;
                _visibleCount = _pageSize;
              }),
              decoration: const InputDecoration(
                hintText: "Mijoz ismi yoki telefon raqami",
                prefixIcon: Icon(Icons.search_rounded, color: AppTheme.textSecondary),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showAddClient(context),
                icon: const Icon(Icons.add_rounded, size: 22),
                label: const Text("Yangi mijoz yaratish"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: list.isEmpty
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
                            "Mijoz qidirish",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Mijoz nomi yoki raqamini kiriting yoki yangi mijoz yarating",
                            style: TextStyle(
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
                              label: const Text("Yana yuklash"),
                            ),
                          ),
                        );
                      }
                      final c = visibleList[index];
                      final debt = _debtMap[c.id] ?? (c.dueAmount != null ? c.dueAmount!.round() : 0);
                      final balanceInt = (c.balance ?? 0).round();
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: AppTheme.primaryLight,
                            child: Icon(Icons.person_rounded, color: AppTheme.primary),
                          ),
                          title: Text(c.name),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (c.phone != null && c.phone!.isNotEmpty) Text(c.phone!),
                              if (debt > 0)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    "Qarz: ${formatThousands(debt)}",
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
                                    "Balans: ${formatThousands(balanceInt)}",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      color: balanceInt > 0 ? Colors.green.shade700 : Colors.red.shade700,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          trailing: debt > 0
                              ? IconButton(
                                  icon: const Icon(Icons.receipt_long_rounded, color: AppTheme.primary),
                                  onPressed: () => _showDebtHistory(context, c),
                                )
                              : null,
                          onTap: () => Navigator.pop(context, c),
                        ),
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
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      barrierColor: CupertinoColors.black.withValues(alpha: 0.4),
      builder: (ctx) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(IosStyleModals.sheetCornerRadius)),
        child: Material(
          color: CupertinoColors.systemBackground.resolveFrom(ctx),
          child: DraggableScrollableSheet(
            initialChildSize: 0.5,
            minChildSize: 0.3,
            maxChildSize: 0.9,
            expand: false,
            builder: (ctx, scrollController) => Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IosStyleModals.grabber(),
                  Text(
                    "${client.name} — qarz (chek bilan)",
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
                  const SizedBox(height: 16),
                  Expanded(
                    child: entries.isEmpty
                        ? const Center(
                            child: Text(
                              "Qarz yozuvlari yo'q",
                              style: TextStyle(color: AppTheme.textSecondary),
                            ),
                          )
                        : ListView.builder(
                            controller: scrollController,
                            itemCount: entries.length,
                            itemBuilder: (context, index) {
                              final e = entries[index];
                              DateTime? dt;
                              try {
                                dt = DateTime.tryParse(e.dateTime);
                              } catch (_) {}
                              final dateStr = dt != null
                                  ? "${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}"
                                  : e.dateTime;
                              return ListTile(
                                leading: const Icon(Icons.receipt_rounded, color: AppTheme.primary),
                                title: Text("Chek #${e.receiptId.startsWith('POS') ? e.receiptId : 'POS${e.receiptId}'}"),
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
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Mijozlar bo'limidagi [YangiMijozScreen] bilan bir xil to'liq ekran forma (savatcha → to'lovda ham shu).
  Future<void> _showAddClient(BuildContext context) async {
    final client = await Navigator.push<Client>(
      context,
      MaterialPageRoute(builder: (_) => const YangiMijozScreen()),
    );
    if (client != null && mounted) Navigator.pop(context, client);
  }
}
