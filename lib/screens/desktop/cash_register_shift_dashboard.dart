import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_notify.dart';
import '../../core/input_formatters.dart';
import '../../core/theme.dart';
import '../../providers/cash_register_shift_provider.dart';
import '../../providers/sales_session_provider.dart';
import '../../utils/cash_register_utils.dart';
import '../../utils/platform_layout.dart';
import '../../widgets/pos_editable_focus_scope.dart';
import 'quick_cash_dialogs.dart';

/// Desktop: dialog. Mobil: to‘liq ekran. UI darhol ochiladi, hisobot fon rejimida yangilanadi.
Future<void> openCashRegisterShiftDashboard(BuildContext context) async {
  final shift = CashRegisterShiftProvider.instance;
  if (!shift.isShiftOpen) return;
  if (!shift.detailLoading) {
    unawaited(shift.loadShiftDetail());
  }
  if (!context.mounted) return;
  if (isDesktopPosLayout) {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const CashRegisterShiftDashboardDialog(),
    );
  } else {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const CashRegisterShiftDashboardScreen()),
    );
  }
}

class CashRegisterShiftDashboardDialog extends StatelessWidget {
  const CashRegisterShiftDashboardDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: PosEditableFocusScope(
        child: SizedBox(
          width: MediaQuery.sizeOf(context).width * 0.92,
          height: MediaQuery.sizeOf(context).height * 0.9,
          child: CashRegisterShiftDashboardBody(
            compact: false,
            onRequestClose: () => Navigator.pop(context),
          ),
        ),
      ),
    );
  }
}

class CashRegisterShiftDashboardScreen extends StatelessWidget {
  const CashRegisterShiftDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: const Text('Kassa smenalari'),
        actions: [
          IconButton(
            onPressed: () => CashRegisterShiftProvider.instance.loadShiftDetail(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: CashRegisterShiftDashboardBody(
        compact: true,
        onRequestClose: () => Navigator.pop(context),
      ),
    );
  }
}

class CashRegisterShiftDashboardBody extends StatefulWidget {
  final bool compact;
  final VoidCallback? onRequestClose;

  const CashRegisterShiftDashboardBody({
    super.key,
    required this.compact,
    this.onRequestClose,
  });

  @override
  State<CashRegisterShiftDashboardBody> createState() => _CashRegisterShiftDashboardBodyState();
}

class _CashRegisterShiftDashboardBodyState extends State<CashRegisterShiftDashboardBody> {
  final _shift = CashRegisterShiftProvider.instance;

  @override
  void initState() {
    super.initState();
    _shift.addListener(_onShift);
  }

  @override
  void dispose() {
    _shift.removeListener(_onShift);
    super.dispose();
  }

  void _onShift() {
    if (mounted) setState(() {});
  }

  Future<void> _refresh() => _shift.loadShiftDetail();

