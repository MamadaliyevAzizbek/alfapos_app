import 'package:flutter/foundation.dart';

import '../core/input_formatters.dart';
import 'cash_register_utils.dart';
import 'kitchen_status.dart';

/// GET /sales/hold-orders javobini xavfsiz parse qilish.
/// Noto'g'ri `orders` / umumiy `data` dan boshqa ro'yxatlarni aralashtirmaydi.
class HoldOrdersResponse {
  HoldOrdersResponse._();

  static List<Map<String, dynamic>> parseList(Map<String, dynamic> res) {
    final list = _extractList(res);
    final holds = <Map<String, dynamic>>[];
    for (final row in list) {
      if (row is! Map) continue;
      final m = Map<String, dynamic>.from(row);
      if (_isHoldRow(m)) holds.add(m);
    }
    assert(() {
      if (kDebugMode) {
        debugPrint(
          '[hold-orders] keys=${res.keys.toList()} parsed=${holds.length} '
          'rawList=${list.length}',
        );
      }
      return true;
    }());
    return holds;
  }

  static int? resolveCashRegisterId(Map<String, dynamic> h) {
    for (final key in [
      'cashRagisterId',
      'cash_ragister_id',
      'cash_register_id',
      'cashRegisterId',
      'cash_register',
      'registerId',
      'register_id',
    ]) {
      final v = h[key];
      if (v is Map) {
        final id = cashRegisterParseId(
          v['id'] ?? v['cash_register_id'] ?? v['cashRagisterId'],
        );
        if (id != null && id > 0) return id;
        continue;
      }
      final id = cashRegisterParseId(v);
      if (id != null && id > 0) return id;
    }
    for (final nestKey in ['order', 'sale', 'sales']) {
      final nested = h[nestKey];
      if (nested is Map) {
        final id = resolveCashRegisterId(Map<String, dynamic>.from(nested));
        if (id != null) return id;
      }
    }
    return null;
  }

  /// Kassa nomi — API dagi obyekt yoki ro'yxatdan id bo'yicha.
  static String? resolveCashRegisterLabel(
    Map<String, dynamic> h, {
    List<Map<String, dynamic>> registers = const [],
  }) {
    for (final key in [
      'cash_register',
      'cashRegister',
      'register',
      'cashRagisterId',
      'cash_ragister_id',
      'cash_register_id',
      'cashRegisterId',
    ]) {
      final v = h[key];
      if (v is Map) {
        final m = Map<String, dynamic>.from(v);
        final title = cashRegisterDisplayTitle(m);
        if (title.trim().isNotEmpty && title != 'Kassa') return title;
        final hasName = m.containsKey('title') ||
            m.containsKey('name') ||
            m.containsKey('cash_register_title');
        if (hasName) return title;
      }
    }

    final id = resolveCashRegisterId(h);
    if (id == null || id <= 0) return null;

    for (final r in registers) {
      final rid = cashRegisterParseId(r['id'] ?? r['cash_register_id'] ?? r['cashRagisterId']);
      if (rid == id) return cashRegisterDisplayTitle(r);
    }

    return 'Kassa $id';
  }

  static int? resolveCreatorUserId(Map<String, dynamic> h) {
    for (final key in [
      'user_id',
      'userId',
      'userID',
      'created_by_id',
      'createdById',
      'seller_id',
      'sellerId',
      'employee_id',
      'employeeId',
      'opened_by',
      'openedBy',
    ]) {
      final id = cashRegisterParseId(h[key]);
      if (id != null && id > 0) return id;
    }
    for (final key in ['created_by', 'createdBy', 'user', 'seller', 'employee']) {
      final v = h[key];
      if (v is Map) {
        final id = cashRegisterParseId(
          v['id'] ?? v['user_id'] ?? v['userId'] ?? v['userID'],
        );
        if (id != null && id > 0) return id;
      }
    }
    for (final nestKey in ['order', 'sale', 'sales']) {
      final nested = h[nestKey];
      if (nested is Map) {
        final id = resolveCreatorUserId(Map<String, dynamic>.from(nested));
        if (id != null) return id;
      }
    }
    return null;
  }

