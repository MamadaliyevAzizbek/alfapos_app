import 'package:flutter/foundation.dart';
import '../models/daily_sales.dart';
import '../services/api_service.dart';
import '../core/api_client.dart';

class DashboardProvider extends ChangeNotifier {
  DashboardProvider._();
  static final DashboardProvider _instance = DashboardProvider._();
  static DashboardProvider get instance => _instance;

  DailySales? _todaySales;
  List<TopSoldProduct> _topProducts = [];
  List<SellerInfo> _sellers = [];
  String? _loadError;
  bool _loading = false;
  String? _currencySymbol;
  /// API dan "Bugungi daromad" / todayIncomes / todayProfit — sof foyda kartasida ko'rsatiladi (yaxlitlanmaydi)
  num? _todayDaromadUzs;
  Map<String, dynamic>? _lastRawDashboard;
  Map<String, dynamic>? _lastRawTopProducts;

  DailySales get todaySales => _todaySales ?? _emptyDailySales();
  /// Valyuta belgisi faqat API dan. API da bo'lmasa bo'sh — dastur hech narsa qo'shmasin.
  String get currencySymbol => _currencySymbol?.trim() ?? '';
  /// API da todayIncomes / todayProfit / todayDaromad bo'lsa — "Bugungi umumiy sof foyda" kartasida shu qiymat.
  num? get todayDaromadUzs => _todayDaromadUzs;
  List<TopSoldProduct> get topProducts => List.unmodifiable(_topProducts);
  List<SellerInfo> get sellers => List.unmodifiable(_sellers);
  String? get loadError => _loadError;
  bool get isLoading => _loading;
  /// API dan kelgan oxirgi javob (debug: qanday format ekanini ko'rish)
  Map<String, dynamic>? get lastRawDashboard => _lastRawDashboard;
  Map<String, dynamic>? get lastRawTopProducts => _lastRawTopProducts;

  static DailySales _emptyDailySales() {
    final now = DateTime.now();
    return DailySales(
      date: DateTime(now.year, now.month, now.day),
      totalUzs: 0,
      expensesUzs: 0,
      transactionCount: 0,
      byPaymentType: const [],
    );
  }