  Future<void> _closeShift() async {
    final expected = _shift.expectedClosingAmount ?? 0;
    final controller = TextEditingController(text: formatThousands(expected.round()));
    final noteController = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kassa yopish'),
        content: SizedBox(
          width: widget.compact ? double.maxFinite : 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Kutilayotgan summa: ${formatThousands(expected.round())}'),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                inputFormatters: [ThousandsInputFormatter()],
                decoration: const InputDecoration(labelText: 'Yopilish summasi', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: noteController,
                decoration: const InputDecoration(labelText: 'Izoh', border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Bekor qilish')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Yopish')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final amount = parseFormattedSum(controller.text) ?? expected;
    final closed = await _shift.closeShift(closingAmount: amount, note: noteController.text.trim());
    if (!mounted) return;
    if (closed) {
      AppNotify.success(context, 'Kassa yopildi');
      widget.onRequestClose?.call();
    } else if (_shift.error != null) {
      AppNotify.error(context, _shift.error!);
    }
  }

  Future<void> _leaveShift() async {
    final id = _shift.cashRegisterId;
    if (id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Smenadan chiqish'),
        content: const Text(
          'Kassani yopmasdan smenadan chiqasiz. Boshqa xodimlar sotuvni davom ettiradi.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Bekor qilish')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Chiqish')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final left = await _shift.leaveShift(id);
    if (!mounted) return;
    if (left) {
      SalesSessionProvider.instance.syncFromShift();
      AppNotify.success(context, 'Smenadan chiqdingiz');
      widget.onRequestClose?.call();
    } else if (_shift.error != null) {
      AppNotify.error(context, _shift.error!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = _shift.shiftInfo ?? {};
    final analytics = _shift.shiftAnalytics ?? {};
    final log = info['log'] is Map ? Map<String, dynamic>.from(info['log'] as Map) : <String, dynamic>{};
    final paymentTypes = parseApiList(analytics['payment_types']);
    final status = (info['status'] ?? log['status'] ?? 'open').toString();
    final statusLabel = status.toLowerCase() == 'open' ? 'Ochiq' : 'Yopilgan';

    final incomePanel = _IncomePanel(
      totalSales: formatShiftMoney(analytics['total_payment'] ?? analytics['total_sales']),
      paymentTypes: paymentTypes,
      ordersCount: '${analytics['shift_orders_count'] ?? 0}',
      scrollable: widget.compact,
    );
    final outcomePanel = _OutcomePanel(
      cashBalance: _cashFromAnalytics(analytics),
      returns: formatShiftMoney(analytics['shift_returns_total']),
      incomes: formatShiftMoney(analytics['total_incomes']),
      expenses: formatShiftMoney(analytics['total_expenses']),
      avgCheck: formatShiftMoney(analytics['shift_avg_check']),
      scrollable: widget.compact,
    );
    final actionPanel = _ActionPanel(
      compact: widget.compact,
      onFullReport: () => AppNotify.info(context, 'To\'liq hisobot — tez orada'),
      onQuickIncome: () async {
        await showQuickIncomeDialog(context);
        unawaited(_refresh());
      },
      onQuickExpense: () async {
        await showQuickExpenseDialog(context);
        unawaited(_refresh());
      },
      onPrint: () => AppNotify.info(context, 'Chop etish — tez orada'),
      onLeave: _shift.canLeaveCurrentShift ? _leaveShift : null,
      onClose: _shift.canCloseFromInfo ? _closeShift : null,
    );

    final chips = Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _infoChip('Kassir tomonidan ochilgan', (info['opened_by_name'] ?? '—').toString(), fullWidth: widget.compact),
        _infoChip('Kassa terminali', (info['cash_register_title'] ?? _shift.cashRegisterTitle).toString(), fullWidth: widget.compact),
        _infoChip('Ochilish vaqti', formatShiftDateTime(log['opening_time']), fullWidth: widget.compact),
        _infoChip('Holat', statusLabel, fullWidth: widget.compact),
      ],
    );

    final staffLine = (info['shift_staff_names'] ?? '').toString();
    final contentLoading = _shift.detailLoading && _shift.shiftAnalytics == null;

    if (widget.compact) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            if (staffLine.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'SMENADA ISHLAYOTGANLAR: $staffLine',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                ),
              ),
            chips,
            const SizedBox(height: 16),
            if (contentLoading)
              const SizedBox(height: 200, child: Center(child: CircularProgressIndicator(color: AppTheme.primary)))
            else ...[
              incomePanel,
              const SizedBox(height: 12),
              outcomePanel,
              const SizedBox(height: 16),
              actionPanel,
            ],
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
          child: Row(
            children: [
              const Text('Kassa smenalari', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
              const Spacer(),
              IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh_rounded)),
              if (widget.onRequestClose != null)
                IconButton(onPressed: widget.onRequestClose, icon: const Icon(Icons.close_rounded)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: chips,
        ),
        if (staffLine.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'SMENADA ISHLAYOTGANLAR: $staffLine',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
              ),
            ),
          ),
        const SizedBox(height: 12),
        Expanded(
          child: contentLoading
              ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
              : Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: 3, child: incomePanel),
                      const SizedBox(width: 12),
                      Expanded(flex: 3, child: outcomePanel),
                      const SizedBox(width: 12),
                      SizedBox(width: 200, child: actionPanel),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  static String _cashFromAnalytics(Map<String, dynamic> analytics) {
    final rows = parseApiList(analytics['current_amount_by_payment_type']);
    for (final r in rows) {
      final name = (r['payment_method'] ?? r['name'] ?? '').toString().toLowerCase();
      if (name.contains('naqd') || name.contains('cash')) {
        return formatShiftMoney(r['total_amount'] ?? r['amount']);
      }
    }
    return formatShiftMoney(analytics['total_current_amount']);
  }

  static Widget _infoChip(String label, String value, {bool fullWidth = false}) {
    return Container(
      width: fullWidth ? double.infinity : 220,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _IncomePanel extends StatelessWidget {
  final String totalSales;
  final List<Map<String, dynamic>> paymentTypes;
  final String ordersCount;
  final bool scrollable;

  const _IncomePanel({
    required this.totalSales,
    required this.paymentTypes,
    required this.ordersCount,
    this.scrollable = false,
  });

  List<Widget> get _detailRows => [
        ...paymentTypes.map((p) => _row(
              (p['payment_method'] ?? p['name'] ?? '—').toString(),
              formatShiftMoney(p['total_amount'] ?? p['amount']),
            )),
        const Divider(),
        _row('Sotilgan cheklar soni', ordersCount),
      ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: scrollable ? MainAxisSize.min : MainAxisSize.max,
        children: [
          const Text('DAROMAD', style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.5)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F4FC),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('JAMI SAVDO', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text(totalSales, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (scrollable)
            ..._detailRows
          else
            Expanded(child: ListView(children: _detailRows)),
        ],
      ),
    );
  }

  static Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _OutcomePanel extends StatelessWidget {
  final String cashBalance;
  final String returns;
  final String incomes;
  final String expenses;
  final String avgCheck;
  final bool scrollable;

  const _OutcomePanel({
    required this.cashBalance,
    required this.returns,
    required this.incomes,
    required this.expenses,
    required this.avgCheck,
    this.scrollable = false,
  });

  List<Widget> get _detailRows => [
        _IncomePanel._row('Qaytarishlar', returns),
        _IncomePanel._row('Kassa kirim', incomes),
        _IncomePanel._row('Kassa chiqim', expenses),
        _IncomePanel._row('O‘rtacha chek summasi', avgCheck),
      ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: scrollable ? MainAxisSize.min : MainAxisSize.max,
        children: [
          const Text('CHIQIM / QAYTIM', style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.5)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('KASSA NAQD QOLDIG‘I', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text(cashBalance, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (scrollable) ..._detailRows else Expanded(child: ListView(children: _detailRows)),
        ],
      ),
    );
  }
}

class _ActionPanel extends StatelessWidget {
  final bool compact;
  final VoidCallback onFullReport;
  final VoidCallback onQuickIncome;
  final VoidCallback onQuickExpense;
  final VoidCallback onPrint;
  final VoidCallback? onLeave;
  final VoidCallback? onClose;

  const _ActionPanel({
    this.compact = false,
    required this.onFullReport,
    required this.onQuickIncome,
    required this.onQuickExpense,
    required this.onPrint,
    this.onLeave,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final buttons = <Widget>[
      _actionBtn('To\'liq hisobot', Icons.bar_chart_rounded, const Color(0xFF2563EB), onFullReport),
      _actionBtn('Tezkor kirim', Icons.arrow_downward_rounded, const Color(0xFF16A34A), onQuickIncome),
      _actionBtn('Tezkor chiqim', Icons.arrow_upward_rounded, const Color(0xFFEA580C), onQuickExpense),
      _actionBtn('Chop etish', Icons.print_rounded, const Color(0xFF94A3B8), onPrint),
    ];
    if (onLeave != null) {
      buttons.add(_actionBtn('Smenadan chiqish', Icons.logout_rounded, const Color(0xFF64748B), onLeave!));
    }
    if (onClose != null) {
      buttons.add(_actionBtn('Kassa yopish', Icons.lock_rounded, const Color(0xFFDC2626), onClose!));
    }

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < buttons.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            buttons[i],
          ],
        ],
      );
    }

    final tail = buttons.length > 4 ? buttons.sublist(4) : <Widget>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < 4 && i < buttons.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          buttons[i],
        ],
        if (tail.isNotEmpty) const Spacer(),
        for (var i = 0; i < tail.length; i++) ...[
          const SizedBox(height: 10),
          tail[i],
        ],
      ],
    );
  }

  Widget _actionBtn(String label, IconData icon, Color color, VoidCallback onTap) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
