import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/auth_storage.dart';
import '../models/receive_cart_item.dart';
import '../providers/receive_session_provider.dart';

/// Web localStorage: alfapos_receiving_drafts_v1_{userId}_{branchId}
class ReceiveDraftStorage {
  ReceiveDraftStorage._();

  static Future<String> _userKey() async {
    final email = (await SharedPreferences.getInstance()).getString('alfapos_login_email');
    if (email != null && email.isNotEmpty) return email;
    return await getCompanyId() ?? 'default';
  }

  static Future<String> _draftsListKey(int branchId) async {
    final user = await _userKey();
    return 'alfapos_receiving_drafts_v1_${user}_$branchId';
  }

  static Future<List<ReceiveDraft>> loadDrafts(int branchId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(await _draftsListKey(branchId));
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map>()
          .map((e) => ReceiveDraft.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveDraft(int branchId, ReceiveDraft draft) async {
    final drafts = await loadDrafts(branchId);
    drafts.removeWhere((d) => d.id == draft.id);
    drafts.insert(0, draft);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      await _draftsListKey(branchId),
      jsonEncode(drafts.map((d) => d.toJson()).toList()),
    );
  }

  /// Joriy kirim savatini qoralama sifatida saqlash (web localStorage).
  static Future<void> saveFromSession(ReceiveSessionProvider session) async {
    if (session.cart.isEmpty) {
      throw StateError('Savat bo\'sh');
    }
    final branch = session.branchId ?? 1;
    final draft = ReceiveDraft(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      selectedSupplierId: session.selectedSupplier?.id,
      selectedPaymentTypeId: session.selectedPaymentType != null
          ? int.tryParse((session.selectedPaymentType!['id'] ?? '').toString())
          : null,
      selectedDate:
          '${session.selectedDate.year}-${session.selectedDate.month.toString().padLeft(2, '0')}-${session.selectedDate.day.toString().padLeft(2, '0')}',
      comment: session.comment,
      receivingDeliveryCost: session.deliveryCostUzs,
      cartItems: session.cart.map((e) => e.toDraftJson()).toList(),
      savedAt: DateTime.now().toIso8601String(),
    );
    await saveDraft(branch, draft);
  }

  static Future<void> deleteDraft(int branchId, String draftId) async {
    final drafts = await loadDrafts(branchId);
    drafts.removeWhere((d) => d.id == draftId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      await _draftsListKey(branchId),
      jsonEncode(drafts.map((d) => d.toJson()).toList()),
    );
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

  const ReceiveDraft({
    required this.id,
    this.selectedSupplierId,
    this.selectedPaymentTypeId,
    required this.selectedDate,
    this.comment = '',
    this.receivingDeliveryCost = 0,
    this.cartItems = const [],
    required this.savedAt,
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
      };

  factory ReceiveDraft.fromJson(Map<String, dynamic> j) => ReceiveDraft(
        id: j['id']?.toString() ?? '',
        selectedSupplierId: j['selectedSupplierId'] as int?,
        selectedPaymentTypeId: j['selectedPaymentTypeId'] as int?,
        selectedDate: j['selectedDate']?.toString() ?? '',
        comment: j['comment']?.toString() ?? '',
        receivingDeliveryCost: j['receivingDeliveryCost'] as int? ?? 0,
        cartItems: (j['cartItems'] as List<dynamic>?)
                ?.whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList() ??
            [],
        savedAt: j['savedAt']?.toString() ?? '',
      );
}

/// Savatni qoralamaga serializatsiya (product id + miqdor/narxlar).
extension ReceiveCartItemDraft on ReceiveCartItem {
  Map<String, dynamic> toDraftJson() => {
        'productId': product.id,
        'variantId': product.variantId,
        'name': product.name,
        'quantity': quantity,
        'purchasePriceUzs': purchasePriceUzs,
        'sellPriceUzs': sellPriceUzs,
        'purchaseCurrency': purchaseCurrency,
        'sellCurrency': sellCurrency,
      };
}