  /// Joriy kassa smenasiga tegishli hold buyurtma (boshqa kassalar aralashmasin).
  static bool belongsToCashRegister(
    Map<String, dynamic> h, {
    int? cashRegisterId,
    int? registerLogId,
    Map<String, dynamic>? activeRegister,
    List<Map<String, dynamic>> otherOpenRegisters = const [],
    Map<int, ({int? cashRegisterId, int? registerLogId})>? localTags,
    bool filterByCashRegister = false,
  }) {
    if (!filterByCashRegister || cashRegisterId == null) return true;

    final orderId = resolveOrderId(h);

    // 1. Lokal teg — xodim boshqa kassaga o'tsa ham hold o'sha kassada qoladi.
    if (orderId != null && localTags != null) {
      final tag = localTags[orderId];
      if (tag != null) {
        if (tag.cashRegisterId != null && tag.cashRegisterId! > 0) {
          return tag.cashRegisterId == cashRegisterId;
        }
        if (tag.registerLogId != null && tag.registerLogId! > 0 && registerLogId != null) {
          return tag.registerLogId == registerLogId;
        }
        return false;
      }
    }

    // 2. API kassa id
    final orderRegId = resolveCashRegisterId(h);
    if (orderRegId != null && orderRegId > 0) {
      return orderRegId == cashRegisterId;
    }

    // 3. API smena log — boshqa smenadagi hold ko'rinmasin.
    final orderLogId = resolveRegisterLogId(h);
    if (orderLogId != null && orderLogId > 0) {
      if (registerLogId == null) return false;
      return orderLogId == registerLogId;
    }

    // 4. API maydoni yo'q — shu kassa smena xodimlari (hamkorlar uchun).
    final creatorId = resolveCreatorUserId(h);
    if (creatorId != null && activeRegister != null) {
      final inCurrent = cashRegisterShiftUserIds(activeRegister).contains(creatorId) ||
          cashRegisterUserIsOpener(activeRegister, creatorId);
      if (!inCurrent) return false;

      // Yaratuvchi faqat boshqa ochiq kassada bo'lsa — joriy kassada ko'rsatilmaydi.
      for (final r in otherOpenRegisters) {
        if (cashRegisterUserIsEnrolled(r, creatorId)) return false;
      }
      return true;
    }

    return false;
  }

  static int? resolveRegisterLogId(Map<String, dynamic> h) {
    for (final key in ['register_log_id', 'registerLogId', 'cash_register_log_id', 'log_id']) {
      final id = cashRegisterParseId(h[key]);
      if (id != null && id > 0) return id;
    }
    for (final nestKey in ['order', 'sale', 'sales']) {
      final nested = h[nestKey];
      if (nested is Map) {
        final id = resolveRegisterLogId(Map<String, dynamic>.from(nested));
        if (id != null) return id;
      }
    }
    return null;
  }

  static List<dynamic> _extractList(Map<String, dynamic> res) {
    // Server `hold_orders: []` qaytarsa — boshqa kalitlardagi umumiy sotuvlarni aralashtirmaymiz.
    if (res.containsKey('hold_orders') || res.containsKey('holdOrders')) {
      final direct = res['hold_orders'] ?? res['holdOrders'];
      return direct is List ? direct : const [];
    }

    final data = res['data'];
    if (data is List) return data;
    if (data is Map) {
      final m = Map<String, dynamic>.from(data);
      for (final key in ['hold_orders', 'holdOrders', 'datarows', 'orders', 'rows']) {
        final inner = m[key];
        if (inner is List && inner.isNotEmpty) return inner;
      }
    }

    final datarows = res['datarows'];
    if (datarows is List) return datarows;

    return const [];
  }

