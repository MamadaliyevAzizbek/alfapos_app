import 'dart:async';

import '../core/api_client.dart';
import '../core/input_formatters.dart';
import '../providers/sales_session_provider.dart';
import '../services/api_service.dart';
import '../services/app_data_sync.dart';
import 'tolovsiz_payment.dart';

/// Chek orqali qaytarish — [SALES_RETURNS_API.md] (web = desktop).
///
/// Qarzli: `POST /sales/store` + `paymentType: "tolovsiz"` (sof `credit` → amend, webga mos emas).
/// To'langan: `POST /sales/return-full-order` (asl naqd/karta nusxasi).
class SalesReturnFlow {
  SalesReturnFlow._();

  /// Chekda qarz qolganmi (qarzli / to'lovsiz sotuv).
  static int saleDueAmount(
    Map<String, dynamic> sale, {
    Map<String, dynamic>? invoiceDetail,
  }) {
    for (final m in [sale, if (invoiceDetail != null) invoiceDetail]) {
      final due = parseAmountFromApi(
        m['due_amount'] ?? m['dueAmount'] ?? m['due_amount_display'] ?? 0,
      );
      if (due > 0) return due;
    }
    return 0;
  }

  static int? customerIdFromSale(
    Map<String, dynamic> sale, {
    Map<String, dynamic>? invoiceDetail,
  }) {
    for (final m in [sale, if (invoiceDetail != null) invoiceDetail]) {
      final direct = m['customer_id'] ?? m['customerId'] ?? m['client_id'];
      final fromDirect = _positiveInt(direct);
      if (fromDirect != null) return fromDirect;

      final customer = m['customer'] ?? m['client'];
      if (customer is Map) {
        final fromMap = _positiveInt(customer['id'] ?? customer['customer_id']);
        if (fromMap != null) return fromMap;
      }
    }
    return null;
  }

  static Map<String, dynamic>? customerPayloadFromSale(
    Map<String, dynamic> sale, {
    Map<String, dynamic>? invoiceDetail,
  }) {
    final id = customerIdFromSale(sale, invoiceDetail: invoiceDetail);
    if (id == null) return null;

    num balance = 0;
    num due = saleDueAmount(sale, invoiceDetail: invoiceDetail).toDouble();
    for (final m in [sale, if (invoiceDetail != null) invoiceDetail]) {
      final customer = m['customer'] ?? m['client'];
      if (customer is Map) {
        balance = parseAmountFromApi(customer['balance'] ?? balance).toDouble();
        final d = parseAmountFromApi(customer['due_amount'] ?? customer['dueAmount'] ?? 0);
        if (d > 0) due = d.toDouble();
      }
      final b = parseAmountFromApi(m['customer_balance'] ?? m['balance'] ?? 0);
      if (b != 0) balance = b.toDouble();
    }
    return {
      'id': id,
      'balance': balance,
      'due_amount': due,
    };
  }

  static String normalizeInvoiceId(String raw, int orderId) {
    final t = raw.trim();
    if (t.isEmpty) return 'POS$orderId';
    if (t.toUpperCase().startsWith('POS')) return t;
    return 'POS$t';
  }

  /// To'liq chek qaytarish — API §4 / §12 / §13.
  static Future<Map<String, dynamic>> returnFullReceipt({
    required Map<String, dynamic> sale,
    Map<String, dynamic>? invoiceDetail,
  }) async {
    final orderId = getOrderIdFromSale(sale);
    if (orderId == null) {
      throw ApiException('Chek ID aniqlanmadi', 400);
    }

    final rawInvoice = (sale['invoice_id'] ??
            sale['invoiceId'] ??
            sale['order_id'] ??
            sale['id'] ??
            '')
        .toString()
        .trim();
    final invoiceId = normalizeInvoiceId(rawInvoice, orderId);
    final due = saleDueAmount(sale, invoiceDetail: invoiceDetail);
    final customer = customerPayloadFromSale(sale, invoiceDetail: invoiceDetail);

    final sess = SalesSessionProvider.instance;
    await sess.ensureTolovsizPaymentReady();

    final tolovsizEnabled = sess.salesTolovsizPaymentEnabled;
    final tolovsizType = _findTolovsizPaymentType(sess.paymentTypes);
    if (due <= 0 || customer == null || !tolovsizEnabled || tolovsizType == null) {
      return SalesApi.returnFullOrder(orderId: orderId, invoiceId: invoiceId);
    }

    try {
      await SalesApi.setReturnsType(salesOrReturnType: 'returns');
    } catch (_) {}

    final cart = await _buildReturnCart(
      orderId: orderId,
      invoiceId: invoiceId,
      sale: sale,
      invoiceDetail: invoiceDetail,
    );
    if (cart.isEmpty) {
      throw ApiException('Qaytarish uchun mahsulot topilmadi', 422);
    }

    final returnAbs = _cartReturnAbs(cart);
    if (returnAbs <= 0) {
      throw ApiException('Qaytarish summasi 0', 422);
    }

    final paymentId = tolovsizType['id'] is int
        ? tolovsizType['id'] as int
        : int.parse(tolovsizType['id'].toString());
    final paymentName = (tolovsizType['name'] ?? "To'lovsiz").toString();

    final body = <String, dynamic>{
      'orderType': 'sales',
      'status': 'done',
      'salesOrReceivingType': 'customer',
      'salesOrReturnType': 'returns',
      'grandTotal': -returnAbs,
      'subTotal': returnAbs,
      'tax': 0,
      'discount': 0,
      'dueAmount': 0,
      'customer': customer,
      'cart': cart,
      'payments': [
        TolovsizPayment.buildStorePaymentRow(
          paymentTypeId: paymentId,
          paymentName: paymentName,
          amount: returnAbs.round(),
          isReturn: true,
        ),
      ],
      'invoiceReturnId': invoiceId,
    };

    sess.syncFromShift();
    if (sess.cashRegisterId != null) {
      body['cashRagisterId'] = sess.cashRegisterId;
      body['isCashRegisterBranch'] = sess.isCashRegisterBranch;
    }
    if (sess.registerLogId != null) {
      body['register_log_id'] = sess.registerLogId;
    }
    if (sess.branchId != null) {
      body['selectedBranchID'] = sess.branchId;
      body['branchId'] = sess.branchId;
      body['currentBranch'] = sess.branchId;
    }

    final res = await SalesApi.storeSale(body);
    unawaited(AppDataSync.afterStockChangingWrite());
    return res;
  }

