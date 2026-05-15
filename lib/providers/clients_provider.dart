import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import '../core/api_client.dart';

const String _keyDebtEntries = 'alfapos_client_debt_entries';

class DebtEntry {
  final String clientId;
  final int amount;
  final String receiptId;
  final String dateTime;

  const DebtEntry({
    required this.clientId,
    required this.amount,
    required this.receiptId,
    required this.dateTime,
  });
}

class Client {
  final String id;
  final String name;
  final String? email;
  final String? phone;
  final String? address;
  /// API: jami qarz (cheklar + qarzlar tab) — due_amount ("4000.00" yoki son)
  final num? dueAmount;
  /// API: mijoz balansi — balance ("2000.00" yoki son)
  final num? balance;
  /// API: oxirgi qarz to'lash muddati — due_payment_date
  final String? duePaymentDate;
  /// API: qarz limiti — debt_limit; -1 = qora ro'yxat
  final int? debtLimit;

  const Client({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.address,
    this.dueAmount,
    this.balance,
    this.duePaymentDate,
    this.debtLimit,
  });

  static Client fromApiJson(Map<String, dynamic> json) {
    int? _intOrNull(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is num) return v.toInt();
      final s = v.toString().trim();
      if (s.isEmpty) return null;
      final n = int.tryParse(s);
      if (n != null) return n;
      final d = double.tryParse(s);
      return d?.round();
    }

    num? _numOrNull(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is num) return v;
      final s = v.toString().trim();
      if (s.isEmpty) return null;
      return double.tryParse(s);
    }

    final id = json['id'];
    final idStr = id is int ? id.toString() : (id is String ? id : '');
    final fullName = (json['full_name'] as String?)?.trim();
    final first = json['first_name'] as String? ?? json['firstName'] as String? ?? '';
    final last = json['last_name'] as String? ?? json['lastName'] as String? ?? '';
    final name = (fullName != null && fullName.isNotEmpty)
        ? fullName
        : ((first.toString() + ' ' + last.toString()).trim().isEmpty ? (json['name'] as String? ?? '') : (first.toString() + ' ' + last.toString()).trim());
    return Client(
      id: idStr,
      name: name.isEmpty ? '—' : name,
      email: json['email'] as String?,
      phone: json['phone_number'] as String? ?? json['phone'] as String?,
      address: json['address'] as String?,
      dueAmount: _numOrNull(json['due_amount']),
      balance: _numOrNull(json['balance']),
      duePaymentDate: json['due_payment_date'] as String?,
      debtLimit: _intOrNull(json['debt_limit']),
    );
  }
}

class ClientsProvider extends ChangeNotifier {
  ClientsProvider._() {
    _items = [];
  }
  static final ClientsProvider _instance = ClientsProvider._();
  static ClientsProvider get instance => _instance;

  List<Client> _items = [];
  bool _loaded = false;
  String? _loadError;
  Map<String, dynamic>? _lastRawCustomers;
  DateTime? _lastLoadedAt;
  Future<void>? _inFlightLoad;
  static const Duration _cacheTtl = Duration(seconds: 45);

  List<Client> get items => List.unmodifiable(_items);
  String? get loadError => _loadError;
  Map<String, dynamic>? get lastRawCustomers => _lastRawCustomers;

  Future<void> loadFromStorage({bool force = false}) async => loadFromApi(force: force);

  /// API javobidan ro'yxatni chiqarish (customers/data/datarows — to'g'ri yoki data ichida)
  static List<dynamic> _extractList(Map<String, dynamic> res) {
    final raw = res['customers'] ?? res['datarows'] ?? res['data'];
    if (raw is List<dynamic>) return raw;
    if (raw is Map<String, dynamic>) {
      final inner = raw['customers'] ?? raw['datarows'] ?? raw['data'] ?? raw['items'];
      if (inner is List<dynamic>) return inner;
    }
    return [];
  }

  Future<void> loadFromApi({bool force = false}) async {
    final now = DateTime.now();
    final freshEnough = _lastLoadedAt != null && now.difference(_lastLoadedAt!) < _cacheTtl;
    if (!force && _loaded && _items.isNotEmpty && freshEnough) return;
    if (_inFlightLoad != null) return _inFlightLoad!;

    final future = _loadFromApiInternal();
    _inFlightLoad = future;
    try {
      await future;
    } finally {
      _inFlightLoad = null;
    }
  }

  Future<void> _loadFromApiInternal() async {
    _loadError = null;
    try {
      // Qarzi va balansi bilan to'liq ro'yxat: POST /contacts/customers
      Map<String, dynamic> res;
      try {
        res = await ContactsApi.getCustomers(body: {
          'rowLimit': 5000,
          'rowOffset': 0,
          // Ba'zi backend implementatsiyalarida columnName/columnKey talab qilinadi
          'columnKey': 'id',
          'columnSortedBy': 'DESC',
          'searchValue': '',
          'reqType': '',
          'filtersData': [],
        });
      } on ApiException catch (_) {
        // POST muvaffaqiyatsiz bo'lsa — GET /contacts/customers-list (datarows, balance, due_amount)
        res = await ContactsApi.getCustomersList();
      }
      _lastRawCustomers = res;
      final list = _extractList(res);
      _items = list
          .map((e) {
            try {
              return Client.fromApiJson(Map<String, dynamic>.from(e as Map));
            } catch (_) {
              return null;
            }
          })
          .whereType<Client>()
          .where((c) => c.id.isNotEmpty)
          .toList();
      _loaded = true;
      _lastLoadedAt = DateTime.now();
      notifyListeners();
    } on ApiException catch (e) {
      _loadError = e.message;
      _loaded = true;
      _items = [];
      notifyListeners();
    } catch (e, st) {
      _loadError = 'Mijozlar yuklanmadi';
      _loaded = true;
      _items = [];
      notifyListeners();
      assert(() {
        // ignore: avoid_print
        print('ClientsProvider.loadFromApi error: $e\n$st');
        return true;
      }());
    }
  }

