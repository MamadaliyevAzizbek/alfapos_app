import '../core/input_formatters.dart';

/// Sessiyada muvaffaqiyatli qaytarilgan order id lar (API darhol yangilanmasa ham ikki marta qaytarilmasin).
class SaleReturnGuard {
  SaleReturnGuard._();

  static final Set<int> _returnedOrderIds = {};

  static void markReturned(int orderId) => _returnedOrderIds.add(orderId);

  static bool wasReturnedInSession(int orderId) => _returnedOrderIds.contains(orderId);

  /// Faqat testlar uchun.
  static void clearSessionForTesting() => _returnedOrderIds.clear();
}

/// Chek allaqachon qaytarilgan yoki qaytarish tranzaksiyasi (qayta qaytarish mumkin emas).
bool isSaleAlreadyReturned(Map<String, dynamic> sale, {Map<String, dynamic>? invoiceDetail}) {
  final orderId = getOrderIdFromSale(sale);
  if (orderId != null && SaleReturnGuard.wasReturnedInSession(orderId)) return true;

  if (_mapIndicatesReturned(sale)) return true;
  if (invoiceDetail != null && _mapIndicatesReturned(invoiceDetail)) return true;
  return false;
}

/// Oddiy sotuv chekida "Chekni qaytarish" ko'rsatish mumkinmi.
bool canShowReturnSaleButton(Map<String, dynamic> sale, {Map<String, dynamic>? invoiceDetail}) {
  if (isSaleAlreadyReturned(sale, invoiceDetail: invoiceDetail)) return false;
  if (getOrderIdFromSale(sale) == null) return false;

  final orderType = (sale['orderType'] ?? sale['order_type'] ?? sale['sales_or_receiving_type'] ?? '')
      .toString()
      .toLowerCase();
  if (orderType.contains('return') || orderType.contains('receiving') || orderType.contains('refund')) {
    return false;
  }

  final total = parseAmountFromApi(sale['total'] ?? sale['grand_total'] ?? sale['total_amount'] ?? 0);
  if (total < 0) return false;

  return true;
}

bool _mapIndicatesReturned(Map<String, dynamic> m) {
  final status = (m['status'] ?? m['order_status'] ?? m['invoice_status'] ?? m['payment_status'] ?? '')
      .toString()
      .toLowerCase()
      .trim();
  if (_textIndicatesReturned(status)) return true;

  final orderType = (m['orderType'] ?? m['order_type'] ?? m['type'] ?? '').toString().toLowerCase();
  if (orderType.contains('return') || orderType.contains('refund')) return true;

  for (final key in ['is_returned', 'is_return', 'returned', 'has_return', 'is_refunded', 'fully_returned']) {
    final v = m[key];
    if (v == true || v == 1 || v == '1' || v == 'true') return true;
  }

  for (final key in ['returned_at', 'return_date', 'returned_date', 'return_order_id', 'return_id', 'return_invoice_id']) {
    final v = m[key];
    if (v != null && v.toString().trim().isNotEmpty && v.toString() != '0' && v.toString().toLowerCase() != 'null') {
      return true;
    }
  }

  final total = parseAmountFromApi(m['total'] ?? m['grand_total'] ?? m['total_amount'] ?? m['sum'] ?? 0);
  if (total < 0) return true;

  for (final key in ['item_purchased', 'title', 'invoice_id', 'note', 'description', 'message']) {
    final t = (m[key] ?? '').toString().toLowerCase();
    if (_textIndicatesReturned(t)) return true;
  }

  return false;
}

bool _textIndicatesReturned(String t) {
  if (t.isEmpty) return false;
  return t.contains('return') ||
      t.contains('refund') ||
      t.contains('qaytarilgan') ||
      t.contains('qaytarildi') ||
      t.contains('bekor') ||
      t == 'returned' ||
      t == 'cancelled' ||
      t == 'canceled';
}