  static bool _isHoldRow(Map<String, dynamic> m) {
    if (resolveOrderId(m) == null) return false;

    final status = (m['status'] ?? m['order_status'] ?? m['orderStatus'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    if (_isCompletedOrCancelledStatus(status)) return false;

    if (status == 'hold' || status == 'paused' || status == 'pause') return true;

    final holdFlag = m['is_hold'] ?? m['isHold'] ?? m['on_hold'];
    if (holdFlag == true || holdFlag == 1 || holdFlag == '1') return true;

    return false;
  }

  static bool _isCompletedOrCancelledStatus(String status) {
    if (status.isEmpty) return false;
    const done = {
      'done',
      'completed',
      'complete',
      'paid',
      'closed',
      'cancelled',
      'canceled',
      'void',
      'final',
      'sold',
    };
    return done.contains(status);
  }

  /// POST /sales/store da mavjud buyurtmani yangilash uchun to‘g‘ri order id.
  static int? resolveOrderId(Map<String, dynamic> h) {
    for (final key in ['orderID', 'order_id', 'orderId']) {
      final v = h[key];
      if (v == null) continue;
      final n = v is int ? v : int.tryParse(v.toString());
      if (n != null && n > 0) return n;
    }
    final fromRow = getOrderIdFromSale(h);
    if (fromRow != null && fromRow > 0) return fromRow;
    final inv = parseOrderIdFromInvoiceId(h['invoice_id'] ?? h['invoiceId']);
    if (inv != null && inv > 0) return inv;
    return null;
  }

  static int orderId(Map<String, dynamic> h) => resolveOrderId(h) ?? 0;

  static String? resolveInvoiceId(Map<String, dynamic> h) {
    final inv = (h['invoice_id'] ?? h['invoiceId'] ?? '').toString().trim();
    return inv.isEmpty ? null : inv;
  }

  static int? resolveQueueNumber(Map<String, dynamic> h) {
    for (final key in ['queueNumber', 'queue_number', 'checkNumber', 'check_number']) {
      final n = cashRegisterParseId(h[key]);
      if (n != null && n > 0) return n;
    }
    for (final nestKey in ['data', 'order', 'sale', 'sales']) {
      final nested = h[nestKey];
      if (nested is Map) {
        final n = resolveQueueNumber(Map<String, dynamic>.from(nested));
        if (n != null) return n;
      }
    }
    return null;
  }

  static KitchenStatus? resolveKitchenStatus(Map<String, dynamic> h) {
    final direct = KitchenStatus.tryParse(h['kitchenStatus'] ?? h['kitchen_status']);
    if (direct != null) return direct;
    for (final nestKey in ['order', 'sale', 'sales']) {
      final nested = h[nestKey];
      if (nested is Map) {
        final status = resolveKitchenStatus(Map<String, dynamic>.from(nested));
        if (status != null) return status;
      }
    }
    return null;
  }

  static int? resolveTableId(Map<String, dynamic> h) {
    for (final key in ['tableId', 'table_id', 'tableID']) {
      final n = cashRegisterParseId(h[key]);
      if (n != null && n > 0) return n;
    }
    final table = h['table'];
    if (table is Map) {
      final n = cashRegisterParseId(table['id'] ?? table['tableId'] ?? table['table_id']);
      if (n != null && n > 0) return n;
    }
    for (final nestKey in ['order', 'sale', 'sales']) {
      final nested = h[nestKey];
      if (nested is Map) {
        final id = resolveTableId(Map<String, dynamic>.from(nested));
        if (id != null) return id;
      }
    }
    return null;
  }

  /// Stol / kabina yorlig‘i — API `tableName` yoki `stol {id}`.
  static String? resolveTableLabel(Map<String, dynamic> h) {
    for (final key in ['tableName', 'table_name', 'table_title', 'tableTitle']) {
      final s = (h[key] ?? '').toString().trim();
      if (s.isNotEmpty) return s;
    }
    final table = h['table'];
    if (table is Map) {
      final s = (table['name'] ?? table['title'] ?? table['tableName'] ?? '').toString().trim();
      if (s.isNotEmpty) return s;
    }
    for (final nestKey in ['order', 'sale', 'sales']) {
      final nested = h[nestKey];
      if (nested is Map) {
        final label = resolveTableLabel(Map<String, dynamic>.from(nested));
        if (label != null) return label;
      }
    }
    final id = resolveTableId(h);
    if (id != null) return 'stol $id';
    return null;
  }

  static Map<String, dynamic> applyKitchenStatusUpdate(
    Map<String, dynamic> hold,
    Map<String, dynamic> res,
  ) {
    final next = Map<String, dynamic>.from(hold);
    final status = res['kitchenStatus'] ?? res['kitchen_status'];
    if (status != null) {
      next['kitchenStatus'] = status;
      next['kitchen_status'] = status;
    }
    final queue = res['queueNumber'] ?? res['queue_number'];
    if (queue != null) {
      next['queueNumber'] = queue;
      next['queue_number'] = queue;
      next['checkNumber'] = queue;
    }
    return next;
  }

  static int displayTotal(Map<String, dynamic> h) {
    final nested = h['order'];
    if (nested is Map) {
      final fromOrder = displayTotal(Map<String, dynamic>.from(nested));
      if (fromOrder > 0) return fromOrder;
    }

    for (final key in _totalKeys) {
      final amt = parseAmountFromApi(h[key]);
      if (amt > 0) return amt;
    }

    final fromCart = _sumCartLines(h);
    if (fromCart > 0) return fromCart;

    return 0;
  }

  static int _sumCartLines(Map<String, dynamic> h) {
    for (final key in ['cart', 'orderItems', 'items', 'order_items']) {
      final raw = h[key];
      if (raw is! List || raw.isEmpty) continue;
      var sum = 0;
      for (final row in raw) {
        if (row is! Map) continue;
        final m = Map<String, dynamic>.from(row);
        if ((m['orderType'] ?? '').toString() == 'discount') continue;
        final line = parseAmountFromApi(m['calculatedPrice'] ?? m['line_total'] ?? m['total']);
        if (line > 0) {
          sum += line;
          continue;
        }
        final price = parseAmountFromApi(m['price'] ?? m['unit_price']);
        final qty = m['quantity'] ?? m['qty'] ?? 1;
        final q = qty is num ? qty.toDouble() : double.tryParse(qty.toString()) ?? 1;
        sum += (price * q).round();
      }
      if (sum > 0) return sum;
    }
    return 0;
  }

  static const _totalKeys = [
    'grandTotal',
    'grand_total',
    'total',
    'total_amount',
    'order_total',
    'orderTotal',
    'amount',
    'sum',
    'subTotal',
    'sub_total',
    'paid',
  ];
}
