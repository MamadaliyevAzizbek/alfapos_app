import 'dart:async';

import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import '../services/company_cache_store.dart';
import '../utils/customer_filter_options.dart';
import '../utils/customer_groups_list.dart';
import '../core/api_client.dart';
import '../utils/customer_store_body.dart';

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
  final num? ordersDueDebt;
  final num? journalNetDebt;
  final int? customerGroupId;
  final String? customerGroupName;
  final String? supplierName;
  final int? supplierId;
  /// POST /sales/customers — guruh chegirma foizi
  final num? customerGroupDiscount;
  /// selling | purchase | wholesale — guruh foizi qaysi narx ustidan
  final String? customerGroupDiscountPriceType;

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
    this.ordersDueDebt,
    this.journalNetDebt,
    this.customerGroupId,
    this.customerGroupName,
    this.supplierName,
    this.supplierId,
    this.customerGroupDiscount,
    this.customerGroupDiscountPriceType,
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

    String? _strLabel(dynamic v) {
      if (v == null) return null;
      if (v is Map) return null;
      final s = v.toString().trim();
      return s.isEmpty ? null : s;
    }

    String? _nestedLabel(dynamic o) {
      if (o is! Map) return null;
      final m = Map<String, dynamic>.from(o);
      return _strLabel(m['title'] ?? m['name'] ?? m['full_name'] ?? m['label']);
    }

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
      ordersDueDebt: _numOrNull(json['orders_due_debt']),
      journalNetDebt: _numOrNull(json['journal_net_debt']),
      customerGroupId: _intOrNull(json['customer_group'] ?? json['customer_group_id']),
      customerGroupName: _strLabel(json['customer_group_title'] ??
              json['group_name'] ??
              json['customer_group_name'] ??
              json['group_title']) ??
          _nestedLabel(json['customer_group'] ?? json['group']),
      supplierName: _strLabel(json['supplier_name'] ??
              json['supplier_title'] ??
              json['taminotchi'] ??
              json['default_supplier_name']) ??
          _nestedLabel(json['supplier'] ?? json['default_supplier']),
      supplierId: _intOrNull(json['supplier_id'] ?? json['default_supplier_id']),
      customerGroupDiscount: _groupDiscountFromJson(json),
      customerGroupDiscountPriceType: _priceTypeFromJson(json),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'full_name': name,
        'email': email,
        'phone_number': phone,
        'address': address,
        'due_amount': dueAmount,
        'balance': balance,
        'due_payment_date': duePaymentDate,
        'debt_limit': debtLimit,
        'orders_due_debt': ordersDueDebt,
        'journal_net_debt': journalNetDebt,
        'customer_group_id': customerGroupId,
        'customer_group_title': customerGroupName,
        'supplier_name': supplierName,
        'supplier_id': supplierId,
        'customer_group_discount': customerGroupDiscount,
        'customer_group_discount_price_type': customerGroupDiscountPriceType,
      };

  static num? _parseNum(dynamic v) {
    if (v == null) return null;
    if (v is num) return v;
    final s = v.toString().trim();
    if (s.isEmpty) return null;
    return num.tryParse(s);
  }

  static num? _groupDiscountFromJson(Map<String, dynamic> json) {
    final direct = _parseNum(json['customer_group_discount'] ??
        json['group_discount'] ??
        json['customerGroupDiscount'] ??
        json['discount_percent']);
    if (direct != null && direct != 0) return direct;
    final group = json['customer_group'] ?? json['group'];
    if (group is Map) {
      return CustomerGroupsListParser.groupDiscount(Map<String, dynamic>.from(group));
    }
    return direct;
  }

  static String? _priceTypeFromJson(Map<String, dynamic> json) {
    for (final key in [
      'group_markup_price_base',
      'customer_group_discount_price_type',
      'discount_price_type',
      'group_discount_price_type',
      'price_type',
      'group_discount_on',
      'discount_on',
    ]) {
      final v = json[key];
      if (v != null && v.toString().trim().isNotEmpty) {
        return v.toString().trim();
      }
    }
    final group = json['customer_group'] ?? json['group'];
    if (group is Map) {
      return CustomerStoreBody.priceTypeFromGroup(Map<String, dynamic>.from(group));
    }
    return null;
  }
}

