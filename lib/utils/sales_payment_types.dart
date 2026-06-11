/// Sotuv to'lov turlari — GET /sales/payment-types
List<Map<String, dynamic>> parseSalesPaymentTypesResponse(dynamic res) {
  final list = <Map<String, dynamic>>[];
  dynamic data;
  if (res is List) {
    data = res;
  } else if (res is Map) {
    data = res['payment_types'] ?? res['paymentTypes'] ?? res['data'] ?? res;
    if (data is Map) {
      data = data['payment_types'] ?? data['paymentTypes'] ?? data['data'];
    }
  }
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
    'hide_in_sales': m['hide_in_sales'] ?? m['hideInSales'],
    'status': m['status'],
  };
}

List<Map<String, dynamic>> normalizeSalesPaymentTypes(List<Map<String, dynamic>> raw) {
  return raw.map(normalizeSalesPaymentType).whereType<Map<String, dynamic>>().toList();
}
