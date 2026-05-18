/// POST /contacts/groups-list javobini jadval qatorlariga ajratish.
class CustomerGroupsListParser {
  CustomerGroupsListParser._();

  static List<Map<String, dynamic>> parseRows(Map<String, dynamic> res) {
    final raw = res['datarows'] ?? res['groups'] ?? res['customerGroups'] ?? res['data'];
    if (raw is! List) return [];
    final out = <Map<String, dynamic>>[];
    for (final e in raw) {
      if (e is! Map) continue;
      final m = Map<String, dynamic>.from(e);
      if (_looksLikeCustomerRow(m)) continue;
      final id = groupIdFrom(m);
      if (id == null) continue;
      out.add(m);
    }
    return out;
  }

  static bool _looksLikeCustomerRow(Map<String, dynamic> m) {
    return m.containsKey('phone_number') ||
        m.containsKey('due_amount') ||
        m.containsKey('customer_group_title') ||
        ((m['first_name']?.toString().trim().isNotEmpty ?? false) && !m.containsKey('title'));
  }

  static int? groupIdFrom(Map<String, dynamic> g) {
    final id = g['id'] ?? g['value'] ?? g['group_id'];
    if (id is int) return id;
    return int.tryParse(id?.toString() ?? '');
  }

  static String groupTitle(Map<String, dynamic> g) {
    return (g['title'] ?? g['name'] ?? g['text'] ?? 'Guruh').toString();
  }

  static num groupDiscount(Map<String, dynamic> g) {
    final nested = g['group'] ?? g['customer_group'] ?? g['customerGroup'];
    if (nested is Map) {
      final fromNested = groupDiscount(Map<String, dynamic>.from(nested));
      if (fromNested != 0) return fromNested;
    }
    for (final key in [
      'discount',
      'group_discount',
      'customer_group_discount',
      'discount_percent',
      'markup_percent',
      'markup',
      'percent',
      'foiz',
    ]) {
      final v = g[key];
      if (v == null) continue;
      if (v is num) return v;
      final s = v.toString().replaceAll('%', '').trim();
      if (s.isEmpty) continue;
      final parsed = num.tryParse(s);
      if (parsed != null) return parsed;
    }
    return 0;
  }

  static List<Map<String, dynamic>> groupsFromResponse(Map<String, dynamic> res) {
    for (final key in ['groups', 'customerGroups', 'customer_groups', 'datarows', 'data']) {
      final raw = res[key];
      if (raw is List && raw.isNotEmpty) {
        return raw
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .where((m) => groupIdFrom(m) != null)
            .toList();
      }
    }
    return [];
  }

  static bool groupIsDefault(Map<String, dynamic> g) {
    final v = g['is_default'] ?? g['isDefault'] ?? g['default'];
    if (v is bool) return v;
    if (v is num) return v != 0;
    final s = v?.toString().trim().toLowerCase();
    return s == '1' || s == 'true' || s == 'yes';
  }

  static Map<String, dynamic> unwrapGroupPayload(Map<String, dynamic> res) {
    final g = res['group'] ?? res['customerGroup'] ?? res['customer_group'] ?? res['data'];
    if (g is Map) return Map<String, dynamic>.from(g);
    return res;
  }
}
