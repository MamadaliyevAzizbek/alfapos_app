import 'package:flutter/foundation.dart';
import '../models/expense.dart';
import '../services/api_service.dart';
import '../core/api_client.dart';

class ExpensesProvider extends ChangeNotifier {
  ExpensesProvider._() {
    _list = [];
  }
  static final ExpensesProvider _instance = ExpensesProvider._();
  static ExpensesProvider get instance => _instance;

  List<Expense> _list = [];
  bool _loaded = false;
  bool _loading = false;
  String? _loadError;
  List<Map<String, dynamic>> _paymentTypes = [];
  List<Map<String, dynamic>> _expenseCategories = [];
  Map<String, dynamic>? _lastRawExpenses;

  List<Expense> get items => List.unmodifiable(_list);
  String? get loadError => _loadError;
  bool get isLoading => _loading;
  /// Debug: GET /expenses oxirgi javobi
  Map<String, dynamic>? get lastRawExpenses => _lastRawExpenses;
  List<Map<String, dynamic>> get paymentTypes => List.unmodifiable(_paymentTypes);
  List<Map<String, dynamic>> get expenseCategories => List.unmodifiable(_expenseCategories);

  void resetForAccountChange() {
    _list = [];
    _loaded = false;
    _loading = false;
    _loadError = null;
    _paymentTypes = [];
    _expenseCategories = [];
    _lastRawExpenses = null;
    notifyListeners();
  }

  int? get _firstPaymentTypeId {
    if (_paymentTypes.isEmpty) return null;
    final v = _paymentTypes.first['id'] ?? _paymentTypes.first['payment_type_id'];
    if (v == null) return null;
    return v is int ? v : int.tryParse(v.toString());
  }

  int? get _firstExpenseCategoryId {
    if (_expenseCategories.isEmpty) return null;
    final v = _expenseCategories.first['id'] ?? _expenseCategories.first['expense_category_id'];
    if (v == null) return null;
    return v is int ? v : int.tryParse(v.toString());
  }

  Future<void> loadFromStorage() async => loadFromApi();

  Future<void> loadFromApi({DateTime? fromDate, DateTime? toDate}) async {
    _loadError = null;
    _loading = true;
    notifyListeners();
    try {
      final now = DateTime.now();
      final fromBase = fromDate ?? DateTime(now.year, now.month, now.day);
      final toBase = toDate ?? fromBase;
      final from = '${fromBase.year}-${fromBase.month.toString().padLeft(2, '0')}-${fromBase.day.toString().padLeft(2, '0')}';
      final to = '${toBase.year}-${toBase.month.toString().padLeft(2, '0')}-${toBase.day.toString().padLeft(2, '0')}';
      final res = await ExpensesApi.getExpenses(from: from, to: to);
      _lastRawExpenses = res;
      final rows = res['expenses'] as List<dynamic>? ?? res['data'] as List<dynamic>? ?? [];
      _list = rows
          .map((e) => Expense.fromApiJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      _list.sort((a, b) => b.date.compareTo(a.date));
      final pt = res['paymentTypes'] as List<dynamic>? ?? res['payment_types'] as List<dynamic>? ?? [];
      _paymentTypes = pt.map((e) => e is Map ? Map<String, dynamic>.from(e as Map) : <String, dynamic>{}).where((m) => m.isNotEmpty).toList();
      final ec = res['expenseCategories'] as List<dynamic>? ?? res['expense_categories'] as List<dynamic>? ?? [];
      _expenseCategories = ec.map((e) => e is Map ? Map<String, dynamic>.from(e as Map) : <String, dynamic>{}).where((m) => m.isNotEmpty).toList();
      _loaded = true;
      _loading = false;
      notifyListeners();
    } on ApiException catch (e) {
      _loadError = e.message;
      _loaded = true;
      _loading = false;
      _list = [];
      notifyListeners();
    } catch (_) {
      _loadError = 'Xarajatlar yuklanmadi';
      _loaded = true;
      _loading = false;
      _list = [];
      notifyListeners();
    }
  }

  /// Faqat API orqali — POST /expenses. Lokal saqlanmaydi.
  /// paymentTypeId va expenseCategoryId API dan kelgan paymentTypes / expenseCategories dan.
  Future<void> addExpense(
    Expense expense, {
    int? paymentTypeId,
    int? expenseCategoryId,
  }) async {
    final body = <String, dynamic>{
      'name': expense.name,
      'price': expense.amountUzs,
      'date': expense.date.toIso8601String().substring(0, 10),
    };
    final pid = paymentTypeId ?? _firstPaymentTypeId;
    if (pid != null) body['payment_type_id'] = pid;
    final cid = expenseCategoryId ?? _firstExpenseCategoryId;
    if (cid != null) body['expense_category_id'] = cid;
    await ExpensesApi.createExpense(body);
    await loadFromApi();
  }

  /// Faqat API orqali — DELETE /expenses/{id}. Keyin ro'yxat API dan qayta yuklanadi.
  Future<void> removeExpense(String id) async {
    final idNum = int.tryParse(id);
    if (idNum == null) return;
    await ExpensesApi.deleteExpense(idNum);
    await loadFromApi();
  }

  int getTotalForDay(DateTime day) {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    return _list
        .where((e) {
          final d = e.date;
          return !d.isBefore(start) && d.isBefore(end);
        })
        .fold<int>(0, (s, e) => s + e.amountUzs);
  }

  int get todayTotal => getTotalForDay(DateTime.now());

  List<Expense> getTodayExpenses() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    return _list
        .where((e) {
          final d = e.date;
          return !d.isBefore(start) && d.isBefore(end);
        })
        .toList();
  }
}
