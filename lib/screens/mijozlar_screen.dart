import 'package:flutter/material.dart';
import '../core/app_notify.dart';
import '../core/constants.dart';
import '../core/theme.dart';
import '../core/input_formatters.dart';
import '../providers/clients_provider.dart';
import '../services/api_service.dart';
import '../utils/customer_filter_options.dart';
import '../utils/customer_groups_list.dart';
import '../utils/platform_layout.dart';
import 'mijoz_detail_screen.dart';
import '../widgets/app_dropdown.dart';
import '../widgets/customer_group_form.dart';
import '../widgets/ios_style_modals.dart';
import 'desktop/desktop_shell_scope.dart';
import 'yangi_mijoz_screen.dart';
import '../widgets/throttled_refresh_indicator.dart';

/// Mijozlar — POST /contacts/customers (web /contacts bilan bir xil).
class MijozlarScreen extends StatefulWidget {
  const MijozlarScreen({super.key});

  @override
  State<MijozlarScreen> createState() => _MijozlarScreenState();
}

class _MijozlarScreenState extends State<MijozlarScreen> with DesktopShellSyncMixin {
  final _searchController = TextEditingController();
  final _clients = ClientsProvider.instance;
  CustomersListFilters _filters = const CustomersListFilters();
  String _search = '';
  /// «Mijoz guruhlari» tabi — POST /groups-list.
  List<Map<String, dynamic>> _tabGroups = [];
  bool _groupsLoading = false;
  List<Map<String, dynamic>> _suppliers = [];
  bool _suppliersLoading = false;
  int _desktopTab = 0;
  int _mobileTab = 0;
  CustomerListFilterMeta _filterMeta = const CustomerListFilterMeta(
    groups: [CustomerFilterOption(value: 'all', label: 'Hammasi')],
    statuses: [CustomerFilterOption(value: 'all', label: 'Hammasi')],
    debtBalances: CustomerListFilterMeta.defaultDebtBalances,
  );

  static const double _actionColWidth = 72;

  bool get _desktop => isDesktopPosLayout;

  double get _btnHeight => _desktop ? 52 : 44;

  double get _btnFontSize => _desktop ? 15 : 14;

  double get _cellFont => _desktop ? 15 : 14;

  @override
  void initState() {
    super.initState();
    _loadFilterOptions();
    _loadTabGroups();
    _loadSuppliers();
    _reload();
  }

  Future<void> _loadFilterOptions() async {
    final meta = await _clients.fetchCustomerFilterMeta();
    if (!mounted) return;
    setState(() => _filterMeta = meta);
  }

  Future<void> _loadTabGroups() async {
    if (mounted) setState(() => _groupsLoading = true);
    try {
      final g = await _clients.loadCustomerGroupsTable();
      if (mounted) setState(() => _tabGroups = g);
    } catch (_) {
      if (mounted) setState(() => _tabGroups = []);
    } finally {
      if (mounted) setState(() => _groupsLoading = false);
    }
  }

  void _mergeFilterMetaFromApiAndClients() {
    final fromList = _clients.filterMetaFromLastResponse();
    final statuses = _unionOptions(_filterMeta.statuses, fromList.statuses);
    var debt = _filterMeta.debtBalances;
    if (fromList.debtBalances.length > debt.length) {
      debt = fromList.debtBalances;
    }

    setState(() {
      _filterMeta = CustomerListFilterMeta(
        groups: _filterMeta.groups,
        statuses: CustomerFilterOptionsParser.withAllFirst(
          statuses.where((s) => s.value != 'all').toList(),
        ),
        debtBalances: debt,
      );
    });
  }

  List<CustomerFilterOption> _unionOptions(
    List<CustomerFilterOption> a,
    List<CustomerFilterOption> b,
  ) {
    final map = <String, CustomerFilterOption>{};
    for (final o in [...a, ...b]) {
      if (o.value == 'all') continue;
      map[o.value] = o;
    }
    return CustomerFilterOptionsParser.withAllFirst(map.values.toList());
  }