  /// Sonlar uchun (savdolar soni, order_count) — butun son
  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.round();
    final s = v.toString().trim();
    if (s.isEmpty) return 0;
    final n = int.tryParse(s);
    if (n != null) return n;
    final d = double.tryParse(s);
    return d != null ? d.round() : 0;
  }

  /// Summalar uchun — API dagi kabi, yaxlitlanmaydi ("10.00" -> 10.0, 2.5 -> 2.5)
  static num _toNum(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v;
    final s = v.toString().trim();
    if (s.isEmpty) return 0;
    final d = double.tryParse(s);
    return d ?? 0;
  }

  Future<void> loadFromApi() async {
    _loadError = null;
    _loading = true;
    notifyListeners();
    try {
      final dateStr = '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}';
      final res = await DashboardApi.getDashboard(date: dateStr);
      _lastRawDashboard = res;
      // API javobi: basicData (todaySales, todayExpenses), root todayPaymentTypes (payment_method, total_amount), dailyProductsSold (son yoki list)
      final basicData = res['basicData'] as Map<String, dynamic>? ?? res['data'] as Map<String, dynamic>? ?? res;

      // Valyuta: API dan currency, currency_symbol, currencySymbol (root yoki basicData)
      final cur = res['currency'] ?? res['currency_symbol'] ?? res['currencySymbol'] ?? basicData['currency'] ?? basicData['currency_symbol'] ?? basicData['currencySymbol'];
      _currencySymbol = cur is String ? cur : (cur?.toString().trim().isEmpty == false ? cur.toString() : null);

      // Bugungi savdo: todayIncomes (root), basicData.todaySales — yaxlitlanmaydi
      num totalUzs = _toNum(res['todayIncomes']);
      if (totalUzs == 0) totalUzs = _toNum(basicData['todaySales']);
      if (totalUzs == 0) totalUzs = _toNum(basicData['total_sales']);
      if (totalUzs == 0) totalUzs = _toNum(basicData['today_total']);
      if (totalUzs == 0) totalUzs = _toNum(res['total_sales']);
      if (totalUzs == 0) totalUzs = _toNum(res['today_total']);

      // To'lov turlari: todayPaymentTypes — summalar API dagi kabi
      List<dynamic> todayPaymentTypes = res['todayPaymentTypes'] as List<dynamic>? ?? res['paymentTypes'] as List<dynamic>? ?? res['payment_types'] as List<dynamic>? ?? [];
      if (todayPaymentTypes.isEmpty) {
        todayPaymentTypes = basicData['todayPaymentTypes'] as List<dynamic>? ?? basicData['paymentTypes'] as List<dynamic>? ?? basicData['payment_types'] as List<dynamic>? ?? [];
      }
      final byPaymentType = <PaymentTypeAmount>[];
      for (final e in todayPaymentTypes) {
        final m = e is Map ? Map<String, dynamic>.from(e as Map) : null;
        if (m == null) continue;
        final typeId = (m['type_id'] ?? m['typeId'] ?? m['id'] ?? m['payment_type'] ?? '').toString();
        final label = (m['payment_method'] ?? m['label'] ?? m['name'] ?? m['title'] ?? typeId).toString();
        final amount = m['total_amount'] ?? m['amount'] ?? m['amountUzs'] ?? m['total'] ?? m['sum'] ?? 0;
        final trimmedLabel = label.trim();
        byPaymentType.add(PaymentTypeAmount(
          typeId: typeId.isEmpty ? (trimmedLabel.isEmpty ? 'payment_${byPaymentType.length}' : trimmedLabel) : typeId,
          label: trimmedLabel.isEmpty ? 'To\'lov' : label,
          amountUzs: _toNum(amount),
        ));
      }
      // Qarz: basicData.todayDebt — yaxlitlanmaydi
      final todayDebt = _toNum(basicData['todayDebt'] ?? basicData['today_debt'] ?? basicData['due_amount'] ?? res['todayDebt'] ?? res['today_debt'] ?? res['due_amount'] ?? 0);
      final hasQarz = byPaymentType.any((p) {
        final l = p.label.toLowerCase();
        final t = p.typeId.toString().toLowerCase();
        return l.contains('qarz') || l.contains('debt') || l.contains('credit') || t.contains('qarz') || t.contains('debt');
      });
      if (!hasQarz && (todayDebt != 0 || byPaymentType.isNotEmpty)) {
        byPaymentType.add(PaymentTypeAmount(typeId: 'qarz', label: 'Qarz', amountUzs: todayDebt));
      }

      // Savdolar soni: basicData yoki sellersReport dagi order_count yig'indisi
      int transactionCount = _toInt(basicData['transaction_count']) + _toInt(basicData['sales_count']);
      if (transactionCount == 0) transactionCount = _toInt(res['transaction_count']) + _toInt(res['sales_count']);
      final sellersRaw = res['sellersReport'] as List<dynamic>? ?? [];
      _sellers = sellersRaw.map((e) {
        if (e is! Map) return null;
        final m = Map<String, dynamic>.from(e as Map);
        return SellerInfo(
          sellerId: _toInt(m['seller_id'] ?? m['id']),
          sellerName: (m['seller_name'] ?? m['name'] ?? '').toString(),
          orderCount: _toInt(m['order_count']),
          totalSales: _toNum(m['total_sales']),
        );
      }).whereType<SellerInfo>().toList();
      if (transactionCount == 0) {
        for (final s in _sellers) transactionCount += s.orderCount;
      }
      // Bugungi xarajat: basicData.todayExpenses — yaxlitlanmaydi
      num expensesUzs = _toNum(basicData['todayExpenses']);
      if (expensesUzs == 0) expensesUzs = _toNum(basicData['today_expenses']) + _toNum(basicData['expensesUzs']);
      if (expensesUzs == 0) expensesUzs = _toNum(res['today_expenses']) + _toNum(res['expensesUzs']);

      // Bugungi daromad / sof foyda: API dagi kabi (2.5, 40002.5)
      num? apiDaromad;
      const daromadKeys = ['todayProfit', 'today_profit', 'todayIncomes', 'today_income', 'todayDaromad', 'daromad'];
      for (final key in daromadKeys) {
        if (basicData.containsKey(key)) {
          apiDaromad = _toNum(basicData[key]);
          break;
        }
      }
      if (apiDaromad == null) {
        for (final key in daromadKeys) {
          if (res.containsKey(key)) {
            apiDaromad = _toNum(res[key]);
            break;
          }
        }
      }
      _todayDaromadUzs = apiDaromad;

      _todaySales = DailySales(
        date: DateTime.now(),
        totalUzs: totalUzs,
        expensesUzs: expensesUzs,
        transactionCount: transactionCount,
        byPaymentType: byPaymentType,
      );

      // dailyProductsSold API da son (0) yoki list bo'lishi mumkin — list bo'lsa ishlatamiz, aks holda /top-selling-products
      List<dynamic> dailyProducts = [];
      final rawDaily = res['dailyProductsSold'] ?? basicData['dailyProductsSold'];
      if (rawDaily is List<dynamic>) dailyProducts = rawDaily;
      if (dailyProducts.isEmpty) {
        try {
          final topRes = await DashboardApi.getTopSellingProducts();
          _lastRawTopProducts = topRes;
          dailyProducts = topRes['dailyProductsSold'] as List<dynamic>? ?? topRes['data'] as List<dynamic>? ?? topRes['top_products'] as List<dynamic>? ?? [];
        } catch (_) {}
      }
      _topProducts = dailyProducts.take(10).map((e) {
        final m = e is Map ? Map<String, dynamic>.from(e as Map) : {};
        final name = (m['product'] ?? m['name'] ?? m['product_name'] ?? m['title'] ?? '').toString();
        final qty = m['total_sold'] ?? m['quantity'] ?? m['quantity_sold'] ?? m['total_quantity'] ?? m['qty'] ?? 0;
        return TopSoldProduct(
          name: name.isEmpty ? '—' : name,
          quantitySold: _toInt(qty),
        );
      }).toList();

      _loading = false;
      notifyListeners();
    } on ApiException catch (e) {
      _loadError = e.message;
      _todaySales = _emptyDailySales();
      _topProducts = [];
      _sellers = [];
      _todayDaromadUzs = null;
      _loading = false;
      notifyListeners();
    } catch (_) {
      _loadError = null;
      _todaySales = _emptyDailySales();
      _topProducts = [];
      _sellers = [];
      _todayDaromadUzs = null;
      _loading = false;
      notifyListeners();
    }
  }
}

/// API sellersReport dan: sotuvchi ismi, savdolar soni, jami savdo (totalSales — API dagi kabi)
class SellerInfo {
  final int sellerId;
  final String sellerName;
  final int orderCount;
  final num totalSales;
  const SellerInfo({
    required this.sellerId,
    required this.sellerName,
    required this.orderCount,
    required this.totalSales,
  });
}

class TopSoldProduct {
  final String name;
  final int quantitySold;
  const TopSoldProduct({required this.name, required this.quantitySold});
}
