import '../core/seller_preferences.dart';
import '../providers/cash_register_shift_provider.dart';
import '../services/api_service.dart';

/// Joriy login xodimining sotuvlarini filtrlash (reports/sales `employee` filter).
class CurrentEmployeeSalesFilter {
  CurrentEmployeeSalesFilter._();

  static Future<int?> resolveUserId() async {
    await CashRegisterShiftProvider.instance.ensureCurrentUserId();
    final fromShift = CashRegisterShiftProvider.instance.currentUserId;
    if (fromShift != null && fromShift > 0) return fromShift;
    return getCurrentUserId();
  }

  static List<Map<String, String>> employeeOptionsFromFilterResponse(Map<String, dynamic> res) {
    final data = res['data'] is Map ? Map<String, dynamic>.from(res['data'] as Map) : res;
    final raw = data['employee'];
    if (raw is! List) return const [];
    final out = <Map<String, String>>[];
    for (final e in raw) {
      if (e is! Map) continue;
      final m = Map<String, dynamic>.from(e);
      final value = (m['value'] ?? m['id'] ?? '').toString();
      final label = (m['text'] ?? m['name'] ?? m['label'] ?? value).toString();
      if (value.isEmpty) continue;
      out.add({'value': value, 'label': label});
    }
    return out;
  }

  /// API `filtersData` uchun employee id (user id) yoki null.
  static Future<int?> resolveEmployeeFilterId({List<Map<String, String>>? employeeOptions}) async {
    final userId = await resolveUserId();
    List<Map<String, String>> options = employeeOptions ?? const [];
    if (options.isEmpty) {
      try {
        final filterRes = await ReportsApi.getSalesFilter();
        options = employeeOptionsFromFilterResponse(filterRes);
      } catch (_) {}
    }
    if (userId != null && userId > 0) {
      final idStr = '$userId';
      if (options.isEmpty || options.any((e) => e['value'] == idStr)) return userId;
    }
    final sellerName = (await getSellerName()).trim().toLowerCase();
    if (sellerName.isNotEmpty && sellerName != 'sotuvchi') {
      for (final e in options) {
        final label = (e['label'] ?? '').trim().toLowerCase();
        if (label == sellerName || label.contains(sellerName)) {
          return int.tryParse(e['value'] ?? '');
        }
      }
    }
    return userId;
  }

  static bool saleBelongsToUser(
    Map<String, dynamic> sale, {
    required int? userId,
    String? sellerName,
  }) {
    if (userId != null && userId > 0) {
      for (final key in const [
        'user_id',
        'userId',
        'userID',
        'created_by_id',
        'createdById',
        'employee_id',
        'employeeId',
      ]) {
        final v = sale[key];
        if (v == null) continue;
        final parsed = v is int ? v : int.tryParse(v.toString());
        if (parsed == userId) return true;
      }
    }
    final name = (sellerName ?? '').trim().toLowerCase();
    if (name.isEmpty || name == 'sotuvchi') return false;
    final createdBy = (sale['created_by'] ?? sale['employee'] ?? sale['user_name'] ?? sale['seller'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    if (createdBy.isEmpty) return false;
    return createdBy == name || createdBy.contains(name) || name.contains(createdBy);
  }
}
