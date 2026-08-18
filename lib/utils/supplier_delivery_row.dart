import '../core/input_formatters.dart';

/// Yetkazib berish / qarz jurnali qatori — POST …/delivery-report.
class SupplierDeliveryRow {
  SupplierDeliveryRow(this.raw)
      : id = _asString(raw['id'] ?? raw['invoice_id'] ?? raw['invoiceId']),
        invoiceId = _asString(
          raw['invoice_id'] ?? raw['invoiceId'] ?? raw['document_number'],
        ),
        dateDisplay = _formatDate(
          raw['date'] ?? raw['created_at'] ?? raw['date_time'],
        ),
        type = (raw['type'] ?? raw['row_type'] ?? raw['kind'] ?? 'order')
            .toString()
            .trim()
            .toLowerCase(),
        amount = parseAmountFromApi(
          raw['due_amount'] ??
              raw['amount'] ??
              raw['total'] ??
              raw['grand_total'] ??
              0,
        ),
        total = parseAmountFromApi(raw['total'] ?? raw['grand_total'] ?? 0),
        description = _resolveDescription(raw);

  final Map<String, dynamic> raw;
  final String id;
  final String invoiceId;
  final String dateDisplay;
  final String type;
  final int amount;
  final int total;
  final String description;

  String get typeLabel {
    switch (type) {
      case 'order':
        return 'Kirim';
      case 'order_due_payment':
        return "Qarz to'lovi";
      case 'bulk_due_payment':
        return "Umumiy to'lov";
      case 'loan':
        return "Qo'lda qarz";
      case 'payment':
        return "Jurnal to'lovi";
      default:
        return type.isEmpty ? 'Yozuv' : type;
    }
  }

  String get title {
    if (invoiceId.isNotEmpty &&
        invoiceId != '—' &&
        !invoiceId.startsWith('__standalone_debt__')) {
      return invoiceId;
    }
    if (description.isNotEmpty && description != '—') return description;
    return typeLabel;
  }

  bool get isOrder => type == 'order' || type.isEmpty && orderId != null;

  int? get orderId {
    if (type == 'loan' ||
        type == 'payment' ||
        type == 'bulk_due_payment' ||
        type == 'order_due_payment') {
      return null;
    }
    final rawId = raw['id'] ?? raw['order_id'] ?? raw['orderId'];
    if (rawId is int) return rawId;
    return int.tryParse(rawId?.toString() ?? '');
  }

  int? get debtId {
    final fromField =
        raw['standalone_debt_id'] ?? raw['debt_id'] ?? raw['supplier_debt_id'];
    if (fromField is int) return fromField;
    final parsed = int.tryParse(fromField?.toString() ?? '');
    if (parsed != null) return parsed;
    if (type == 'loan' || type == 'payment') {
      final id = raw['id'];
      if (id is int) return id;
      final s = id?.toString() ?? '';
      final n = int.tryParse(s);
      if (n != null) return n;
      final match = RegExp(r'(\d+)$').firstMatch(s);
      return match != null ? int.tryParse(match.group(1)!) : null;
    }
    return null;
  }

  String? get bulkGroupId {
    final v = raw['bulk_group_id'] ?? raw['bulkGroupId'];
    final s = v?.toString().trim() ?? '';
    if (s.isNotEmpty && s != 'null') return s;
    final desc = description;
    final match = RegExp(r'BULK_GROUP:([0-9a-fA-F-]{36})').firstMatch(desc);
    return match?.group(1);
  }

  bool get canOpenCheck => isOrder && orderId != null;

  bool get canDeleteJournal =>
      (type == 'loan' || type == 'payment') && debtId != null;

  bool get canDeleteBulk =>
      type == 'bulk_due_payment' && (bulkGroupId ?? '').isNotEmpty;

  static List<SupplierDeliveryRow> listFromResponse(Map<String, dynamic> res) {
    final raw = res['datarows'] ?? res['data'] ?? res['orders'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => SupplierDeliveryRow(Map<String, dynamic>.from(e)))
        .toList();
  }

  static String _resolveDescription(Map<String, dynamic> m) {
    final desc =
        (m['description'] ?? m['note'] ?? m['comment'] ?? m['title'] ?? '')
            .toString()
            .trim();
    return desc.isEmpty ? '—' : desc;
  }

  static String _asString(dynamic v) {
    final s = v?.toString().trim() ?? '';
    return s.isEmpty || s == 'null' ? '—' : s;
  }

  static String _formatDate(dynamic raw) {
    if (raw == null) return '—';
    final s = raw.toString().trim();
    if (s.isEmpty) return '—';
    try {
      final dt = DateTime.parse(s);
      final local = dt.isUtc ? dt.toLocal() : dt;
      return '${local.year}-'
          '${local.month.toString().padLeft(2, '0')}-'
          '${local.day.toString().padLeft(2, '0')}';
    } catch (_) {
      if (s.length >= 10) return s.substring(0, 10);
      return s;
    }
  }
}
