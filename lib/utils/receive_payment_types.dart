/// Kirim to'lov turlari filtri (web ReceivingComponent).
class ReceivePaymentTypes {
  ReceivePaymentTypes._();

  static List<Map<String, dynamic>> parseAndFilter(Map<String, dynamic> res) {
    final raw = res['data'] ?? res['payment_types'] ?? res['paymentTypes'];
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .where(isAllowedForReceiving)
        .toList();
  }

  static bool isAllowedForReceiving(Map<String, dynamic> e) {
    final status = e['status'];
    if (status == 0 || status == '0' || status == false) return false;
    final type = (e['type'] ?? e['payment_type'] ?? '').toString().toLowerCase();
    if (type == 'customer_balance') return false;
    return true;
  }

  static int? idOf(Map<String, dynamic> e) {
    final raw = e['id'] ?? e['paymentID'] ?? e['payment_type_id'];
    if (raw is int) return raw;
    return int.tryParse(raw?.toString() ?? '');
  }

  static String labelOf(Map<String, dynamic> e) {
    return (e['name'] ?? e['title'] ?? e['payment_method'] ?? idOf(e)).toString();
  }

  static String typeOf(Map<String, dynamic> e) {
    return (e['type'] ?? e['payment_type'] ?? 'cash').toString();
  }
}
