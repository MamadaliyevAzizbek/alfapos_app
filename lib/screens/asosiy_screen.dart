import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../core/constants.dart';
import '../core/theme.dart';
import '../models/daily_sales.dart';
import '../providers/dashboard_provider.dart';
import '../widgets/liquid_glass.dart';

class AsosiyScreen extends StatefulWidget {
  const AsosiyScreen({super.key});

  static const double cardRadius = 18;

  @override
  State<AsosiyScreen> createState() => _AsosiyScreenState();
}

class _AsosiyScreenState extends State<AsosiyScreen> {
  @override
  void initState() {
    super.initState();
    DashboardProvider.instance.addListener(_onChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _onChanged() => setState(() {});

  Future<void> _load() async {
    await DashboardProvider.instance.loadFromApi();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    DashboardProvider.instance.removeListener(_onChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = DashboardProvider.instance;
    // Bugungi savdo va xarajatlar faqat API dan (DashboardProvider.todaySales)
    final DailySales sales = dashboard.todaySales;
    final todayExpenses = sales.expensesUzs;
    final currency = dashboard.currencySymbol;
    final safePadding = MediaQuery.paddingOf(context);
    final loadError = dashboard.loadError;
    final isLoading = dashboard.isLoading;

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(Strings.navAsosiy, style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
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
                          Text('Ma\'lumotlar yuklanmoqda...', style: TextStyle(fontSize: 15, color: AppTheme.textSecondary)),
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
                            Text(loadError, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, color: AppTheme.textSecondary)),
                            const SizedBox(height: 16),
                            TextButton.icon(
                              onPressed: () => _load(),
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Qayta yuklash'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : CustomScrollView(
            physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics()),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Bugungi savdo — to'liq qator
                      SizedBox(
                        width: double.infinity,
                        child: _GlassMetricCard(
                          title: Strings.bugungiUmumiySavdo,
                          amount: sales.totalFormatted(currency),
                          color: AppTheme.primary,
                          subtitle: sales.transactionCount > 0
                              ? "${sales.transactionCount} ta sotuv"
                              : null,
                        ),
                      ),
                      const SizedBox(height: 10),
                      // 2. Bugungi xarajatlar — to'liq qator (to'lov turi kartochkalari bilan bir xil o'lcham)
                      SizedBox(
                        width: double.infinity,
                        child: _GlassMetricCard(
                          title: Strings.bugungiUmumiyXarajatlar,
                          amount: DailySalesFormat.formatWithCurrency(todayExpenses, currency),
                          color: Colors.orange.shade700,
                          subtitle: null,
                        ),
                      ),
                      const SizedBox(height: 20),
                      // To'lov turlari bo'yicha
                      _SectionTitle(Strings.tolovTurlari),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = sales.byPaymentType[index];
                      final isQarz = item.label.toLowerCase().contains('qarz');
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _GlassTolovTuriTile(amount: item, currency: currency, isQarz: isQarz),
                      );
                    },
                    childCount: sales.byPaymentType.length,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                  child: _SectionTitle('Bugungi sotuvchilar hisoboti'),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final s = dashboard.sellers[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _GlassSotuvchiTile(
                          sellerName: s.sellerName,
                          orderCount: s.orderCount,
                          totalSalesUzs: s.totalSales,
                          currency: currency,
                        ),
                      );
                    },
                    childCount: dashboard.sellers.length,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                  child: _GlassMetricCard(
                    title: Strings.bugungiUmumiySofFoyda,
                    amount: dashboard.todayDaromadUzs != null
                        ? DailySalesFormat.formatWithCurrency(dashboard.todayDaromadUzs!, currency)
                        : sales.netProfitFormatted(currency),
                    color: (dashboard.todayDaromadUzs ?? sales.netProfitUzs) >= 0
                        ? Colors.green.shade700
                        : Colors.red.shade700,
                    subtitle: dashboard.todayDaromadUzs != null
                        ? 'API: Bugungi daromad'
                        : 'Sotish − kelish narxi (marja)',
                  ),
                ),
              ),
              SliverToBoxAdapter(
                  child: SizedBox(height: safePadding.bottom + 16)),
            ],
          ),
        ),
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

class _GlassMetricCard extends StatelessWidget {
  final String title;
  final String amount;
  final Color color;
  final String? subtitle;

  const _GlassMetricCard({
    required this.title,
    required this.amount,
    required this.color,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return LiquidGlass(
      borderRadius: AsosiyScreen.cardRadius,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            amount,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: -0.5,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
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
    final icon = isQarz ? Icons.receipt_long_rounded : _iconForType(amount.typeId);
    final accentColor = isQarz ? Colors.red.shade700 : AppTheme.primary;
    return LiquidGlass(
      borderRadius: 14,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: (isQarz ? Colors.red.shade50 : AppTheme.primaryLight).withValues(alpha: isQarz ? 0.8 : 0.6),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: accentColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              amount.label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isQarz ? Colors.red.shade800 : AppTheme.textPrimary,
              ),
            ),
          ),
          Text(
            amount.amountFormatted(currency),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isQarz ? Colors.red.shade700 : (amount.amountUzs != 0 ? AppTheme.textPrimary : AppTheme.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  static IconData _iconForType(String typeId) {
    switch (typeId) {
      case 'naqd':
        return CupertinoIcons.money_dollar_circle_fill;
      case 'karta':
      case 'uzcard':
      case 'humo':
        return CupertinoIcons.creditcard_fill;
      case 'payme':
        return CupertinoIcons.phone_fill;
      case 'qarz':
        return Icons.receipt_long_rounded;
      default:
        return CupertinoIcons.doc_text_fill;
    }
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
        : (currency.isEmpty ? '0.00' : '0.00 $currency');
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
                  sellerName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                if (orderCount > 0)
                  Text(
                    '$orderCount ta savdo',
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
              color: AppTheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}
