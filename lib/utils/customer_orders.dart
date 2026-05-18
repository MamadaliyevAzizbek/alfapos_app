import '../core/input_formatters.dart';

/// Mijoz sotuvlari jadvali — API `merged_row_type` (MOBILE_CONTACTS_API_UZ.md).
class CustomerOrderRow {
  final Map<String, dynamic> raw;
  final String mergedRowType;
  final String invoiceId;
  final String dateStr;
  final num total;
  final num dueAmount;
  final int? orderId;
  final int? debtId;
  final int? sourcePaymentId;

  CustomerOrderRow(this.raw)
      : mergedRowType = (raw['merged_row_type'] ?? raw['row_type'] ?? 'order').toString(),
        invoiceId = (raw['invoice_id'] ?? raw['invoiceId'] ?? '').toString(),
        dateStr = (raw['date'] ?? raw['created_at'] ?? raw['date_time'] ?? '').toString(),
        total = parseAmountFromApi(raw['total'] ?? raw['grand_total'] ?? raw['total_amount'] ?? 0),
        dueAmount = parseAmountFromApi(raw['due_amount'] ?? 0),
        orderId = _intOrNull(raw['id'] ?? raw['order_id']),
        debtId = _intOrNull(raw['debt_id'] ?? raw['customer_debt_id']),
        sourcePaymentId = _intOrNull(raw['source_payment_id'] ?? raw['payment_id']);

  static int? _intOrNull(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  String get displayTitle {
    if (invoiceId.isNotEmpty && !invoiceId.startsWith('lang.')) return invoiceId;
    final label = (raw['title'] ?? raw['description'] ?? raw['note'] ?? '').toString().trim();
    if (label.isNotEmpty && !label.startsWith('lang.')) return label;
    switch (mergedRowType) {
      case 'customer_debt':
        return label.isNotEmpty && !label.startsWith('lang.')
            ? label
            : 'Qo\'shimcha qarz (jurnal)';
      case 'order_due_payment':
      case 'bulk_due_payment':
        return "To'lov";
      case 'summary':
        return 'Grand total';
      default:
        return 'Chek';
    }
  }

  bool get isOrder => mergedRowType == 'order';
  bool get isDebtJournal => mergedRowType == 'customer_debt';
  bool get isPayment =>
      mergedRowType == 'order_due_payment' || mergedRowType == 'bulk_due_payment';
  bool get isSummary => mergedRowType == 'summary';

  static bool isSummaryRow(Map<String, dynamic> o) {
    final t = (o['merged_row_type'] ?? o['row_type'] ?? '').toString();
    if (t == 'summary') return true;
    final title = (o['title'] ?? o['name'] ?? '').toString().trim().toLowerCase();
    if (title.contains('grand total') || title == 'umumiy' || title == 'jami') return true;
    if (o['is_total'] == true || o['is_summary'] == true) return true;
    return false;
  }

  static List<Map<String, dynamic>> extractList(Map<String, dynamic> res) {
    dynamic raw = res['datarows'] ?? res['orders'] ?? res['data'];
    if (raw is List) return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    if (raw is Map) {
      final inner = raw['datarows'] ?? raw['orders'] ?? raw['data'] ?? raw['items'];
      if (inner is List) {
        return inner.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      }
    }
    return [];
  }
}
