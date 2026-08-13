import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/cart_item.dart';
import '../models/product.dart';
import '../providers/clients_provider.dart';
import '../providers/products_provider.dart';
import '../services/api_service.dart';
import 'hold_orders_response.dart';

/// GET hold-orders javobidagi savatni CartItem ga aylantirish.
class HoldOrderResume {
  const HoldOrderResume({
    required this.items,
    this.customer,
    this.orderId,
    this.invoiceId,
    this.discountPercent,
    this.grandTotal,
    this.queueNumber,
  });

  final List<CartItem> items;
  final Client? customer;
  final int? orderId;
  final String? invoiceId;
  final int? discountPercent;
  final int? grandTotal;
  final int? queueNumber;
}

class HoldOrderCart {
  HoldOrderCart._();

  static const _cartKeys = [
    'cart',
    'orderItems',
    'items',
    'cart_items',
    'order_items',
    'lines',
    'products',
  ];

  /// Chop etish uchun — tez: ichki cart yoki bitta continue-sale (invoice/catalog yo‘q).
  static Future<HoldOrderResume?> fetchResumeForPrint(Map<String, dynamic> hold) async {
    final embedded = parse(hold);
    if (embedded != null && embedded.items.isNotEmpty) return embedded;

    final orderId = _int(hold['orderID'] ?? hold['order_id'] ?? hold['id']);
    if (orderId == null) return embedded;

    try {
      final cont = await SalesApi.continueSale(orderId);
      final fromCont = _resumeFromApiPayload(cont, hold);
      if (fromCont != null && fromCont.items.isNotEmpty) return fromCont;
    } catch (e) {
      _debug('print continue-sale failed: $e');
    }
    return embedded;
  }

  /// Ro'yxatdagi qisqa yozuvdan (cart bo'lmasa ham) to'liq savatni yuklash.
  static Future<HoldOrderResume?> fetchResume(Map<String, dynamic> hold) async {
    final embedded = parse(hold);
    if (embedded != null && embedded.items.isNotEmpty) return embedded;

    final orderId = _int(hold['orderID'] ?? hold['order_id'] ?? hold['id']);
    if (orderId == null) return embedded;

    try {
      final cont = await SalesApi.continueSale(orderId);
      final fromCont = _resumeFromApiPayload(cont, hold);
      if (fromCont != null && fromCont.items.isNotEmpty) {
        _debug('resume via continue-sale: ${fromCont.items.length} lines');
        return fromCont;
      }
      _debug('continue-sale: cart empty or missing');
    } catch (e) {
      _debug('continue-sale failed: $e');
    }

    try {
      await _ensureCatalog();
      final inv = await ReportsApi.getInvoiceDetails(orderId);
      final fromInv = _resumeFromInvoiceDetails(inv, hold);
      if (fromInv != null && fromInv.items.isNotEmpty) {
        _debug('resume via invoice-details: ${fromInv.items.length} lines');
        return fromInv;
      }
      _debug('invoice-details: no product rows');
    } catch (e) {
      _debug('invoice-details failed: $e');
    }

    return embedded;
  }

  static HoldOrderResume? parse(Map<String, dynamic> hold) {
    final cartRaw = _cartLinesFromMap(hold);
    if (cartRaw == null || cartRaw.isEmpty) return null;

    final items = _itemsFromCartRows(cartRaw);
    if (items.isEmpty) return null;

    return _resumeMeta(hold, items);
  }

  static List<dynamic>? _cartLinesFromMap(Map<String, dynamic> map) {
    for (final key in _cartKeys) {
      final v = map[key];
      if (v is List && v.isNotEmpty) return v;
      if (v is String && v.trim().isNotEmpty) {
        try {
          final decoded = jsonDecode(v);
          if (decoded is List && decoded.isNotEmpty) return decoded;
        } catch (_) {}
      }
    }
    final order = map['order'];
    if (order is Map) {
      return _cartLinesFromMap(Map<String, dynamic>.from(order));
    }
    final data = map['data'];
    if (data is Map) {
      return _cartLinesFromMap(Map<String, dynamic>.from(data));
    }
    return null;
  }

  static void _debug(String msg) {
    assert(() {
      if (kDebugMode) debugPrint('[HoldOrderCart] $msg');
      return true;
    }());
  }

  static HoldOrderResume? _resumeFromApiPayload(
    Map<String, dynamic> res,
    Map<String, dynamic> hold,
  ) {
    final cartRaw = _cartLinesFromMap(res);
    if (cartRaw == null || cartRaw.isEmpty) return null;
    final items = _itemsFromCartRows(cartRaw);
    if (items.isEmpty) return null;
    return _resumeMeta(hold, items, extra: res);
  }

