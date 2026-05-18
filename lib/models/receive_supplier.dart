class ReceiveSupplier {
  final int id;
  final String name;
  final String? phone;
  final num? balance;
  final num? dueAmount;

  const ReceiveSupplier({
    required this.id,
    required this.name,
    this.phone,
    this.balance,
    this.dueAmount,
  });

  static ReceiveSupplier? fromJson(Map<String, dynamic> m) {
    final idRaw = m['id'] ?? m['supplierID'];
    final id = idRaw is int ? idRaw : int.tryParse(idRaw?.toString() ?? '');
    if (id == null) return null;
    final first = (m['first_name'] ?? '').toString().trim();
    final last = (m['last_name'] ?? '').toString().trim();
    final combined = '$first $last'.trim();
    final name = combined.isNotEmpty
        ? combined
        : (m['name'] ?? m['company'] ?? m['title'] ?? 'Taminotchi $id').toString();
    return ReceiveSupplier(
      id: id,
      name: name,
      phone: m['phone_number']?.toString(),
      balance: _num(m['balance']),
      dueAmount: _num(m['due_amount'] ?? m['dueAmount']),
    );
  }

  static num? _num(dynamic v) {
    if (v == null) return null;
    if (v is num) return v;
    return num.tryParse(v.toString());
  }

  static List<ReceiveSupplier> listFromResponse(Map<String, dynamic> res) {
    final raw = res['datarows'] ?? res['suppliers'] ?? res['data'];
    List<dynamic> list = [];
    if (raw is List) {
      list = raw;
    } else if (raw is Map) {
      list = raw['datarows'] as List? ?? raw['data'] as List? ?? [];
    }
    return list
        .whereType<Map>()
        .map((e) => ReceiveSupplier.fromJson(Map<String, dynamic>.from(e)))
        .whereType<ReceiveSupplier>()
        .toList();
  }
}
