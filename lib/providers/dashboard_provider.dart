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
  /// API `summary.today_incomes` — «Bugungi daxod» kartasi (daromad emas, kirimlar).
  num? _todayDaromadUzs;
  num _totalPaymentToday = 0;
  Map<String, dynamic>? _lastRawDashboard;
  Map<String, dynamic>? _lastRawTopProducts;

  num _todayDebt = 0;
  num _totalDebtAll = 0;
  num _warehouseValue = 0;
  num _salesValue = 0;
  int _totalProductsCount = 0;
  int _totalStockQuantity = 0;
  int _customersCount = 0;
  int _soldProductsToday = 0;
  num _returnedToday = 0;
  num _last30DaysProfit = 0;
  num _totalProfitAll = 0;
  List<DashboardBarPoint> _barChart = [];
  List<DashboardLinePoint> _lineChart = [];

  DailySales get todaySales => _todaySales ?? _emptyDailySales();
  /// Valyuta belgisi faqat API dan. API da bo'lmasa bo'sh — dastur hech narsa qo'shmasin.
  String get currencySymbol => _currencySymbol?.trim() ?? '';
  /// `summary.today_incomes` — Bugungi daxod kartasi.
  num? get todayDaromadUzs => _todayDaromadUzs;
  num get todayDaxod => _todayDaromadUzs ?? 0;
  /// `payment_types.total_payment_today` — Bugungi jami to'lov.
  num get totalPaymentToday => _totalPaymentToday;
  List<TopSoldProduct> get topProducts => List.unmodifiable(_topProducts);
  List<SellerInfo> get sellers => List.unmodifiable(_sellers);
  String? get loadError => _loadError;
  bool get isLoading => _loading;
  /// API dan kelgan oxirgi javob (debug: qanday format ekanini ko'rish)
  Map<String, dynamic>? get lastRawDashboard => _lastRawDashboard;
  Map<String, dynamic>? get lastRawTopProducts => _lastRawTopProducts;
  num get todayDebt => _todayDebt;
  num get totalDebtAll => _totalDebtAll;
  num get warehouseValue => _warehouseValue;
  num get salesValue => _salesValue;
  int get totalProductsCount => _totalProductsCount;
  int get totalStockQuantity => _totalStockQuantity;
  int get customersCount => _customersCount;
  int get soldProductsToday => _soldProductsToday;
  num get returnedToday => _returnedToday;
  num get last30DaysProfit => _last30DaysProfit;
  num get totalProfitAll => _totalProfitAll;
  List<DashboardBarPoint> get barChart => List.unmodifiable(_barChart);
  List<DashboardLinePoint> get lineChart => List.unmodifiable(_lineChart);

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

  DateTime _selectedDate = DateTime.now();
  DateTime get selectedDate => _selectedDate;

  Future<void> loadFromApi([DateTime? forDate]) async {
    _loadError = null;
    _loading = true;
    if (forDate != null) {
      _selectedDate = DateTime(forDate.year, forDate.month, forDate.day);
    }
    notifyListeners();
    try {
      final d = _selectedDate;
      final dateStr = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      final res = await DashboardApi.getDashboard(date: dateStr);
      _lastRawDashboard = res;
      await _parseDashboardResponse(res);

      _loading = false;
      notifyListeners();
    } on ApiException catch (e) {
      _loadError = e.message;
      _todaySales = _emptyDailySales();
      _topProducts = [];
      _sellers = [];
      _todayDaromadUzs = null;
      _clearExtended();
      _loading = false;
      notifyListeners();
    } catch (_) {
      _loadError = null;
      _todaySales = _emptyDailySales();
      _topProducts = [];
      _sellers = [];
      _todayDaromadUzs = null;
      _clearExtended();
      _loading = false;
      notifyListeners();
    }
  }

  /// Yangi `GET /dashboard` (summary, payment_types, …) + `legacy` fallback.
  Future<void> _parseDashboardResponse(Map<String, dynamic> res) async {
    final root = res['data'] is Map
        ? Map<String, dynamic>.from(res['data'] as Map)
        : res;
    final legacy = root['legacy'] is Map
        ? Map<String, dynamic>.from(root['legacy'] as Map)
        : <String, dynamic>{};
    final basicData = legacy['basicData'] is Map
        ? Map<String, dynamic>.from(legacy['basicData'] as Map)
        : (root['basicData'] is Map
            ? Map<String, dynamic>.from(root['basicData'] as Map)
            : root);

    final cur = root['currency'] ??
        root['currency_symbol'] ??
        root['currencySymbol'] ??
        basicData['currency'] ??
        basicData['currency_symbol'] ??
        basicData['currencySymbol'];
    _currencySymbol = cur is String ? cur : (cur?.toString().trim().isEmpty == false ? cur.toString() : null);

    final summary = root['summary'] is Map
        ? Map<String, dynamic>.from(root['summary'] as Map)
        : null;

    num totalUzs = 0;
    num expensesUzs = 0;
    num todayDebt = 0;
    num daxod = 0;
    num returned = 0;

    if (summary != null) {
      totalUzs = _toNum(summary['today_sales']);
      todayDebt = _toNum(summary['today_debt']);
      expensesUzs = _toNum(summary['today_expenses']);
      daxod = _toNum(summary['today_incomes']);
      returned = _toNum(summary['today_returned_amount']);
    } else {
      totalUzs = _toNum(
        basicData['todaySales'] ??
            basicData['today_sales'] ??
            basicData['total_sales'] ??
            root['todaySales'] ??
            root['total_sales'],
      );
      todayDebt = _toNum(
        basicData['todayDebt'] ??
            basicData['today_debt'] ??
            root['todayDebt'] ??
            root['today_debt'],
      );
      expensesUzs = _toNum(
        basicData['todayExpenses'] ??
            basicData['today_expenses'] ??
            root['todayExpenses'] ??
            root['today_expenses'],
      );
      daxod = _toNum(
        basicData['todayIncomes'] ??
            basicData['today_incomes'] ??
            root['todayIncomes'] ??
            root['today_incomes'],
      );
      returned = _toNum(
        basicData['todayReturnedAmount'] ??
            basicData['today_returned_amount'] ??
            root['todayReturnedAmount'] ??
            root['today_returned_amount'],
      );
    }
    _todayDebt = todayDebt;
    _todayDaromadUzs = daxod;
    _returnedToday = returned;

    // To'lov turlari
    _totalPaymentToday = 0;
    List<dynamic> paymentItems = [];
    final paymentTypes = root['payment_types'];
    if (paymentTypes is Map) {
      final pt = Map<String, dynamic>.from(paymentTypes);
      _totalPaymentToday = _toNum(pt['total_payment_today']);
      paymentItems = pt['items'] as List<dynamic>? ?? [];
      if (returned == 0) returned = _toNum(pt['today_returned_amount']);
      if (returned != 0) _returnedToday = returned;
    }
    if (paymentItems.isEmpty) {
      paymentItems = root['todayPaymentTypes'] as List<dynamic>? ??
          legacy['todayPaymentTypes'] as List<dynamic>? ??
          basicData['todayPaymentTypes'] as List<dynamic>? ??
          [];
    }
    final byPaymentType = _parsePaymentItems(paymentItems);
    if (_totalPaymentToday == 0 && byPaymentType.isNotEmpty) {
      _totalPaymentToday = byPaymentType.fold<num>(0, (s, e) => s + e.amountUzs);
    }
    _ensureQarzInPayments(byPaymentType, todayDebt);

    // Sotuvchilar
    final sellersRaw = root['sellers_report'] as List<dynamic>? ??
        root['sellersReport'] as List<dynamic>? ??
        legacy['sellersReport'] as List<dynamic>? ??
        [];
    _sellers = sellersRaw.map((e) {
      if (e is! Map) return null;
      final m = Map<String, dynamic>.from(e);
      return SellerInfo(
        sellerId: _toInt(m['seller_id'] ?? m['id']),
        sellerName: (m['seller_name'] ?? m['name'] ?? '').toString(),
        orderCount: _toInt(m['order_count']),
        totalSales: _toNum(m['total_sales']),
      );
    }).whereType<SellerInfo>().toList();

    var transactionCount = _toInt(basicData['transaction_count']) + _toInt(basicData['sales_count']);
    if (transactionCount == 0) {
      for (final s in _sellers) {
        transactionCount += s.orderCount;
      }
    }

    _todaySales = DailySales(
      date: _selectedDate,
      totalUzs: totalUzs,
      expensesUzs: expensesUzs,
      transactionCount: transactionCount,
      byPaymentType: byPaymentType,
    );

    // Qo'shimcha ma'lumot
    final additional = root['additional_info'];
    if (additional is Map) {
      final ai = Map<String, dynamic>.from(additional);
      _soldProductsToday = _toInt(ai['daily_products_sold']);
      _totalProductsCount = _toInt(ai['total_products_count']);
      _totalDebtAll = _toNum(ai['total_debt']);
      _salesValue = _toNum(ai['stock_selling_value']);
      _warehouseValue = _toNum(ai['stock_purchase_value']);
      _totalStockQuantity = _toInt(ai['total_remaining_quantity']);
    } else {
      _applyLegacyAdditionalInfo(root, basicData, legacy, todayDebt);
    }

    // Foyda (pastki kartalar / kelajak) — daxod emas!
    final profit = root['profit'];
    if (profit is Map) {
      final p = Map<String, dynamic>.from(profit);
      _last30DaysProfit = _toNum(p['last_30_days']);
      _totalProfitAll = _toNum(p['total']);
    } else {
      _last30DaysProfit = _toNum(
        basicData['last30DaysProfit'] ??
            basicData['last_30_days_profit'] ??
            basicData['monthlyProfit'],
      );
      _totalProfitAll = _toNum(basicData['totalProfit'] ?? basicData['total_profit']);
    }

    final charts = root['charts'];
    if (charts is Map) {
      final c = Map<String, dynamic>.from(charts);
      _barChart = _parseBarChart(c['yearly_sales_expenses'] ?? legacy['barChartData']);
      _lineChart = _parseLineChart(c['last_7_days_sales'] ?? legacy['lineChartData']);
    } else {
      _barChart = _parseBarChart(root['barChartData'] ?? legacy['barChartData'] ?? basicData['barChartData']);
      _lineChart = _parseLineChart(root['lineChartData'] ?? legacy['lineChartData'] ?? basicData['lineChartData']);
    }

    // Kunlik sotilgan — son yoki top mahsulotlar ro'yxati
    List<dynamic> dailyProducts = [];
    final rawDaily = root['additional_info'] is Map
        ? (root['additional_info'] as Map)['daily_products_sold']
        : (root['dailyProductsSold'] ?? basicData['dailyProductsSold'] ?? legacy['dailyProductsSold']);
    if (rawDaily is List<dynamic>) dailyProducts = rawDaily;
    if (dailyProducts.isEmpty && _soldProductsToday == 0) {
      try {
        final topRes = await DashboardApi.getTopSellingProducts();
        _lastRawTopProducts = topRes;
        dailyProducts = _extractList(topRes);
      } catch (_) {}
    }
    _topProducts = dailyProducts.take(10).map((e) {
      final m = e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{};
      final name = (m['product'] ?? m['name'] ?? m['product_name'] ?? m['title'] ?? '').toString();
      final qty = m['total_sold'] ?? m['quantity'] ?? m['quantity_sold'] ?? m['total_quantity'] ?? m['qty'] ?? 0;
      return TopSoldProduct(
        name: name.isEmpty ? '—' : name,
        quantitySold: _toInt(qty),
      );
    }).toList();

    if (_soldProductsToday == 0) {
      if (rawDaily is num && rawDaily is! bool) {
        _soldProductsToday = _toInt(rawDaily);
      } else if (_topProducts.isNotEmpty) {
        _soldProductsToday = _topProducts.fold<int>(0, (s, p) => s + p.quantitySold);
      }
    }
  }

  void _applyLegacyAdditionalInfo(
    Map<String, dynamic> root,
    Map<String, dynamic> basicData,
    Map<String, dynamic> legacy,
    num todayDebt,
  ) {
    _totalDebtAll = _toNum(
      basicData['totalDebt'] ?? basicData['total_debt'] ?? root['totalDebt'] ?? todayDebt,
    );
    _warehouseValue = _toNum(
      basicData['warehouseValue'] ??
          basicData['warehouse_value'] ??
          root['totalPurchaseValue'] ??
          legacy['totalPurchaseValue'],
    );
    _salesValue = _toNum(
      basicData['salesValue'] ??
          basicData['sales_value'] ??
          root['totalOrderValue'] ??
          legacy['totalOrderValue'],
    );
    _totalProductsCount = _toInt(
      basicData['totalProducts'] ??
          root['totalRemainingProductsCount'] ??
          legacy['totalRemainingProductsCount'],
    );
    _totalStockQuantity = _toInt(
      root['totalProductsQuantity'] ?? legacy['totalProductsQuantity'],
    );
    if (_soldProductsToday == 0) {
      final rawDaily = root['dailyProductsSold'] ?? legacy['dailyProductsSold'];
      if (rawDaily is num && rawDaily is! bool) {
        _soldProductsToday = _toInt(rawDaily);
      }
    }
    _customersCount = _toInt(
      basicData['totalCustomers'] ?? root['customersCount'] ?? root['totalCustomers'],
    );
  }

  static List<dynamic> _extractList(dynamic raw) {
    if (raw is List) return raw;
    if (raw is Map) {
      final inner = raw['data'] ?? raw['items'] ?? raw['products'] ?? raw['datarows'];
      if (inner is List) return inner;
    }
    return [];
  }

  static List<PaymentTypeAmount> _parsePaymentItems(List<dynamic> items) {
    final out = <PaymentTypeAmount>[];
    for (final e in items) {
      if (e is! Map) continue;
      final m = Map<String, dynamic>.from(e);
      final typeId = (m['type_id'] ?? m['typeId'] ?? m['id'] ?? m['type'] ?? m['payment_type'] ?? '').toString();
      final label = (m['payment_method'] ?? m['label'] ?? m['name'] ?? m['title'] ?? typeId).toString();
      final amount = m['total_amount'] ?? m['amount'] ?? m['amountUzs'] ?? m['total'] ?? m['sum'] ?? 0;
      final trimmedLabel = label.trim();
      out.add(PaymentTypeAmount(
        typeId: typeId.isEmpty ? (trimmedLabel.isEmpty ? 'payment_${out.length}' : trimmedLabel) : typeId,
        label: trimmedLabel.isEmpty ? 'To\'lov' : label,
        amountUzs: _toNum(amount),
      ));
    }
    return out;
  }

  static void _ensureQarzInPayments(List<PaymentTypeAmount> items, num todayDebt) {
    final hasQarz = items.any((p) {
      final l = p.label.toLowerCase();
      final t = p.typeId.toLowerCase();
      return l.contains('qarz') || l.contains('debt') || t.contains('credit') || t == 'credit';
    });
    if (!hasQarz && todayDebt != 0) {
      items.add(PaymentTypeAmount(typeId: 'qarz', label: 'Qarz', amountUzs: todayDebt));
    }
  }

  void _clearExtended() {
    _todayDebt = 0;
    _totalPaymentToday = 0;
    _totalDebtAll = 0;
    _warehouseValue = 0;
    _salesValue = 0;
    _totalProductsCount = 0;
    _totalStockQuantity = 0;
    _customersCount = 0;
    _soldProductsToday = 0;
    _returnedToday = 0;
    _last30DaysProfit = 0;
    _totalProfitAll = 0;
    _barChart = [];
    _lineChart = [];
  }

  static List<DashboardBarPoint> _parseBarChart(dynamic raw) {
    if (raw is Map) {
      final m = Map<String, dynamic>.from(raw);
      final months = m['months'];
      if (months is List) {
        final out = <DashboardBarPoint>[];
        for (final e in months) {
          if (e is! Map) continue;
          final row = Map<String, dynamic>.from(e);
          final label = (row['label'] ?? row['month'] ?? '').toString();
          out.add(DashboardBarPoint(
            label: label.isEmpty ? '${out.length + 1}' : label,
            sales: _toNum(row['sales']),
            expenses: _toNum(row['expenses']),
          ));
        }
        if (out.isNotEmpty) return out;
      }
      final sales = m['sales'];
      final expenses = m['expenses'];
      if (sales is List) {
        final expList = expenses is List ? expenses : <dynamic>[];
        final labels = m['months'] ?? m['labels'] ?? m['month'];
        final labelList = labels is List ? labels : null;
        final out = <DashboardBarPoint>[];
        for (var i = 0; i < sales.length; i++) {
          final label = labelList != null && i < labelList.length
              ? labelList[i].toString()
              : '${i + 1}';
          out.add(DashboardBarPoint(
            label: label,
            sales: _toNum(sales[i]),
            expenses: i < expList.length ? _toNum(expList[i]) : 0,
          ));
        }
        return out;
      }
    }
    if (raw is! List) return [];
    final out = <DashboardBarPoint>[];
    for (final e in raw) {
      if (e is! Map) continue;
      final m = Map<String, dynamic>.from(e);
      final label = (m['month'] ?? m['label'] ?? m['name'] ?? '').toString();
      if (label.isEmpty && out.isNotEmpty) continue;
      out.add(DashboardBarPoint(
        label: label.isEmpty ? '${out.length + 1}' : label,
        sales: _toNum(m['sales'] ?? m['sale'] ?? m['total_sales'] ?? m['value'] ?? m['amount']),
        expenses: _toNum(m['expenses'] ?? m['expense'] ?? m['xarajat'] ?? m['cost']),
      ));
    }
    return out;
  }

  static List<DashboardLinePoint> _parseLineChart(dynamic raw) {
    if (raw is Map) {
      final m = Map<String, dynamic>.from(raw);
      final days = m['days'];
      if (days is List && days.isNotEmpty && days.first is Map) {
        final out = <DashboardLinePoint>[];
        for (final e in days) {
          if (e is! Map) continue;
          final row = Map<String, dynamic>.from(e);
          final label = (row['label'] ?? row['day'] ?? '').toString();
          out.add(DashboardLinePoint(
            label: label.isEmpty ? '${out.length + 1}' : label,
            value: _toNum(row['sales'] ?? row['value'] ?? row['total']),
          ));
        }
        if (out.isNotEmpty) return out;
      }
      final sales = m['sales'];
      if (sales is List) {
        final dayList = days is List ? days : (m['labels'] ?? m['dates']);
        final labels = dayList is List ? dayList : null;
        final out = <DashboardLinePoint>[];
        for (var i = 0; i < sales.length; i++) {
          final label = labels != null && i < labels.length
              ? labels[i].toString()
              : '${i + 1}';
          out.add(DashboardLinePoint(label: label, value: _toNum(sales[i])));
        }
        return out;
      }
    }
    if (raw is! List) return [];
    final out = <DashboardLinePoint>[];
    for (final e in raw) {
      if (e is! Map) continue;
      final m = Map<String, dynamic>.from(e);
      final label = (m['day'] ?? m['label'] ?? m['date'] ?? m['name'] ?? '').toString();
      out.add(DashboardLinePoint(
        label: label.isEmpty ? '${out.length + 1}' : label,
        value: _toNum(m['sales'] ?? m['value'] ?? m['total'] ?? m['amount']),
      ));
    }
    return out;
  }
}

class DashboardBarPoint {
  final String label;
  final num sales;
  final num expenses;
  const DashboardBarPoint({required this.label, required this.sales, required this.expenses});
}

class DashboardLinePoint {
  final String label;
  final num value;
  const DashboardLinePoint({required this.label, required this.value});
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
