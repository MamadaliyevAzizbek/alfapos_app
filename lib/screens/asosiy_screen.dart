import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../core/theme.dart';
import '../models/daily_sales.dart';
import '../providers/dashboard_provider.dart';
import '../widgets/liquid_glass.dart';
import '../widgets/throttled_refresh_indicator.dart';

class AsosiyScreen extends StatefulWidget {
  const AsosiyScreen({super.key});

  static const double cardRadius = 18;

  @override
  State<AsosiyScreen> createState() => _AsosiyScreenState();
}

class _AsosiyScreenState extends State<AsosiyScreen> {
  bool _sellersExpanded = false;
  bool _extraExpanded = false;

  @override
  void initState() {
    super.initState();
    DashboardProvider.instance.addListener(_onChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _onChanged() => setState(() {});

  Future<void> _load([DateTime? date]) async {
    // Listener allaqachon notifyListeners → setState qiladi.
    await DashboardProvider.instance.loadFromApi(date);
  }

  Future<void> _onPullSync() async {
    // Faqat dashboard — to‘liq AppDataSync(force) 429 chiqaradi.
    await _load();
  }

  Future<void> _pickDate() async {
    final dash = DashboardProvider.instance;
    final picked = await showDatePicker(
      context: context,
      initialDate: dash.selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) await _load(picked);
  }

  static String _formatHeaderDate(DateTime d) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day} ${months[d.month]}, ${d.year}';
  }

