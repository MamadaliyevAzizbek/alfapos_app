import '../providers/sales_session_provider.dart';
import '../services/api_service.dart';
import 'cash_register_utils.dart';

/// Tezkor kirim/chiqim formasi — to'lov turlari va kategoriyalar (kesh).
class QuickCashFormData {
  final List<Map<String, dynamic>> paymentTypes;
  final List<Map<String, dynamic>> categories;

  const QuickCashFormData({
    required this.paymentTypes,
    required this.categories,
  });
}

class QuickCashFormLoader {
  QuickCashFormLoader._();

  static List<Map<String, dynamic>>? _incomeCategories;
  static List<Map<String, dynamic>>? _expenseCategories;
  static DateTime? _cachedAt;
  static const _cacheTtl = Duration(minutes: 30);

  static String _todayYmd() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  static bool _cacheValid() {
    if (_cachedAt == null) return false;
    return DateTime.now().difference(_cachedAt!) < _cacheTtl;
  }

  static List<Map<String, dynamic>> _paymentTypesFromSession() {
    return SalesSessionProvider.instance.paymentTypes
        .map((m) => {
              'id': m['id'],
              'name': m['name'] ?? m['title'] ?? '${m['id']}',
            })
        .toList();
  }

  static Future<List<Map<String, dynamic>>> _loadCategories(bool isIncome) async {
    if (_cacheValid()) {
      final cached = isIncome ? _incomeCategories : _expenseCategories;
      if (cached != null && cached.isNotEmpty) return cached;
    }

    final today = _todayYmd();
    final res = isIncome
        ? await IncomesApi.getIncomes(from: today, to: today)
        : await ExpensesApi.getExpenses(from: today, to: today);
    final categories = parseDropdownList(
      isIncome
          ? (res['incomeCategories'] ?? res['income_categories'])
          : (res['expenseCategories'] ?? res['expense_categories']),
    );

    if (isIncome) {
      _incomeCategories = categories;
    } else {
      _expenseCategories = categories;
    }
    _cachedAt = DateTime.now();
    return categories;
  }

  /// To'lov turlari (sotuv keshi) + kategoriyalar parallel.
  static Future<QuickCashFormData> load({required bool isIncome}) async {
    final categoriesFuture = _loadCategories(isIncome);
    await SalesSessionProvider.instance.ensurePaymentTypesLoaded();
    final paymentTypes = _paymentTypesFromSession();
    final categories = await categoriesFuture;
    return QuickCashFormData(paymentTypes: paymentTypes, categories: categories);
  }

  static void invalidateCache() {
    _incomeCategories = null;
    _expenseCategories = null;
    _cachedAt = null;
  }
}
