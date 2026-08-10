import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/input_formatters.dart';
import '../../core/theme.dart';
import '../../models/daily_sales.dart';
import '../../providers/dashboard_provider.dart';
import 'desktop_shell_scope.dart';
import '../../widgets/throttled_refresh_indicator.dart';

/// Desktop: butun sonlar — `.00` siz; kasrli qiymatda faqat kerakli kasrlar.
String _desktopFmtAmount(num n, String currency) {
  final sym = currency.trim();
  final d = n.toDouble();
  final String s;
  if ((d - d.roundToDouble()).abs() < 0.000001) {
    s = formatThousands(d.round());
  } else {
    var fixed = d.toStringAsFixed(2);
    if (fixed.endsWith('.00')) {
      s = formatThousands(d.round());
    } else {
      fixed = fixed.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
      s = fixed;
    }
  }
  return sym.isEmpty ? s : '$s $sym';
}

/// Desktop statistika — 2-rasm (veb panel) ko‘rinishi.
class AsosiyDesktopScreen extends StatefulWidget {
  const AsosiyDesktopScreen({super.key});

  @override
  State<AsosiyDesktopScreen> createState() => _AsosiyDesktopScreenState();
}

class _AsosiyDesktopScreenState extends State<AsosiyDesktopScreen> with DesktopShellSyncMixin {
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
  Future<void> onDesktopShellSync() => _load();

