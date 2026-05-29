import 'package:flutter/foundation.dart';
import '../models/transaction_record.dart';
import '../models/daily_sales.dart';

/// To'lov turi id -> label (chek detali va boshqa ekranlar uchun)
const Map<String, String> paymentTypeLabels = {
  'naqd': 'Naqd',
  'karta': 'Karta',
  'uzcard': 'UzCard',
  'humo': 'HUMO',
  'payme': 'Payme',
  'qarz': 'Qarz',
};

/// Tranzaksiyalar faqat API dan (Tranzaksiyalar/Hisobotlar). Lokal saqlash yo'q.
class TransactionsProvider extends ChangeNotifier {
  TransactionsProvider._() {
    _records = [];
  }
  static final TransactionsProvider _instance = TransactionsProvider._();
  static TransactionsProvider get instance => _instance;

  List<TransactionRecord> _records = [];
  bool _loaded = false;

  List<TransactionRecord> get records => List.unmodifiable(_records);

  void resetForAccountChange() {
    _records = [];
    _loaded = false;
    notifyListeners();
  }

  /// Lokal saqlash yo'q — faqat xotirada bo'sh ro'yxat (API dan tranzaksiyalar boshqa ekranlarda).
  Future<void> loadFromStorage() async {
    if (_loaded) return;
    _loaded = true;
    _records = [];
    notifyListeners();
  }

  /// Lokal saqlanmaydi — API orqali chek yopiladi, bu provider da yozuv qo'shilmaydi.
  Future<void> addTransaction(TransactionRecord record) async {
    await loadFromStorage();
    _records.insert(0, record);
    _records.sort((a, b) => b.dateTime.compareTo(a.dateTime));
    notifyListeners();
  }

  /// Lokal saqlanmaydi — faqat xotirada o'chiradi (chek qaytarish API orqali bo'lsa shu yerda chaqirilmasin).
  Future<void> removeTransaction(String receiptId) async {
    await loadFromStorage();
    _records.removeWhere((r) => r.receiptId == receiptId);
    notifyListeners();
  }

  /// Bugungi kun uchun barcha tranzaksiyalar
  List<TransactionRecord> getTransactionsForDay(DateTime day) {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    return _records.where((r) {
      final d = r.date;
      return !d.isBefore(start) && d.isBefore(end);
    }).toList();
  }

  /// Bugungi kunlik savdo (bosh sahifa: jami + to'lov turlari + xarajat = kelish narxi, sof foyda)
  DailySales getTodaySales() {
    final now = DateTime.now();
    final today = getTransactionsForDay(now);
    final totalUzs = today.fold<int>(0, (s, r) => s + r.totalSum);
    final expensesUzs = today.fold<int>(0, (s, r) => s + r.totalCostUzs);
    final byType = <String, int>{};
    final labelByKey = <String, String>{};
    for (final r in today) {
      for (final e in r.payments.entries) {
        byType[e.key] = (byType[e.key] ?? 0) + e.value;
        if (r.paymentLabels != null && r.paymentLabels!.containsKey(e.key)) {
          labelByKey[e.key] = r.paymentLabels![e.key]!;
        } else if (!labelByKey.containsKey(e.key)) {
          labelByKey[e.key] = paymentTypeLabels[e.key] ?? e.key;
        }
      }
    }
    final byPaymentType = byType.entries.map((e) => PaymentTypeAmount(
      typeId: e.key,
      label: labelByKey[e.key] ?? e.key,
      amountUzs: e.value,
    )).toList();
    return DailySales(
      date: DateTime(now.year, now.month, now.day),
      totalUzs: totalUzs,
      expensesUzs: expensesUzs,
      transactionCount: today.length,
      byPaymentType: byPaymentType,
    );
  }

  /// Barcha tranzaksiyalar (eng yangisi birinchi)
  Future<List<TransactionRecord>> getAllTransactions() async {
    await loadFromStorage();
    return List.from(_records);
  }

  /// Mijozga biriktirilgan cheklar (ketma-ket, yangisi birinchi)
  Future<List<TransactionRecord>> getTransactionsByClientId(String clientId) async {
    await loadFromStorage();
    return _records.where((r) => r.clientId == clientId).toList();
  }

  /// Bugungi eng ko'p sotilgan mahsulotlar (quantityDeducted bo'yicha), limit ta
  List<TopSoldProduct> getTopSoldProductsToday(int limit) {
    final today = getTransactionsForDay(DateTime.now());
    final map = <String, _TopSoldAccumulator>{};
    for (final r in today) {
      for (final row in r.productRows) {
        final key = row.productId?.isNotEmpty == true ? row.productId! : row.productName;
        map.putIfAbsent(key, () => _TopSoldAccumulator(row.productName));
        map[key]!.add(row.quantityDeducted);
      }
    }
    final list = map.entries
        .map((e) => TopSoldProduct(name: e.value.name, quantitySold: e.value.total))
        .where((p) => p.quantitySold > 0)
        .toList();
    list.sort((a, b) => b.quantitySold.compareTo(a.quantitySold));
    return list.take(limit).toList();
  }
}

class TopSoldProduct {
  final String name;
  final int quantitySold;
  const TopSoldProduct({required this.name, required this.quantitySold});
}

class _TopSoldAccumulator {
  final String name;
  int total = 0;
  _TopSoldAccumulator(this.name);
  void add(int q) => total += q;
}
