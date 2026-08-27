/// POST /sales/store `dueAmount` — aralash to'lovda qarz qoldig'i.
int computeStoreDueAmount({
  required num grandTotal,
  required List<Map<String, dynamic>> paymentTypes,
  required Map<String, num> allocated,
  required bool Function(Map<String, dynamic> e) isQarzPayment,
}) {
  var paidNonQarz = 0.0;
  var qarzLineTotal = 0.0;
  for (final e in paymentTypes) {
    final id = (e['id'] is int ? e['id'] as int : int.tryParse(e['id']?.toString() ?? '0') ?? 0)
        .toString();
    final amt = (allocated[id] ?? 0).toDouble();
    if (amt <= 0) continue;
    if (isQarzPayment(e)) {
      qarzLineTotal += amt;
    } else {
      paidNonQarz += amt;
    }
  }
  if (qarzLineTotal > 0) return qarzLineTotal.round();
  final due = grandTotal.toDouble() - paidNonQarz;
  if (due <= 0) return 0;
  return due.round();
}
