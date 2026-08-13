import 'kitchen_status.dart';

class TvQueueOrder {
  const TvQueueOrder({
    required this.orderId,
    this.invoiceId,
    this.kitchenStatus,
    this.queueNumber,
    this.tableName,
    this.customerName,
    this.grandTotal,
    this.date,
  });

  final int orderId;
  final String? invoiceId;
  final KitchenStatus? kitchenStatus;
  final int? queueNumber;
  final String? tableName;
  final String? customerName;
  final int? grandTotal;
  final String? date;

  int? get displayNumber => queueNumber;
}

class TvOrdersSnapshot {
  const TvOrdersSnapshot({
    this.branchId,
    this.branchName,
    this.serverTime,
    this.orders = const [],
  });

  final int? branchId;
  final String? branchName;
  final String? serverTime;
  final List<TvQueueOrder> orders;

  List<TvQueueOrder> get preparing => orders
      .where((o) => o.kitchenStatus == KitchenStatus.preparing && o.queueNumber != null)
      .toList();

  List<TvQueueOrder> get ready => orders
      .where((o) => o.kitchenStatus == KitchenStatus.ready && o.queueNumber != null)
      .toList();
}

/// GET /sales/tv-orders javobi.
class TvOrdersResponse {
  TvOrdersResponse._();

  static TvOrdersSnapshot parse(Map<String, dynamic> res) {
    final data = res['data'];
    final root = data is Map ? {...res, ...Map<String, dynamic>.from(data)} : res;
    final rawOrders = root['orders'] ?? root['tv_orders'] ?? root['tvOrders'];
    final orders = <TvQueueOrder>[];
    if (rawOrders is List) {
      for (final row in rawOrders) {
        if (row is! Map) continue;
        final order = _parseOrder(Map<String, dynamic>.from(row));
        if (order != null) orders.add(order);
      }
    }
    return TvOrdersSnapshot(
      branchId: _int(root['branch_id'] ?? root['branchId'] ?? root['branchID']),
      branchName: _str(root['branch_name'] ?? root['branchName']),
      serverTime: _str(root['server_time'] ?? root['serverTime']),
      orders: orders,
    );
  }

  static TvQueueOrder? _parseOrder(Map<String, dynamic> m) {
    final orderId = _int(m['orderID'] ?? m['order_id'] ?? m['orderId'] ?? m['id']);
    if (orderId == null || orderId <= 0) return null;
    return TvQueueOrder(
      orderId: orderId,
      invoiceId: _str(m['invoiceId'] ?? m['invoice_id']),
      kitchenStatus: KitchenStatus.tryParse(m['kitchenStatus'] ?? m['kitchen_status']),
      queueNumber: _int(m['queueNumber'] ?? m['queue_number'] ?? m['checkNumber'] ?? m['check_number']),
      tableName: _str(m['tableName'] ?? m['table_name']),
      customerName: _str(m['customerName'] ?? m['customer_name']),
      grandTotal: _int(m['grandTotal'] ?? m['grand_total']),
      date: _str(m['date']),
    );
  }

  static int? _int(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString().trim());
  }

  static String? _str(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }
}
