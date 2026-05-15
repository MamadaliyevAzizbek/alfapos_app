import '../core/constants.dart';
import '../models/daily_sales.dart';

/// Bugungi savdo, xarajatlar va to'lov turlari. Real hisobotlar 0 dan boshlanadi.
DailySales getTodaySales() {
  final now = DateTime.now();
  return DailySales(
    date: DateTime(now.year, now.month, now.day),
    totalUzs: 0,
    expensesUzs: 0,
    transactionCount: 0,
    byPaymentType: const [
      PaymentTypeAmount(typeId: 'naqd', label: Strings.naqd, amountUzs: 0),
      PaymentTypeAmount(typeId: 'karta', label: Strings.karta, amountUzs: 0),
      PaymentTypeAmount(typeId: 'transfer', label: Strings.tolovOtkazma, amountUzs: 0),
      PaymentTypeAmount(typeId: 'click', label: Strings.click, amountUzs: 0),
      PaymentTypeAmount(typeId: 'payme', label: Strings.payme, amountUzs: 0),
      PaymentTypeAmount(typeId: 'other', label: Strings.boshqaTolov, amountUzs: 0),
    ],
  );
}
