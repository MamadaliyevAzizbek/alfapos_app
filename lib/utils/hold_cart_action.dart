import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/app_notify.dart';
import '../models/cart_item.dart';
import '../providers/cart_provider.dart';
import '../providers/sales_session_provider.dart';

/// Savatni pauza (hold) qilish — desktop «To'xtatish» va mobil to'lov ekrani.
class HoldCartAction {
  HoldCartAction._();

  static Future<bool> savePausedCart({
    required BuildContext context,
    required List<CartItem> cartItems,
    required int subTotal,
    required int grandTotal,
    int? customerId,
    int? orderId,
    String? invoiceId,
    int discountPercent = 0,
    bool clearLocalCart = true,
  }) async {
    final sales = SalesSessionProvider.instance;
    if (sales.holdCartInFlight) {
      AppNotify.info(context, 'Buyurtma saqlanmoqda, kuting...');
      return false;
    }
    if (cartItems.isEmpty) {
      AppNotify.info(context, 'Savat bo\'sh');
      return false;
    }

    sales.setCartDiscountPercent(discountPercent);

    try {
      final res = await sales.holdCart(
        cartItems: cartItems,
        subTotal: subTotal,
        grandTotal: grandTotal,
        customerId: customerId,
        orderId: orderId,
        invoiceId: invoiceId,
      );
      if (res == null) return false;

      var newOrderId = orderId;
      final oid = res['orderID'] ?? res['order_id'] ?? res['id'];
      if (oid != null) {
        newOrderId = oid is int ? oid : int.tryParse(oid.toString());
      }
      if (orderId != null && newOrderId != null && newOrderId != orderId) {
        try {
          await sales.cancelHoldOrder({
            'orderID': orderId,
            'invoice_id': invoiceId ?? '',
          });
        } catch (_) {}
      }

      if (clearLocalCart) CartProvider.instance.clear();
      if (context.mounted) {
        AppNotify.success(
          context,
          orderId != null ? 'Buyurtma yangilandi' : 'Buyurtma saqlandi',
        );
      }
      return true;
    } on ApiException catch (e) {
      if (context.mounted) {
        final code = e.statusCode;
        AppNotify.error(
          context,
          code != null ? 'Pauza saqlanmadi ($code): ${e.message}' : 'Pauza saqlanmadi: ${e.message}',
        );
      }
      return false;
    } catch (e) {
      if (context.mounted) AppNotify.error(context, 'Pauza saqlanmadi: $e');
      return false;
    }
  }
}
