import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/api_client.dart';
import '../core/app_notify.dart';
import '../core/constants.dart';
import '../core/theme.dart';
import '../core/input_formatters.dart';
import '../providers/clients_provider.dart';
import '../services/api_service.dart';
import '../utils/customer_bulk_payment.dart';
import '../utils/customer_balance_transaction.dart';
import '../utils/customer_orders.dart';
import '../utils/platform_layout.dart';
import 'api_chek_detail_screen.dart';
import 'desktop/desktop_shell_scope.dart';
import 'yangi_mijoz_screen.dart';
import '../widgets/app_dropdown.dart';
import '../widgets/ios_style_modals.dart';
import '../widgets/throttled_refresh_indicator.dart';

/// Mijoz detali: ma'lumotlar, cheklar ro'yxati, qarz to'lash
class MijozDetailScreen extends StatefulWidget {
  final Client client;
  /// Ro‘yxatdan «Umumiy to‘lash» — yuklangach dialog ochiladi.
  final bool openPaymentOnStart;

  const MijozDetailScreen({
    super.key,
    required this.client,
    this.openPaymentOnStart = false,
  });

  @override
  State<MijozDetailScreen> createState() => _MijozDetailScreenState();
}

class _MijozDetailScreenState extends State<MijozDetailScreen> with SingleTickerProviderStateMixin {
  static const int _ordersPageSize = 20;
  late Client _client;
  TabController? _tabs;
  num _totalDebt = 0;
  num _balance = 0;
  List<Map<String, dynamic>> _apiOrders = [];
  List<Map<String, dynamic>> _balanceRows = [];
  List<Map<String, dynamic>> _paymentTypes = [];
  bool _loading = true;
  bool _balanceLoading = false;
  bool _ordersLoadingMore = false;
  bool _ordersHasMore = true;
  int _ordersOffset = 0;
  String _groupLabel = '';
  bool _autoTelegramReceipt = false;

  void _goBack() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  bool get _desktop => isDesktopPosLayout;

  double get _btnHeight => _desktop ? 52 : 44;

  double get _btnFontSize => _desktop ? 16 : 14;

  double get _rowPadV => _desktop ? 20 : 14;

  double get _rowPadH => _desktop ? 24 : 16;

  double get _cellFontSize => _desktop ? 16 : 14;

  double get _headerFontSize => _desktop ? 14 : 12;

  double get _debtLabelFontSize => _desktop ? 16 : 14;

  double get _debtValueFontSize => _desktop ? 20 : 16;

  double get _actionBtnWidth => _desktop ? 220 : 180;

  double get _sidebarBtnHeight => _desktop ? 52 : 48;

  static const _debtRed = Color(0xFFDC2626);

  static const _primaryBlue = Color(0xFF2563EB);

  @override
  void initState() {
    super.initState();
    _client = widget.client;
    _tabs = TabController(length: 2, vsync: this);
    _tabs!.addListener(_onTabChanged);
    _load();
  }

  void _onTabChanged() {
    final tabs = _tabs;
    if (tabs == null || tabs.indexIsChanging) return;
    if (tabs.index == 1 && _balanceRows.isEmpty && !_balanceLoading) {
      _loadBalanceHistory();
    }
  }

