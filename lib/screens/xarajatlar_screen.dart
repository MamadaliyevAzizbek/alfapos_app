import 'package:flutter/material.dart';
import '../core/app_notify.dart';
import '../core/constants.dart';
import '../core/theme.dart';
import '../models/expense.dart';
import '../providers/expenses_provider.dart';
import '../utils/platform_layout.dart';
import 'xarajat_qoshish_screen.dart';
import 'desktop/desktop_shell_scope.dart';
import '../widgets/throttled_refresh_indicator.dart';

/// Xarajatlar: mobil — kartalar; desktop — toolbar + jadval.
class XarajatlarScreen extends StatefulWidget {
  const XarajatlarScreen({super.key});

  @override
  State<XarajatlarScreen> createState() => _XarajatlarScreenState();
}

class _XarajatlarScreenState extends State<XarajatlarScreen> with DesktopShellSyncMixin {
  final _expenses = ExpensesProvider.instance;
  late DateTimeRange _range;
  bool _deleting = false;

  bool get _desktop => isDesktopPosLayout;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _range = DateTimeRange(start: today, end: today);
    _expenses.addListener(_onChanged);
    _expenses.loadFromApi(fromDate: _range.start, toDate: _range.end);
  }

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    _expenses.removeListener(_onChanged);
    super.dispose();
  }

  static String _formatUzs(int n) {
    final s = n.abs().toString();
    final buf = StringBuffer();
    if (n < 0) buf.write('-');
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
      buf.write(s[i]);
    }
    return "$buf so'm";
  }

  static String _formatDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
  }

  bool get _isTodayRange {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return _range.start == today && _range.end == today;
  }

  String get _rangeLabel {
    if (_range.start == _range.end) return _formatDate(_range.start);
    return '${_formatDate(_range.start)} — ${_formatDate(_range.end)}';
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _range,
    );
    if (picked == null || !mounted) return;
    setState(() => _range = DateTimeRange(
          start: DateTime(picked.start.year, picked.start.month, picked.start.day),
          end: DateTime(picked.end.year, picked.end.month, picked.end.day),
        ));
    await _expenses.loadFromApi(fromDate: _range.start, toDate: _range.end);
  }

  Future<void> _resetToToday() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    setState(() => _range = DateTimeRange(start: today, end: today));
    await _expenses.loadFromApi(fromDate: _range.start, toDate: _range.end);
  }

  Future<void> _reload() =>
      _expenses.loadFromApi(fromDate: _range.start, toDate: _range.end);

  @override
  Future<void> onDesktopShellSync() => _reload();

  Future<void> _openAddExpense() async {
    final bool? added;
    if (_desktop) {
      added = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: SizedBox(
              width: 520,
              height: 640,
              child: const ClipRRect(
                borderRadius: BorderRadius.all(Radius.circular(12)),
                child: XarajatQoshishScreen(embedded: true),
              ),
            ),
        ),
      );
    } else {
      added = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => const XarajatQoshishScreen()),
      );
    }
    if (added == true && mounted) await _reload();
  }

  Future<void> _confirmDelete(Expense e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xarajatni o‘chirish'),
        content: Text('«${e.name}» — ${_formatUzs(e.amountUzs)} ni o‘chirmoqchimisiz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Bekor')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade600),
            child: const Text('O‘chirish'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _deleting = true);
    try {
      await _expenses.removeExpense(e.id);
      if (mounted) AppNotify.success(context, 'Xarajat o‘chirildi');
      await _reload();
    } catch (err) {
      if (mounted) AppNotify.error(context, 'O‘chirilmadi: $err');
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_desktop) return _buildDesktopScaffold();
    return _buildMobileScaffold();
  }

  // ─── Desktop ─────────────────────────────────────────────────────────────

  Widget _buildDesktopScaffold() {
    final list = _expenses.items;
    final total = list.fold<int>(0, (s, e) => s + e.amountUzs);
    final loading = _expenses.isLoading;
    final error = _expenses.loadError;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildDesktopToolbar(total: total, loading: loading),
          Expanded(child: _buildDesktopBody(list: list, loading: loading, error: error)),
        ],
      ),
    );
  }

  Widget _buildDesktopToolbar({required int total, required bool loading}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppTheme.divider)),
      ),
      child: Row(
        children: [
          OutlinedButton.icon(
            onPressed: _pickRange,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 48),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              foregroundColor: AppTheme.textPrimary,
              side: const BorderSide(color: AppTheme.divider),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.date_range_rounded, size: 20),
            label: Text(_rangeLabel, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ),
          if (!_isTodayRange) ...[
            const SizedBox(width: 10),
            TextButton(
              onPressed: _resetToToday,
              style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
              child: const Text('Bugun'),
            ),
          ],
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.primary.withValues(alpha: 0.25)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Jami xarajat',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                ),
                const SizedBox(width: 12),
                Text(
                  _formatUzs(total),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.primary),
                ),
              ],
            ),
          ),
          const Spacer(),
          FilledButton.icon(
            onPressed: loading ? null : _openAddExpense,
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 48),
              padding: const EdgeInsets.symmetric(horizontal: 18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.add_rounded, size: 22),
            label: const Text(Strings.yangiXarajat, style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopBody({
    required List<Expense> list,
    required bool loading,
    required String? error,
  }) {
    if (loading && list.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    }
    if (error != null && list.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(error, textAlign: TextAlign.center, style: TextStyle(color: Colors.red.shade700)),
            const SizedBox(height: 12),
            FilledButton(onPressed: _reload, child: const Text('Qayta yuklash')),
          ],
        ),
      );
    }
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_rounded, size: 56, color: AppTheme.textSecondary.withValues(alpha: 0.45)),
            const SizedBox(height: 12),
            const Text(
              'Bu oraliqda xarajat topilmadi',
              style: TextStyle(fontSize: 16, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _openAddExpense,
              icon: const Icon(Icons.add_rounded),
              label: const Text(Strings.yangiXarajat),
            ),
          ],
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
                    Expanded(flex: 4, child: Text('NOMI', style: _thStyle)),
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
                  onRefresh: _reload,
                  child: ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (context, index) => _desktopRow(list[index], index),
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

  Widget _desktopRow(Expense e, int index) {
    final bg = index.isEven ? Colors.white : const Color(0xFFFAFBFC);
    return Material(
      color: bg,
      child: Container(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppTheme.divider)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Text(
                _formatDate(e.date),
                style: const TextStyle(fontSize: 15, color: AppTheme.textSecondary),
              ),
            ),
            Expanded(
              flex: 4,
              child: Text(
                e.name.isEmpty ? '—' : e.name,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                _formatUzs(e.amountUzs),
                textAlign: TextAlign.end,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.primary),
              ),
            ),
            SizedBox(
              width: 72,
              child: Center(
                child: IconButton(
                  tooltip: 'O‘chirish',
                  onPressed: _deleting ? null : () => _confirmDelete(e),
                  icon: Icon(Icons.delete_outline_rounded, color: Colors.red.shade600, size: 22),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Mobile ──────────────────────────────────────────────────────────────

  Widget _buildMobileScaffold() {
    final list = _expenses.items;
    final total = list.fold<int>(0, (s, e) => s + e.amountUzs);
    final loading = _expenses.isLoading;
    final error = _expenses.loadError;
    final canPop = Navigator.of(context).canPop();

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: canPop,
        title: const Text(Strings.xarajatlar),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.primaryLight.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Jami xarajat',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                  ),
                  Text(
                    _formatUzs(total),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.primary),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickRange,
                    icon: const Icon(Icons.date_range_rounded, size: 18),
                    label: Text(_rangeLabel),
                  ),
                ),
                if (!_isTodayRange) ...[
                  const SizedBox(width: 8),
                  TextButton(onPressed: _resetToToday, child: const Text('Bugun')),
                ],
              ],
            ),
          ),
          Expanded(
            child: ThrottledRefreshIndicator(
              onRefresh: _reload,
              child: loading && list.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 160),
                        Center(child: CircularProgressIndicator()),
                      ],
                    )
                  : error != null && list.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(24),
                          children: [
                            const SizedBox(height: 48),
                            Text(
                              error,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.red.shade700, fontSize: 14),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Pastga tortib yangilang',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                            ),
                          ],
                        )
                      : list.isEmpty
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: [
                                SizedBox(height: MediaQuery.sizeOf(context).height * 0.2),
                                Icon(Icons.receipt_long_rounded, size: 64, color: AppTheme.textSecondary.withValues(alpha: 0.5)),
                                const SizedBox(height: 16),
                                const Text(
                                  'Bu oraliqda xarajat topilmadi',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 16, color: AppTheme.textSecondary),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "Yangi xarajat qo'shish tugmasini bosing",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 14, color: AppTheme.textSecondary.withValues(alpha: 0.8)),
                                ),
                              ],
                            )
                          : ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              itemCount: list.length,
                              itemBuilder: (context, index) {
                                final e = list[index];
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: Colors.orange.shade100,
                                      child: Icon(Icons.payments_rounded, color: Colors.orange.shade700, size: 22),
                                    ),
                                    title: Text(e.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                                    subtitle: Text(
                                      _formatDate(e.date),
                                      style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                                    ),
                                    trailing: Text(
                                      _formatUzs(e.amountUzs),
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppTheme.primary),
                                    ),
                                  ),
                                );
                              },
                            ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _openAddExpense,
              icon: const Icon(Icons.add_rounded),
              label: const Text(Strings.yangiXarajat),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
