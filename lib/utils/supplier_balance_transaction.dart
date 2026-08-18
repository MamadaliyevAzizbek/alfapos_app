import '../core/input_formatters.dart';

/// Taminotchi balans tarixi — POST …/balance-transactions.
class SupplierBalanceTransactionRow {
  SupplierBalanceTransactionRow(this.raw)
      : id = _resolveId(raw),
        signedAmount = _resolveSignedAmount(raw),
        description = _resolveDescription(raw),
        dateDisplay =
            _formatDate(raw['date'] ?? raw['created_at'] ?? raw['date_time']),
        createdBy = _resolveCreatedBy(raw),
        balanceAfter = _resolveBalanceAfter(raw);

  final Map<String, dynamic> raw;
  final int? id;
  final int signedAmount;
  final String description;
  final String dateDisplay;
  final String createdBy;
  final int? balanceAfter;

  static int? _resolveId(Map<String, dynamic> m) {
    for (final key in ['id', 'transaction_id', 'balance_transaction_id']) {
      final v = m[key];
      if (v is int && v > 0) return v;
      final n = int.tryParse(v?.toString() ?? '');
      if (n != null && n > 0) return n;
    }
    return null;
  }

  static int _resolveSignedAmount(Map<String, dynamic> m) {
    final type = (m['type'] ?? m['transaction_type'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    final amount =
        parseAmountFromApi(m['amount'] ?? m['sum'] ?? 0).round().abs();

    if (type == 'add' ||
        type == 'deposit' ||
        type == 'credit' ||
        type == 'income' ||
        type == 'cashback' ||
        type == 'set') {
      return amount;
    }
    if (type == 'subtract' ||
        type == 'used' ||
        type == 'debit' ||
        type == 'payment' ||
        type == 'expense' ||
        type == 'withdraw') {
      return -amount;
    }
    return parseAmountFromApi(m['amount'] ?? 0).round();
  }

  static String _resolveDescription(Map<String, dynamic> m) {
    final desc =
        (m['description'] ?? m['note'] ?? m['comment'] ?? '').toString().trim();
    if (desc.isNotEmpty && !desc.startsWith('lang.')) return desc;

    final type = (m['type'] ?? m['transaction_type'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    switch (type) {
      case 'subtract':
        return 'Balansdan yechildi';
      case 'used':
        return "Balans qarz to'lovi uchun ishlatildi";
      case 'add':
        return "Balans qo'shildi";
      case 'set':
        return "Balans o'rnatildi";
      case 'cashback':
        return 'Cashback';
      default:
        return type.isEmpty ? '—' : type;
    }
  }

  static String _resolveCreatedBy(Map<String, dynamic> m) {
    for (final key in [
      'created_by_name',
      'employee_name',
      'seller_name',
      'user_name',
      'created_by',
      'employee',
      'user',
    ]) {
      final v = m[key];
      if (v is Map) {
        final name = (v['name'] ?? v['full_name'] ?? '').toString().trim();
        if (name.isNotEmpty) return name;
        continue;
      }
      final s = v?.toString().trim() ?? '';
      if (s.isNotEmpty && s != 'null') return s;
    }
    return '—';
  }

  static int? _resolveBalanceAfter(Map<String, dynamic> m) {
    final v = m['balance_after'] ?? m['balanceAfter'];
    if (v == null) return null;
    return parseAmountFromApi(v).round();
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
          '${local.day.toString().padLeft(2, '0')} '
          '${local.hour.toString().padLeft(2, '0')}:'
          '${local.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      if (s.length >= 16) return s.substring(0, 16).replaceFirst('T', ' ');
      return s;
    }
  }

  static String formatSignedAmount(int signed) {
    final abs = formatThousands(signed.abs());
    if (signed < 0) return '-$abs';
    if (signed > 0) return '+$abs';
    return abs;
  }
}