  static Map<String, dynamic>? _findTolovsizPaymentType(List<Map<String, dynamic>> types) {
    for (final e in types) {
      if (TolovsizPayment.isPaymentType(e) && !TolovsizPayment.isHiddenInSales(e)) {
        return e;
      }
    }
    for (final e in types) {
      if (TolovsizPayment.isPaymentType(e)) return e;
    }
    return null;
  }

  static Future<List<Map<String, dynamic>>> _buildReturnCart({
    required int orderId,
    required String invoiceId,
    required Map<String, dynamic> sale,
    Map<String, dynamic>? invoiceDetail,
  }) async {
    try {
      final res = await SalesApi.getOrderItemsForReturn(orderId: orderId);
      final fromItems = _cartFromOrderItemsForReturn(res, invoiceId: invoiceId, orderId: orderId);
      if (fromItems.isNotEmpty) return fromItems;
    } catch (_) {}

    try {
      final res = await SalesApi.getReturnOrders(orderId: invoiceId);
      final fromOrders = _cartFromReturnOrders(res, invoiceId: invoiceId, orderId: orderId);
      if (fromOrders.isNotEmpty) return fromOrders;
    } catch (_) {}

    return _cartFromInvoiceDetail(
      sale: sale,
      invoiceDetail: invoiceDetail,
      invoiceId: invoiceId,
      orderId: orderId,
    );
  }

  static List<Map<String, dynamic>> _cartFromOrderItemsForReturn(
    Map<String, dynamic> res, {
    required String invoiceId,
    required int orderId,
  }) {
    final raw = res['items'] ?? res['data'] ?? res['cart'];
    if (raw is! List) return const [];
    final out = <Map<String, dynamic>>[];
    for (final row in raw) {
      if (row is! Map) continue;
      final m = Map<String, dynamic>.from(row);
      final canReturn = m['canReturn'];
      if (canReturn == false || canReturn == 0 || canReturn == '0') continue;

      final qty = parseAmountFromApi(
        m['availableQuantity'] ?? m['available_quantity'] ?? m['quantity'] ?? m['qty'] ?? 0,
      );
      if (qty <= 0) continue;

      final productId = _positiveInt(m['productID'] ?? m['product_id'] ?? m['productId']);
      if (productId == null) continue;
      final variantId = _positiveInt(m['variantID'] ?? m['variant_id'] ?? m['variantId']) ?? 1;
      final price = parseAmountFromApi(m['price'] ?? m['unit_price'] ?? m['unitPrice'] ?? 0);
      final lineTotal = price * qty;

      out.add({
        'productID': productId,
        'variantID': variantId,
        'quantity': -qty.abs(),
        'price': price.abs(),
        'orderType': 'sales',
        'invoiceReturnId': invoiceId,
        'returnSourceOrderId': orderId,
        'calculatedPrice': lineTotal.abs(),
        if (m['productTitle'] != null || m['title'] != null)
          'productTitle': (m['productTitle'] ?? m['title']).toString(),
      });
    }
    return out;
  }

