import '../core/input_formatters.dart';

/// Web «Umumiy to'lash» (bulk-due-payment) uchun yordamchi funksiyalar.
class CustomerBulkPayment {
  CustomerBulkPayment._();

  /// GET due-orders javobidan jami qarz (standalone_debt ikki marta qo'shilmasin).
  static num totalDueFromDueOrdersResponse(Map<String, dynamic> res) {
    final orders = res['orders'] as List<dynamic>? ?? [];
    var sum = 0.0;
    var hasStandaloneInOrders = false;
    for (final o in orders) {
      if (o is! Map) continue;
      final m = Map<String, dynamic>.from(o);
      if (m['is_standalone_debt'] == true) hasStandaloneInOrders = true;
      sum += parseAmountFromApi(m['due_amount'] ?? 0).toDouble();
    }
    if (!hasStandaloneInOrders) {
      final standalone = res['standalone_debt'];
      if (standalone != null) {
        sum += parseAmountFromApi(standalone).toDouble();
      }
    }
    return sum;
  }

  static int dueOrdersCount(Map<String, dynamic> res) {
    final orders = res['orders'] as List<dynamic>? ?? [];
    return orders.whereType<Map>().length;
  }

  /// API javobidan to'lov turlari ro'yxati.
  static List<Map<String, dynamic>> parsePaymentTypesResponse(
      Map<String, dynamic> res) {
    final raw = res['data'] ?? res['payment_types'] ?? res['paymentTypes'];
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .where((e) => (e['id'] ?? '').toString().isNotEmpty)
        .toList();
  }

  /// Umumiy to'lov dropdown: credit / supplier_balance chiqariladi; customer_balance alohida.
  static bool isExcludedBulkPaymentType(Map<String, dynamic> e) {
    final type =
        (e['type'] ?? e['payment_type'] ?? '').toString().toLowerCase();
    final name = (e['name'] ?? e['title'] ?? e['payment_method'] ?? '')
        .toString()
        .toLowerCase();
    if (type == 'credit' ||
        type == 'supplier_balance' ||
        type == 'customer_balance') return true;
    if (name.contains('qarz') && type == 'credit') return true;
    if (name.contains('supplier') && name.contains('balans')) return true;
    if (name.contains('mijoz') && name.contains('balans')) return true;
    return false;
  }

  static String paymentTypeLabel(Map<String, dynamic> e) {
    return (e['name'] ?? e['title'] ?? e['payment_method'] ?? e['id'])
        .toString();
  }

  static int? paymentTypeId(Map<String, dynamic> e) {
    final raw = e['id'] ?? e['paymentID'] ?? e['payment_type_id'];
    if (raw is int) return raw;
    return int.tryParse(raw?.toString() ?? '');
  }
}

/// Dropdown qiymati: oddiy to'lov turi ID yoki mijoz balansi.
sealed class BulkDuePaymentMethod {
  const BulkDuePaymentMethod();

  Object get apiValue;
  String get label;
}

class BulkDuePaymentMethodId extends BulkDuePaymentMethod {
  final int id;
  final String displayName;

  const BulkDuePaymentMethodId(this.id, this.displayName);

  @override
  Object get apiValue => id;

  @override
  String get label => displayName;
}

class BulkDuePaymentMethodCustomerBalance extends BulkDuePaymentMethod {
  const BulkDuePaymentMethodCustomerBalance();

  @override
  Object get apiValue => 'customer_balance';

  @override
  String get label => 'Mijoz balansidan';
}

class BulkDuePaymentMethodSupplierBalance extends BulkDuePaymentMethod {
  const BulkDuePaymentMethodSupplierBalance();

  @override
  Object get apiValue => 'supplier_balance';

  @override
  String get label => 'Taminotchi balansidan';
}