  @override
  void dispose() {
    DashboardProvider.instance.removeListener(_onChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = DashboardProvider.instance;
    final DailySales sales = dashboard.todaySales;
    final currency = dashboard.currencySymbol;
    final safePadding = MediaQuery.paddingOf(context);
    final loadError = dashboard.loadError;
    final isLoading = dashboard.isLoading;
    final paymentTotal = dashboard.totalPaymentToday > 0
        ? dashboard.totalPaymentToday
        : sales.byPaymentType.fold<num>(0, (s, e) => s + e.amountUzs);

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text(Strings.navAsosiy),
      ),
      body: ThrottledRefreshIndicator(
          onRefresh: _onPullSync,
          child: isLoading && sales.totalUzs == 0 && sales.byPaymentType.every((e) => e.amountUzs == 0)
              ? SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: SizedBox(
                    height: MediaQuery.sizeOf(context).height - 100,
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: AppTheme.primary),
                          SizedBox(height: 12),
                          Text(
                            'Ma\'lumotlar yuklanmoqda...',
                            style: TextStyle(fontSize: 15, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : loadError != null
                  ? SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(height: 48),
                            Icon(Icons.error_outline_rounded, size: 56, color: Theme.of(context).colorScheme.error),
                            const SizedBox(height: 16),
                            Text(
                              loadError,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 15, color: AppTheme.textSecondary),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Pastga tortib yangilang',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    )
                  : CustomScrollView(
                      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                      slivers: [
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Center(
                                  child: _DatePickerBar(
                                    label: _formatHeaderDate(dashboard.selectedDate),
                                    onPrev: () {
                                      final d = dashboard.selectedDate.subtract(const Duration(days: 1));
                                      _load(d);
                                    },
                                    onNext: () {
                                      final d = dashboard.selectedDate.add(const Duration(days: 1));
                                      if (d.isAfter(DateTime.now())) return;
                                      _load(d);
                                    },
                                    onPick: _pickDate,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                // KPI — veb rasmdan
                                GridView.count(
                                  crossAxisCount: 2,
                                  mainAxisSpacing: 10,
                                  crossAxisSpacing: 10,
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  childAspectRatio: 1.55,
                                  children: [
                                    _KpiCard(
                                      title: 'Bugungi savdo',
                                      amount: DailySalesFormat.formatWithCurrency(sales.totalUzs, currency),
                                      color: AppTheme.primary,
                                      subtitle: sales.transactionCount > 0
                                          ? '${sales.transactionCount} ta buyurtma'
                                          : null,
                                    ),
                                    _KpiCard(
                                      title: 'Bugungi qarz',
                                      amount: DailySalesFormat.formatWithCurrency(dashboard.todayDebt, currency),
                                      color: Colors.red.shade700,
                                    ),
                                    _KpiCard(
                                      title: 'Bugungi xarajat',
                                      amount: DailySalesFormat.formatWithCurrency(sales.expensesUzs, currency),
                                      color: Colors.orange.shade700,
                                    ),
                                    _KpiCard(
                                      title: 'Bugungi Даход',
                                      amount: DailySalesFormat.formatWithCurrency(dashboard.todayDaxod, currency),
                                      color: const Color(0xFF16A34A),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                const _SectionTitle("Bugungi to'lov turlari"),
                                const SizedBox(height: 4),
                                const Text(
                                  "To'lov usullari bo'yicha taqsimot",
                                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  child: Row(
                                    children: [
                                      const Expanded(
                                        child: Text(
                                          "Bugungi jami to'lov",
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        DailySalesFormat.formatWithCurrency(paymentTotal, currency),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 10),
                              ],
                            ),
                          ),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          sliver: SliverGrid(
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 10,
                              crossAxisSpacing: 10,
                              childAspectRatio: 1.55,
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final item = sales.byPaymentType[index];
                                final isQarz = item.label.toLowerCase().contains('qarz');
                                return _GlassTolovTuriTile(
                                  amount: item,
                                  currency: currency,
                                  isQarz: isQarz,
                                );
                              },
                              childCount: sales.byPaymentType.length,
                            ),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                            child: LiquidGlass(
                              borderRadius: 14,
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                              child: Row(
                                children: [
                                  const Expanded(
                                    child: Text(
                                      'Bugungi qaytarilgan summa',
                                      style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                                    ),
                                  ),
                                  Text(
                                    DailySalesFormat.formatWithCurrency(dashboard.returnedToday, currency),
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Sotuvchilar — to‘lov turlaridan keyin, ochiladigan
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                            child: _ExpandableSection(
                              title: 'Bugungi sotuvchilar hisobotlari',
                              subtitle: 'Qaysi sotuvchi qancha savdo qilgani',
                              expanded: _sellersExpanded,
                              onToggle: () => setState(() => _sellersExpanded = !_sellersExpanded),
                              child: dashboard.sellers.isEmpty
                                  ? LiquidGlass(
                                      borderRadius: 14,
                                      padding: const EdgeInsets.all(16),
                                      child: Text(
                                        'Sotuvchilar yo\'q',
                                        style: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.9)),
                                      ),
                                    )
                                  : Column(
                                      children: [
                                        for (final s in dashboard.sellers)
                                          Padding(
                                            padding: const EdgeInsets.only(bottom: 10),
                                            child: _GlassSotuvchiTile(
                                              sellerName: s.sellerName,
                                              orderCount: s.orderCount,
                                              totalSalesUzs: s.totalSales,
                                              currency: currency,
                                            ),
                                          ),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                        // Qo‘shimcha ma’lumot — ochiladigan
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                            child: _ExpandableSection(
                              title: "Qo'shimcha ma'lumot",
                              subtitle: 'Savdo va mahsulotlar tahlili',
                              expanded: _extraExpanded,
                              onToggle: () => setState(() => _extraExpanded = !_extraExpanded),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  GridView.count(
                                    crossAxisCount: 2,
                                    mainAxisSpacing: 10,
                                    crossAxisSpacing: 10,
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    childAspectRatio: 1.7,
                                    children: [
                                      _InfoTile(
                                        icon: Icons.shopping_basket_outlined,
                                        label: 'Kunlik sotilgan mahsulotlar',
                                        value: '${dashboard.soldProductsToday} dona',
                                      ),
                                      _InfoTile(
                                        icon: Icons.inventory_2_outlined,
                                        label: 'Umumiy mahsulotlar',
                                        value: '${dashboard.totalProductsCount} dona',
                                      ),
                                      _InfoTile(
                                        icon: Icons.payments_outlined,
                                        label: 'Umumiy qarzdorlik:',
                                        value: DailySalesFormat.formatWithCurrency(
                                          dashboard.totalDebtAll,
                                          currency,
                                        ),
                                        valueColor: const Color(0xFFDC2626),
                                      ),
                                      _InfoTile(
                                        icon: Icons.account_balance_outlined,
                                        label: 'Ostatka (Sotish narxi)',
                                        value: DailySalesFormat.formatWithCurrency(
                                          dashboard.salesValue,
                                          currency,
                                        ),
                                      ),
                                      _InfoTile(
                                        icon: Icons.shopping_cart_outlined,
                                        label: 'Ostatka (Kelish narxi)',
                                        value: DailySalesFormat.formatWithCurrency(
                                          dashboard.warehouseValue,
                                          currency,
                                        ),
                                      ),
                                      _InfoTile(
                                        icon: Icons.layers_outlined,
                                        label: 'Umumiy ostatka tovar soni',
                                        value: '${dashboard.totalStockQuantity} dona',
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _KpiCard(
                                          title: 'Bugungi daromadi',
                                          amount: DailySalesFormat.formatWithCurrency(
                                            dashboard.todayDaxod,
                                            currency,
                                          ),
                                          color: AppTheme.primary,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: _KpiCard(
                                          title: 'Kechagi daromadi',
                                          amount: DailySalesFormat.formatWithCurrency(
                                            dashboard.yesterdayIncome,
                                            currency,
                                          ),
                                          color: AppTheme.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  SizedBox(
                                    width: double.infinity,
                                    child: _KpiCard(
                                      title: 'Bu oylik daromad',
                                      amount: DailySalesFormat.formatWithCurrency(
                                        dashboard.monthlyIncome,
                                        currency,
                                      ),
                                      color: const Color(0xFF0F766E),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        SliverToBoxAdapter(child: SizedBox(height: safePadding.bottom + 16)),
                      ],
                    ),
      ),
    );
  }
}

class _ExpandableSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool expanded;
  final VoidCallback onToggle;
  final Widget child;

  const _ExpandableSection({
    required this.title,
    required this.subtitle,
    required this.expanded,
    required this.onToggle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.divider),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                    color: AppTheme.textSecondary,
                  ),
                ],
              ),
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox(width: double.infinity),
          secondChild: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: child,
          ),
          crossFadeState: expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
          sizeCurve: Curves.easeInOut,
        ),
      ],
    );
  }
}

// --- placeholders below will be fixed by removing duplicate old widgets ---
class _DatePickerBar extends StatelessWidget {
  final String label;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onPick;

  const _DatePickerBar({
    required this.label,
    required this.onPrev,
    required this.onNext,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return LiquidGlass(
      borderRadius: 12,
      padding: EdgeInsets.zero,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(icon: const Icon(Icons.chevron_left), onPressed: onPrev),
          InkWell(
            onTap: onPick,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              child: Row(
                children: [
                  Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  const Icon(Icons.calendar_today_outlined, size: 18, color: AppTheme.textSecondary),
                ],
              ),
            ),
          ),
          IconButton(icon: const Icon(Icons.chevron_right), onPressed: onNext),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: AppTheme.textPrimary,
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String title;
  final String amount;
  final Color color;
  final String? subtitle;

  const _KpiCard({
    required this.title,
    required this.amount,
    required this.color,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return LiquidGlass(
      borderRadius: AsosiyScreen.cardRadius,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            amount,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: -0.3,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return LiquidGlass(
      borderRadius: 14,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, height: 1.2),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: valueColor ?? AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassTolovTuriTile extends StatelessWidget {
  final PaymentTypeAmount amount;
  final String currency;
  final bool isQarz;

  const _GlassTolovTuriTile({required this.amount, required this.currency, this.isQarz = false});

  @override
  Widget build(BuildContext context) {
    final icon = isQarz
        ? Icons.payments_rounded
        : _iconForPayment(amount.typeId, amount.label);
    final accentColor = isQarz ? Colors.red.shade700 : AppTheme.primary;
    return LiquidGlass(
      borderRadius: 14,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: (isQarz ? Colors.red.shade50 : AppTheme.primaryLight)
                      .withValues(alpha: isQarz ? 0.8 : 0.6),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: accentColor, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  amount.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.15,
                    color: isQarz ? Colors.red.shade800 : AppTheme.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            amount.amountFormatted(currency),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: isQarz
                  ? Colors.red.shade700
                  : (amount.amountUzs != 0 ? AppTheme.textPrimary : AppTheme.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  static IconData _iconForPayment(String typeId, String label) {
    final key = '${typeId}_$label'.toLowerCase();
    if (key.contains('qarz') || key.contains('debt') || key.contains('credit')) {
      return Icons.payments_rounded;
    }
    if (key.contains('karta') ||
        key.contains('card') ||
        key.contains('uzcard') ||
        key.contains('humo') ||
        key.contains('visa') ||
        key.contains('master')) {
      return Icons.credit_card_rounded;
    }
    if (key.contains('payme') ||
        key.contains('click') ||
        key.contains('paynet') ||
        key.contains('uzum')) {
      return Icons.account_balance_wallet_rounded;
    }
    if (key.contains('bank') || key.contains('transfer') || key.contains("o'tkaz")) {
      return Icons.account_balance_rounded;
    }
    // Default: pul ikonkasi (hujjat emas)
    return Icons.payments_rounded;
  }
}

class _GlassSotuvchiTile extends StatelessWidget {
  final String sellerName;
  final int orderCount;
  final num totalSalesUzs;
  final String currency;

  const _GlassSotuvchiTile({
    required this.sellerName,
    required this.orderCount,
    required this.totalSalesUzs,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final formatted = totalSalesUzs != 0
        ? DailySalesFormat.formatWithCurrency(totalSalesUzs, currency)
        : (currency.isEmpty ? '0' : '0 $currency');
    return LiquidGlass(
      borderRadius: 14,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.primaryLight.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.person_rounded, color: AppTheme.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  sellerName.isEmpty ? '—' : sellerName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                if (orderCount > 0)
                  Text(
                    '$orderCount ta buyurtma',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary.withValues(alpha: 0.9),
                    ),
                  ),
              ],
            ),
          ),
          Text(
            formatted,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF16A34A),
            ),
          ),
        ],
      ),
    );
  }
}
