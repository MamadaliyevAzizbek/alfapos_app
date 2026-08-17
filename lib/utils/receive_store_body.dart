import '../models/receive_cart_item.dart';
import 'receive_payment_types.dart';

/// POST /receives/store body (web confirmReceiving).
class ReceiveStoreBody {
  ReceiveStoreBody._();

  static Map<String, dynamic> build({
    required int supplierId,
    required List<ReceiveCartItem> cart,
    required Map<String, dynamic> paymentType,
    required int grandTotalUzs,
    required String date,
    String? time,
    String? salesNote,
    int? editOrderId,
    String? editReason,
    double usdRate = 1,
  }) {
    final cartApi = cart.map((item) {
      final purchase = item.unitPurchaseInUzs(usdRate: usdRate);
      final wholesale = item.unitWholesaleInUzs(usdRate: usdRate);
      final sell = item.unitSellInUzs(usdRate: usdRate);
      final lineTotal = (purchase * item.quantity).round();
      final productId = int.tryParse(item.product.id) ?? 0;
      return {
        'productID': productId,
        'variantID': item.product.variantId ?? 1,
        'productTitle': item.product.name,
        'variantTitle': 'default_variant',
        'quantity': item.quantity,
        'price': purchase,
        'purchase_price': purchase,
        // API: store body faqat so‘m (kurs bo‘yicha aylantirilgan).
        'price_currency': 'uzs',
        'wholesale_price': wholesale,
        'selling_price': sell,
        'calculatedPrice': lineTotal,
        'orderType': 'receiving',
        'taxID': null,
        'productTaxPercentage': 0,
        'discount': null,
        'cartItemNote': '',
      };
    }).toList();

    final payId = ReceivePaymentTypes.idOf(paymentType) ?? 1;
    final payName = ReceivePaymentTypes.labelOf(paymentType);
    final payType = ReceivePaymentTypes.typeOf(paymentType);
    final nowIso = DateTime.now().toUtc().toIso8601String();

    return {
      'orderType': 'receiving',
      'salesOrReceivingType': 'supplier',
      'status': 'done',
      'supplier': {'id': supplierId},
      'customer': null,
      'subTotal': grandTotalUzs,
      'grandTotal': grandTotalUzs,
      'tax': 0,
      'discount': null,
      'profit': 0,
      'dueAmount': 0,
      'date': date,
      if (time != null) 'time': time,
      if (salesNote != null && salesNote.isNotEmpty) 'salesNote': salesNote,
      if (editOrderId != null) 'editOrderId': editOrderId,
      if (editReason != null && editReason.isNotEmpty) 'editReason': editReason,
      'cart': cartApi,
      'payments': [
        {
          'paymentID': payId,
          'paymentName': payName,
          'paymentType': payType,
          'paid': grandTotalUzs,
          'exchange': 0,
          'is_active': 1,
          'options': <String, dynamic>{},
          'PaymentTime': nowIso,
        },
      ],
    };
  }

  static String buildSalesNote({String? comment, int? deliveryCostUzs}) {
    final parts = <String>[];
    if (comment != null && comment.trim().isNotEmpty) parts.add(comment.trim());
    if (deliveryCostUzs != null && deliveryCostUzs > 0) {
      parts.add("Kelish xarajati (so'm): $deliveryCostUzs");
    }
    return parts.join('\n');
  }
}
