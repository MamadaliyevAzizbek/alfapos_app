/// Mijozlar ro'yxati filtrlari — GET customer-groups va POST customers javobidan.
class CustomerFilterOption {
  const CustomerFilterOption({required this.value, required this.label});

  final String value;
  final String label;
}

class CustomerListFilterMeta {
  const CustomerListFilterMeta({
    required this.groups,
    required this.statuses,
    required this.debtBalances,
  });

  final List<CustomerFilterOption> groups;
  final List<CustomerFilterOption> statuses;
  final List<CustomerFilterOption> debtBalances;

  static const defaultDebtBalances = [
    CustomerFilterOption(value: 'all', label: 'Hammasi'),
    CustomerFilterOption(value: 'has_debt', label: 'Qarzi bor'),
    CustomerFilterOption(value: 'has_balance', label: 'Balansi bor'),
  ];
}

class CustomerFilterOptionsParser {
  CustomerFilterOptionsParser._();

  static List<CustomerFilterOption> parseOptionList(dynamic raw) {
    if (raw is! List) return [];
    final out = <CustomerFilterOption>[];
    for (final e in raw) {
      if (e is! Map) continue;
      final m = Map<String, dynamic>.from(e);
      final value = (m['value'] ?? m['id'] ?? m['key'] ?? m['code'] ?? '').toString().trim();
      if (value.isEmpty) continue;
      final label = (m['text'] ??
              m['label'] ??
              m['title'] ??
              m['name'] ??
              m['first_name'] ??
              value)
          .toString()
          .trim();
      out.add(CustomerFilterOption(value: value, label: label.isEmpty ? value : label));
    }
    return out;
  }

  /// Mijoz qatori emas, faqat guruh yozuvi (datarows/customers ro'yxatini aralashtirmaslik).
  static bool looksLikeCustomerRow(Map<String, dynamic> m) {
    if (m.containsKey('phone_number') || m.containsKey('due_amount') || m.containsKey('customer_group_title')) {
      return true;
    }
    final hasPersonName = (m['first_name']?.toString().trim().isNotEmpty ?? false) &&
        !m.containsKey('title') &&
        !m.containsKey('group_name');
    return hasPersonName;
  }

  static List<CustomerFilterOption> parseGroupList(dynamic raw) {
    if (raw is! List) return [];
    final out = <CustomerFilterOption>[];
    for (final e in raw) {
      if (e is! Map) continue;
      final m = Map<String, dynamic>.from(e);
      if (looksLikeCustomerRow(m)) continue;
      final value = (m['value'] ?? m['id'] ?? m['key'] ?? '').toString().trim();
      if (value.isEmpty) continue;
      final label = (m['title'] ?? m['name'] ?? m['text'] ?? m['group_name'] ?? m['label'] ?? '')
          .toString()
          .trim();
      if (label.isEmpty) continue;
      out.add(CustomerFilterOption(value: value, label: label));
    }
    return out;
  }

  /// Faqat aniq guruh kalitlari — `datarows` / `data` mijozlar ro'yxati, guruh emas.
  static List<CustomerFilterOption> parseGroupsFromResponse(Map<String, dynamic> res) {
    final raw = res['customerGroups'] ?? res['customer_groups'] ?? res['groups'];
    if (raw is List) return parseGroupList(raw);
    if (raw is Map<String, dynamic>) {
      final inner = raw['customerGroups'] ?? raw['groups'];
      if (inner is List) return parseGroupList(inner);
    }
    return [];
  }

  static List<CustomerFilterOption> parseStatusesFromResponse(Map<String, dynamic> res) {
    final raw = res['customerStatuses'] ??
        res['customer_statuses'] ??
        res['statuses'] ??
        res['customerStatus'] ??
        res['filterStatuses'];
    return parseOptionList(raw);
  }

  static List<CustomerFilterOption> parseDebtBalancesFromResponse(Map<String, dynamic> res) {
    final raw = res['customerDebtBalance'] ??
        res['customerDebtBalances'] ??
        res['customer_debt_balance'] ??
        res['debtBalanceOptions'] ??
        res['debt_balance_options'];
    return parseOptionList(raw);
  }

  static List<CustomerFilterOption> withAllFirst(
    List<CustomerFilterOption> items, {
    String allValue = 'all',
    String allLabel = 'Hammasi',
  }) {
    final rest = items.where((e) => e.value != allValue).toList();
    return [CustomerFilterOption(value: allValue, label: allLabel), ...rest];
  }

  static CustomerListFilterMeta fromResponses({
    Map<String, dynamic>? groupsResponse,
    Map<String, dynamic>? customersResponse,
  }) {
    var groups = <CustomerFilterOption>[];
    var statuses = <CustomerFilterOption>[];
    var debt = <CustomerFilterOption>[];

    if (groupsResponse != null) {
      groups = parseGroupsFromResponse(groupsResponse);
    }
    for (final res in [groupsResponse, customersResponse]) {
      if (res == null) continue;
      if (statuses.isEmpty) statuses = parseStatusesFromResponse(res);
      if (debt.isEmpty) debt = parseDebtBalancesFromResponse(res);
    }

    return CustomerListFilterMeta(
      groups: withAllFirst(groups),
      statuses: withAllFirst(statuses),
      debtBalances: debt.isEmpty
          ? CustomerListFilterMeta.defaultDebtBalances
          : withAllFirst(debt),
    );
  }
}
