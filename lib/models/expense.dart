/// Bitta xarajat yozuvi (sana, nom, summa)
class Expense {
  final String id;
  final DateTime date;
  final String name;
  final int amountUzs;

  const Expense({
    required this.id,
    required this.date,
    required this.name,
    required this.amountUzs,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String().substring(0, 10),
        'name': name,
        'amountUzs': amountUzs,
      };

  static Expense fromJson(Map<String, dynamic> json) {
    final dateStr = json['date'] as String? ?? '';
    DateTime date = DateTime.now();
    if (dateStr.length >= 10) {
      date = DateTime.tryParse(dateStr) ?? date;
    }
    return Expense(
      id: json['id'] as String? ?? '',
      date: date,
      name: json['name'] as String? ?? '',
      amountUzs: json['amountUzs'] as int? ?? 0,
    );
  }

  static Expense fromApiJson(Map<String, dynamic> json) {
    final id = json['id'];
    final idStr = id is int ? id.toString() : (id is String ? id : '');
    final dateStr = json['date'] as String? ?? json['created_at'] as String? ?? '';
    DateTime date = DateTime.now();
    if (dateStr.length >= 10) {
      final parsed = DateTime.tryParse(dateStr);
      if (parsed != null) {
        final local = parsed.toLocal();
        date = DateTime(local.year, local.month, local.day);
      } else {
        date = DateTime.tryParse(dateStr.substring(0, 10)) ?? date;
      }
    }
    final raw = json['price'] ?? json['amountUzs'] ?? json['amount'] ?? 0;
    final amountUzs = _parseAmount(raw);
    return Expense(
      id: idStr,
      date: date,
      name: json['name'] as String? ?? '',
      amountUzs: amountUzs,
    );
  }

  /// API dan "50000.00" (string) yoki 50000 (int) kelishi mumkin
  static int _parseAmount(dynamic raw) {
    if (raw == null) return 0;
    if (raw is int) return raw;
    if (raw is double) return raw.round();
    final s = raw.toString().trim();
    if (s.isEmpty) return 0;
    final d = double.tryParse(s);
    return d != null ? d.round() : 0;
  }
}
