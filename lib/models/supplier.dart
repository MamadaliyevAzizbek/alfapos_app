/// Taminotchi — POST /api/v1/contacts/suppliers.
class Supplier {
  final int id;
  final String firstName;
  final String lastName;
  final String? email;
  final String? company;
  final String? phone;
  final String? address;
  final String? tinNumber;
  final String? description;
  final num balance;
  final num dueAmount;
  final num? ordersDueDebt;
  final num? journalNetDebt;

  const Supplier({
    required this.id,
    required this.firstName,
    this.lastName = '',
    this.email,
    this.company,
    this.phone,
    this.address,
    this.tinNumber,
    this.description,
    this.balance = 0,
    this.dueAmount = 0,
    this.ordersDueDebt,
    this.journalNetDebt,
  });

  String get name {
    final joined = '$firstName $lastName'.trim();
    if (joined.isNotEmpty) return joined;
    final companyName = company?.trim() ?? '';
    if (companyName.isNotEmpty) return companyName;
    return 'Taminotchi $id';
  }

  String get displayPhone {
    final p = phone?.trim() ?? '';
    return p.isEmpty ? '—' : p;
  }

  Supplier copyWith({
    int? id,
    String? firstName,
    String? lastName,
    String? email,
    String? company,
    String? phone,
    String? address,
    String? tinNumber,
    String? description,
    num? balance,
    num? dueAmount,
    num? ordersDueDebt,
    num? journalNetDebt,
  }) {
    return Supplier(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      company: company ?? this.company,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      tinNumber: tinNumber ?? this.tinNumber,
      description: description ?? this.description,
      balance: balance ?? this.balance,
      dueAmount: dueAmount ?? this.dueAmount,
      ordersDueDebt: ordersDueDebt ?? this.ordersDueDebt,
      journalNetDebt: journalNetDebt ?? this.journalNetDebt,
    );
  }

  factory Supplier.fromJson(Map<String, dynamic> m) {
    final first = (m['first_name'] ?? m['firstName'] ?? '').toString().trim();
    final last = (m['last_name'] ?? m['lastName'] ?? '').toString().trim();
    final full =
        (m['fullName'] ?? m['full_name'] ?? m['name'] ?? '').toString().trim();
    final resolvedFirst = first.isNotEmpty
        ? first
        : (full.isNotEmpty ? full : (m['company'] ?? '').toString().trim());

    return Supplier(
      id: _asInt(m['id'] ?? m['supplierID'] ?? m['supplier_id']) ?? 0,
      firstName: resolvedFirst,
      lastName: last,
      email: _nullableString(m['email']),
      company: _nullableString(m['company']),
      phone: _nullableString(m['phone_number'] ?? m['phone']),
      address: _nullableString(m['address']),
      tinNumber: _nullableString(m['tin_number'] ?? m['tinNumber']),
      description: _nullableString(m['description'] ?? m['note']),
      balance: _asNum(m['balance']) ?? 0,
      dueAmount: _asNum(m['due_amount'] ?? m['dueAmount']) ?? 0,
      ordersDueDebt: _asNum(m['orders_due_debt'] ?? m['ordersDueDebt']),
      journalNetDebt: _asNum(m['journal_net_debt'] ?? m['journalNetDebt']),
    );
  }

  /// Ro‘yxat yoki edit/profile javobidan bitta taminotchi.
  static Supplier? fromResponse(Map<String, dynamic> res) {
    final nested = res['supplierData'] ??
        res['supplier'] ??
        res['data'] ??
        res['customer'];
    if (nested is Map) {
      return Supplier.fromJson(Map<String, dynamic>.from(nested));
    }
    if (res.containsKey('id') || res.containsKey('first_name')) {
      return Supplier.fromJson(res);
    }
    return null;
  }

  static List<Supplier> listFromResponse(Map<String, dynamic> res) {
    final raw = res['datarows'] ?? res['suppliers'] ?? res['data'];
    List<dynamic> list = const [];
    if (raw is List) {
      list = raw;
    } else if (raw is Map) {
      list = raw['datarows'] as List? ?? raw['data'] as List? ?? const [];
    }
    return list
        .whereType<Map>()
        .map((e) => Supplier.fromJson(Map<String, dynamic>.from(e)))
        .where((s) => s.id > 0)
        .toList();
  }

  static String? _nullableString(dynamic v) {
    final s = v?.toString().trim() ?? '';
    if (s.isEmpty || s == 'null') return null;
    return s;
  }

  static int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.round();
    return int.tryParse(v.toString());
  }

  static num? _asNum(dynamic v) {
    if (v == null) return null;
    if (v is num) return v;
    final s = v.toString().replaceAll(RegExp(r'\s+'), '').replaceAll(',', '');
    return num.tryParse(s);
  }
}

/// Ro‘yxat javobidagi jami qarz / balans.
class SupplierListTotals {
  final num totalDebt;
  final num totalBalance;
  final int count;

  const SupplierListTotals({
    this.totalDebt = 0,
    this.totalBalance = 0,
    this.count = 0,
  });

  factory SupplierListTotals.fromResponse(Map<String, dynamic> res) {
    return SupplierListTotals(
      totalDebt: Supplier._asNum(res['totalDebt'] ?? res['total_debt']) ?? 0,
      totalBalance:
          Supplier._asNum(res['totalBalance'] ?? res['total_balance']) ?? 0,
      count: Supplier._asInt(res['count']) ?? 0,
    );
  }
}
