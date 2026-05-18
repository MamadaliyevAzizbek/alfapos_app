/// Sotuv to'lov turlari — GET /sales/payment-types
List<Map<String, dynamic>> parseSalesPaymentTypesResponse(dynamic res) {
  final list = <Map<String, dynamic>>[];
  if (res is! Map) return list;
  final data = res['payment_types'] ?? res['data'] ?? res;
  if (data is! List) return list;
  for (final e in data) {
    if (e is! Map) continue;
    final normalized = normalizeSalesPaymentType(Map<String, dynamic>.from(e));
    if (normalized != null) list.add(normalized);
  }
  return list;
}

Map<String, dynamic>? normalizeSalesPaymentType(Map<String, dynamic> m) {
  final id = m['id'] is int ? m['id'] as int : int.tryParse(m['id']?.toString() ?? '');
  if (id == null) return null;
  return {
    'id': id,
    'name': m['name'] ?? m['title'] ?? m['payment_method'] ?? '$id',
    'type': m['type'] ?? m['payment_type'],
  };
}

List<Map<String, dynamic>> normalizeSalesPaymentTypes(List<Map<String, dynamic>> raw) {
  return raw.map(normalizeSalesPaymentType).whereType<Map<String, dynamic>>().toList();
}
