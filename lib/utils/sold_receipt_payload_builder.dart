import '../models/cart_item.dart';
import '../providers/clients_provider.dart';

/// Sotuvdan keyin lokal kesh uchun sale row + invoice-details shakli.
class SoldReceiptPayloadBuilder {
  SoldReceiptPayloadBuilder._();

  static Map<String, dynamic> buildSaleRow({
    required int orderId,
    required String invoiceId,
    required num subTotal,
    required num grandTotal,
    required num discountUzs,
    required List<CartItem> items,
    Client? customer,
    String? sellerName,
    DateTime? saleDate,
    int? queueNumber,
    String? tableName,
  }) {
    final inv = invoiceId.trim().isEmpty
        ? 'POS$orderId'
        : (invoiceId.startsWith('POS') ? invoiceId : 'POS$invoiceId');
    final dt = saleDate ?? DateTime.now();
    final dateStr =
        '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';

    final customerId = customer != null ? int.tryParse(customer.id) : null;
    final customerName = (customer?.name ?? '').trim();

    return {
      'id': orderId,
      'order_id': orderId,
      'orderID': orderId,
      'invoice_id': inv,
      'date': dateStr,
      'created_at': dateStr,
      'customer': () {
        if (customerName.isNotEmpty) return customerName;
        if (customerId == null) return null;
        return {
          'id': customerId,
          if ((customer?.phone ?? '').trim().isNotEmpty)
            'phone_number': customer!.phone,
          if ((customer?.address ?? '').trim().isNotEmpty)
            'address': customer!.address,
        };
      }(),
      if (customerId != null) 'customer_id': customerId,
      'created_by': (sellerName ?? '').trim().isEmpty ? 'Sotuvchi' : sellerName!.trim(),
      'item_purchased': items.length,
      'discount': discountUzs,
      'tax': 0,
      'total': grandTotal,
      'grand_total': grandTotal,
      'sub_total': subTotal,
      if (queueNumber != null && queueNumber > 0) 'queueNumber': queueNumber,
      if (tableName != null && tableName.trim().isNotEmpty) 'tableName': tableName.trim(),
      '_localCached': true,
    };
  }

  /// ApiChekDetailScreen / reprint uchun invoice-details ga o‘xshash payload.
  static Map<String, dynamic> buildInvoiceDetail({
    required List<CartItem> items,
    required num subTotal,
    required num grandTotal,
    required num discountUzs,
    required List<Map<String, dynamic>> payments,
  }) {
    final datarows = <Map<String, dynamic>>[];

    for (final item in items) {
      final pricing = item.salesStoreLinePricing;
      final p = item.product;
      datarows.add({
        'title': p.name,
        'productTitle': p.name,
        'productID': int.tryParse(p.id) ?? 0,
        'product_id': int.tryParse(p.id) ?? 0,
        'variantID': p.variantId ?? 1,
        'quantity': item.quantity,
        'qty': item.quantity,
        'price': pricing.catalogUnitPrice,
        'discount': pricing.lineDiscount,
        'total': pricing.lineTotal,
        'calculatedPrice': pricing.lineTotal,
        'unit': p.unit,
        'unit_name': p.unit,
        if (item.sellByPack && p.canSellByPack) 'isPackage': true,
        if (item.sellByPack && p.canSellByPack)
          'unitsPerPackage': p.quantityPerPack,
      });
    }

    datarows.add({'title': 'Sub total', 'total': subTotal});
    datarows.add({'title': 'Tax', 'total': 0});
    if (discountUzs > 0) {
      datarows.add({'title': 'Discount', 'total': discountUzs});
    }
    datarows.add({'title': 'Total', 'total': grandTotal});

    final paymentRows = <Map<String, dynamic>>[];
    for (final p in payments) {
      final name = (p['paymentName'] ??
              p['payment_name'] ??
              p['name'] ??
              p['title'] ??
              p['paymentType'] ??
              'To‘lov')
          .toString()
          .trim();
      final amountRaw = p['paid'] ?? p['total'] ?? p['amount'] ?? 0;
      final amount = amountRaw is num
          ? amountRaw.round()
          : int.tryParse(amountRaw.toString().replaceAll(' ', '').split('.').first) ??
              0;
      if (amount == 0 && name.isEmpty) continue;
      final row = {
        'title': name.isEmpty ? 'To‘lov' : name,
        'total': amount.abs(),
        'paid': amount,
        'amount': amount,
        if (p['paymentID'] != null) 'paymentID': p['paymentID'],
        if (p['paymentType'] != null) 'paymentType': p['paymentType'],
      };
      datarows.add(row);
      paymentRows.add(row);
    }

    return {
      'datarows': datarows,
      'count': datarows.length,
      'payments': paymentRows,
      'sub_total': subTotal,
      'grand_total': grandTotal,
      'total': grandTotal,
      'discount': discountUzs,
      '_localCached': true,
    };
  }
}