  Future<void> _pickDate() async {
    final dash = DashboardProvider.instance;
    final picked = await showDatePicker(
      context: context,
      initialDate: dash.selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) {
      await dash.loadFromApi(picked);
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    DashboardProvider.instance.removeListener(_onChanged);
    super.dispose();
  }

  static String _formatHeaderDate(DateTime d) {
    const months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${d.day} ${months[d.month]}, ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final dash = DashboardProvider.instance;
    final sales = dash.todaySales;
    final currency = dash.currencySymbol;
    final isLoading = dash.isLoading;
    final loadError = dash.loadError;

    final todayDebt = dash.todayDebt;
    final paymentTotal = dash.totalPaymentToday > 0
        ? dash.totalPaymentToday
        : sales.byPaymentType.fold<num>(0, (s, e) => s + e.amountUzs);
    final daxod = dash.todayDaxod;

    return ColoredBox(
      color: const Color(0xFFF1F5F9),
      child: ThrottledRefreshIndicator(
        onRefresh: _load,
        child: isLoading && sales.totalUzs == 0
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 200),
                  Center(child: CircularProgressIndicator(color: AppTheme.primary)),
                ],
              )
            : loadError != null
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(32),
                    children: [
                      Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
                      const SizedBox(height: 12),
                      Text(loadError, textAlign: TextAlign.center),
                      TextButton(onPressed: _load, child: const Text('Qayta yuklash')),
                    ],
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                    children: [
                      Center(
                        child: _DatePickerBar(
                          label: _formatHeaderDate(dash.selectedDate),
                          onPrev: () async {
                            final d = dash.selectedDate.subtract(const Duration(days: 1));
                            await dash.loadFromApi(d);
                            if (mounted) setState(() {});
                          },
                          onNext: () async {
                            final d = dash.selectedDate.add(const Duration(days: 1));
                            if (d.isAfter(DateTime.now())) return;
                            await dash.loadFromApi(d);
                            if (mounted) setState(() {});
                          },
                          onPick: _pickDate,
                        ),
                      ),
                      const SizedBox(height: 20),
                      LayoutBuilder(
                        builder: (context, c) {
                          final w = c.maxWidth;
                          final cols = w >= 1100 ? 4 : (w >= 700 ? 2 : 1);
                          return GridView.count(
                            crossAxisCount: cols,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            childAspectRatio: cols == 4 ? 3.4 : 2.8,
                            children: [
                              _MetricCard(
                                icon: Icons.add_shopping_cart_rounded,
                                value: _desktopFmtAmount(sales.totalUzs, currency),
                                label: Strings.bugungiSavdo,
                              ),
                              _MetricCard(
                                icon: Icons.payments_outlined,
                                value: _desktopFmtAmount(todayDebt, currency),
                                label: 'Bugungi qarz',
                              ),
                              _MetricCard(
                                icon: Icons.payments_outlined,
                                value: _desktopFmtAmount(sales.expensesUzs, currency),
                                label: 'Bugungi xarajat',
                              ),
                              _MetricCard(
                                icon: Icons.trending_up_rounded,
                                value: _desktopFmtAmount(daxod, currency),
                                label: 'Bugungi Даход',
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                      LayoutBuilder(
                        builder: (context, c) {
                          if (c.maxWidth >= 900) {
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: _SellersPanel(sellers: dash.sellers, currency: currency)),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _PaymentsPanel(
                                    items: sales.byPaymentType,
                                    currency: currency,
                                    total: paymentTotal,
                                    returnedAmount: dash.returnedToday,
                                  ),
                                ),
                              ],
                            );
                          }
                          return Column(
                            children: [
                              _SellersPanel(sellers: dash.sellers, currency: currency),
                              const SizedBox(height: 16),
                              _PaymentsPanel(
                                items: sales.byPaymentType,
                                currency: currency,
                                total: paymentTotal,
                                returnedAmount: dash.returnedToday,
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      _AdditionalInfoSection(dash: dash, currency: currency),
                      const SizedBox(height: 24),
                      LayoutBuilder(
                        builder: (context, c) {
                          final cols = c.maxWidth >= 900 ? 3 : (c.maxWidth >= 600 ? 2 : 1);
                          return GridView.count(
                            crossAxisCount: cols,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            childAspectRatio: cols == 3 ? 3.4 : 2.8,
                            children: [
                              _MetricCard(
                                icon: Icons.account_balance_wallet_outlined,
                                value: _desktopFmtAmount(daxod, currency),
                                label: 'Bugungi daromadi',
                              ),
                              _MetricCard(
                                icon: Icons.history_rounded,
                                value: _desktopFmtAmount(dash.yesterdayIncome, currency),
                                label: 'Kechagi daromadi',
                              ),
                              _MetricCard(
                                icon: Icons.calendar_month_rounded,
                                value: _desktopFmtAmount(dash.monthlyIncome, currency),
                                label: 'Bu oylik daromad',
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
      ),
    );
  }
}

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
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      elevation: 0,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.divider),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(icon: const Icon(Icons.chevron_left), onPressed: onPrev),
            InkWell(
              onTap: onPick,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Text(
                      label,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.calendar_today_outlined, size: 18, color: AppTheme.textSecondary),
                  ],
                ),
              ),
            ),
            IconButton(icon: const Icon(Icons.chevron_right), onPressed: onNext),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _MetricCard({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SellersPanel extends StatelessWidget {
  final List<SellerInfo> sellers;
  final String currency;

  const _SellersPanel({required this.sellers, required this.currency});

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Bugungi sotuvchilar hisobotlari',
      subtitle: 'Qaysi sotuvchi qancha savdo qilgani',
      child: sellers.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Sotuvchilar yo\'q', style: TextStyle(color: AppTheme.textSecondary)),
            )
          : Column(
              children: sellers.map((s) {
                return Container(
                  margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 18,
                        backgroundColor: AppTheme.primaryLight,
                        child: Icon(Icons.person, color: AppTheme.primary, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.sellerName.isEmpty ? '—' : s.sellerName,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                            ),
                            Text(
                              '${s.orderCount} ta buyurtma',
                              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        _desktopFmtAmount(s.totalSales, currency),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: Color(0xFF16A34A),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }
}

class _PaymentsPanel extends StatelessWidget {
  final List<PaymentTypeAmount> items;
  final String currency;
  final num total;
  final num returnedAmount;

  const _PaymentsPanel({
    required this.items,
    required this.currency,
    required this.total,
    required this.returnedAmount,
  });

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: "Bugungi to'lov turlari",
      subtitle: "To'lov usullari bo'yicha taqsimot",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.primary,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    "Bugungi jami to'lov",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  _desktopFmtAmount(total, currency),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: LayoutBuilder(
              builder: (context, c) {
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: items.map((e) {
                    return SizedBox(
                      width: (c.maxWidth - 8) / 2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppTheme.divider),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                e.label,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              _desktopFmtAmount(e.amountUzs, currency),
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Bugungi qaytarilgan summa',
                    style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                  ),
                ),
                Text(
                  _desktopFmtAmount(returnedAmount, currency),
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;

  const _Panel({required this.title, required this.child, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, subtitle == null ? 8 : 2),
            child: Text(
              title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
            ),
          ),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                subtitle!,
                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
            ),
          child,
        ],
      ),
    );
  }
}

/// "Qo'shimcha ma'lumot" — veb paneldagi 3×2 kartalar.
class _AdditionalInfoSection extends StatelessWidget {
  final DashboardProvider dash;
  final String currency;

  const _AdditionalInfoSection({required this.dash, required this.currency});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.divider),
      ),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            "Qo'shimcha ma'lumot",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 4),
          const Text(
            'Savdo va mahsulotlar tahlili',
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: AppTheme.divider),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, c) {
              final cols = c.maxWidth >= 1000 ? 3 : (c.maxWidth >= 640 ? 2 : 1);
              return GridView.count(
                crossAxisCount: cols,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: cols == 3 ? 3.6 : (cols == 2 ? 3.2 : 2.8),
                children: [
                  _AdditionalInfoTile(
                    icon: Icons.shopping_basket_outlined,
                    label: 'Kunlik sotilgan mahsulotlar',
                    value: '${dash.soldProductsToday} dona',
                  ),
                  _AdditionalInfoTile(
                    icon: Icons.inventory_2_outlined,
                    label: 'Umumiy mahsulotlar',
                    value: '${dash.totalProductsCount} dona',
                  ),
                  _AdditionalInfoTile(
                    icon: Icons.payments_outlined,
                    label: 'Umumiy qarzdorlik:',
                    value: _desktopFmtAmount(dash.totalDebtAll, currency),
                    valueColor: const Color(0xFFDC2626),
                  ),
                  _AdditionalInfoTile(
                    icon: Icons.account_balance_outlined,
                    label: 'Ostatka (Sotish narxi)',
                    value: _desktopFmtAmount(dash.salesValue, currency),
                  ),
                  _AdditionalInfoTile(
                    icon: Icons.shopping_cart_outlined,
                    label: 'Ostatka (Kelish narxi)',
                    value: _desktopFmtAmount(dash.warehouseValue, currency),
                  ),
                  _AdditionalInfoTile(
                    icon: Icons.layers_outlined,
                    label: 'Umumiy ostatka tovar soni',
                    value: '${dash.totalStockQuantity} dona',
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AdditionalInfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _AdditionalInfoTile({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.25),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 17,
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
