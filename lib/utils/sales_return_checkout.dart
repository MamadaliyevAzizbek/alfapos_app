/// Desktop POS ichki qaytarish — POST /sales/store yukini web POS bilan moslashtirish.
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

  /// UI ijobiy summalar → API manfiy qaytarish cheki.
  static Map<String, dynamic> applyInlineReturnToStoreBody(
    Map<String, dynamic> body, {
    required bool creditPaymentUsed,
    List<String> invoiceReturnIds = const [],
    List<int> returnStandaloneDebtIds = const [],
  }) {
    final out = Map<String, dynamic>.from(body);
    out['salesOrReturnType'] = 'sales';
    out['dueAmount'] = 0;

    out['subTotal'] = -_absInt(out['subTotal']);
    out['grandTotal'] = -_absInt(out['grandTotal']);

    final profit = out['profit'];
    if (profit is num) out['profit'] = -profit.abs().round();

    final discount = out['discount'];
    if (discount is num && discount != 0) {
      out['discount'] = discount is int ? -discount.abs() : -discount.abs();
    }

    final cart = out['cart'];
    if (cart is List) {
      out['cart'] = cart.map((row) {
        if (row is! Map) return row;
        final line = Map<String, dynamic>.from(row);
        line['quantity'] = -_absNum(line['quantity']);
        line['calculatedPrice'] = -_absInt(line['calculatedPrice']);
        if (invoiceReturnIds.isNotEmpty) {
          line['invoiceReturnId'] = invoiceReturnIds.first;
          line['invoiceReturnIds'] = List<String>.from(invoiceReturnIds);
        }
        return line;
      }).toList();
    }

    final payments = out['payments'];
    if (payments is List) {
      out['payments'] = payments.map((row) {
        if (row is! Map) return row;
        final p = Map<String, dynamic>.from(row);
        p['paid'] = -_absInt(p['paid']);
        return p;
      }).toList();
    }

    if (creditPaymentUsed) {
      out['returnCreditStandaloneSelected'] = returnStandaloneDebtIds.isNotEmpty;
      out['returnStandaloneDebtIds'] = List<int>.from(returnStandaloneDebtIds);
    }

    return out;
  }

  static int refundDueFromPositiveCartTotal(int positiveTotal) => positiveTotal.abs();

  static int _absInt(Object? value) {
    if (value is int) return value.abs();
    if (value is num) return value.abs().round();
    return int.tryParse(value?.toString() ?? '')?.abs() ?? 0;
  }

  static num _absNum(Object? value) {
    if (value is num) return value.abs();
    return num.tryParse(value?.toString() ?? '')?.abs() ?? 0;
  }
}
