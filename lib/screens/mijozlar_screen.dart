import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../core/theme.dart';
import '../core/input_formatters.dart';
import '../providers/clients_provider.dart';
import 'mijoz_detail_screen.dart';
import 'yangi_mijoz_screen.dart';

/// Menu → Mijozlar: barcha mijozlar, yangi qo'shish, bosilganda mijoz detali
class MijozlarScreen extends StatefulWidget {
  const MijozlarScreen({super.key});

  @override
  State<MijozlarScreen> createState() => _MijozlarScreenState();
}

class _MijozlarScreenState extends State<MijozlarScreen> {
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
    final totalClients = _clients.items.length;
    final totalDebt = _clients.items.fold<int>(0, (s, c) => s + ((c.dueAmount ?? 0).round()));
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(Strings.mijozlar),
      ),
      backgroundColor: const Color(0xFFF4F8FF),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0D6EFD), Color(0xFF4DA3FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0D6EFD).withValues(alpha: 0.30),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Mijozlar paneli",
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _statBadge("Mijozlar", "$totalClients"),
                    const SizedBox(width: 8),
                    _statBadge("Jami qarz", formatThousands(totalDebt)),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFD7E8FF)),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() {
                  _query = v;
                  _visibleCount = _pageSize;
                }),
                decoration: const InputDecoration(
                  hintText: "Mijoz ismi yoki telefon raqami",
                  prefixIcon: Icon(Icons.search_rounded, color: Color(0xFF3D7DFF)),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0D6EFD), Color(0xFF4DA3FF)],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: SizedBox(
                width: double.infinity,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () async {
                      await Navigator.of(context).push<bool>(
                        MaterialPageRoute(builder: (_) => const YangiMijozScreen()),
                      );
                      if (mounted) _load(force: true);
                    },
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_circle_outline_rounded, color: Colors.white, size: 24),
                          SizedBox(width: 10),
                          Text(
                            "Yangi mijoz qo'shish",
                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: _clients.loadError != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.error_outline_rounded, size: 56, color: Theme.of(context).colorScheme.error),
                          const SizedBox(height: 12),
                          Text(
                            _clients.loadError!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 15, color: AppTheme.textSecondary),
                          ),
                          const SizedBox(height: 16),
                          TextButton.icon(
                            onPressed: () => _load(force: true),
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text("Qayta yuklash"),
                          ),
                        ],
                      ),
                    ),
                  )
                : list.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.people_outline_rounded, size: 72, color: AppTheme.textSecondary.withValues(alpha: 0.5)),
                            const SizedBox(height: 16),
                            const Text("Mijozlar yo'q", style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                            const SizedBox(height: 8),
                            Text("Yangi mijoz qo'shing", style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
                          ],
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
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          leading: Container(
                            width: 44,
                            height: 44,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(colors: [Color(0xFFDFF0FF), Color(0xFFC8E3FF)]),
                            ),
                            child: const Icon(Icons.person_rounded, color: Color(0xFF0D6EFD)),
                          ),
                          title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w700)),
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
                                    style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF0D6EFD), fontSize: 13),
                                  ),
                                ),
                              if (balanceInt != 0)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    "Balans: ${formatThousands(balanceInt)}",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                      color: balanceInt > 0 ? Colors.green.shade700 : Colors.red.shade700,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF6699FF)),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => MijozDetailScreen(client: c)),
                          ).then((_) => _load(force: true)),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _statBadge(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
