import '../models/receive_cart_item.dart';
import '../providers/receive_session_provider.dart';
import 'api_service.dart';

/// Kirim qoralamalari — `GET/POST/DELETE /api/v1/receives/drafts` (MOBILE_RECEIVES_API_UZ.md §6).
///
/// Filial bo‘yicha umumiy; max 30 ta. Auth + company middleware orqali filial aniqlanadi.
class ReceiveDraftStorage {
  ReceiveDraftStorage._();

  static Future<List<ReceiveDraft>> loadDrafts([int? branchId]) async {
    final res = await ReceivesApi.getDrafts();
    final raw = res['data'] ?? res['drafts'] ?? res['datarows'];
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((e) => ReceiveDraft.fromJson(Map<String, dynamic>.from(e)))
        .where((d) => d.id.isNotEmpty)
        .toList();
  }

  /// Joriy kirim savatini qoralama sifatida saqlash.
  ///
  /// [activeDraftId] bo‘lsa — `POST .../drafts/{id}` (yangilash),
  /// aks holda — `POST .../drafts` (yangi).
  static Future<String> saveFromSession(ReceiveSessionProvider session) async {
    if (session.cart.isEmpty) {
      throw StateError('Savat bo\'sh');
    }
    final body = _bodyFromSession(session);
    final activeId = session.activeDraftId?.trim();
    final Map<String, dynamic> res;
    if (activeId != null && activeId.isNotEmpty) {
      res = await ReceivesApi.updateDraft(activeId, body);
    } else {
      res = await ReceivesApi.saveDraft(body);
    }
    return _extractDraftId(res, fallback: activeId);
  }

  static Future<void> deleteDraft(int branchId, String draftId) async {
    final id = draftId.trim();
    if (id.isEmpty) return;
    await ReceivesApi.deleteDraft(id);
  }

  static Map<String, dynamic> _bodyFromSession(ReceiveSessionProvider session) {
    final date =
        '${session.selectedDate.year}-${session.selectedDate.month.toString().padLeft(2, '0')}-${session.selectedDate.day.toString().padLeft(2, '0')}';
    final paymentId = session.selectedPaymentType != null
        ? int.tryParse((session.selectedPaymentType!['id'] ?? '').toString())
        : null;
    final rate = session.usdExchangeRate;
    return <String, dynamic>{
      'selectedSupplierId': session.selectedSupplier?.id,
      'selectedPaymentTypeId': paymentId,
      'selectedDate': date,
      'comment': session.comment,
      'receivingDeliveryCost': session.deliveryCostUzs,
      'receivingLoadLabel': '',
      'receivingSetupSupplierId': session.selectedSupplier?.id,
      'receivingSetupArrivalDate': date,
      'cartItems': session.cart
          .map((e) => e.toDraftJson(usdRate: rate))
          .toList(),
    };
  }

  static String _extractDraftId(
    Map<String, dynamic> res, {
    String? fallback,
  }) {
    final data = res['data'];
    if (data is Map) {
      final id = data['id']?.toString().trim();
      if (id != null && id.isNotEmpty) return id;
    }
    final top = res['id']?.toString().trim();
    if (top != null && top.isNotEmpty) return top;
    final fb = fallback?.trim();
    if (fb != null && fb.isNotEmpty) return fb;
    throw StateError('Qoralama id qaytmadi');
  }
}

class ReceiveDraft {
  final String id;
  final int? selectedSupplierId;
  final int? selectedPaymentTypeId;
  final String selectedDate;
  final String comment;
  final int receivingDeliveryCost;
  final List<Map<String, dynamic>> cartItems;
  final String savedAt;
  final int? receivingSessionOrderId;
  final List<String> receivingSessionNakladnoyIds;
  final int? createdBy;
  final int? branchId;

  const ReceiveDraft({
    required this.id,
    this.selectedSupplierId,
    this.selectedPaymentTypeId,
    required this.selectedDate,
    this.comment = '',
    this.receivingDeliveryCost = 0,
    this.cartItems = const [],
    required this.savedAt,
    this.receivingSessionOrderId,
    this.receivingSessionNakladnoyIds = const [],
    this.createdBy,
    this.branchId,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'selectedSupplierId': selectedSupplierId,
        'selectedPaymentTypeId': selectedPaymentTypeId,
        'selectedDate': selectedDate,
        'comment': comment,
        'receivingDeliveryCost': receivingDeliveryCost,
        'cartItems': cartItems,
        'savedAt': savedAt,
        if (receivingSessionOrderId != null)
          'receivingSessionOrderId': receivingSessionOrderId,
        if (receivingSessionNakladnoyIds.isNotEmpty)
          'receivingSessionNakladnoyIds': receivingSessionNakladnoyIds,
        if (createdBy != null) 'createdBy': createdBy,
        if (branchId != null) 'branchId': branchId,
      };

  factory ReceiveDraft.fromJson(Map<String, dynamic> j) {
    final nakladnoy = j['receivingSessionNakladnoyIds'];
    return ReceiveDraft(
      id: j['id']?.toString() ?? '',
      selectedSupplierId: _asInt(j['selectedSupplierId']),
      selectedPaymentTypeId: _asInt(j['selectedPaymentTypeId']),
      selectedDate: j['selectedDate']?.toString() ?? '',
      comment: j['comment']?.toString() ?? '',
      receivingDeliveryCost: _asInt(j['receivingDeliveryCost']) ?? 0,
      cartItems: (j['cartItems'] as List<dynamic>?)
              ?.whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList() ??
          [],
      savedAt: j['savedAt']?.toString() ?? '',
      receivingSessionOrderId: _asInt(j['receivingSessionOrderId']),
      receivingSessionNakladnoyIds: nakladnoy is List
          ? nakladnoy.map((e) => e.toString()).toList()
          : const [],
      createdBy: _asInt(j['createdBy']),
      branchId: _asInt(j['branchId']),
    );
  }

  static int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.round();
    return int.tryParse(v.toString());
  }
}

/// Savatni API qoralama formatiga serializatsiya (MOBILE_RECEIVES_API_UZ.md §6).
extension ReceiveCartItemDraft on ReceiveCartItem {
  Map<String, dynamic> toDraftJson({double usdRate = 1}) {
    final purchase = unitPurchaseInUzs(usdRate: usdRate);
    final wholesale = unitWholesaleInUzs(usdRate: usdRate);
    final sell = unitSellInUzs(usdRate: usdRate);
    final qty = quantity;
    final productId = int.tryParse(product.id);
    return <String, dynamic>{
      if (productId != null) 'productID': productId else 'productID': product.id,
      'productTitle': product.name,
      'variantID': product.variantId,
      'price': purchase,
      'sellingPrice': sell,
      'wholesalePrice': wholesale,
      'quantity': qty,
      'total': (purchase * qty).round(),
      'priceCurrency': 'uzs',
    };
  }
}
