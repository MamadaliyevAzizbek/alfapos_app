import '../core/input_formatters.dart';
import 'sale_return_utils.dart';

/// Tahrirlash uchun savat + to‘lovlar (editable-order javobi).
class InvoiceEditResume {
  final List<dynamic> cartRows;
  final int editOrderId;
  final String editReason;
  final String? sourceInvoiceId;
  final Map<String, dynamic>? customerJson;
  final int? discountPercent;
  final int? grandTotal;
  final List<Map<String, dynamic>> payments;
  final DateTime? saleDate;

  const InvoiceEditResume({
    required this.cartRows,
    required this.editOrderId,
    required this.editReason,
    this.sourceInvoiceId,
    this.customerJson,
    this.discountPercent,
    this.grandTotal,
    this.payments = const [],
    this.saleDate,
  });
}


bool _settingDisabled(dynamic v) {
  if (v == false || v == 0) return true;
  final s = v?.toString().trim().toLowerCase() ?? '';
  return s == '0' || s == 'false' || s == 'no';
}

/// Admin panelda aniq o‘chirilgan bo‘lsa false; aks holda true (default yoqilgan).
bool parseSalesListEditEnabled(Map<String, dynamic> res) {
  for (final key in const [
    'salesListEdit',
    'sales_list_edit_option',
    'salesListEditEnabled',
  ]) {
    if (res.containsKey(key)) {
      return !_settingDisabled(res[key]);
    }
    final data = res['data'];
    if (data is Map && data.containsKey(key)) {
      return !_settingDisabled(data[key]);
    }
  }
  return true;
}

bool parseEnableEditSaleDate(Map<String, dynamic> res) {
  for (final key in const [
    'enable_edit_sale_date',
    'enableEditSaleDate',
    'salesListEdit',
    'sales_list_edit_option',
  ]) {
    if (res.containsKey(key)) {
      return !_settingDisabled(res[key]);
    }
    final data = res['data'];
    if (data is Map && data.containsKey(key)) {
      return !_settingDisabled(data[key]);
    }
  }
  return true;
}

bool _statusIsDone(Map<String, dynamic> sale) {
  final status = (sale['status'] ?? sale['order_status'] ?? sale['invoice_status'] ?? '')
      .toString()
      .toLowerCase()
      .trim();
  if (status.isEmpty) return true;
  return status == 'done' || status == 'completed' || status == 'paid';
}

bool _isReturnOrReceiving(Map<String, dynamic> sale) {
  final orderType = (sale['orderType'] ?? sale['order_type'] ?? sale['sales_or_receiving_type'] ?? sale['type'] ?? '')
      .toString()
      .toLowerCase();
  if (orderType.contains('return') || orderType.contains('refund')) return true;
  if (orderType.contains('receiving') || orderType == 'receive') return true;
  final invoiceId = (sale['invoice_id'] ?? sale['invoiceId'] ?? '').toString().toLowerCase();
  if (invoiceId.contains('return')) return true;
  for (final key in const ['returned_invoice', 'is_return', 'is_returned']) {
    final v = sale[key];
    if (v == true || v == 1 || v == '1') return true;
  }
  return false;
}

/// To‘liq chek tahrirlash tugmasi ko‘rinsinmi (chek holati bo‘yicha; server vaqt/qaytarish tekshiradi).
bool canShowInvoiceEditButton(
  Map<String, dynamic> sale, {
  Map<String, dynamic>? invoiceDetail,
}) {
  if (getOrderIdFromSale(sale) == null) return false;
  if (isSaleAlreadyReturned(sale, invoiceDetail: invoiceDetail)) return false;
  if (_isReturnOrReceiving(sale)) return false;
  if (!_statusIsDone(sale)) return false;
  final status = (sale['status'] ?? '').toString().toLowerCase();
  if (status == 'cancelled' || status == 'canceled' || status == 'hold') return false;
  return true;
}

/// Faqat sana/vaqt tahrirlash.
bool canShowInvoiceDateEditButton(
  Map<String, dynamic> sale, {
  Map<String, dynamic>? invoiceDetail,
}) {
  if (getOrderIdFromSale(sale) == null) return false;
  if (isSaleAlreadyReturned(sale, invoiceDetail: invoiceDetail)) return false;
  if (_isReturnOrReceiving(sale)) return false;
  if (!_statusIsDone(sale)) return false;
  final status = (sale['status'] ?? '').toString().toLowerCase();
  if (status == 'cancelled' || status == 'canceled' || status == 'hold') return false;
  return true;
}

InvoiceEditResume? invoiceEditResumeFromApi(
  Map<String, dynamic> res, {
  required int editOrderId,
  required String editReason,
}) {
  final order = res['order'];
  if (order is! Map) return null;
  final m = Map<String, dynamic>.from(order);
  final cart = m['cart'];
  if (cart is! List || cart.isEmpty) return null;

  final invoiceRaw = (m['invoice_id'] ?? m['invoiceId'] ?? '').toString().trim();
  final customer = m['customer'];
  Map<String, dynamic>? customerJson;
  if (customer is Map) customerJson = Map<String, dynamic>.from(customer);

  final discount = m['discount'];
  int? discountPct;
  if (discount is int) {
    discountPct = discount;
  } else if (discount is num && discount > 0 && discount <= 100) {
    discountPct = discount.round();
  }

  final payments = <Map<String, dynamic>>[];
  final payRaw = m['payments'];
  if (payRaw is List) {
    for (final p in payRaw) {
      if (p is Map) payments.add(Map<String, dynamic>.from(p));
    }
  }

  DateTime? saleDate;
  final dateRaw = m['date'] ?? m['created_at'];
  if (dateRaw != null && dateRaw.toString().isNotEmpty) {
    saleDate = DateTime.tryParse(dateRaw.toString().replaceFirst(' ', 'T'));
  }

  return InvoiceEditResume(
    cartRows: cart,
    editOrderId: editOrderId,
    editReason: editReason,
    sourceInvoiceId: invoiceRaw.isEmpty ? null : invoiceRaw,
    customerJson: customerJson,
    discountPercent: discountPct,
    grandTotal: parseAmountFromApi(m['grand_total'] ?? m['grandTotal']),
    payments: payments,
    saleDate: saleDate,
  );
}
