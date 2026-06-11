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
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const CashRegisterShiftDashboardFullscreen(),
      ),
    );
  } else {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const CashRegisterShiftDashboardScreen()),
    );
  }
}

/// Desktop: to‘liq ekran (Navigator route — Dialog.fullscreen ba’zi platformalarda ko‘rinmasligi mumkin).
class CashRegisterShiftDashboardFullscreen extends StatelessWidget {
  const CashRegisterShiftDashboardFullscreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      body: SafeArea(
        child: PosEditableFocusScope(
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
    unawaited(_shift.ensureCurrentUserId());
    if (_shift.shiftInfo == null && !_shift.detailLoading) {
      unawaited(_shift.loadShiftDetail());
    }
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
      large: !widget.compact,
    );
    final outcomePanel = _OutcomePanel(
      cashBalance: _cashFromAnalytics(analytics),
      returns: formatShiftMoney(analytics['shift_returns_total']),
      incomes: formatShiftMoney(analytics['total_incomes']),
      expenses: formatShiftMoney(analytics['total_expenses']),
      avgCheck: formatShiftMoney(analytics['shift_avg_check']),
      scrollable: widget.compact,
      large: !widget.compact,
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

    final chips = widget.compact
        ? Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _infoChip('Kassir tomonidan ochilgan', (info['opened_by_name'] ?? '—').toString(), fullWidth: true),
              _infoChip('Kassa terminali', (info['cash_register_title'] ?? _shift.cashRegisterTitle).toString(), fullWidth: true),
              _infoChip('Ochilish vaqti', formatShiftDateTime(log['opening_time']), fullWidth: true),
              _infoChip('Holat', statusLabel, fullWidth: true),
            ],
          )
        : IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _infoChip('Kassir tomonidan ochilgan', (info['opened_by_name'] ?? '—').toString(), large: true)),
                const SizedBox(width: 16),
                Expanded(child: _infoChip('Kassa terminali', (info['cash_register_title'] ?? _shift.cashRegisterTitle).toString(), large: true)),
                const SizedBox(width: 16),
                Expanded(child: _infoChip('Ochilish vaqti', formatShiftDateTime(log['opening_time']), large: true)),
                const SizedBox(width: 16),
                Expanded(child: _infoChip('Holat', statusLabel, large: true)),
              ],
            ),
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
          padding: const EdgeInsets.fromLTRB(24, 20, 20, 12),
          child: Row(
            children: [
              const Text('Kassa smenalari', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
              const Spacer(),
              IconButton(
                tooltip: 'Yangilash',
                onPressed: _refresh,
                icon: const Icon(Icons.refresh_rounded, size: 28),
              ),
              if (widget.onRequestClose != null)
                IconButton(
                  tooltip: 'Yopish',
                  onPressed: widget.onRequestClose,
                  style: IconButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    fixedSize: const Size(48, 48),
                  ),
                  icon: const Icon(Icons.close_rounded, size: 30),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: chips,
        ),
        if (staffLine.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.divider),
              ),
              child: Text(
                'SMENADA ISHLAYOTGANLAR: $staffLine',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
              ),
            ),
          ),
        const SizedBox(height: 16),
        Expanded(
          child: contentLoading
              ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
              : Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: 3, child: incomePanel),
                      const SizedBox(width: 16),
                      Expanded(flex: 3, child: outcomePanel),
                      const SizedBox(width: 16),
                      Expanded(flex: 2, child: actionPanel),
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

  static Widget _infoChip(String label, String value, {bool fullWidth = false, bool large = false}) {
    return Container(
      width: fullWidth ? double.infinity : null,
      padding: EdgeInsets.all(large ? 20 : 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(large ? 12 : 8),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: large ? 14 : 11,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          SizedBox(height: large ? 10 : 4),
          Text(
            value,
            style: TextStyle(
              fontSize: large ? 20 : 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
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
  final bool large;

  const _IncomePanel({
    required this.totalSales,
    required this.paymentTypes,
    required this.ordersCount,
    this.scrollable = false,
    this.large = false,
  });

  List<Widget> get _detailRows => [
        ...paymentTypes.map((p) => _row(
              (p['payment_method'] ?? p['name'] ?? '—').toString(),
              formatShiftMoney(p['total_amount'] ?? p['amount']),
              large: large,
            )),
        const Divider(),
        _row('Sotilgan cheklar soni', ordersCount, large: large),
      ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(large ? 24 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(large ? 12 : 8),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: scrollable ? MainAxisSize.min : MainAxisSize.max,
        children: [
          Text(
            'DAROMAD',
            style: TextStyle(
              fontSize: large ? 18 : 14,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
          SizedBox(height: large ? 16 : 12),
          Container(
            padding: EdgeInsets.all(large ? 22 : 16),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F4FC),
              borderRadius: BorderRadius.circular(large ? 12 : 8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'JAMI SAVDO',
                  style: TextStyle(fontSize: large ? 15 : 12, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: large ? 12 : 8),
                Text(
                  totalSales,
                  style: TextStyle(fontSize: large ? 36 : 28, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          SizedBox(height: large ? 16 : 12),
          if (scrollable)
            ..._detailRows
          else
            Expanded(child: ListView(children: _detailRows)),
        ],
      ),
    );
  }

  static Widget _row(String label, String value, {bool large = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: large ? 10 : 6),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: TextStyle(fontSize: large ? 16 : 13)),
          ),
          Text(
            value,
            style: TextStyle(fontSize: large ? 16 : 13, fontWeight: FontWeight.w700),
          ),
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
  final bool large;

  const _OutcomePanel({
    required this.cashBalance,
    required this.returns,
    required this.incomes,
    required this.expenses,
    required this.avgCheck,
    this.scrollable = false,
    this.large = false,
  });

  List<Widget> get _detailRows => [
        _IncomePanel._row('Qaytarishlar', returns, large: large),
        _IncomePanel._row('Kassa kirim', incomes, large: large),
        _IncomePanel._row('Kassa chiqim', expenses, large: large),
        _IncomePanel._row('O‘rtacha chek summasi', avgCheck, large: large),
      ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(large ? 24 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(large ? 12 : 8),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: scrollable ? MainAxisSize.min : MainAxisSize.max,
        children: [
          Text(
            'CHIQIM / QAYTIM',
            style: TextStyle(
              fontSize: large ? 18 : 14,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
          SizedBox(height: large ? 16 : 12),
          Container(
            padding: EdgeInsets.all(large ? 22 : 16),
            decoration: BoxDecoration(
              color: const Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(large ? 12 : 8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'KASSA NAQD QOLDIG‘I',
                  style: TextStyle(fontSize: large ? 15 : 12, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: large ? 12 : 8),
                Text(
                  cashBalance,
                  style: TextStyle(fontSize: large ? 36 : 28, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          SizedBox(height: large ? 16 : 12),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < buttons.length; i++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: i > 0 ? 14 : 0),
              child: buttons[i],
            ),
          ),
      ],
    );
  }

  Widget _actionBtn(String label, IconData icon, Color color, VoidCallback onTap) {
    final large = !compact;
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(large ? 12 : 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(large ? 12 : 8),
        child: SizedBox.expand(
          child: Padding(
            padding: EdgeInsets.symmetric(
              vertical: large ? 20 : 14,
              horizontal: large ? 20 : 12,
            ),
            child: Row(
              children: [
                Icon(icon, color: Colors.white, size: large ? 32 : 22),
                SizedBox(width: large ? 16 : 10),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: large ? 18 : 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
