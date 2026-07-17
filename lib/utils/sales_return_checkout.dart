/// Qaytarish — POST /sales/store (SALES_RETURNS_API.md).
class SalesReturnCheckout {
  SalesReturnCheckout._();

  /// Qarz to'lovi tanlangan, lekin alohida chek tanlanmagan (FIFO / jurnal qarz).
  static bool usesGeneralDebtCredit({
    required bool hasCreditPayment,
    List<String> invoiceReturnIds = const [],
    List<int> standaloneDebtIds = const [],
  }) {
    if (!hasCreditPayment) return false;
    if (invoiceReturnIds.isNotEmpty || standaloneDebtIds.isNotEmpty) return false;
    return true;
  }

  /// UI ijobiy summalar → API qaytarish cheki (`salesOrReturnType: returns`).
  static Map<String, dynamic> applyReturnToStoreBody(
    Map<String, dynamic> body, {
    required bool creditPaymentUsed,
    String? invoiceReturnId,
    int? returnSourceOrderId,
    List<String> invoiceReturnIds = const [],
    List<int> returnStandaloneDebtIds = const [],
  }) {
    final out = Map<String, dynamic>.from(body);
    out['salesOrReturnType'] = 'returns';
    out['dueAmount'] = 0;

    // API: subTotal musbat, grandTotal manfiy.
    out['subTotal'] = _absNum(out['subTotal']);
    out['grandTotal'] = -_absNum(out['grandTotal']);

    final profit = out['profit'];
    if (profit is num) out['profit'] = -profit.abs().round();

    final discount = out['discount'];
    if (discount is num && discount != 0) {
      out['discount'] = discount.abs();
    }

    final invId = _firstNonEmpty([
      invoiceReturnId,
      if (invoiceReturnIds.isNotEmpty) invoiceReturnIds.first,
    ]);

    final cart = out['cart'];
    if (cart is List) {
      out['cart'] = cart.map((row) {
        if (row is! Map) return row;
        final line = Map<String, dynamic>.from(row);
        line['quantity'] = -_absNum(line['quantity']);
        line['calculatedPrice'] = _absNum(line['calculatedPrice']);
        if (invId != null) {
          line['invoiceReturnId'] = invId;
          line['invoiceReturnIds'] =
              invoiceReturnIds.isNotEmpty ? List<String>.from(invoiceReturnIds) : [invId];
        }
        if (returnSourceOrderId != null && returnSourceOrderId > 0) {
          line['returnSourceOrderId'] = returnSourceOrderId;
        }
        return line;
      }).toList();
    }

    final payments = out['payments'];
    if (payments is List) {
      out['payments'] = payments.map((row) {
        if (row is! Map) return row;
        final p = Map<String, dynamic>.from(row);
        final neg = -_absNum(p['paid']);
        final existing = p['paid']?.toString() ?? '';
        p['paid'] = existing.contains('.') ? neg.toStringAsFixed(2) : neg;
        return p;
      }).toList();
    }

    if (invId != null) {
      out['invoiceReturnId'] = invId;
    }

    final branch = out['selectedBranchID'] ?? out['branchId'];
    if (branch != null) {
      out['branchId'] = branch;
      out['currentBranch'] = branch;
    }

    if (creditPaymentUsed) {
      out['returnCreditStandaloneSelected'] = returnStandaloneDebtIds.isNotEmpty;
      out['returnStandaloneDebtIds'] = List<int>.from(returnStandaloneDebtIds);
    }

    return out;
  }

  /// Eski nom — ichki qaytarish uchun.
  static Map<String, dynamic> applyInlineReturnToStoreBody(
    Map<String, dynamic> body, {
    required bool creditPaymentUsed,
    String? invoiceReturnId,
    int? returnSourceOrderId,
    List<String> invoiceReturnIds = const [],
    List<int> returnStandaloneDebtIds = const [],
  }) =>
      applyReturnToStoreBody(
        body,
        creditPaymentUsed: creditPaymentUsed,
        invoiceReturnId: invoiceReturnId,
        returnSourceOrderId: returnSourceOrderId,
        invoiceReturnIds: invoiceReturnIds,
        returnStandaloneDebtIds: returnStandaloneDebtIds,
      );

  static int refundDueFromPositiveCartTotal(int positiveTotal) => positiveTotal.abs();

  static String? _firstNonEmpty(List<String?> values) {
    for (final v in values) {
      final s = v?.trim();
      if (s != null && s.isNotEmpty) return s;
    }
    return null;
  }

  static num _absNum(Object? value) {
    if (value is num) return value.abs();
    final s = value?.toString().trim() ?? '';
    if (s.isEmpty) return 0;
    return num.tryParse(s)?.abs() ?? 0;
  }
}