/// Filterlar — POST /contacts/customers (web bilan bir xil).
class CustomersListFilters {
  final String groupId;
  final String statusId;
  final String debtBalance;
  final bool blacklistOnly;

  const CustomersListFilters({
    this.groupId = 'all',
    this.statusId = 'all',
    this.debtBalance = 'all',
    this.blacklistOnly = false,
  });

  List<Map<String, String>> toFiltersData() => [
        {'key': 'customerGroups', 'value': groupId},
        {'key': 'customerStatuses', 'value': statusId},
        {'key': 'customerDebtBalance', 'value': debtBalance},
      ];
}

class ClientsProvider extends ChangeNotifier {
  ClientsProvider._() {
    _items = [];
  }
  static final ClientsProvider _instance = ClientsProvider._();
  static ClientsProvider get instance => _instance;

  List<Client> _items = [];
  bool _loaded = false;
  bool _loading = false;
  bool _hasMore = true;
  int _rowOffset = 0;
  static const int pageSize = 20;
  String _lastSearch = '';
  CustomersListFilters _lastFilters = const CustomersListFilters();
  num _listTotalDebt = 0;
  num _listTotalBalance = 0;
  int _listCount = 0;
  String? _loadError;
  Map<String, dynamic>? _lastRawCustomers;
  DateTime? _lastLoadedAt;
  Future<void>? _inFlightLoad;
  static const Duration _cacheTtl = Duration(seconds: 45);

  List<Client> get items => List.unmodifiable(_items);
  bool get isLoading => _loading;
  bool get hasMore => _hasMore;
  num get listTotalDebt => _listTotalDebt;
  num get listTotalBalance => _listTotalBalance;
  int get listCount => _listCount > 0 ? _listCount : _items.length;
  String? get loadError => _loadError;
  Map<String, dynamic>? get lastRawCustomers => _lastRawCustomers;

  void resetForAccountChange() {
    _items = [];
    _loaded = false;
    _loading = false;
    _hasMore = true;
    _rowOffset = 0;
    _lastSearch = '';
    _lastFilters = const CustomersListFilters();
    _listTotalDebt = 0;
    _listTotalBalance = 0;
    _listCount = 0;
    _loadError = null;
    _lastRawCustomers = null;
    _lastLoadedAt = null;
    _inFlightLoad = null;
    notifyListeners();
    unawaited(CompanyCacheStore.remove(CompanyCacheStore.clients));
  }

