import '../core/api_client.dart';

/// POST /sales/store javobi — chek serverda yaratilganini tekshirish.
class SaleStoreResponse {
  SaleStoreResponse._();

  static bool isSuccessFlag(Map<String, dynamic> map) {
    final s = map['success'];
    if (s == false || s == 0) return false;
    if (s is String) {
      final v = s.toLowerCase().trim();
      if (v == 'false' || v == '0' || v == 'no') return false;
    }
    return true;
  }

  /// Chek/order ID — invoice_id yoki order_id ustun.
  static String? extractReceiptId(Map<String, dynamic>? res) {
    if (res == null) return null;
    if (!isSuccessFlag(res)) return null;

    final maps = <Map<String, dynamic>>[res];
    final data = res['data'];
    if (data is Map) maps.add(Map<String, dynamic>.from(data));
    final order = res['order'];
    if (order is Map) maps.add(Map<String, dynamic>.from(order));

    const preferred = ['invoice_id', 'invoiceId', 'order_id', 'orderId', 'orderID'];
    for (final map in maps) {
      for (final k in preferred) {
        final s = _nonEmpty(map[k]);
        if (s != null) return s;
      }
    }

    for (final map in maps) {
      final s = _nonEmpty(map['id']);
      if (s != null && int.tryParse(s) != null) return s;
    }
    return null;
  }

  static int? extractOrderId(Map<String, dynamic>? res) {
    if (res == null) return null;
    final maps = <Map<String, dynamic>>[res];
    final data = res['data'];
    if (data is Map) maps.add(Map<String, dynamic>.from(data));
    final order = res['order'];
    if (order is Map) maps.add(Map<String, dynamic>.from(order));

    const keys = ['order_id', 'orderId', 'orderID', 'id'];
    for (final map in maps) {
      for (final k in keys) {
        final v = map[k];
        if (v == null) continue;
        final n = v is int ? v : int.tryParse(v.toString());
        if (n != null && n > 0) return n;
      }
    }
    return null;
  }

  static String? _nonEmpty(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  static bool isStockQuantityCheckFailed(Map<String, dynamic> res) {
    final v = res['checkAvailableQuantity'];
    return v == true || v == 'true' || v == 1 || v == '1';
  }

  static String stockQuantityErrorMessage(Map<String, dynamic> res) {
    final m = res['message'];
    if (m is List) {
      final parts = m.map((e) => e.toString().trim()).where((s) => s.isNotEmpty);
      if (parts.isNotEmpty) return parts.join('\n');
    }
    if (m is String && m.trim().isNotEmpty) return m.trim();
    return 'Mahsulot omborda yetarli emas';
  }

  static void ensureCreated(Map<String, dynamic> res) {
    if (isStockQuantityCheckFailed(res)) {
      throw ApiException(stockQuantityErrorMessage(res), 422);
    }
    if (!isSuccessFlag(res)) {
      throw ApiException(
        res['message']?.toString() ?? 'Sotuv serverda saqlanmadi',
        422,
      );
    }
    final receiptId = extractReceiptId(res);
    if (receiptId == null || receiptId.isEmpty) {
      throw ApiException(
        'Server chek raqamini qaytarmadi. Sotuv API da saqlanmagan bo‘lishi mumkin.',
        422,
      );
    }
  }
}