  static HoldOrderResume? _resumeFromInvoiceDetails(
    Map<String, dynamic> inv,
    Map<String, dynamic> hold,
  ) {
    List<dynamic> datarows = inv['datarows'] as List<dynamic>? ??
        inv['data'] as List<dynamic>? ??
        inv['items'] as List<dynamic>? ??
        inv['products'] as List<dynamic>? ??
        [];
    if (datarows is! List && inv['data'] is Map) {
      final d = inv['data'] as Map;
      datarows = d['datarows'] as List<dynamic>? ?? d['items'] as List<dynamic>? ?? [];
    }
    if (datarows is! List) return null;

    const summaryTitles = {'sub total', 'tax', 'total', 'discount', 'chegirma', 'umumiy', 'umumiy summa'};
    final items = <CartItem>[];
    for (final row in datarows) {
      if (row is! Map) continue;
      final m = Map<String, dynamic>.from(row);
      final title = (m['title'] ?? m['name'] ?? '').toString().trim().toLowerCase();
      if (summaryTitles.contains(title)) continue;
      final hasQty = m.containsKey('quantity') || m.containsKey('qty');
      final hasPrice = m.containsKey('price') || m.containsKey('unit_price');
      if (!hasQty && !hasPrice) continue;

      final item = _lineFromMap(m);
      if (item != null) items.add(item);
    }
    if (items.isEmpty) return null;
    return _resumeMeta(hold, items, extra: inv);
  }

  static List<CartItem> _itemsFromCartRows(List<dynamic> cartRaw) {
    final items = <CartItem>[];
    for (final row in cartRaw) {
      if (row is! Map) continue;
      final item = _lineFromMap(Map<String, dynamic>.from(row));
      if (item != null) items.add(item);
    }
    return items;
  }

  static HoldOrderResume _resumeMeta(
    Map<String, dynamic> hold,
    List<CartItem> items, {
    Map<String, dynamic>? extra,
  }) {
    Client? customer;
    final cust = hold['customer'] ?? extra?['customer'];
    if (cust is Map) {
      try {
        customer = Client.fromApiJson(Map<String, dynamic>.from(cust));
      } catch (_) {}
    }

    final orderId = HoldOrdersResponse.resolveOrderId(hold) ??
        (extra != null ? HoldOrdersResponse.resolveOrderId(extra) : null);
    final invoiceId = HoldOrdersResponse.resolveInvoiceId(hold) ??
        (extra != null ? HoldOrdersResponse.resolveInvoiceId(extra) : null);
    final discount = _int(hold['discount'] ?? extra?['discount']);
    final grand = _int(hold['grandTotal'] ?? hold['grand_total'] ?? extra?['grandTotal'] ?? extra?['grand_total']);

    return HoldOrderResume(
      items: items,
      customer: customer,
      orderId: orderId,
      invoiceId: invoiceId,
      discountPercent: discount,
      grandTotal: grand,
      queueNumber: HoldOrdersResponse.resolveQueueNumber(hold) ??
          (extra != null ? HoldOrdersResponse.resolveQueueNumber(extra) : null),
    );
  }

  static Future<void> _ensureCatalog() async {
    if (!ProductsProvider.instance.isLoaded) {
      try {
        await ProductsProvider.instance.warmFromCache();
        await ProductsProvider.instance.refreshFromServer(force: false);
      } catch (_) {}
    }
  }

  static CartItem? _lineFromMap(Map<String, dynamic> m) {
    final orderType = (m['orderType'] ?? m['order_type'] ?? '').toString();
    if (orderType == 'discount') return null;

    var productId = (m['productID'] ?? m['product_id'] ?? '').toString();
    final title = (m['productTitle'] ?? m['product_title'] ?? m['title'] ?? 'Mahsulot').toString();
    if (productId.isEmpty || productId == '0') {
      final resolved = _resolveProductId(title);
      if (resolved == null) return null;
      productId = resolved;
    }

    final qty = m['quantity'] ?? m['qty'];
    final quantity = qty is num ? qty : num.tryParse(qty?.toString() ?? '') ?? 1;
    final price = m['price'] ?? m['unit_price'] ?? m['calculatedPrice'] ?? m['total'];
    final unitPrice = price is num ? price.toDouble() : double.tryParse(price?.toString() ?? '') ?? 0;
    final variantId = _int(m['variantID'] ?? m['variant_id']);
    final isPack = m['isPackage'] == true || m['isPackage'] == 1 || m['is_package'] == true;
    final unitsPerPackage = _int(m['unitsPerPackage'] ?? m['units_per_package']) ?? 1;

    Product? catalog;
    for (final p in ProductsProvider.instance.items) {
      if (p.id == productId) {
        catalog = p;
        break;
      }
    }

    final product = catalog ??
        Product(
          id: productId,
          name: title,
          priceUzs: unitPrice.round(),
          variantId: variantId,
          quantityInPack: isPack && unitsPerPackage > 1,
          quantityPerPack: unitsPerPackage,
          sellPricePerPack: isPack ? unitPrice.round() : null,
          sellingPriceApi: unitPrice,
        );

    final catalogUnit = product.pieceSellPriceNum.toDouble();
    double? override;
    if ((catalogUnit - unitPrice).abs() > 0.01) {
      override = unitPrice;
    }

    return CartItem(
      product: product,
      quantity: quantity,
      sellByPack: isPack,
      salePriceOverride: override,
    );
  }

  static String? _resolveProductId(String title) {
    final t = title.trim().toLowerCase();
    if (t.isEmpty) return null;
    for (final p in ProductsProvider.instance.items) {
      if (p.name.trim().toLowerCase() == t) return p.id;
    }
    return null;
  }

  static int? _int(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }
}