  static List<Map<String, dynamic>> _cartFromReturnOrders(
    Map<String, dynamic> res, {
    required String invoiceId,
    required int orderId,
  }) {
    dynamic orders = res['orders'] ?? res['data'] ?? res['cart'] ?? res;
    if (orders is Map) {
      final inner = orders['orders'] ?? orders['cart'] ?? orders['data'];
      if (inner != null) orders = inner;
    }

    final lines = <dynamic>[];
    if (orders is List) {
      for (final o in orders) {
        if (o is Map) {
          final cart = o['cart'];
          if (cart is List) {
            lines.addAll(cart);
          } else if (o.containsKey('productID') || o.containsKey('product_id')) {
            lines.add(o);
          }
        }
      }
    }

    final out = <Map<String, dynamic>>[];
    for (final row in lines) {
      if (row is! Map) continue;
      final m = Map<String, dynamic>.from(row);
      final productId = _positiveInt(m['productID'] ?? m['product_id'] ?? m['productId']);
      if (productId == null) continue;
      final qty = parseAmountFromApi(m['quantity'] ?? m['qty'] ?? 0);
      if (qty == 0) continue;
      final variantId = _positiveInt(m['variantID'] ?? m['variant_id'] ?? m['variantId']) ?? 1;
      final price = parseAmountFromApi(m['price'] ?? m['unit_price'] ?? 0);
      final calc = parseAmountFromApi(m['calculatedPrice'] ?? m['calculated_price'] ?? (price * qty.abs()));

      out.add({
        'productID': productId,
        'variantID': variantId,
        'quantity': -qty.abs(),
        'price': price.abs(),
        'orderType': 'sales',
        'invoiceReturnId': invoiceId,
        'returnSourceOrderId': orderId,
        'calculatedPrice': calc.abs(),
      });
    }
    return out;
  }

  static List<Map<String, dynamic>> _cartFromInvoiceDetail({
    required Map<String, dynamic> sale,
    Map<String, dynamic>? invoiceDetail,
    required String invoiceId,
    required int orderId,
  }) {
    final inv = invoiceDetail ?? const <String, dynamic>{};
    List<dynamic> datarows = inv['datarows'] as List<dynamic>? ??
        inv['items'] as List<dynamic>? ??
        inv['products'] as List<dynamic>? ??
        [];
    if (datarows.isEmpty && inv['data'] is Map) {
      final d = inv['data'] as Map;
      datarows = d['datarows'] as List<dynamic>? ?? d['items'] as List<dynamic>? ?? [];
    }

    final out = <Map<String, dynamic>>[];
    for (final row in datarows) {
      if (row is! Map) continue;
      final m = Map<String, dynamic>.from(row);
      final title = (m['title'] ?? m['name'] ?? '').toString().trim().toLowerCase();
      if (title == 'sub total' ||
          title == 'tax' ||
          title == 'total' ||
          title == 'discount' ||
          title == 'chegirma') {
        continue;
      }
      final hasQty = m.containsKey('quantity') || m.containsKey('qty');
      if (!hasQty) continue;

      final productId = _positiveInt(
        m['productID'] ?? m['product_id'] ?? m['productId'] ?? m['item_id'],
      );
      if (productId == null) continue;
      final qty = parseAmountFromApi(m['quantity'] ?? m['qty'] ?? 0);
      if (qty == 0) continue;
      final variantId = _positiveInt(m['variantID'] ?? m['variant_id'] ?? m['variantId']) ?? 1;
      final price = parseAmountFromApi(m['price'] ?? m['unit_price'] ?? 0);
      final lineTotal = parseAmountFromApi(
        m['total'] ?? m['calculatedPrice'] ?? (price * qty.abs()),
      );

      out.add({
        'productID': productId,
        'variantID': variantId,
        'quantity': -qty.abs(),
        'price': price.abs(),
        'orderType': 'sales',
        'invoiceReturnId': invoiceId,
        'returnSourceOrderId': orderId,
        'calculatedPrice': lineTotal.abs(),
      });
    }

    if (out.isEmpty) {
      // oxirgi chora: bitta qator jami summa bilan (server infer qilishi mumkin)
      final total = parseAmountFromApi(sale['total'] ?? inv['total'] ?? inv['grand_total'] ?? 0).abs();
      if (total > 0) {
        out.add({
          'productID': 0,
          'variantID': 1,
          'quantity': -1,
          'price': total,
          'orderType': 'sales',
          'invoiceReturnId': invoiceId,
          'returnSourceOrderId': orderId,
          'calculatedPrice': total,
        });
      }
    }
    return out.where((e) => (e['productID'] as int) > 0).toList();
  }

  static num _cartReturnAbs(List<Map<String, dynamic>> cart) {
    num sum = 0;
    for (final line in cart) {
      sum += parseAmountFromApi(line['calculatedPrice']).abs();
    }
    return sum;
  }

  static int? _positiveInt(dynamic v) {
    if (v == null) return null;
    final n = v is int ? v : int.tryParse(v.toString());
    if (n == null || n <= 0) return null;
    return n;
  }
}
