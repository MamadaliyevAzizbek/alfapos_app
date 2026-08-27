import 'company_cache_store.dart';
import '../core/input_formatters.dart';

/// Sotilgan cheklar — kompaniya bo‘yicha lokal kesh (429 / offline uchun).
class SoldReceiptCache {
  SoldReceiptCache._();

  static const maxEntries = 200;
  static const maxAge = Duration(days: 35);

  static Future<List<Map<String, dynamic>>> _readEntries() async {
    final decoded = await CompanyCacheStore.readJson(CompanyCacheStore.soldReceipts);
    if (decoded is! Map) return [];
    final raw = decoded['entries'];
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  static Future<void> _writeEntries(List<Map<String, dynamic>> entries) async {
    await CompanyCacheStore.writeJson(CompanyCacheStore.soldReceipts, {
      'entries': entries,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  static List<Map<String, dynamic>> _evict(List<Map<String, dynamic>> entries) {
    final now = DateTime.now();
    final kept = entries.where((e) {
      final savedAt = DateTime.tryParse((e['savedAt'] ?? '').toString());
      if (savedAt == null) return true;
      return now.difference(savedAt) <= maxAge;
    }).toList();
    kept.sort((a, b) {
      final aa = DateTime.tryParse((a['savedAt'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final bb = DateTime.tryParse((b['savedAt'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return bb.compareTo(aa);
    });
    if (kept.length <= maxEntries) return kept;
    return kept.sublist(0, maxEntries);
  }

  /// Sotuv muvaffaqiyatli bo‘lgach chaqiriladi.
  static Future<void> save({
    required int orderId,
    required String invoiceId,
    required Map<String, dynamic> sale,
    required Map<String, dynamic> invoiceDetail,
  }) async {
    if (orderId <= 0) return;
    final inv = invoiceId.trim().isEmpty ? 'POS$orderId' : invoiceId.trim();
    final entry = <String, dynamic>{
      'orderId': orderId,
      'invoiceId': inv.startsWith('POS') ? inv : 'POS$inv',
      'savedAt': DateTime.now().toIso8601String(),
      'sale': Map<String, dynamic>.from(sale),
      'invoiceDetail': Map<String, dynamic>.from(invoiceDetail),
    };

    final entries = await _readEntries();
    entries.removeWhere((e) {
      final oid = _int(e['orderId'] ?? e['order_id']);
      final iid = (e['invoiceId'] ?? e['invoice_id'] ?? '').toString();
      return oid == orderId ||
          (iid.isNotEmpty &&
              iid.toLowerCase() == entry['invoiceId'].toString().toLowerCase());
    });
    entries.insert(0, entry);
    await _writeEntries(_evict(entries));
  }

  /// API dan kelgan batafsilni ham lokalga yozish (boshqa qurilma cheklari).
  static Future<void> saveFromApi({
    required int orderId,
    required Map<String, dynamic> sale,
    required Map<String, dynamic> invoiceDetail,
  }) async {
    if (orderId <= 0) return;
    if (!_detailHasProducts(invoiceDetail)) return;
    final inv = (sale['invoice_id'] ?? sale['invoiceId'] ?? 'POS$orderId')
        .toString()
        .trim();
    await save(
      orderId: orderId,
      invoiceId: inv,
      sale: sale,
      invoiceDetail: invoiceDetail,
    );
  }

  static Future<Map<String, dynamic>?> getDetail(int orderId) async {
    final entry = await _findByOrderId(orderId);
    if (entry == null) return null;
    final detail = entry['invoiceDetail'];
    if (detail is Map) return Map<String, dynamic>.from(detail);
    return null;
  }

  static Future<Map<String, dynamic>?> getSale(int orderId) async {
    final entry = await _findByOrderId(orderId);
    if (entry == null) return null;
    final sale = entry['sale'];
    if (sale is Map) return Map<String, dynamic>.from(sale);
    return null;
  }

  static Future<Map<String, dynamic>?> _findByOrderId(int orderId) async {
    final entries = await _readEntries();
    for (final e in entries) {
      if (_int(e['orderId'] ?? e['order_id']) == orderId) return e;
    }
    return null;
  }

  /// Tranzaksiyalar ro‘yxatiga lokal cheklarni qo‘shish (API ustun, lokal zaxira).
  static Future<List<Map<String, dynamic>>> mergeIntoSalesList(
    List<Map<String, dynamic>> apiRows,
  ) async {
    final entries = _evict(await _readEntries());
    if (entries.isEmpty) return apiRows;

    final byId = <int, Map<String, dynamic>>{};
    final byInvoice = <String, Map<String, dynamic>>{};
    for (final row in apiRows) {
      final id = getOrderIdFromSale(row);
      if (id != null) byId[id] = row;
      final inv = (row['invoice_id'] ?? row['invoiceId'] ?? '').toString().trim().toLowerCase();
      if (inv.isNotEmpty) byInvoice[inv] = row;
    }

    final merged = <Map<String, dynamic>>[...apiRows];
    for (final e in entries) {
      final oid = _int(e['orderId'] ?? e['order_id']);
      final inv = (e['invoiceId'] ?? e['invoice_id'] ?? '').toString().trim();
      final invKey = inv.toLowerCase();
      if (oid != null && byId.containsKey(oid)) continue;
      if (invKey.isNotEmpty && byInvoice.containsKey(invKey)) continue;
      final sale = e['sale'];
      if (sale is! Map) continue;
      final row = Map<String, dynamic>.from(sale);
      row['_localCached'] = true;
      merged.insert(0, row);
      if (oid != null) byId[oid] = row;
      if (invKey.isNotEmpty) byInvoice[invKey] = row;
    }
    return merged;
  }

  static Future<List<Map<String, dynamic>>> listSalesOnly() async {
    final entries = _evict(await _readEntries());
    final out = <Map<String, dynamic>>[];
    for (final e in entries) {
      final sale = e['sale'];
      if (sale is! Map) continue;
      final row = Map<String, dynamic>.from(sale);
      row['_localCached'] = true;
      out.add(row);
    }
    return out;
  }

  static bool _detailHasProducts(Map<String, dynamic> detail) {
    final rows = detail['datarows'] ?? detail['data'] ?? detail['items'];
    if (rows is! List) return false;
    for (final r in rows) {
      if (r is! Map) continue;
      final m = Map<String, dynamic>.from(r);
      final title = (m['title'] ?? m['name'] ?? '').toString().trim().toLowerCase();
      if (title.isEmpty) continue;
      const skip = {
        'sub total',
        'tax',
        'total',
        'discount',
        'chegirma',
        'umumiy',
        'umumiy summa',
        'soliq',
      };
      if (skip.contains(title)) continue;
      final hasQty = m.containsKey('quantity') || m.containsKey('qty');
      final hasPrice = m.containsKey('price') || m.containsKey('unit_price');
      if (hasQty || hasPrice) return true;
    }
    return false;
  }

  static int? _int(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString().trim());
  }
}