  Future<void> _loadSuppliers() async {
    if (mounted) setState(() => _suppliersLoading = true);
    try {
      final res = await ContactsApi.getSuppliers();
      final raw = res['datarows'] ?? res['suppliers'] ?? res['data'];
      if (raw is List) {
        _suppliers = raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      } else {
        _suppliers = [];
      }
    } catch (_) {
      _suppliers = [];
    } finally {
      if (mounted) setState(() => _suppliersLoading = false);
    }
  }

  String _groupTitleFor(Client c) {
    if (c.customerGroupName != null && c.customerGroupName!.isNotEmpty) {
      return c.customerGroupName!;
    }
    if (c.customerGroupId != null) {
      for (final g in _tabGroups) {
        final id = g['id'] ?? g['value'];
        final idNum = id is int ? id : int.tryParse(id.toString());
        if (idNum == c.customerGroupId) {
          return (g['title'] ?? g['name'] ?? 'Guruh').toString();
        }
      }
      for (final o in _filterMeta.groups) {
        if (o.value == c.customerGroupId.toString()) return o.label;
      }
    }
    return '—';
  }

  String _supplierTitleFor(Client c) {
    if (c.supplierName != null && c.supplierName!.isNotEmpty) return c.supplierName!;
    return '—';
  }

  static String _personName(Map<String, dynamic> m) {
    final full = (m['full_name'] ?? '').toString().trim();
    if (full.isNotEmpty) return full;
    final first = (m['first_name'] ?? '').toString();
    final last = (m['last_name'] ?? '').toString();
    final joined = '$first $last'.trim();
    if (joined.isNotEmpty) return joined;
    return (m['name'] ?? m['title'] ?? '—').toString();
  }

  @override
  Future<void> onDesktopShellSync() => _reload(force: true);

  Future<void> _reload({bool force = true}) async {
    await _clients.loadCustomersPage(
      reset: true,
      force: force,
      searchValue: _search,
      filters: _filters,
    );
    if (!mounted) return;
    _mergeFilterMetaFromApiAndClients();
  }

