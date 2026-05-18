import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../core/theme.dart';
import '../providers/expenses_provider.dart';
import 'xarajat_qoshish_screen.dart';
import 'desktop/desktop_shell_scope.dart';

/// Menu → Xarajatlar: ro'yxat va yangi xarajat faqat API dan (GET /expenses, POST /expenses).
class XarajatlarScreen extends StatefulWidget {
  const XarajatlarScreen({super.key});

  @override
  State<XarajatlarScreen> createState() => _XarajatlarScreenState();
}

class _XarajatlarScreenState extends State<XarajatlarScreen> with DesktopShellSyncMixin {
  final _expenses = ExpensesProvider.instance;
  late DateTimeRange _range;

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
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
      buf.write(s[i]);
    }
    return '$buf so\'m';
  }

  static String _formatDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
  }

  bool get _isTodayRange {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return _range.start == today && _range.end == today;
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

  @override
  Future<void> onDesktopShellSync() =>
      _expenses.loadFromApi(fromDate: _range.start, toDate: _range.end);

  Future<void> _openAddExpenseScreen() async {
    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => const XarajatQoshishScreen(),
      ),
    );
    if (added == true && mounted) {
      _expenses.loadFromApi(fromDate: _range.start, toDate: _range.end);
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = _expenses.items;
    final total = list.fold<int>(0, (s, e) => s + e.amountUzs);
    final loading = _expenses.isLoading;
    final error = _expenses.loadError;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(Strings.xarajatlar),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: loading ? null : () => _expenses.loadFromApi(fromDate: _range.start, toDate: _range.end),
            tooltip: "Qayta yuklash",
          ),
        ],
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
                    "Jami xarajat",
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  Text(
                    _formatUzs(total),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickRange,
                    icon: const Icon(Icons.date_range_rounded, size: 18),
                    label: Text(
                      _range.start == _range.end
                          ? _formatDate(_range.start)
                          : '${_formatDate(_range.start)} - ${_formatDate(_range.end)}',
                    ),
                  ),
                ),
                if (!_isTodayRange) ...[
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: _resetToToday,
                    child: const Text('Bugun'),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: loading && list.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : error != null && list.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                error,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.red.shade700,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: () => _expenses.loadFromApi(fromDate: _range.start, toDate: _range.end),
                                icon: const Icon(Icons.refresh_rounded, size: 20),
                                label: const Text("Qayta yuklash"),
                              ),
                            ],
                          ),
                        ),
                      )
                    : list.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.receipt_long_rounded,
                                  size: 64,
                                  color: AppTheme.textSecondary.withValues(alpha: 0.5),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  "Bu oraliqda xarajat topilmadi",
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "Yangi xarajat qo'shish tugmasini bosing",
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppTheme.textSecondary.withValues(alpha: 0.8),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
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
                                  title: Text(
                                    e.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                    ),
                                  ),
                                  subtitle: Text(
                                    _formatDate(e.date),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                  trailing: Text(
                                    _formatUzs(e.amountUzs),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                      color: AppTheme.primary,
                                    ),
                                  ),
                                ),
                              );
                            },
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
              onPressed: _openAddExpenseScreen,
              icon: const Icon(Icons.add_rounded),
              label: const Text(Strings.yangiXarajat),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
