/// To'lov turi bo'yicha summa (num — API dagi kabi, yaxlitlanmaydi)
class PaymentTypeAmount {
  final String typeId;
  final String label;
  final num amountUzs;
  final String? iconName; // optional: naqd, karta, etc.

  const PaymentTypeAmount({
    required this.typeId,
    required this.label,
    required this.amountUzs,
    this.iconName,
  });
}

/// Kunlik savdo (bugungi yoki tanlangan kun). Summalar num — API dagi ko'rinishida.
class DailySales {
  final DateTime date;
  final num totalUzs;
  final num expensesUzs;
  final int transactionCount;
  final List<PaymentTypeAmount> byPaymentType;

  const DailySales({
    required this.date,
    required this.totalUzs,
    required this.expensesUzs,
    required this.transactionCount,
    required this.byPaymentType,
  });

  num get netProfitUzs => totalUzs - expensesUzs;

  /// Eski usul: API + mahalliy birlashtirish. Hozir barcha cheklar/savdo faqat API dan (merge ishlatilmaydi).
  static DailySales merge(DailySales api, DailySales local) {
    final byType = <String, num>{};
    final labels = <String, String>{};
    for (final e in api.byPaymentType) {
      byType[e.typeId] = (byType[e.typeId] ?? 0) + e.amountUzs;
      labels[e.typeId] = e.label;
    }
    for (final e in local.byPaymentType) {
      byType[e.typeId] = (byType[e.typeId] ?? 0) + e.amountUzs;
      if (!labels.containsKey(e.typeId)) labels[e.typeId] = e.label;
    }
    final byPaymentType = byType.entries
        .map((e) => PaymentTypeAmount(
              typeId: e.key,
              label: labels[e.key] ?? e.key,
              amountUzs: e.value,
            ))
        .toList();
    return DailySales(
      date: api.date,
      totalUzs: api.totalUzs + local.totalUzs,
      expensesUzs: api.expensesUzs + local.expensesUzs,
      transactionCount: api.transactionCount + local.transactionCount,
      byPaymentType: byPaymentType,
    );
  }
}

/// Minglik bo'shliq: 60010 -> "60 010"
String _spaceGroup(int n) {
  final s = n.abs().toString();
  final buf = StringBuffer();
  if (n < 0) buf.write('-');
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
    buf.write(s[i]);
  }
  return buf.toString();
}

extension DailySalesFormat on DailySales {
  String totalFormatted(String currency) => DailySalesFormat.formatWithCurrency(totalUzs, currency);
  String expensesFormatted(String currency) => DailySalesFormat.formatWithCurrency(expensesUzs, currency);
  String netProfitFormatted(String currency) => DailySalesFormat.formatWithCurrency(netProfitUzs, currency);
  static String formatUzs(num n) => formatWithCurrency(n, 'UZS');
  /// API dagi ko'rinishida: butun "10.00", kasr "2.5". Valyuta API dan kelsa qo'shiladi, bo'lmasa hech narsa qo'shilmaydi.
  static String formatWithCurrency(num n, String currency) {
    final s = n == n.round() ? '${_spaceGroup(n.toInt())}.00' : '$n';
    final sym = currency.trim();
    return sym.isEmpty ? s : '$s $sym';
  }
}

extension PaymentTypeAmountFormat on PaymentTypeAmount {
  String amountFormatted(String currency) => DailySalesFormat.formatWithCurrency(amountUzs, currency);
}