  Future<void> _loadMore() async {
    await _clients.loadCustomersPage(
      reset: false,
      searchValue: _search,
      filters: _filters,
    );
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _fmtAmount(num n) {
    if (n == n.round()) return formatThousands(n.round());
    return n.toString();
  }

  static String _formatGroupDiscount(num discount) {
    if (discount == 0) return '0%';
    final n = discount == discount.round() ? discount.round() : discount;
    if (discount > 0) return '+$n%';
    return '$n%';
  }

  void _applyFilters(CustomersListFilters f) {
    setState(() => _filters = f);
    _reload(force: true);
  }

  void _applySearch() {
    _search = _searchController.text.trim();
    _reload(force: true);
  }

  Future<void> _openAddCustomer() async {
    if (_desktop) {
      await showYangiMijozDialog(context);
    } else {
      await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const YangiMijozScreen()),
      );
    }
    if (mounted) {
      await _loadFilterOptions();
      await _loadTabGroups();
      _reload(force: true);
    }
  }

  List<DropdownMenuItem<String>> _filterDropdownItems(List<CustomerFilterOption> options) {
    return options
        .map((o) => DropdownMenuItem<String>(value: o.value, child: Text(o.label)))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_desktop) return _buildDesktopScaffold();
    return _buildMobileScaffold();
  }

  Widget _buildDesktopScaffold() {
    final underShell = DesktopShellScope.maybeOf(context) != null;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        actions: [
          // Shell top bar «Sinxronlash» bo‘lsa dublikat yo‘q; push route’da Yangilash qoladi.
          if (!underShell)
            IconButton(
              tooltip: 'Yangilash',
              onPressed: _desktopTab == 1
                  ? (_groupsLoading ? null : () => _loadTabGroups())
                  : (_clients.isLoading ? null : () => _reload(force: true)),
              icon: const Icon(Icons.refresh_rounded),
            ),
          if (!underShell) const SizedBox(width: 8),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildDesktopTabs(),
          if (_desktopTab == 0) _buildDesktopToolbar(),
          if (_desktopTab == 1) _buildGroupsToolbar(),
          Expanded(child: _buildDesktopTabBody()),
        ],
      ),
    );
  }

  Widget _buildDesktopTabs() {
    const tabs = ['Mijozlar', 'Mijoz guruhlari', 'Taminotchilar'];
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.divider)),
      ),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final selected = _desktopTab == i;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () {
                setState(() => _desktopTab = i);
                if (i == 1) _loadTabGroups();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: selected ? AppTheme.primary : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Text(
                  tabs[i],
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: selected ? AppTheme.primary : AppTheme.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  static const double _desktopToolbarPad = 24;
  static const double _desktopFilterGap = 16;
  static const double _desktopFilterHeight = 64;
  static const double _desktopFilterFontSize = 16;

  InputDecoration _desktopFilterDecoration(String label) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppTheme.divider),
    );
    return InputDecoration(
      labelText: label,
      floatingLabelBehavior: FloatingLabelBehavior.always,
      alignLabelWithHint: true,
      filled: true,
      fillColor: Colors.white,
      isDense: false,
      floatingLabelStyle: TextStyle(fontSize: 13, color: Colors.grey.shade600),
      contentPadding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      constraints: const BoxConstraints(minHeight: _desktopFilterHeight),
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
      ),
    );
  }

  Widget _desktopFilterField(Widget child) {
    return SizedBox(
      height: _desktopFilterHeight,
      child: child,
    );
  }

  Widget _buildDesktopToolbar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(_desktopToolbarPad, 20, _desktopToolbarPad, 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppTheme.divider)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F0FE),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.people_alt_rounded, color: Color(0xFF2563EB), size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Mijozlar', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(
                      'Mijozlarni boshqarish va tashkil etish',
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text.rich(
                          TextSpan(
                            text: 'Umumiy qarzdorlik: ',
                            style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                            children: [
                              TextSpan(
                                text: _fmtAmount(_clients.listTotalDebt),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFDC2626),
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text.rich(
                          TextSpan(
                            text: 'Umumiy balans: ',
                            style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                            children: [
                              TextSpan(
                                text: _fmtAmount(_clients.listTotalBalance),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF16A34A),
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              SizedBox(
                height: _btnHeight,
                child: FilledButton.icon(
                  onPressed: () => _openAddCustomer(),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    minimumSize: Size(0, _btnHeight),
                    textStyle: TextStyle(fontSize: _btnFontSize + 1, fontWeight: FontWeight.w600),
                  ),
                  icon: const Icon(Icons.add, size: 22),
                  label: const Text("Qo'shish"),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _desktopFilterField(
                  _desktopFilterDropdown(
                    fieldKey: ValueKey('status_${_filterMeta.statuses.length}'),
                    label: 'Mijoz statusi',
                    value: _filters.statusId,
                    items: _filterDropdownItems(_filterMeta.statuses),
                    onChanged: (v) {
                      if (v == null) return;
                      _applyFilters(CustomersListFilters(
                        groupId: _filters.groupId,
                        statusId: v,
                        debtBalance: _filters.debtBalance,
                      ));
                    },
                  ),
                ),
              ),
              const SizedBox(width: _desktopFilterGap),
              Expanded(
                child: _desktopFilterField(
                  _desktopFilterDropdown(
                    fieldKey: ValueKey('group_${_filterMeta.groups.length}'),
                    label: 'Mijoz guruh',
                    value: _filters.groupId,
                    items: _filterDropdownItems(_filterMeta.groups),
                    onChanged: (v) {
                      if (v == null) return;
                      _applyFilters(CustomersListFilters(
                        groupId: v,
                        statusId: _filters.statusId,
                        debtBalance: _filters.debtBalance,
                      ));
                    },
                  ),
                ),
              ),
              const SizedBox(width: _desktopFilterGap),
              Expanded(
                child: _desktopFilterField(
                  _desktopFilterDropdown(
                    fieldKey: ValueKey('debt_${_filterMeta.debtBalances.length}'),
                    label: 'Qarz / balans',
                    value: _filters.debtBalance,
                    items: _filterDropdownItems(_filterMeta.debtBalances),
                    onChanged: (v) {
                      if (v == null) return;
                      _applyFilters(CustomersListFilters(
                        groupId: _filters.groupId,
                        statusId: _filters.statusId,
                        debtBalance: v,
                      ));
                    },
                  ),
                ),
              ),
              const SizedBox(width: _desktopFilterGap),
              Expanded(
                child: _desktopFilterField(
                  TextField(
                    controller: _searchController,
                    onSubmitted: (_) => _applySearch(),
                    style: const TextStyle(fontSize: _desktopFilterFontSize),
                    decoration: _desktopFilterDecoration('Qidirish').copyWith(
                      hintText: 'Qidirish',
                      hintStyle: TextStyle(fontSize: _desktopFilterFontSize, color: Colors.grey.shade500),
                      prefixIcon: const Icon(Icons.search_rounded, size: 24, color: AppTheme.textSecondary),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.arrow_forward_rounded, size: 24),
                        onPressed: _applySearch,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _desktopFilterDropdown({
    Key? fieldKey,
    required String label,
    required String value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    final selected = items.any((e) => e.value == value) ? value : items.firstOrNull?.value;
    return AppDropdownField<String>(
      key: fieldKey,
      label: label,
      value: selected,
      menuMaxHeight: 360,
      items: items,
      onChanged: items.length <= 1 ? null : onChanged,
    );
  }

  Widget _buildGroupsToolbar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(_desktopToolbarPad, 20, _desktopToolbarPad, 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppTheme.divider)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F0FE),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.groups_rounded, color: Color(0xFF2563EB), size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Mijoz guruhlari', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  'Guruh nomi va chegirma foizini boshqaring',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          SizedBox(
            height: _btnHeight,
            child: FilledButton.icon(
              onPressed: _groupsLoading ? null : () => _openGroupForm(),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                minimumSize: Size(0, _btnHeight),
                textStyle: TextStyle(fontSize: _btnFontSize + 1, fontWeight: FontWeight.w600),
              ),
              icon: const Icon(Icons.add, size: 22),
              label: const Text("Guruh qo'shish"),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openGroupForm({Map<String, dynamic>? group}) async {
    final id = group != null ? CustomerGroupsListParser.groupIdFrom(group) : null;
    final result = await showCustomerGroupForm(context, groupId: id);
    if (!mounted || result == null) return;
    AppNotify.success(context, id == null ? 'Guruh qo\'shildi' : 'Guruh yangilandi');
    _clients.invalidateGroupsCache();
    await _loadTabGroups();
    await _loadFilterOptions();
  }

  Future<void> _confirmDeleteGroup(Map<String, dynamic> group) async {
    final id = CustomerGroupsListParser.groupIdFrom(group);
    if (id == null) return;
    final title = CustomerGroupsListParser.groupTitle(group);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("O'chirish"),
        content: Text('«$title» guruhi o\'chirilsinmi?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text(Strings.bekorQilish)),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("O'chirish"),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ContactsApi.deleteCustomerGroup(id);
      if (!mounted) return;
      AppNotify.success(context, 'Guruh o\'chirildi');
      _clients.invalidateGroupsCache();
      await _loadTabGroups();
      await _loadFilterOptions();
    } catch (e) {
      if (mounted) AppNotify.error(context, e.toString());
    }
  }

  Widget _buildGroupActionMenu(Map<String, dynamic> group) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, size: 24, color: AppTheme.textSecondary),
      padding: EdgeInsets.zero,
      offset: const Offset(0, 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (v) {
        if (v == 'edit') {
          _openGroupForm(group: group);
        } else if (v == 'delete') {
          _confirmDeleteGroup(group);
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem<String>(
          value: 'edit',
          height: 48,
          child: Row(
            children: [
              Icon(Icons.edit_outlined, size: 22, color: Color(0xFF2563EB)),
              SizedBox(width: 12),
              Text('Tahrirlash', style: TextStyle(fontSize: 15)),
            ],
          ),
        ),
        const PopupMenuDivider(height: 1),
        PopupMenuItem<String>(
          value: 'delete',
          height: 48,
          child: Row(
            children: [
              Icon(Icons.delete_outline, size: 22, color: Colors.red.shade700),
              const SizedBox(width: 12),
              Text("O'chirish", style: TextStyle(fontSize: 15, color: Colors.red.shade700)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopTabBody() {
    if (_desktopTab == 1) return _buildGroupsTableArea();
    if (_desktopTab == 2) return _buildSuppliersTableArea();
    return _buildCustomersTableArea();
  }

  Widget _buildCustomersTableArea() {
    if (_clients.loadError != null && _clients.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_clients.loadError!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: () => _reload(force: true), child: const Text('Qayta yuklash')),
          ],
        ),
      );
    }

    if (_clients.isLoading && _clients.items.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    }

    if (_clients.items.isEmpty) {
      return const Center(child: Text("Mijozlar yo'q", style: TextStyle(color: AppTheme.textSecondary)));
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.divider),
          borderRadius: BorderRadius.circular(8),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Column(
            children: [
              _buildDesktopTableHeader(),
              Expanded(
                child: ThrottledRefreshIndicator(
                  onRefresh: () => _reload(force: true),
                  child: ListView.builder(
                    itemCount: _clients.items.length + 1,
                    itemBuilder: (context, index) {
                      if (index == _clients.items.length) {
                        if (!_clients.hasMore) return const SizedBox(height: 8);
                        return Padding(
                          padding: const EdgeInsets.all(16),
                          child: Center(
                            child: OutlinedButton.icon(
                              style: ButtonStyle(
                                minimumSize: WidgetStateProperty.all(Size(0, _btnHeight)),
                              ),
                              onPressed: _clients.isLoading ? null : _loadMore,
                              icon: _clients.isLoading
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.expand_more_rounded),
                              label: Text(_clients.isLoading ? 'Yuklanmoqda...' : 'Yana yuklash'),
                            ),
                          ),
                        );
                      }
                      return _desktopTableRow(_clients.items[index], index);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopTableHeader() {
    return Container(
      color: const Color(0xFFF8FAFC),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text('NOMI', style: _thStyleDesktop)),
          Expanded(flex: 2, child: Text('TELEFON RAQAMI', style: _thStyleDesktop)),
          Expanded(flex: 2, child: Text('MIJOZ GURUH', style: _thStyleDesktop)),
          Expanded(flex: 2, child: Text('TAMINOTCHI', style: _thStyleDesktop)),
          Expanded(flex: 2, child: Text('QARZDORLIK', style: _thStyleDesktop, textAlign: TextAlign.end)),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.only(right: 20),
              child: Text('BALANS', style: _thStyleDesktop, textAlign: TextAlign.end),
            ),
          ),
          SizedBox(
            width: _actionColWidth,
            child: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text('AMAL', style: _thStyleDesktop, textAlign: TextAlign.center),
            ),
          ),
        ],
      ),
    );
  }

  static const _thStyleDesktop = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    color: AppTheme.textSecondary,
    letterSpacing: 0.4,
  );

  Widget _desktopTableRow(Client c, int index) {
    final debt = (c.dueAmount ?? 0).round();
    final balance = (c.balance ?? 0).round();
    final bg = index.isEven ? Colors.white : const Color(0xFFFAFBFC);

    return Material(
      color: bg,
      child: Container(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppTheme.divider)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () => _openDetail(c),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        c.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        c.phone ?? '—',
                        style: TextStyle(fontSize: _cellFont, color: AppTheme.textSecondary),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        _groupTitleFor(c),
                        style: TextStyle(fontSize: _cellFont, color: AppTheme.textPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        _supplierTitleFor(c),
                        style: TextStyle(fontSize: _cellFont, color: AppTheme.textSecondary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        _fmtAmount(debt),
                        textAlign: TextAlign.end,
                        style: TextStyle(
                          fontSize: _cellFont,
                          fontWeight: FontWeight.w700,
                          color: debt > 0 ? const Color(0xFFDC2626) : AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 20),
                        child: Text(
                          _fmtAmount(balance),
                          textAlign: TextAlign.end,
                          style: TextStyle(
                            fontSize: _cellFont,
                            fontWeight: FontWeight.w600,
                            color: balance > 0 ? const Color(0xFF16A34A) : AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: SizedBox(width: _actionColWidth, child: Center(child: _buildActionMenu(c))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupsTableArea() {
    if (_groupsLoading && _tabGroups.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    }
    if (_tabGroups.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Guruhlar yo\'q', style: TextStyle(color: AppTheme.textSecondary)),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => _openGroupForm(),
              icon: const Icon(Icons.add),
              label: const Text("Guruh qo'shish"),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: DecoratedBox(
        decoration: BoxDecoration(
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
                child: Row(
                  children: [
                    Expanded(flex: 3, child: Text('GURUH NOMI', style: _thStyleDesktop)),
                    Expanded(
                      flex: 2,
                      child: Text('FOIZ (%)', style: _thStyleDesktop, textAlign: TextAlign.end),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text('STANDART', style: _thStyleDesktop, textAlign: TextAlign.center),
                    ),
                    SizedBox(width: _actionColWidth, child: Text('AMAL', style: _thStyleDesktop, textAlign: TextAlign.center)),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  itemCount: _tabGroups.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final g = _tabGroups[i];
                    final title = CustomerGroupsListParser.groupTitle(g);
                    final discount = CustomerGroupsListParser.groupDiscount(g);
                    final isDefault = CustomerGroupsListParser.groupIsDefault(g);
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Text(title, style: TextStyle(fontSize: _cellFont, fontWeight: FontWeight.w600)),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              _formatGroupDiscount(discount),
                              textAlign: TextAlign.end,
                              style: TextStyle(
                                fontSize: _cellFont,
                                color: discount == 0
                                    ? AppTheme.textSecondary
                                    : (discount < 0 ? const Color(0xFF16A34A) : const Color(0xFFDC2626)),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Center(
                              child: isDefault
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFDCFCE7),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: const Text(
                                        'Standart',
                                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF16A34A)),
                                      ),
                                    )
                                  : Text('—', style: TextStyle(fontSize: _cellFont, color: AppTheme.textSecondary)),
                            ),
                          ),
                          SizedBox(
                            width: _actionColWidth,
                            child: Center(child: _buildGroupActionMenu(g)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuppliersTableArea() {
    if (_suppliersLoading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    }
    if (_suppliers.isEmpty) {
      return const Center(child: Text('Taminotchilar yo\'q', style: TextStyle(color: AppTheme.textSecondary)));
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: DecoratedBox(
        decoration: BoxDecoration(
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
                    Expanded(flex: 2, child: Text('NOMI', style: _thStyleDesktop)),
                    Expanded(flex: 2, child: Text('TELEFON', style: _thStyleDesktop)),
                    Expanded(flex: 2, child: Text('KOMPANIYA', style: _thStyleDesktop)),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  itemCount: _suppliers.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final s = _suppliers[i];
                    final name = _personName(s);
                    final phone = (s['phone_number'] ?? s['phone'] ?? '—').toString();
                    final company = (s['company'] ?? '—').toString();
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Text(name, style: TextStyle(fontSize: _cellFont, fontWeight: FontWeight.w600)),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(phone, style: TextStyle(fontSize: _cellFont, color: AppTheme.textSecondary)),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(company, style: TextStyle(fontSize: _cellFont, color: AppTheme.textSecondary)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ——— Mobil (o'zgarmagan) ———

  Widget _buildMobileScaffold() {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(Strings.mijozlar),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                Expanded(child: _mobileSectionTab('Mijozlar', _mobileTab == 0, () => setState(() => _mobileTab = 0))),
                const SizedBox(width: 8),
                Expanded(
                  child: _mobileSectionTab('Guruhlar', _mobileTab == 1, () {
                    setState(() => _mobileTab = 1);
                    if (_tabGroups.isEmpty) _loadTabGroups();
                  }),
                ),
              ],
            ),
          ),
          if (_mobileTab == 1) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _groupsLoading ? null : () => _openGroupForm(),
                  icon: const Icon(Icons.group_add_rounded),
                  label: const Text("Guruh qo'shish"),
                ),
              ),
            ),
            Expanded(child: _buildMobileGroupsBody()),
          ] else ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: _headerStat(
                    'Umumiy qarzdorlik',
                    _fmtAmount(_clients.listTotalDebt),
                    Icons.receipt_long_outlined,
                    const Color(0xFFDC2626),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _headerStat(
                    'Umumiy balans',
                    _fmtAmount(_clients.listTotalBalance),
                    Icons.account_balance_wallet_outlined,
                    const Color(0xFF16A34A),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              onSubmitted: (_) => _applySearch(),
              decoration: InputDecoration(
                hintText: 'Mijoz ismi yoki telefon',
                filled: true,
                fillColor: Colors.white,
                prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textSecondary),
                suffixIcon: _search.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: () {
                          _searchController.clear();
                          _search = '';
                          _reload(force: true);
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppTheme.divider),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _filterChip('Barcha guruhlar', _filters.groupId == 'all', () {
                  _applyFilters(CustomersListFilters(
                    groupId: 'all',
                    statusId: _filters.statusId,
                    debtBalance: _filters.debtBalance,
                  ));
                }),
                const SizedBox(width: 6),
                _filterChip('Qarzi bor', _filters.debtBalance == 'has_debt', () {
                  _applyFilters(CustomersListFilters(
                    groupId: _filters.groupId,
                    statusId: _filters.statusId,
                    debtBalance: _filters.debtBalance == 'has_debt' ? 'all' : 'has_debt',
                  ));
                }),
                const SizedBox(width: 6),
                _filterChip('Balansi bor', _filters.debtBalance == 'has_balance', () {
                  _applyFilters(CustomersListFilters(
                    groupId: _filters.groupId,
                    statusId: _filters.statusId,
                    debtBalance: _filters.debtBalance == 'has_balance' ? 'all' : 'has_balance',
                  ));
                }),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _openAddCustomer(),
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: const Text("Yangi mijoz qo'shish"),
              ),
            ),
          ),
          Expanded(child: _buildMobileBody()),
          ],
        ],
      ),
    );
  }

  Widget _mobileSectionTab(String label, bool selected, VoidCallback onTap) {
    return Material(
      color: selected ? AppTheme.primary.withValues(alpha: 0.12) : AppTheme.cardBg,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: selected ? AppTheme.primary : AppTheme.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileGroupsBody() {
    if (_groupsLoading && _tabGroups.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    }
    if (_tabGroups.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Guruhlar yo\'q', style: TextStyle(color: AppTheme.textSecondary)),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _openGroupForm(),
              icon: const Icon(Icons.add),
              label: const Text("Guruh qo'shish"),
            ),
          ],
        ),
      );
    }
    return ThrottledRefreshIndicator(
      onRefresh: _loadTabGroups,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        itemCount: _tabGroups.length,
        itemBuilder: (context, i) {
          final g = _tabGroups[i];
          final title = CustomerGroupsListParser.groupTitle(g);
          final discount = CustomerGroupsListParser.groupDiscount(g);
          final isDefault = CustomerGroupsListParser.groupIsDefault(g);
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.divider),
            ),
            child: ListTile(
              title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(
                'Chegirma: ${_formatGroupDiscount(discount)}${isDefault ? ' • Standart' : ''}',
                style: TextStyle(
                  fontSize: 13,
                  color: discount == 0
                      ? AppTheme.textSecondary
                      : (discount < 0 ? const Color(0xFF16A34A) : const Color(0xFFDC2626)),
                ),
              ),
              trailing: _buildGroupActionMenu(g),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMobileBody() {
    if (_clients.loadError != null && _clients.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_clients.loadError!, textAlign: TextAlign.center),
            TextButton(onPressed: () => _reload(force: true), child: const Text('Qayta yuklash')),
          ],
        ),
      );
    }

    if (_clients.isLoading && _clients.items.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    }

    if (_clients.items.isEmpty) {
      return const Center(child: Text("Mijozlar yo'q", style: TextStyle(color: AppTheme.textSecondary)));
    }

    return ThrottledRefreshIndicator(
      onRefresh: () => _reload(force: true),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        itemCount: _clients.items.length + 1,
        itemBuilder: (context, index) {
          if (index == _clients.items.length) {
            if (!_clients.hasMore) return const SizedBox(height: 8);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: OutlinedButton.icon(
                  onPressed: _clients.isLoading ? null : _loadMore,
                  icon: _clients.isLoading
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.expand_more_rounded),
                  label: Text(_clients.isLoading ? 'Yuklanmoqda...' : 'Yana yuklash'),
                ),
              ),
            );
          }
          return _mobileCard(_clients.items[index]);
        },
      ),
    );
  }

  Widget _mobileCard(Client c) {
    final debt = (c.dueAmount ?? 0).round();
    final balance = (c.balance ?? 0).round();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.divider),
      ),
      child: ListTile(
        onTap: () => _openDetail(c),
        title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (c.phone != null && c.phone!.isNotEmpty) Text(c.phone!),
            Text('Guruh: ${_groupTitleFor(c)}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            if (_supplierTitleFor(c) != '—')
              Text('Taminotchi: ${_supplierTitleFor(c)}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            if (debt > 0)
              Text('Qarz: ${_fmtAmount(debt)}', style: const TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.w600)),
            if (balance != 0) Text('Balans: ${_fmtAmount(balance)}', style: const TextStyle(color: Color(0xFF16A34A))),
          ],
        ),
        trailing: _buildActionMenu(c),
      ),
    );
  }

  Widget _buildActionMenu(Client c) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, size: 24, color: AppTheme.textSecondary),
      padding: EdgeInsets.zero,
      offset: const Offset(0, 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      elevation: 8,
      onSelected: (v) async {
        if (v == 'edit') {
          await _showEditCustomer(c);
        } else if (v == 'pay') {
          await _openDetail(c, openPayment: true);
        } else if (v == 'delete') {
          await _confirmDelete(c);
        }
      },
      itemBuilder: (_) => [
        if ((c.dueAmount ?? 0) > 0)
          PopupMenuItem<String>(
            value: 'pay',
            height: 48,
            child: Row(
              children: [
                Icon(Icons.credit_card_rounded, size: 22, color: Colors.blue.shade700),
                const SizedBox(width: 12),
                const Text(Strings.umumiyTolash, style: TextStyle(fontSize: 15)),
              ],
            ),
          ),
        if ((c.dueAmount ?? 0) > 0) const PopupMenuDivider(height: 1),
        PopupMenuItem<String>(
          value: 'edit',
          height: 48,
          child: Row(
            children: [
              Icon(Icons.edit_outlined, size: 22, color: Colors.blue.shade700),
              const SizedBox(width: 12),
              const Text('Tahrirlash', style: TextStyle(fontSize: 15)),
            ],
          ),
        ),
        const PopupMenuDivider(height: 1),
        PopupMenuItem<String>(
          value: 'delete',
          height: 48,
          child: Row(
            children: [
              Icon(Icons.delete_outline, size: 22, color: Colors.blue.shade700),
              const SizedBox(width: 12),
              const Text("O'chirish", style: TextStyle(fontSize: 15)),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _showEditCustomer(Client c) async {
    final updated = await showMijozTahrirlashDialog(context, client: c);
    if (updated != null && mounted) _reload(force: true);
  }

  Future<void> _openDetail(Client c, {bool openPayment = false}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MijozDetailScreen(
          client: c,
          openPaymentOnStart: openPayment && !_desktop,
        ),
      ),
    );
    if (mounted) _reload(force: true);
  }

  Future<void> _confirmDelete(Client c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("O'chirish"),
        content: Text('${c.name} o\'chirilsinmi?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text(Strings.bekorQilish)),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("O'chirish"),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _clients.deleteClient(c.id);
      if (mounted) _reload(force: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Widget _headerStat(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }

  Widget _filterChip(String label, bool selected, VoidCallback onTap) {
    return FilterChip(
      label: Text(label, style: TextStyle(fontSize: 12, color: selected ? Colors.white : AppTheme.textPrimary)),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AppTheme.primary,
      backgroundColor: Colors.white,
      showCheckmark: false,
      side: const BorderSide(color: AppTheme.divider),
    );
  }
}