  Future<void> warmFromCache() async {
    if (_items.isNotEmpty) return;
    final decoded = await CompanyCacheStore.readJson(CompanyCacheStore.clients);
    if (decoded is! List) return;
    try {
      _items = decoded
          .whereType<Map>()
          .map((e) => Client.fromApiJson(Map<String, dynamic>.from(e)))
          .where((c) => c.id.isNotEmpty)
          .toList();
      if (_items.isNotEmpty) {
        _loaded = true;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> refreshFromServer({bool force = false}) async =>
      loadFromApi(force: force);

  Future<void> loadFromStorage({bool force = false}) async {
    if (!force) await warmFromCache();
    await loadFromApi(force: force);
  }

  Future<void> _persistCache() async {
    if (_items.isEmpty) return;
    await CompanyCacheStore.writeJson(
      CompanyCacheStore.clients,
      _items.map((c) => c.toJson()).toList(),
    );
  }

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

  Future<void> loadFromApi({
    bool force = false,
    String searchValue = '',
    CustomersListFilters filters = const CustomersListFilters(),
  }) async {
    await loadCustomersPage(
      reset: true,
      force: force,
      searchValue: searchValue,
      filters: filters,
    );
  }

  Future<void> loadCustomersPage({
    bool reset = true,
    bool force = false,
    String searchValue = '',
    CustomersListFilters filters = const CustomersListFilters(),
  }) async {
    if (!reset && (!_hasMore || _loading)) return;

    final now = DateTime.now();
    final sameQuery = searchValue == _lastSearch &&
        filters.groupId == _lastFilters.groupId &&
        filters.statusId == _lastFilters.statusId &&
        filters.debtBalance == _lastFilters.debtBalance &&
        filters.blacklistOnly == _lastFilters.blacklistOnly;
    final freshEnough = _lastLoadedAt != null && now.difference(_lastLoadedAt!) < _cacheTtl;
    if (!force && reset && _loaded && _items.isNotEmpty && freshEnough && sameQuery) return;

    if (reset) {
      _rowOffset = 0;
      _hasMore = true;
      _lastSearch = searchValue;
      _lastFilters = filters;
    }

    if (_inFlightLoad != null && reset) {
      await _inFlightLoad;
      if (!force && sameQuery && _loaded) return;
    }

    _loading = true;
    _loadError = null;
    notifyListeners();

    final future = _fetchPage(reset: reset, searchValue: searchValue, filters: filters);
    _inFlightLoad = future;
    try {
      await future;
    } finally {
      _inFlightLoad = null;
      _loading = false;
    }
  }

  Future<void> _fetchPage({
    required bool reset,
    required String searchValue,
    required CustomersListFilters filters,
  }) async {
    try {
      final body = <String, dynamic>{
        'rowLimit': pageSize,
        'rowOffset': _rowOffset,
        'searchValue': searchValue,
        'columnKey': 'first_name',
        'columnSortedBy': 'asc',
        'filtersData': filters.toFiltersData(),
      };
      if (filters.blacklistOnly) body['debt_limit'] = true;

      Map<String, dynamic> res;
      try {
        res = await ContactsApi.getCustomers(body: body);
      } on ApiException catch (_) {
        if (_rowOffset > 0) rethrow;
        res = await ContactsApi.getCustomersList();
      }

      _lastRawCustomers = res;
      _parseListTotals(res);

      final page = _extractList(res)
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

      if (reset) {
        _items = page;
      } else {
        final seen = _items.map((c) => c.id).toSet();
        _items = [..._items, ...page.where((c) => !seen.contains(c.id))];
      }

      _rowOffset += page.length;
      _hasMore = page.length >= pageSize;
      _loaded = true;
      _lastLoadedAt = DateTime.now();
      notifyListeners();
      if (reset && searchValue.isEmpty) {
        unawaited(_persistCache());
      }
    } on ApiException catch (e) {
      _loadError = e.message;
      if (reset) _items = [];
      notifyListeners();
    } catch (e, st) {
      _loadError = 'Mijozlar yuklanmadi';
      if (reset) _items = [];
      notifyListeners();
      assert(() {
        // ignore: avoid_print
        print('ClientsProvider.loadCustomersPage error: $e\n$st');
        return true;
      }());
    }
  }

  void _parseListTotals(Map<String, dynamic> res) {
    num toNum(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v;
      return double.tryParse(v.toString()) ?? 0;
    }

    _listTotalDebt = toNum(res['totalDebt'] ?? res['total_debt']);
    _listTotalBalance = toNum(res['totalBalance'] ?? res['total_balance']);
    final c = res['count'];
    _listCount = c is int ? c : int.tryParse(c?.toString() ?? '') ?? 0;
  }

  List<Map<String, dynamic>>? _groupsCache;
  DateTime? _groupsCacheAt;
  Future<List<Map<String, dynamic>>>? _groupsFetchInFlight;
  static const _groupsCacheTtl = Duration(seconds: 45);

  void invalidateGroupsCache() {
    _groupsCache = null;
    _groupsCacheAt = null;
  }

  /// POST /groups-list → form-options / customer-groups (foiz bilan).
  Future<List<Map<String, dynamic>>> _fetchCustomerGroupsImpl() async {
    try {
      final res = await ContactsApi.postGroupsList();
      final rows = CustomerGroupsListParser.parseRows(res);
      final normalized = _normalizeGroupRows(rows);
      if (normalized.any((g) => CustomerGroupsListParser.groupDiscount(g) != 0)) {
        return normalized;
      }
    } catch (_) {}

    for (final fetcher in [
      () => ContactsApi.getCustomerFormOptions(),
      () => ContactsApi.getCustomerGroups(),
      () => ContactsApi.getGroupsShort(),
    ]) {
      try {
        final res = await fetcher();
        final rows = CustomerGroupsListParser.groupsFromResponse(res);
        if (rows.isNotEmpty) {
          final normalized = _normalizeGroupRows(rows);
          if (normalized.isNotEmpty) return normalized;
        }
      } catch (_) {}
    }

    try {
      final res = await ContactsApi.postGroupsList();
      final rows = CustomerGroupsListParser.parseRows(res);
      if (rows.isNotEmpty) return _normalizeGroupRows(rows);
    } catch (_) {}

    return [];
  }

  List<Map<String, dynamic>> _normalizeGroupRows(List<Map<String, dynamic>> rows) {
    return rows
        .map((g) {
          final id = CustomerGroupsListParser.groupIdFrom(g);
          if (id == null) return null;
          return {
            'id': id,
            'title': CustomerGroupsListParser.groupTitle(g),
            'name': CustomerGroupsListParser.groupTitle(g),
            'discount': CustomerGroupsListParser.groupDiscount(g),
            'is_default': CustomerGroupsListParser.groupIsDefault(g) ? 1 : 0,
          };
        })
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  Future<List<Map<String, dynamic>>> _getCustomerGroupsCached() async {
    if (_groupsCache != null &&
        _groupsCacheAt != null &&
        DateTime.now().difference(_groupsCacheAt!) < _groupsCacheTtl) {
      return _groupsCache!;
    }

    if (_groupsFetchInFlight != null) return _groupsFetchInFlight!;

    _groupsFetchInFlight = _fetchCustomerGroupsImpl();
    try {
      final list = await _groupsFetchInFlight!;
      _groupsCache = list;
      _groupsCacheAt = DateTime.now();
      return list;
    } finally {
      _groupsFetchInFlight = null;
    }
  }

  /// «Mijoz guruhlari» tabi.
  Future<List<Map<String, dynamic>>> loadCustomerGroupsTable() => _getCustomerGroupsCached();

  Future<List<Map<String, dynamic>>> fetchCustomerGroups() => _getCustomerGroupsCached();

  /// Savatda mijoz guruhi foizini aniqlash uchun oxirgi guruhlar ro'yxati.
  List<Map<String, dynamic>> get cachedCustomerGroups => _groupsCache ?? const [];

  /// GET customer-groups (+ POST customers) javobidan filtr variantlari.
  Future<CustomerListFilterMeta> fetchCustomerFilterMeta() async {
    Map<String, dynamic>? groupsRes;
    Map<String, dynamic>? customersRes;

    try {
      groupsRes = await ContactsApi.getCustomerGroups();
    } catch (_) {}

    if (CustomerFilterOptionsParser.parseGroupsFromResponse(groupsRes ?? {}).isEmpty) {
      try {
        groupsRes = await ContactsApi.getGroupsShort();
      } catch (_) {}
    }

    try {
      customersRes = await ContactsApi.getCustomers(body: {
        'rowLimit': 1,
        'rowOffset': 0,
        'searchValue': '',
        'columnKey': 'first_name',
        'columnSortedBy': 'asc',
        'filtersData': const CustomersListFilters().toFiltersData(),
      });
    } catch (_) {}

    return CustomerFilterOptionsParser.fromResponses(
      groupsResponse: groupsRes,
      customersResponse: customersRes,
    );
  }

  CustomerListFilterMeta filterMetaFromLastResponse() {
    return CustomerFilterOptionsParser.fromResponses(customersResponse: _lastRawCustomers);
  }

  Future<void> deleteClient(String clientId) async {
    final idNum = int.tryParse(clientId);
    if (idNum == null) return;
    await ContactsApi.deleteCustomer(idNum);
    _items.removeWhere((c) => c.id == clientId);
    notifyListeners();
  }

  Future<Client?> refreshCustomer(String clientId) async {
    final idNum = int.tryParse(clientId);
    if (idNum == null) return null;
    final res = await ContactsApi.getCustomer(idNum);
    final customer = res['customer'] as Map<String, dynamic>? ?? res;
    final fresh = Client.fromApiJson(Map<String, dynamic>.from(customer));
    final idx = _items.indexWhere((e) => e.id == fresh.id);
    if (idx >= 0) _items[idx] = fresh;
    notifyListeners();
    return fresh;
  }

  Future<List<Map<String, dynamic>>> fetchBalanceTransactions(String clientId) async {
    final idNum = int.tryParse(clientId);
    if (idNum == null) return [];
    final res = await ContactsApi.getCustomerBalanceTransactions(idNum);
    final raw = res['datarows'] ?? res['data'] ?? res['transactions'];
    if (raw is List) {
      return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return [];
  }

  Future<void> updateCustomerBalance(
    String clientId, {
    required num amount,
    required String type,
    String description = '',
  }) async {
    final idNum = int.tryParse(clientId);
    if (idNum == null) return;
    await ContactsApi.updateCustomerBalance(idNum, amount: amount, type: type, description: description);
    await refreshCustomer(clientId);
  }

  Future<void> addJournalDebt(
    String clientId, {
    required num amount,
    required String type,
    String description = '',
    int? paymentTypeId,
  }) async {
    final idNum = int.tryParse(clientId);
    if (idNum == null) return;
    final body = <String, dynamic>{
      'amount': amount,
      'type': type,
      'description': description,
    };
    await ContactsApi.storeCustomerDebt(idNum, body, paymentTypeId: paymentTypeId);
    await refreshCustomer(clientId);
  }

  /// Vaqtinchalik lokal ID (ms timestamp) — server mijoz ID emas.
  static bool isPlausibleServerCustomerId(String id) {
    final n = int.tryParse(id.trim());
    if (n == null || n <= 0) return false;
    return n < 100000000;
  }

  static Client? clientFromStoreResponse(
    Map<String, dynamic> res, {
    required Client draft,
  }) {
    dynamic raw = res['customer'] ?? res['data'];
    if (raw is Map) {
      try {
        return Client.fromApiJson(Map<String, dynamic>.from(raw as Map));
      } catch (_) {}
    }
    final idRaw = res['id'] ?? res['customer_id'] ?? res['customerId'];
    if (idRaw != null) {
      final idStr = idRaw is int ? idRaw.toString() : idRaw.toString().trim();
      if (isPlausibleServerCustomerId(idStr)) {
        return Client(
          id: idStr,
          name: draft.name,
          email: draft.email,
          phone: draft.phone,
          address: draft.address,
          customerGroupId: draft.customerGroupId,
          customerGroupName: draft.customerGroupName,
          customerGroupDiscount: draft.customerGroupDiscount,
          customerGroupDiscountPriceType: draft.customerGroupDiscountPriceType,
        );
      }
    }
    return null;
  }

  Client? _findClientByPhoneOrName(String? phone, String name) {
    final phoneNorm = _normalizePhone(phone);
    if (phoneNorm.isNotEmpty) {
      for (final c in _items) {
        if (_normalizePhone(c.phone) == phoneNorm) return c;
      }
    }
    final nameNorm = name.trim().toLowerCase();
    if (nameNorm.isNotEmpty) {
      for (final c in _items) {
        if (c.name.trim().toLowerCase() == nameNorm) return c;
      }
    }
    return null;
  }

  static String _normalizePhone(String? phone) {
    if (phone == null) return '';
    return phone.replaceAll(RegExp(r'\D'), '');
  }

  /// Sotuvdan oldin: haqiqiy server `customer.id` (yangi mijoz vaqtinchalik ID bilan qolmasin).
  Future<Client> resolveClientForSales(Client client) async {
    if (isPlausibleServerCustomerId(client.id)) {
      try {
        final res = await ContactsApi.getCustomer(int.parse(client.id));
        final raw = res['customer'] ?? res['data'] ?? res;
        if (raw is Map) {
          return Client.fromApiJson(Map<String, dynamic>.from(raw as Map));
        }
      } catch (_) {}
    }
    await loadFromApi(force: true);
    final found = _findClientByPhoneOrName(client.phone, client.name);
    if (found != null && isPlausibleServerCustomerId(found.id)) {
      return found;
    }
    throw ApiException(
      'Mijoz serverda topilmadi. Ro\'yxatdan qayta tanlang yoki mijozni qayta saqlang.',
      400,
    );
  }

  Future<Client> add(
    Client client, {
    String? groupDiscountPriceType,
  }) async {
    try {
      final nameParts = client.name.trim().split(RegExp(r'\s+'));
      final firstName = nameParts.isNotEmpty ? nameParts.first : client.name;
      final lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';
      final res = await ContactsApi.storeCustomer(
        CustomerStoreBody.build(
          firstName: firstName,
          lastName: lastName,
          phone: client.phone,
          address: client.address,
          customerGroupId: client.customerGroupId ?? 1,
          groupDiscountPriceType: groupDiscountPriceType,
          email: client.email ?? '',
        ),
      );
      var saved = clientFromStoreResponse(res, draft: client);
      if (saved == null || !isPlausibleServerCustomerId(saved.id)) {
        await loadFromApi(force: true);
        saved = _findClientByPhoneOrName(client.phone, client.name);
      }
      final savedClient = saved;
      if (savedClient == null || !isPlausibleServerCustomerId(savedClient.id)) {
        throw ApiException(
          'Mijoz serverda saqlandi, lekin ID qaytmadi. Ro\'yxatni yangilab qayta tanlang.',
          500,
        );
      }
      final idx = _items.indexWhere((e) => e.id == savedClient.id);
      if (idx >= 0) {
        _items[idx] = savedClient;
      } else {
        _items.insert(0, savedClient);
      }
      notifyListeners();
      return savedClient;
    } catch (_) {
      rethrow;
    }
  }

  Future<void> updateClient(
    Client client, {
    String? groupDiscountPriceType,
  }) async {
    try {
      final idNum = int.tryParse(client.id);
      if (idNum == null) return;
      final nameParts = client.name.trim().split(RegExp(r'\s+'));
      final firstName = nameParts.isNotEmpty ? nameParts.first : client.name;
      final lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';
      final priceType = groupDiscountPriceType ?? client.customerGroupDiscountPriceType;
      await ContactsApi.updateCustomer(
        idNum,
        CustomerStoreBody.build(
          firstName: firstName,
          lastName: lastName,
          phone: client.phone,
          address: client.address,
          customerGroupId: client.customerGroupId ?? 1,
          groupDiscountPriceType: priceType,
          email: client.email ?? '',
        ),
      );
      final fresh = await refreshCustomer(client.id);
      if (fresh == null) {
        final i = _items.indexWhere((e) => e.id == client.id);
        if (i >= 0) {
          _items[i] = client;
          notifyListeners();
        } else {
          await loadFromApi(force: true);
        }
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

  /// Umumiy to'lash — POST /contacts/customers/{id}/bulk-due-payment (cheklar FIFO, keyin jurnal).
  Future<Map<String, dynamic>> payBulkDue(
    String clientId, {
    required num amount,
    required Object paymentMethod,
  }) async {
    final idNum = int.tryParse(clientId);
    if (idNum == null) {
      throw ApiException('Mijoz ID noto\'g\'ri', 400);
    }
    final res = await ContactsApi.bulkDuePayment(
      idNum,
      amount: amount,
      paymentMethod: paymentMethod,
    );
    try {
      final customerRes = await ContactsApi.getCustomer(idNum);
      final customer = customerRes['customer'] as Map<String, dynamic>?;
      if (customer != null) {
        final fresh = Client.fromApiJson(Map<String, dynamic>.from(customer));
        final idx = _items.indexWhere((e) => e.id == fresh.id);
        if (idx >= 0) _items[idx] = fresh;
      }
    } catch (_) {}
    notifyListeners();
    return res;
  }

  /// Faqat API orqali — POST /contacts/customers/{id}/debt/store (jurnal qarz/to'lov).
  /// Umumiy to'lash uchun [payBulkDue] ishlating.
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