  Future<void> add(Client client) async {
    try {
      final nameParts = client.name.trim().split(RegExp(r'\s+'));
      final firstName = nameParts.isNotEmpty ? nameParts.first : client.name;
      final lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';
      await ContactsApi.storeCustomer({
        'first_name': firstName,
        'last_name': lastName,
        'email': client.email ?? '',
        'phone_number': client.phone ?? '',
        'address': client.address ?? '',
        'customer_group': 1,
      });
      await loadFromApi();
    } catch (_) {
      rethrow;
    }
  }

  Future<void> updateClient(Client client) async {
    try {
      final idNum = int.tryParse(client.id);
      if (idNum == null) return;
      final nameParts = client.name.trim().split(RegExp(r'\s+'));
      final firstName = nameParts.isNotEmpty ? nameParts.first : client.name;
      final lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';
      await ContactsApi.updateCustomer(idNum, {
        'first_name': firstName,
        'last_name': lastName,
        'email': client.email ?? '',
        'phone_number': client.phone ?? '',
        'address': client.address ?? '',
      });
      final i = _items.indexWhere((e) => e.id == client.id);
      if (i >= 0) {
        _items[i] = client;
        notifyListeners();
      } else {
        await loadFromApi();
      }
    } catch (_) {
      rethrow;
    }
  }

  Client? getById(String id) {
    try {
      return _items.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  List<Client> search(String query) {
    if (query.trim().isEmpty) return _items;
    final q = query.trim().toLowerCase();
    return _items
        .where((c) =>
            c.name.toLowerCase().contains(q) ||
            (c.phone?.contains(query.trim()) ?? false))
        .toList();
  }

  Future<int> getTotalDebt(String clientId) async {
    // 1) Avval ro'yxatdagi due_amount'dan foydalanamiz (cheklar + qarzlar tab)
    final c = getById(clientId);
    if (c != null && (c.dueAmount ?? 0) > 0) {
      return (c.dueAmount!).round();
    }

    // 2) Agar ro'yxatda 0 bo'lsa, bitta mijozni alohida GET /contacts/customers/{id} orqali yangilab ko'ramiz
    try {
      final idNum = int.tryParse(clientId);
      if (idNum != null) {
        final res = await ContactsApi.getCustomer(idNum);
        final customer = res['customer'] as Map<String, dynamic>?;
        if (customer != null) {
          final fresh = Client.fromApiJson(Map<String, dynamic>.from(customer));
          final idx = _items.indexWhere((e) => e.id == fresh.id);
          if (idx >= 0) {
            _items[idx] = fresh;
          }
          if ((fresh.dueAmount ?? 0) > 0) {
            return (fresh.dueAmount!).round();
          }
        }
      }
    } catch (_) {
      // Agar bu yerda xato bo'lsa, pastdagi eski usulga o'tamiz
    }

    // 3) Aks holda eski usul: /debts javobidan hisoblaymiz
    final entries = await getDebtEntries(clientId);
    return entries.fold<int>(0, (s, e) => s + e.amount);
  }

  /// Ro'yxat ekranlari: har mijoz uchun alohida API yo'q — faqat ro'yxatdagi `due_amount`.
  /// (Eski getDebtMap N ta ketma-ket chaqiriq — juda sekin.)
  static Map<String, int> quickDebtMap(Iterable<Client> items) {
    final map = <String, int>{};
    for (final c in items) {
      final due = c.dueAmount;
      if (due != null && due > 0) map[c.id] = due.round();
    }
    return map;
  }

  /// To'liq aniqlik kerak bo'lganda (kamdan-kam): har mijoz bo'yicha API.
  Future<Map<String, int>> getDebtMap() async {
    final map = <String, int>{};
    for (final c in _items) {
      final debt = await getTotalDebt(c.id);
      if (debt > 0) map[c.id] = debt;
    }
    return map;
  }

  Future<List<DebtEntry>> getDebtEntries(String clientId) async {
    try {
      final idNum = int.tryParse(clientId);
      if (idNum == null) return [];
      final res = await ContactsApi.getCustomerDebts(idNum);
      final debts = res['customer_debts'] as List<dynamic>? ??
          res['datarows'] as List<dynamic>? ??
          res['data'] as List<dynamic>? ??
          res['debts'] as List<dynamic>? ??
          [];
      return debts.map((d) {
        final m = Map<String, dynamic>.from(d as Map);
        return DebtEntry(
          clientId: clientId,
          amount: m['amount'] as int? ?? 0,
          receiptId: m['receipt_id'] as String? ?? m['receiptId'] as String? ?? '',
          dateTime: m['date_time'] as String? ?? m['dateTime'] as String? ?? m['created_at'] as String? ?? '',
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// Faqat API orqali — POST /contacts/customers/{id}/debt/store.
  /// Hujjatga mos: payment holatida payment_type_id ham yuboriladi.
  Future<void> addDebt(
    String clientId,
    int amount,
    String receiptId, {
    int? paymentTypeId,
  }) async {
    final idNum = int.tryParse(clientId);
    if (idNum == null) return;
    final isPayment = amount < 0;
    final body = <String, dynamic>{
      'amount': amount.abs(),
      'type': isPayment ? 'payment' : 'loan',
      'description': receiptId,
    };
    // API docs: type=payment uchun payment_type_id talab qilinadi.
    await ContactsApi.storeCustomerDebt(
      idNum,
      body,
      paymentTypeId: isPayment ? (paymentTypeId ?? 1) : null,
    );
  }
}
