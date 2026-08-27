import '../providers/clients_provider.dart';
import '../services/api_service.dart';
import 'sales_return_flow.dart';

/// Savdo/chek qatoridan mijoz ismini chiqarish (reports/sales, hold, reprint).
class SaleCustomerLabel {
  SaleCustomerLabel._();

  static const _genericNames = {
    'mijoz',
    'customer',
    'client',
    'walk-in',
    'walk in',
    'наличные',
    'гость',
  };

  /// Jadval/chek uchun ko‘rsatiladigan ism. [resolvedById] — oldindan yuklangan ismlar.
  static String displayName(
    Map<String, dynamic> sale, {
    Map<String, String>? resolvedById,
  }) {
    final fromRow = fromSaleFields(sale);
    if (isUsableName(fromRow)) return fromRow;

    final id = SalesReturnFlow.customerIdFromSale(sale);
    if (id != null) {
      final key = id.toString();
      final fromMap = (resolvedById?[key] ?? '').trim();
      if (isUsableName(fromMap)) return fromMap;

      final cached = ClientsProvider.instance.getById(key);
      final fromCache = (cached?.name ?? '').trim();
      if (isUsableName(fromCache)) return fromCache;
    }

    if (fromRow.isNotEmpty) return fromRow;
    return '—';
  }

  static String fromSaleFields(Map<String, dynamic> sale) {
    for (final key in [
      'customer_name',
      'customerName',
      'client_name',
      'clientName',
      'contact_name',
      'buyer_name',
    ]) {
      final v = (sale[key] ?? '').toString().trim();
      if (v.isNotEmpty) return v;
    }

    final customer = sale['customer'] ?? sale['client'] ?? sale['contact'];
    if (customer is String && customer.trim().isNotEmpty) {
      return customer.trim();
    }
    if (customer is Map) {
      final m = Map<String, dynamic>.from(customer);
      final name = (m['name'] ?? m['full_name'] ?? m['fullName'] ?? '')
          .toString()
          .trim();
      if (name.isNotEmpty) return name;
      final first = (m['first_name'] ?? m['firstName'] ?? '').toString().trim();
      final last = (m['last_name'] ?? m['lastName'] ?? '').toString().trim();
      final joined = '$first $last'.trim();
      if (joined.isNotEmpty) return joined;
      final company = (m['company'] ?? '').toString().trim();
      if (company.isNotEmpty) return company;
    }
    return '';
  }

  static bool isUsableName(String? name) {
    final t = (name ?? '').trim();
    if (t.isEmpty || t == '—' || t == '-') return false;
    return !_genericNames.contains(t.toLowerCase());
  }

  /// Ro‘yxatdagi `customer_id` lar bo‘yicha ismlarni yuklash (jadval uchun).
  static Future<Map<String, String>> resolveNamesForSales(
    List<Map<String, dynamic>> sales,
  ) async {
    try {
      await ClientsProvider.instance.warmFromCache();
    } catch (_) {}

    final out = <String, String>{};
    final missing = <int>{};

    for (final sale in sales) {
      final id = SalesReturnFlow.customerIdFromSale(sale);
      if (id == null) continue;
      final key = id.toString();
      if (out.containsKey(key)) continue;

      final fromRow = fromSaleFields(sale);
      if (isUsableName(fromRow)) {
        out[key] = fromRow;
        continue;
      }

      final cached = ClientsProvider.instance.getById(key);
      final fromCache = (cached?.name ?? '').trim();
      if (isUsableName(fromCache)) {
        out[key] = fromCache;
      } else {
        missing.add(id);
      }
    }

    if (missing.isEmpty) return out;

    final ids = missing.toList();
    const chunk = 8;
    for (var i = 0; i < ids.length; i += chunk) {
      final slice = ids.sublist(i, i + chunk > ids.length ? ids.length : i + chunk);
      await Future.wait(slice.map((id) async {
        try {
          final res = await ContactsApi.getCustomer(id);
          final raw = res['customer'] ?? res['data'] ?? res;
          if (raw is! Map) return;
          final client = Client.fromApiJson(Map<String, dynamic>.from(raw));
          final name = client.name.trim();
          if (isUsableName(name)) out[id.toString()] = name;
        } catch (_) {}
      }));
    }
    return out;
  }
}