  @override
  void dispose() {
    _tabs?.removeListener(_onTabChanged);
    _tabs?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    final idNum = int.tryParse(_client.id);
    if (idNum == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    // Avval hozirgi ma'lumotni darhol ko'rsatamiz
    _totalDebt = _client.dueAmount ?? 0;
    _balance = _client.balance ?? 0;

    final customerFuture = ContactsApi.getCustomer(idNum);

    try {
      final customerRes = await customerFuture;

      final customer = customerRes['customer'] as Map<String, dynamic>? ?? customerRes;
      final one = Client.fromApiJson(Map<String, dynamic>.from(customer));
      _client = one;
      _totalDebt = one.dueAmount ?? _totalDebt;
      _balance = one.balance ?? _balance;
      _groupLabel = (customer['customer_group_title'] ??
              customer['group_name'] ??
              customer['customer_group_name'] ??
              '')
          .toString();
      _autoTelegramReceipt = _readAutoTelegram(customer);

      await _loadOrdersPage(reset: true);
      await _loadBulkPaymentTypes();
      // Customer due_amount — asosiy manba (to'lovdan keyin 0 bo'lishi kerak).
      if (_client.dueAmount != null) {
        _totalDebt = _client.dueAmount!;
      }
    } catch (_) {
      // qisman xato bo'lsa ham ekran qolgan ma'lumot bilan ishlaydi
    } finally {
      if (mounted) setState(() => _loading = false);
      if (widget.openPaymentOnStart && !_desktop && _totalDebt > 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showPayDebtDialog(context);
        });
      }
    }
  }

  Future<void> _loadOrdersPage({required bool reset}) async {
    final idNum = int.tryParse(_client.id);
    if (idNum == null) return;
    if (!reset && (_ordersLoadingMore || !_ordersHasMore)) return;

    if (reset) {
      _ordersOffset = 0;
      _ordersHasMore = true;
      _apiOrders = [];
    } else {
      if (mounted) setState(() => _ordersLoadingMore = true);
    }
    try {
      final res = await ContactsApi.getCustomerOrders(idNum, body: {
        'merge_customer_debts': true,
        'rowLimit': _ordersPageSize,
        'rowOffset': _ordersOffset,
        'columnKey': 'date',
        'columnSortedBy': 'DESC',
        'filtersData': [
          {'key': 'payment_type', 'value': 'all'},
        ],
      });

      if (_ordersOffset == 0) {
        _applyTotalDebtFromApi(res);
      }

      final raw = CustomerOrderRow.extractList(res);
      final list = raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e as Map))
          .where((o) => !CustomerOrderRow.isSummaryRow(o))
          .toList();
      final merged = _deduplicateOrdersById([..._apiOrders, ...list]);
      _apiOrders = merged;

      final fetchedCount = list.length;
      _ordersOffset += fetchedCount;
      _ordersHasMore = fetchedCount >= _ordersPageSize;
    } catch (_) {
      if (reset) _apiOrders = [];
    } finally {
      if (!reset && mounted) setState(() => _ordersLoadingMore = false);
    }
  }

  /// Jami qarz: avvalo GET /customers/{id} `due_amount`, keyin orders `totalDebt`.
  void _applyTotalDebtFromApi(Map<String, dynamic> res) {
    if (_client.dueAmount != null) {
      _totalDebt = _client.dueAmount!;
      return;
    }
    final fromOrders = res['totalDebt'] ?? res['total_debt'];
    if (fromOrders != null) {
      final n = parseAmountFromApi(fromOrders);
      if (n >= 0) _totalDebt = n;
    }
  }

  static bool _readAutoTelegram(Map<String, dynamic> customer) {
    final v = customer['auto_telegram_customer_receipt'] ?? customer['autoTelegramCustomerReceipt'];
    return v == true || v == 1 || v == '1';
  }

  Future<void> _loadBalanceHistory() async {
    if (mounted) setState(() => _balanceLoading = true);
    try {
      _balanceRows = await ClientsProvider.instance.fetchBalanceTransactions(_client.id);
    } catch (_) {
      _balanceRows = [];
    } finally {
      if (mounted) setState(() => _balanceLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_desktop) return _buildDesktopScaffold(context);
    return _buildMobileScaffold(context);
  }

  /// Mobil — vertikal scroll (desktop Row layout emas).
  Widget _buildMobileScaffold(BuildContext context) {
    final c = _client;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FF),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(c.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            onPressed: () => _showEditDialog(context),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TabBar(
              controller: _tabs,
              labelColor: AppTheme.primary,
              unselectedLabelColor: AppTheme.textSecondary,
              indicatorColor: AppTheme.primary,
              tabs: const [
                Tab(text: 'Cheklar'),
                Tab(text: 'Balans tarixi'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                ThrottledRefreshIndicator(
                  onRefresh: _load,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0D6EFD), Color(0xFF4DA3FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0D6EFD).withValues(alpha: 0.28),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Mijoz dashboard",
                      style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      c.name,
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
                    if (c.phone != null && c.phone!.isNotEmpty)
                      Row(
                        children: [
                          const Icon(Icons.phone_rounded, color: Colors.white, size: 16),
                          const SizedBox(width: 6),
                          Text(c.phone!, style: const TextStyle(color: Colors.white, fontSize: 13)),
                        ],
                      ),
                    if (c.address != null && c.address!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.location_on_rounded, color: Colors.white, size: 16),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(c.address!, style: const TextStyle(color: Colors.white, fontSize: 13)),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _metricCard(
                      title: "Jami qarz",
                      value: _formatAmount(_totalDebt),
                      valueColor: _totalDebt > 0 ? Colors.red.shade700 : const Color(0xFF2D5B9A),
                      icon: Icons.receipt_long_rounded,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _metricCard(
                      title: "Balans",
                      value: _formatAmount(_balance),
                      valueColor: _balance > 0
                          ? Colors.green.shade700
                          : (_balance < 0 ? Colors.red.shade700 : const Color(0xFF2D5B9A)),
                      icon: Icons.account_balance_wallet_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildToolbar(),
              const SizedBox(height: 16),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
                )
              else if (_apiOrders.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: Text(
                      "Bu mijoz uchun chek topilmadi",
                      style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                    ),
                  ),
                )
              else ...[
                ..._apiOrders.map((o) {
                  final invoiceId = (o['invoice_id'] ?? o['invoiceId'] ?? '').toString();
                  final totalInt = parseAmountFromApi(o['total'] ?? o['grand_total'] ?? o['total_amount'] ?? 0);
                  final total = formatThousands(totalInt);
                  final due = parseAmountFromApi(o['due_amount'] ?? 0);
                  final dateStr = (o['date'] ?? o['created_at'] ?? '').toString();
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
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFE6F1FF),
                        child: Icon(Icons.receipt_long_rounded, color: Color(0xFF0D6EFD)),
                      ),
                      title: Text(
                        invoiceId.isNotEmpty ? "Chek #$invoiceId" : "Chek",
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text([if (dateStr.isNotEmpty) dateStr, total].join(" — ")),
                      trailing: due > 0
                          ? Text(
                              "Qoldiq: ${formatThousands(due)}",
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.red),
                            )
                          : const Icon(Icons.chevron_right_rounded, color: Color(0xFF5C8DFF)),
                      onTap: () => _openApiChek(context, o),
                    ),
                  );
                }),
                if (_ordersHasMore)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 8),
                    child: Center(
                      child: OutlinedButton.icon(
                        onPressed: _ordersLoadingMore
                            ? null
                            : () => _loadOrdersPage(reset: false).then((_) {
                                  if (mounted) setState(() {});
                                }),
                        icon: _ordersLoadingMore
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.expand_more_rounded),
                        label: Text(_ordersLoadingMore ? "Yuklanmoqda..." : "Yana yuklash"),
                      ),
                    ),
                  ),
              ],
                    ],
                  ),
                ),
              ),
                _buildBalanceTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Desktop POS — chap sidebar + jadval.
  Widget _buildDesktopScaffold(BuildContext context) {
    final tabs = _tabs!;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): _goBack,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              tooltip: 'Orqaga (Esc)',
              onPressed: _goBack,
            ),
            title: Text(_client.name),
            actions: [
              // Shell «Sinxronlash» bo‘lsa dublikat yo‘q; push route’da Yangilash qoladi.
              if (DesktopShellScope.maybeOf(context) == null)
                IconButton(
                  tooltip: 'Yangilash',
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: _loading ? null : _load,
                ),
            ],
          ),
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(width: 320, child: _buildLeftSidebar()),
              const VerticalDivider(width: 1, thickness: 1),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildToolbar(),
                    TabBar(
                      controller: tabs,
                      labelColor: AppTheme.primary,
                      unselectedLabelColor: AppTheme.textSecondary,
                      indicatorColor: AppTheme.primary,
                      labelStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      unselectedLabelStyle: const TextStyle(fontSize: 16),
                      tabs: const [
                        Tab(text: 'Mijoz sotuvlar'),
                        Tab(text: 'Balans tarixi'),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        controller: tabs,
                        children: [
                          _buildOrdersTable(),
                          _buildBalanceTab(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLeftSidebar() {
    final c = _client;
    return ColoredBox(
      color: const Color(0xFFF1F5F9),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sidebarCard(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: _desktop ? 44 : 38,
                    backgroundColor: const Color(0xFFE8F0FE),
                    child: Icon(Icons.person_rounded, size: _desktop ? 48 : 40, color: _primaryBlue),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    c.name,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: _desktop ? 18 : 16, fontWeight: FontWeight.w700),
                  ),
                  if (_groupLabel.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline, size: 14, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(_groupLabel, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                      ],
                    ),
                  ],
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Divider(height: 1),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Mijoz ma\'lumoti',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (c.phone != null && c.phone!.isNotEmpty)
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.phone_outlined, size: 18, color: AppTheme.textSecondary),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Text(c.phone!, style: TextStyle(fontSize: _cellFontSize))),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _sidebarCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text('Balans', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                      ),
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F0FE),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.account_balance_wallet_outlined, size: 18, color: _primaryBlue),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _formatAmount(_balance),
                    style: TextStyle(
                      fontSize: _desktop ? 32 : 28,
                      fontWeight: FontWeight.w700,
                      color: _primaryBlue,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _sidebarFullButton(
                    label: 'Balans qo\'shish',
                    icon: Icons.add,
                    backgroundColor: const Color(0xFF4B5563),
                    foregroundColor: Colors.white,
                    onPressed: () => _showAddBalanceDialog(context),
                  ),
                  const SizedBox(height: 10),
                  _sidebarFullButton(
                    label: 'Telegramga yuborish',
                    icon: Icons.send_rounded,
                    backgroundColor: _primaryBlue,
                    foregroundColor: Colors.white,
                    onPressed: _sendTelegramDebtBalance,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Switch(
                        value: _autoTelegramReceipt,
                        onChanged: _toggleAutoTelegram,
                        activeColor: _primaryBlue,
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(
                            'To\'lovdan keyin chekni Telegramga avtomatik yuborish',
                            style: TextStyle(fontSize: _desktop ? 13 : 12, height: 1.35),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sidebarCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider),
      ),
      child: child,
    );
  }

  Widget _sidebarFullButton({
    required String label,
    required IconData icon,
    required Color backgroundColor,
    required Color foregroundColor,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: _sidebarBtnHeight,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: TextStyle(fontSize: _btnFontSize, fontWeight: FontWeight.w600),
        ),
        icon: Icon(icon, size: _desktop ? 20 : 18),
        label: Text(label),
      ),
    );
  }

  Widget _buildDebtActionButton({
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
    required bool filled,
  }) {
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(28));
    final iconSize = _desktop ? 22.0 : 20.0;

    return SizedBox(
      width: _desktop ? _actionBtnWidth : double.infinity,
      height: _btnHeight,
      child: filled
          ? FilledButton.icon(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                backgroundColor: _primaryBlue,
                foregroundColor: Colors.white,
                shape: shape,
                textStyle: TextStyle(fontSize: _btnFontSize, fontWeight: FontWeight.w600),
                padding: const EdgeInsets.symmetric(horizontal: 20),
              ),
              icon: Icon(icon, size: iconSize),
              label: Text(label),
            )
          : OutlinedButton.icon(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: _debtRed,
                side: const BorderSide(color: _debtRed, width: 1.5),
                shape: shape,
                textStyle: TextStyle(fontSize: _btnFontSize, fontWeight: FontWeight.w600),
                padding: const EdgeInsets.symmetric(horizontal: 20),
              ),
              icon: Icon(icon, size: iconSize),
              label: Text(label),
            ),
    );
  }

  Widget _buildToolbar() {
    final debtLabel = Text.rich(
      TextSpan(
        text: 'Umumiy qarzdorlik: ',
        style: TextStyle(fontSize: _debtLabelFontSize, color: AppTheme.textSecondary),
        children: [
          TextSpan(
            text: _formatAmount(_totalDebt),
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: _debtRed,
              fontSize: _debtValueFontSize,
            ),
          ),
        ],
      ),
    );

    final payButtons = Row(
      children: [
        Expanded(
          child: _buildDebtActionButton(
            label: 'Qarz qo\'shish',
            icon: Icons.add,
            onPressed: () => _showAddDebtDialog(context),
            filled: false,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildDebtActionButton(
            label: Strings.umumiyTolash,
            icon: Icons.credit_card_rounded,
            onPressed: _totalDebt > 0 ? () => _showPayDebtDialog(context) : null,
            filled: true,
          ),
        ),
      ],
    );

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(_rowPadH, _desktop ? 20 : 14, _rowPadH, _desktop ? 20 : 14),
      decoration: BoxDecoration(
        color: _desktop ? null : Colors.white,
        borderRadius: _desktop ? null : BorderRadius.circular(14),
        border: Border.all(color: AppTheme.divider),
      ),
      child: _desktop
          ? Row(
              children: [
                Expanded(child: debtLabel),
                SizedBox(
                  width: _actionBtnWidth,
                  child: _buildDebtActionButton(
                    label: 'Qarz qo\'shish',
                    icon: Icons.add,
                    onPressed: () => _showAddDebtDialog(context),
                    filled: false,
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: _actionBtnWidth,
                  child: _buildDebtActionButton(
                    label: Strings.umumiyTolash,
                    icon: Icons.credit_card_rounded,
                    onPressed: _totalDebt > 0 ? () => _showPayDebtDialog(context) : null,
                    filled: true,
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                debtLabel,
                const SizedBox(height: 12),
                payButtons,
              ],
            ),
    );
  }

  Future<void> _sendTelegramDebtBalance() async {
    final idNum = int.tryParse(_client.id);
    if (idNum == null) return;
    try {
      await ContactsApi.sendTelegramDebtBalance(idNum);
      if (mounted) AppNotify.success(context, 'Telegramga yuborildi');
    } catch (e) {
      if (mounted) AppNotify.error(context, '$e');
    }
  }

  Future<void> _toggleAutoTelegram(bool value) async {
    final idNum = int.tryParse(_client.id);
    if (idNum == null) return;
    setState(() => _autoTelegramReceipt = value);
    try {
      await ContactsApi.setAutoTelegramCustomerReceipt(idNum, value);
    } catch (e) {
      if (mounted) {
        setState(() => _autoTelegramReceipt = !value);
        AppNotify.error(context, '$e');
      }
    }
  }

  Widget _buildOrdersTable() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    }
    if (_apiOrders.isEmpty) {
      return Center(
        child: Text(
          'Ma\'lumot yo\'q',
          style: TextStyle(fontSize: _cellFontSize, color: AppTheme.textSecondary),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(_rowPadH, _desktop ? 16 : 8, _rowPadH, _desktop ? 16 : 8),
      child: Column(
        children: [
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: AppTheme.divider),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildOrdersTableHeader(),
                    Expanded(
                      child: ColoredBox(
                        color: const Color(0xFFFAFBFC),
                        child: ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: _apiOrders.length,
                          separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.divider),
                          itemBuilder: (context, i) => _buildOrderRow(_apiOrders[i], i),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_ordersHasMore)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: OutlinedButton.icon(
                style: ButtonStyle(
                  minimumSize: WidgetStateProperty.all(Size(0, _btnHeight)),
                  textStyle: WidgetStateProperty.all(TextStyle(fontSize: _btnFontSize)),
                ),
                onPressed: _ordersLoadingMore
                    ? null
                    : () => _loadOrdersPage(reset: false).then((_) {
                          if (mounted) setState(() {});
                        }),
                icon: _ordersLoadingMore
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(Icons.expand_more_rounded, size: _desktop ? 22 : 18),
                label: Text(_ordersLoadingMore ? 'Yuklanmoqda...' : 'Yana yuklash'),
              ),
            ),
        ],
      ),
    );
  }

  TextStyle get _tableHeaderStyle => TextStyle(
        fontSize: _headerFontSize,
        fontWeight: FontWeight.w600,
        color: AppTheme.textSecondary,
      );

  TextStyle get _tableCellStyle => TextStyle(fontSize: _cellFontSize, color: AppTheme.textPrimary);

  Widget _buildOrdersTableHeader() {
    return Container(
      color: const Color(0xFFF1F5F9),
      padding: EdgeInsets.symmetric(horizontal: _rowPadH, vertical: _desktop ? 16 : 12),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text('Chek id', style: _tableHeaderStyle)),
          Expanded(flex: 4, child: Text('Sana', style: _tableHeaderStyle)),
          Expanded(flex: 3, child: Text('Sotuvchi', style: _tableHeaderStyle)),
          Expanded(flex: 2, child: Text('Umumiy', style: _tableHeaderStyle, textAlign: TextAlign.end)),
          Expanded(flex: 2, child: Text('Qarz', style: _tableHeaderStyle, textAlign: TextAlign.end)),
        ],
      ),
    );
  }

  Widget _buildOrderRow(Map<String, dynamic> raw, int index) {
    final row = CustomerOrderRow(raw);
    final seller = (raw['seller_name'] ?? raw['employee_name'] ?? raw['seller'] ?? '—').toString();
    final due = row.dueAmount;
    final chekLabel = row.invoiceId.isNotEmpty ? row.invoiceId : row.displayTitle;
    final bg = index.isEven ? Colors.white : const Color(0xFFF8FAFC);

    return Material(
      color: bg,
      child: InkWell(
        onTap: row.isOrder ? () => _openApiChek(context, raw) : null,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: _rowPadH, vertical: _rowPadV),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  chekLabel,
                  style: _tableCellStyle.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: _desktop ? 17 : 15,
                    color: row.isOrder ? const Color(0xFF2563EB) : AppTheme.textPrimary,
                  ),
                ),
              ),
              Expanded(
                flex: 4,
                child: Text(row.dateStr.isEmpty ? '—' : row.dateStr, style: _tableCellStyle),
              ),
              Expanded(flex: 3, child: Text(seller, style: _tableCellStyle)),
              Expanded(
                flex: 2,
                child: Text(_formatAmount(row.total), textAlign: TextAlign.end, style: _tableCellStyle),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  _formatAmount(due),
                  textAlign: TextAlign.end,
                  style: _tableCellStyle.copyWith(
                    fontWeight: due != 0 ? FontWeight.w700 : FontWeight.normal,
                    color: due > 0
                        ? const Color(0xFFDC2626)
                        : due < 0
                            ? const Color(0xFF059669)
                            : AppTheme.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBalanceTab() {
    if (_balanceLoading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    }
    if (_balanceRows.isEmpty) {
      return Center(
        child: Text(
          'Balans harakatlari yo\'q',
          style: TextStyle(fontSize: _cellFontSize, color: AppTheme.textSecondary),
        ),
      );
    }

    // Mobilda 5 ustunli jadval sig'maydi — har bir yozuv karta ko'rinishida.
    if (!_desktop) {
      return ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        itemCount: _balanceRows.length,
        itemBuilder: (context, i) => _buildBalanceCard(_balanceRows[i]),
      );
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(_rowPadH, _desktop ? 16 : 8, _rowPadH, _desktop ? 16 : 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppTheme.divider),
          borderRadius: BorderRadius.circular(8),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildBalanceTableHeader(),
              Expanded(
                child: ColoredBox(
                  color: const Color(0xFFFAFBFC),
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: _balanceRows.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.divider),
                    itemBuilder: (context, i) => _buildBalanceRow(_balanceRows[i], i),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Mobil karta: sana + summa, tavsif, yaratgan va o'chirish tugmasi.
  Widget _buildBalanceCard(Map<String, dynamic> raw) {
    final row = CustomerBalanceTransactionRow(raw);
    final amountText =
        CustomerBalanceTransactionRow.formatSignedAmount(row.signedAmount);
    final amountColor = row.signedAmount < 0
        ? const Color(0xFFDC2626)
        : row.signedAmount > 0
            ? const Color(0xFF16A34A)
            : AppTheme.textPrimary;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        row.dateDisplay,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      amountText,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: amountColor,
                      ),
                    ),
                  ],
                ),
                if (row.description.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    row.description,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.textPrimary,
                      height: 1.3,
                    ),
                  ),
                ],
                if (row.createdBy.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.person_outline_rounded,
                        size: 14,
                        color: AppTheme.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          row.createdBy,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (row.id != null)
            IconButton(
              tooltip: 'O\'chirish',
              onPressed: () => _deleteBalanceTransaction(row.id!),
              visualDensity: VisualDensity.compact,
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: Color(0xFFDC2626),
                size: 20,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBalanceTableHeader() {
    return Container(
      color: const Color(0xFFF1F5F9),
      padding: EdgeInsets.symmetric(horizontal: _rowPadH, vertical: _desktop ? 16 : 12),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text('Sana', style: _tableHeaderStyle)),
          Expanded(flex: 2, child: Text('Summa', style: _tableHeaderStyle)),
          Expanded(flex: 5, child: Text('Tavsif', style: _tableHeaderStyle)),
          Expanded(flex: 3, child: Text('Yaratgan', style: _tableHeaderStyle)),
          SizedBox(
            width: _desktop ? 52 : 44,
            child: Text('Amal', style: _tableHeaderStyle, textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceRow(Map<String, dynamic> raw, int index) {
    final row = CustomerBalanceTransactionRow(raw);
    final amountText = CustomerBalanceTransactionRow.formatSignedAmount(row.signedAmount);
    final amountColor = row.signedAmount < 0
        ? const Color(0xFFDC2626)
        : row.signedAmount > 0
            ? const Color(0xFF16A34A)
            : AppTheme.textPrimary;
    final bg = index.isEven ? Colors.white : const Color(0xFFF8FAFC);

    return Material(
      color: bg,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: _rowPadH, vertical: _rowPadV),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              flex: 3,
              child: Text(
                row.dateDisplay,
                style: _tableCellStyle,
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                amountText,
                style: _tableCellStyle.copyWith(
                  fontWeight: FontWeight.w700,
                  color: amountColor,
                ),
              ),
            ),
            Expanded(
              flex: 5,
              child: Text(
                row.description,
                style: _tableCellStyle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                row.createdBy,
                style: _tableCellStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(
              width: _desktop ? 52 : 44,
              child: Center(
                child: row.id != null
                    ? IconButton(
                        tooltip: 'O\'chirish',
                        onPressed: () => _deleteBalanceTransaction(row.id!),
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0xFFE53935),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 18),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteBalanceTransaction(int transactionId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('O\'chirish'),
        content: const Text('Ushbu balans yozuvini o\'chirasizmi?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text(Strings.bekorQilish)),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Ha'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ContactsApi.deleteCustomerBalanceTransaction(transactionId);
      await _loadBalanceHistory();
      await _load();
      if (mounted) AppNotify.success(context, 'O\'chirildi');
    } catch (e) {
      if (mounted) AppNotify.error(context, '$e');
    }
  }

  /// API chek (mijoz orders) ustiga bosilganda: invoice-details yuklab, ApiChekDetailScreen ochish.
  Future<void> _openApiChek(BuildContext context, Map<String, dynamic> order) async {
    final orderId = getOrderIdFromSale(order);
    if (orderId == null) {
      if (context.mounted) {
        AppNotify.warning(context, "Chek ID aniqlanmadi");
      }
      return;
    }
    Map<String, dynamic>? detail;
    String? loadError;
    try {
      detail = await ReportsApi.getInvoiceDetails(orderId);
    } catch (e) {
      loadError = e.toString();
      try {
        final now = DateTime.now();
        final to = now.toIso8601String().substring(0, 10);
        final from = now.subtract(const Duration(days: 30)).toIso8601String().substring(0, 10);
        final invoice = (order['invoice_id'] ?? order['order_id'] ?? order['id'] ?? '').toString();
        detail = await ReportsApi.getSalesAllDetails(
          body: ReportsApi.salesAllDetailsBody(
            from: from,
            to: to,
            rowLimit: 200,
            rowOffset: 0,
            searchValue: invoice,
          ),
        );
      } catch (_) {}
    }
    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ApiChekDetailScreen(
          sale: order,
          invoiceDetail: detail ?? {},
          invoiceLoadError: loadError,
        ),
      ),
    ).then((_) => _load());
  }

  /// API javobidan buyurtmalar ro'yxati — datarows, data.datarows, orders va h.k.
  static List<dynamic> _extractOrdersList(Map<String, dynamic> res) {
    dynamic raw = res['datarows'] ?? res['orders'] ?? res['data'];
    if (raw is List<dynamic>) return raw;
    if (raw is Map<String, dynamic>) {
      final inner = raw['datarows'] ?? raw['orders'] ?? raw['data'] ?? raw['items'];
      if (inner is List<dynamic>) return inner;
    }
    return [];
  }

  /// Jadval oxiridagi umumiy qarz qatori — chek emas, ko'rsatilmasin (API dagi "Umumiy" / "Jami" qatori)
  static bool _isSummaryRow(Map<String, dynamic> o) {
    final title = (o['title'] ?? o['name'] ?? o['label'] ?? o['type'] ?? '').toString().trim().toLowerCase();
    if (title.isNotEmpty) {
      if (title == 'umumiy' || title == 'total' || title == 'jami' || title == 'general total' || title == 'overall') return true;
      if (title.contains('umumiy') || title.contains('jami') || title == 'grand total') return true;
    }
    if (o['is_total'] == true || o['is_summary'] == true || o['row_type'] == 'total') return true;
    final invoiceId = (o['invoice_id'] ?? o['invoiceId'] ?? '').toString().trim();
    final id = o['id'];
    if (invoiceId.isEmpty && (id == null || id == 0 || id == '0')) return true;
    // Chek raqami (POS...) bo'lmagan qator — odatda jadval oxiridagi umumiy qarz qatori
    if (invoiceId.isEmpty) return true;
    return false;
  }

  /// Bir xil chek (id yoki invoice_id) ikki marta kelmasin — API dublikat qaytarsa bitta ko'rsatamiz
  static List<Map<String, dynamic>> _deduplicateOrdersById(List<Map<String, dynamic>> list) {
    final seen = <String>{};
    return list.where((o) {
      final id = (o['id'] ?? o['order_id'] ?? o['invoice_id'] ?? '').toString();
      final key = id.isEmpty ? null : id;
      if (key == null || seen.contains(key)) return false;
      seen.add(key);
      return true;
    }).toList();
  }

  /// API dagi ko'rinishida: butun "4 000.00", kasr "2 000.50" (dastur hech narsa qo'shmasin — faqat raqam)
  static String _formatAmount(num n) {
    if (n == n.round()) return formatThousands(n.round());
    return n.toString();
  }

  Widget _metricCard({
    required String title,
    required String value,
    required Color valueColor,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD6E8FF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 17, color: const Color(0xFF0D6EFD)),
              const SizedBox(width: 6),
              Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: valueColor),
          ),
        ],
      ),
    );
  }

  Future<void> _loadBulkPaymentTypes() async {
    try {
      final res = await ContactsApi.getPaymentList();
      _paymentTypes = CustomerBulkPayment.parsePaymentTypesResponse(res)
          .where((e) => !CustomerBulkPayment.isExcludedBulkPaymentType(e))
          .toList();
    } catch (_) {
      try {
        final res = await SalesApi.getPaymentTypes();
        _paymentTypes = CustomerBulkPayment.parsePaymentTypesResponse(res)
            .where((e) => !CustomerBulkPayment.isExcludedBulkPaymentType(e))
            .toList();
      } catch (_) {
        _paymentTypes = [];
      }
    }
  }

  List<BulkDuePaymentMethod> _bulkPaymentMethodOptions() {
    final options = <BulkDuePaymentMethod>[
      for (final e in _paymentTypes)
        if (CustomerBulkPayment.paymentTypeId(e) != null)
          BulkDuePaymentMethodId(
            CustomerBulkPayment.paymentTypeId(e)!,
            CustomerBulkPayment.paymentTypeLabel(e),
          ),
    ];
    if ((_balance) > 0) {
      options.add(const BulkDuePaymentMethodCustomerBalance());
    }
    return options;
  }

  Future<void> _showPayDebtDialog(BuildContext context) async {
    final idNum = int.tryParse(_client.id);
    if (idNum == null) return;

    if (!context.mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    Map<String, dynamic>? dueOrdersRes;
    try {
      dueOrdersRes = await ContactsApi.getCustomerDueOrders(idNum);
      if (_paymentTypes.isEmpty) await _loadBulkPaymentTypes();
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
      if (context.mounted) AppNotify.error(context, 'Ma\'lumot yuklanmadi: $e');
      return;
    }

    if (context.mounted) Navigator.pop(context);

    final dueTotal = CustomerBulkPayment.totalDueFromDueOrdersResponse(dueOrdersRes);
    final dueCount = CustomerBulkPayment.dueOrdersCount(dueOrdersRes);
    if (dueTotal <= 0) {
      if (context.mounted) AppNotify.info(context, 'Qarzdorlik yo\'q');
      return;
    }

    final methods = _bulkPaymentMethodOptions();
    if (methods.isEmpty) {
      if (context.mounted) {
        AppNotify.error(context, 'To\'lov turlari yuklanmadi');
      }
      return;
    }

    if (!context.mounted) return;

    final controller = TextEditingController();
    BulkDuePaymentMethod selectedMethod = methods.first;
    final maxPay = dueTotal.round();

    final Map<String, dynamic>? result;
    if (_desktop) {
      result = await _showPayDebtDialogDesktop(
        context,
        dueTotal: dueTotal,
        dueCount: dueCount,
        methods: methods,
        controller: controller,
        maxPay: maxPay,
        initialMethod: selectedMethod,
        onMethodChanged: (m) => selectedMethod = m,
        getSelectedMethod: () => selectedMethod,
      );
    } else {
      result = await _showPayDebtDialogMobile(
        context,
        dueTotal: dueTotal,
        dueCount: dueCount,
        methods: methods,
        controller: controller,
        maxPay: maxPay,
        selectedMethod: selectedMethod,
        onMethodChanged: (m) => selectedMethod = m,
        getSelectedMethod: () => selectedMethod,
      );
    }
    controller.dispose();

    final amount = result?['amount'] as int? ?? 0;
    final paymentMethod = result?['paymentMethod'];
    if (amount <= 0 || paymentMethod == null || !mounted) return;

    try {
      final res = await ClientsProvider.instance.payBulkDue(
        _client.id,
        amount: amount,
        paymentMethod: paymentMethod,
      );
      if (!mounted) return;
      // Provider ro'yxatdagi mijozni yangiladi — ekrandagi nusxani ham sinxronlashtiramiz.
      final fresh = ClientsProvider.instance.getById(_client.id);
      if (fresh != null) {
        _client = fresh;
        _totalDebt = fresh.dueAmount ?? 0;
        _balance = fresh.balance ?? _balance;
      }
      await _load();
      final msg = (res['message'] ?? '').toString();
      if (mounted) {
        AppNotify.success(
          context,
          msg.isNotEmpty ? msg : "${formatThousands(amount)} to'landi",
        );
      }
    } on ApiException catch (e) {
      if (mounted) AppNotify.error(context, e.message);
    } catch (e) {
      if (mounted) AppNotify.error(context, 'Xatolik: $e');
    }
  }

  Future<void> _showEditDialog(BuildContext context) async {
    final updated = await showMijozTahrirlashDialog(context, client: _client);
    if (updated == null || !mounted) return;
    setState(() => _client = updated);
    await _load();
  }

  Future<Map<String, dynamic>?> _showPayDebtDialogMobile(
    BuildContext context, {
    required num dueTotal,
    required int dueCount,
    required List<BulkDuePaymentMethod> methods,
    required TextEditingController controller,
    required int maxPay,
    required BulkDuePaymentMethod selectedMethod,
    required void Function(BulkDuePaymentMethod) onMethodChanged,
    required BulkDuePaymentMethod Function() getSelectedMethod,
  }) {
    var method = selectedMethod;
    return IosStyleModals.showSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      showGrabber: true,
      child: Builder(
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDialogState) => IosStyleModals.sheetKeyboardForm(
            context: ctx,
            onCancel: () => Navigator.pop(ctx),
            onSave: () {
              final selected = getSelectedMethod();
              final amount = parseFormattedSum(controller.text) ?? 0;
              if (amount <= 0) return;
              if (amount > maxPay) {
                AppNotify.info(ctx, 'Summa qarzdan oshmasligi kerak');
                return;
              }
              if (selected is BulkDuePaymentMethodCustomerBalance && amount > _balance.round()) {
                AppNotify.info(ctx, 'Balans yetarli emas');
                return;
              }
              Navigator.pop(ctx, {'amount': amount, 'paymentMethod': selected.apiValue});
            },
            cancelLabel: Strings.bekorQilish,
            saveLabel: "To'lash",
            body: [
              const Text(Strings.umumiyTolash, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
              const SizedBox(height: 8),
              Text('Jami qarz: ${_formatAmount(dueTotal)}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              if (dueCount > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '$dueCount ta qarzdor qator (cheklar va jurnal)',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                autofocus: true,
                inputFormatters: [ThousandsInputFormatter()],
                decoration: InputDecoration(
                  labelText: "To'lov summasi",
                  suffixText: 'UZS',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => controller.text = formatThousands(maxPay),
                  child: const Text('To\'liq to\'lash'),
                ),
              ),
              const SizedBox(height: 4),
              AppDropdownField<BulkDuePaymentMethod>(
                label: "To'lov turi",
                value: method,
                items: methods
                    .map((m) => appDropdownItem(value: m, label: m.label))
                    .toList(),
                onChanged: (v) {
                  if (v != null) {
                    method = v;
                    onMethodChanged(v);
                    setDialogState(() {});
                  }
                },
              ),
              if (method is BulkDuePaymentMethodCustomerBalance)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Mavjud balans: ${_formatAmount(_balance)}',
                    style: TextStyle(fontSize: 13, color: Colors.green.shade700),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<Map<String, dynamic>?> _showPayDebtDialogDesktop(
    BuildContext context, {
    required num dueTotal,
    required int dueCount,
    required List<BulkDuePaymentMethod> methods,
    required TextEditingController controller,
    required int maxPay,
    required BulkDuePaymentMethod initialMethod,
    required void Function(BulkDuePaymentMethod) onMethodChanged,
    required BulkDuePaymentMethod Function() getSelectedMethod,
  }) {
    var method = initialMethod;
    return AppModals.showPopupPanel<Map<String, dynamic>>(
      context: context,
      child: StatefulBuilder(
        builder: (ctx, setDialogState) {
          return SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 24, 28, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(Strings.umumiyTolash, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      Text(
                        'Jami qarz: ${_formatAmount(dueTotal)}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      if (dueCount > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '$dueCount ta qarzdor qator',
                            style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: controller,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(fontSize: 16),
                        inputFormatters: [ThousandsInputFormatter()],
                        decoration: AppModals.desktopField("To'lov summasi", suffix: 'UZS'),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => controller.text = formatThousands(maxPay),
                          child: const Text('To\'liq to\'lash', style: TextStyle(fontSize: 15)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      AppDropdownField<BulkDuePaymentMethod>(
                        label: "To'lov turi",
                        value: method,
                        items: methods
                            .map((m) => appDropdownItem(value: m, label: m.label))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) {
                            method = v;
                            onMethodChanged(v);
                            setDialogState(() {});
                          }
                        },
                      ),
                      if (method is BulkDuePaymentMethodCustomerBalance)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(
                            'Mavjud balans: ${_formatAmount(_balance)}',
                            style: TextStyle(fontSize: 14, color: Colors.green.shade700),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 20, 28, 24),
                  child: AppModals.sheetPillCancelSaveRow(
                    onCancel: () => Navigator.pop(ctx),
                    onSave: () {
                      final selected = getSelectedMethod();
                      final amount = parseFormattedSum(controller.text) ?? 0;
                      if (amount <= 0) return;
                      if (amount > maxPay) {
                        AppNotify.info(ctx, 'Summa qarzdan oshmasligi kerak');
                        return;
                      }
                      if (selected is BulkDuePaymentMethodCustomerBalance && amount > _balance.round()) {
                        AppNotify.info(ctx, 'Balans yetarli emas');
                        return;
                      }
                      Navigator.pop(ctx, {'amount': amount, 'paymentMethod': selected.apiValue});
                    },
                    saveLabel: "To'lash",
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _showAddDebtDialog(BuildContext context) async {
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    final bool? ok;
    if (_desktop) {
      ok = await AppModals.showDesktopFormPanel<bool>(
        context: context,
        title: 'Qarz qo\'shish',
        children: [
          TextField(
            controller: amountCtrl,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 16),
            inputFormatters: [ThousandsInputFormatter()],
            decoration: AppModals.desktopField('Summa', suffix: 'UZS'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: descCtrl,
            style: const TextStyle(fontSize: 16),
            decoration: AppModals.desktopField('Izoh'),
          ),
        ],
        trySubmit: () {
          final amount = parseFormattedSum(amountCtrl.text) ?? 0;
          if (amount <= 0) return null;
          return true;
        },
      );
    } else {
      ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Qarz qo\'shish'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [ThousandsInputFormatter()],
                decoration: const InputDecoration(labelText: 'Summa', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(labelText: 'Izoh', border: OutlineInputBorder()),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text(Strings.bekorQilish)),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text(Strings.saqlash)),
          ],
        ),
      );
    }
    if (ok != true || !mounted) return;
    final amount = parseFormattedSum(amountCtrl.text) ?? 0;
    if (amount <= 0) return;
    try {
      await ClientsProvider.instance.addJournalDebt(
        _client.id,
        amount: amount,
        type: 'loan',
        description: descCtrl.text.trim().isEmpty ? 'Qo\'shimcha qarz' : descCtrl.text.trim(),
      );
      if (mounted) await _load();
    } catch (e) {
      if (mounted) AppNotify.error(context, '$e');
    }
  }

  Future<void> _showAddBalanceDialog(BuildContext context) async {
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    final bool? ok;
    if (_desktop) {
      ok = await AppModals.showDesktopFormPanel<bool>(
        context: context,
        title: 'Balans qo\'shish',
        children: [
          TextField(
            controller: amountCtrl,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 16),
            inputFormatters: [ThousandsInputFormatter()],
            decoration: AppModals.desktopField('Summa', suffix: 'UZS'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: descCtrl,
            style: const TextStyle(fontSize: 16),
            decoration: AppModals.desktopField('Izoh'),
          ),
        ],
        trySubmit: () {
          final amount = parseFormattedSum(amountCtrl.text) ?? 0;
          if (amount <= 0) return null;
          return true;
        },
        saveBackgroundColor: const Color(0xFF4B5563),
      );
    } else {
      ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Balans qo\'shish'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [ThousandsInputFormatter()],
                decoration: const InputDecoration(labelText: 'Summa', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(labelText: 'Izoh', border: OutlineInputBorder()),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text(Strings.bekorQilish)),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text(Strings.saqlash)),
          ],
        ),
      );
    }
    if (ok != true || !mounted) return;
    final amount = parseFormattedSum(amountCtrl.text) ?? 0;
    if (amount <= 0) return;
    try {
      await ClientsProvider.instance.updateCustomerBalance(
        _client.id,
        amount: amount,
        type: 'add',
        description: descCtrl.text.trim(),
      );
      if (mounted) await _load();
    } catch (e) {
      if (mounted) AppNotify.error(context, '$e');
    }
  }
}
