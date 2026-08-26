import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../core/input_formatters.dart';
import '../models/cart_item.dart';
import '../models/product.dart';
import '../providers/clients_provider.dart';
import '../providers/products_provider.dart';
import '../services/api_service.dart';
import 'hold_orders_response.dart';
import 'sales_store_body.dart';

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
    this.description,
  });

  final List<CartItem> items;
  final Client? customer;
  final int? orderId;
  final String? invoiceId;
  final int? discountPercent;
  final int? grandTotal;
  final int? queueNumber;
  final String? description;
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
  static Future<HoldOrderResume?> fetchResumeForPrint(
      Map<String, dynamic> hold) async {
    final embedded = parse(hold);
    if (_cartHasExplicitSoldUnitHints(hold) &&
        embedded != null &&
        embedded.items.isNotEmpty) {
      _debug('print: using embedded cart because sold-unit hint exists');
      return embedded;
    }
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
  ///
  /// Hold-orders ro‘yxatidagi cart ko‘pincha katalog narxida qisqartirilgan —
  /// shu sababli avval `continue-sale` dan to‘liq qatorlarni olamiz.
  static Future<HoldOrderResume?> fetchResume(Map<String, dynamic> hold) async {
    final orderId = _int(hold['orderID'] ?? hold['order_id'] ?? hold['id']);
    final embedded = parse(hold);
    final embeddedHasSoldUnitHints = _cartHasExplicitSoldUnitHints(hold);

    if (embeddedHasSoldUnitHints &&
        embedded != null &&
        embedded.items.isNotEmpty) {
      _debug('resume: using embedded cart because sold-unit hint exists');
      return embedded;
    }

    if (orderId != null) {
      try {
        final cont = await SalesApi.continueSale(orderId);
        final fromCont = _resumeFromApiPayload(cont, hold);
        if (fromCont != null && fromCont.items.isNotEmpty) {
          final preferred = _preferPricedResume(fromCont, embedded);
          _debug(
            'resume via continue-sale: ${preferred.items.length} lines '
            '(locked=${preferred.items.where((e) => e.priceLocked).length})',
          );
          return preferred;
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
          final preferred = _preferPricedResume(fromInv, embedded);
          _debug('resume via invoice-details: ${preferred.items.length} lines');
          return preferred;
        }
        _debug('invoice-details: no product rows');
      } catch (e) {
        _debug('invoice-details failed: $e');
      }
    }

    return embedded;
  }

  /// Ikki manbadan qaysi biri chegirmali/tiklangan narxlarni saqlaganini tanlaydi.
  static HoldOrderResume _preferPricedResume(
    HoldOrderResume primary,
    HoldOrderResume? fallback,
  ) {
    if (fallback == null || fallback.items.isEmpty) return primary;
    final primaryScore = _resumePriceFidelity(primary);
    final fallbackScore = _resumePriceFidelity(fallback);
    if (fallbackScore > primaryScore) {
      _debug('prefer embedded cart prices (score $fallbackScore > $primaryScore)');
      return fallback;
    }
    return primary;
  }

  static int _resumePriceFidelity(HoldOrderResume resume) {
    var score = 0;
    for (final item in resume.items) {
      if (item.priceLocked) score += 3;
      if (item.hasSalePriceOverride) score += 2;
      final base = item.unitPriceBaseForCartPercent;
      if (base != null &&
          (base - item.defaultLineUnitPrice).abs() > 0.5) {
        score += 1;
      }
    }
    return score;
  }

  static HoldOrderResume? parse(Map<String, dynamic> hold) {
    final cartRaw = _cartLinesFromMap(hold);
    if (cartRaw == null || cartRaw.isEmpty) return null;

    final items = _itemsFromCartRows(cartRaw);
    if (items.isEmpty) return null;

    return _resumeMeta(hold, items);
  }

  /// Sotilgan chek detail javobidan savatni tiklash.
  static HoldOrderResume? fromInvoiceDetails(
    Map<String, dynamic> invoiceDetail, {
    Map<String, dynamic>? metaSource,
  }) {
    final meta = metaSource ?? invoiceDetail;
    return _resumeFromInvoiceDetails(invoiceDetail, meta);
  }

  static bool _cartHasExplicitSoldUnitHints(Map<String, dynamic> map) {
    final rows = _cartLinesFromMap(map);
    if (rows == null || rows.isEmpty) return false;
    for (final row in rows) {
      if (row is! Map) continue;
      final m = Map<String, dynamic>.from(row);
      final soldUnit = m['soldUnitPrice'] ?? m['sold_unit_price'];
      if (soldUnit != null && soldUnit.toString().trim().isNotEmpty) return true;
      final note = (m['cartItemNote'] ?? m['cart_item_note'] ?? '').toString();
      if (SalesStoreBody.parseSoldUnitNote(note) != null) return true;
    }
    return false;
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
    var datarows = inv['datarows'] ?? inv['data'] ?? inv['items'] ?? inv['products'] ?? [];
    if (datarows is! List && inv['data'] is Map) {
      final d = inv['data'] as Map;
      datarows =
          d['datarows'] as List<dynamic>? ?? d['items'] as List<dynamic>? ?? [];
    }
    if (datarows is! List) return null;

    const summaryTitles = {
      'sub total',
      'tax',
      'total',
      'discount',
      'chegirma',
      'umumiy',
      'umumiy summa'
    };
    final items = <CartItem>[];
    for (final row in datarows) {
      if (row is! Map) continue;
      final m = Map<String, dynamic>.from(row);
      final title =
          (m['title'] ?? m['name'] ?? '').toString().trim().toLowerCase();
      if (summaryTitles.contains(title)) continue;
      final hasQty = m.containsKey('quantity') || m.containsKey('qty');
      final hasPrice = m.containsKey('price') || m.containsKey('unit_price');
      if (!hasQty && !hasPrice) continue;

      final item = _lineFromMap(m, allowTotalFallback: true);
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
    final grand = _int(hold['grandTotal'] ??
        hold['grand_total'] ??
        extra?['grandTotal'] ??
        extra?['grand_total']);

    applyGrandTotalSoldPriceCorrection(items, grand);

    return HoldOrderResume(
      items: items,
      customer: customer,
      orderId: orderId,
      invoiceId: invoiceId,
      // Hold da `discount` ko‘pincha so‘m; savat foizi faqat ±100 oralig‘ida.
      discountPercent: cartPercentFromOrderDiscount(discount),
      grandTotal: grand,
      queueNumber: HoldOrdersResponse.resolveQueueNumber(hold) ??
          (extra != null ? HoldOrdersResponse.resolveQueueNumber(extra) : null),
      description: _noteFrom(hold) ?? (extra != null ? _noteFrom(extra) : null),
    );
  }

  /// Backend faqat `price - discount` ni saqlaydi — katalogdan qimmat sotuv
  /// (`3480 → 5000`) yo‘qoladi. `grandTotal` farqini katalogda qolgan qatorlarga qaytaramiz.
  ///
  /// Default: faqat aralash savat (ba’zi qatorlar chegirmali) — noto‘g‘ri/katta
  /// `grandTotal` bilan bitta katalog qatorini “markup” deb oshirmaslik uchun.
  /// Invoice edit: [allowAllCatalogMarkup] = true (barcha qatorlar markup bo‘lishi mumkin).
  static void applyGrandTotalSoldPriceCorrection(
    List<CartItem> items,
    int? grandTotal, {
    bool allowAllCatalogMarkup = false,
  }) {
    if (grandTotal == null || grandTotal <= 0 || items.isEmpty) return;
    final current = items.fold<int>(0, (s, e) => s + e.total);
    final surplus = grandTotal - current;
    if (surplus <= 1) return;

    final belowCatalog = items.where((item) {
      return item.unitPriceForLine < item.defaultLineUnitPrice.toDouble() - 0.5;
    }).toList();
    final candidates = items.where((item) {
      final catalog = item.defaultLineUnitPrice.toDouble();
      return (item.unitPriceForLine - catalog).abs() < 0.5;
    }).toList();
    if (candidates.isEmpty) return;
    if (belowCatalog.isEmpty) {
      if (!allowAllCatalogMarkup) return;
      if (candidates.length != items.length) return;
    }

    final totalQty = candidates.fold<num>(0, (s, e) => s + e.quantity);
    if (totalQty <= 0) return;

    var remaining = surplus;
    for (var i = 0; i < candidates.length; i++) {
      final item = candidates[i];
      final share = i == candidates.length - 1
          ? remaining
          : (surplus * item.quantity / totalQty).round();
      remaining -= share;
      final qty = item.quantity <= 0 ? 1.0 : item.quantity.toDouble();
      final newUnit = item.unitPriceForLine + (share / qty);
      item.salePriceOverride = newUnit;
      item.unitPriceBaseForCartPercent = newUnit;
      item.priceLocked = true;
      _debug(
        'grandTotal markup fix product=${item.product.id} '
        'catalog=${item.defaultLineUnitPrice} -> $newUnit (share=$share)',
      );
    }
  }

  /// Buyurtma `discount` maydoni foiz (±100) yoki so‘m bo‘lishi mumkin.
  /// Qator narxlari `calculatedPrice` orqali tiklanadi — so‘mni foiz deb qo‘llamaslik.
  static int cartPercentFromOrderDiscount(dynamic discount) {
    final d = _int(discount);
    if (d == null || d == 0) return 0;
    if (d.abs() <= 100) return d;
    return 0;
  }

  static String? _noteFrom(Map<String, dynamic> source) {
    for (final key in const [
      'description',
      'note',
      'comment',
      'izoh',
      'remarks'
    ]) {
      final value = source[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    final nested = source['data'];
    if (nested is Map) {
      return _noteFrom(Map<String, dynamic>.from(nested));
    }
    return null;
  }

  static Future<void> _ensureCatalog() async {
    if (!ProductsProvider.instance.isLoaded) {
      try {
        await ProductsProvider.instance.warmFromCache();
        await ProductsProvider.instance.refreshFromServer(force: false);
      } catch (_) {}
    }
  }

  static CartItem? _lineFromMap(
    Map<String, dynamic> m, {
    bool allowTotalFallback = false,
  }) {
    final orderType = (m['orderType'] ?? m['order_type'] ?? '').toString();
    if (orderType == 'discount') return null;

    var productId = (m['productID'] ?? m['product_id'] ?? '').toString();
    final title =
        (m['productTitle'] ?? m['product_title'] ?? m['title'] ?? 'Mahsulot')
            .toString();
    if (productId.isEmpty || productId == '0') {
      final resolved = _resolveProductId(title);
      if (resolved != null) {
        productId = resolved;
      } else if (title.trim().isNotEmpty && title.trim().toLowerCase() != 'mahsulot') {
        // invoice-details ba’zan productID bermaydi — title bilan vaqtinchalik id.
        productId = 'title:${title.trim()}';
      } else {
        return null;
      }
    }

    final qty = m['quantity'] ?? m['qty'];
    final quantity =
        qty is num ? qty : num.tryParse(qty?.toString() ?? '') ?? 1;
    final variantId = _int(m['variantID'] ?? m['variant_id']);
    final isPack = m['isPackage'] == true ||
        m['isPackage'] == 1 ||
        m['is_package'] == true;
    final unitsPerPackage =
        _int(m['unitsPerPackage'] ?? m['units_per_package']) ?? 1;

    final soldFromNote = SalesStoreBody.parseSoldUnitNote(
      (m['cartItemNote'] ?? m['cart_item_note'] ?? '').toString(),
    );
    final soldUnit = soldFromNote ??
        _soldUnitPriceFromLine(
          m,
          quantity,
          allowTotalFallback: allowTotalFallback,
        );
    final catalogFromApi = _num(m['price'] ?? m['unit_price']);
    _debug(
      'line product=$productId qty=$quantity '
      'price=${m['price'] ?? m['unit_price']} '
      'discount=${m['discount'] ?? m['line_discount'] ?? m['lineDiscount']} '
      'calculated=${m['calculatedPrice'] ?? m['calculated_price'] ?? m['line_total']} '
      'total=${m['total'] ?? m['sum']} '
      'noteUnit=$soldFromNote soldUnit=$soldUnit',
    );

    Product? catalog;
    for (final p in ProductsProvider.instance.items) {
      if (p.id == productId) {
        catalog = p;
        break;
      }
    }

    // Katalog yo‘q bo‘lsa — API `price` (katalog) va sotilgan birlikni alohida saqlaymiz.
    final catalogHint = catalogFromApi ?? soldUnit;
    final product = catalog ??
        Product(
          id: productId,
          name: title,
          priceUzs: catalogHint.round(),
          variantId: variantId,
          quantityInPack: isPack && unitsPerPackage > 1,
          quantityPerPack: unitsPerPackage,
          sellPricePerPack: isPack ? catalogHint.round() : null,
          sellingPriceApi: catalogHint,
        );

    final draft = CartItem(
      product: product,
      quantity: quantity,
      sellByPack: isPack,
    );
    final catalogUnit = draft.defaultLineUnitPrice.toDouble();
    final hasCustomSold = soldFromNote != null ||
        (catalogUnit - soldUnit).abs() > 0.01;
    final double? override = hasCustomSold ? soldUnit : null;

    return CartItem(
      product: product,
      quantity: quantity,
      sellByPack: isPack,
      salePriceOverride: override,
      unitPriceBaseForCartPercent: soldUnit,
      // Tiklangan sotuv narxi — mijoz tanlash/qayta hisoblash o‘chirmasin.
      priceLocked: hasCustomSold,
    );
  }

  /// API `price` = katalog; haqiqiy sotuv = note / soldUnitPrice / calculatedPrice / discount.
  static double _soldUnitPriceFromLine(
    Map<String, dynamic> m,
    num quantity, {
    bool allowTotalFallback = false,
  }) {
    final qty = quantity <= 0 ? 1.0 : quantity.toDouble();

    // Biz yozgan ishonchli maydonlar.
    final explicit = _num(
      m['soldUnitPrice'] ?? m['sold_unit_price'] ?? m['unitSalePrice'],
    );
    if (explicit != null && explicit > 0) return explicit;

    if (allowTotalFallback) {
      final displayedLineTotal = _num(m['total'] ?? m['sum']);
      if (displayedLineTotal != null && displayedLineTotal > 0) {
        return displayedLineTotal / qty;
      }
    }

    final catalogUnit = _num(m['price'] ?? m['unit_price']) ?? 0;
    final lineDiscount = _num(m['discount'] ?? m['line_discount'] ?? m['lineDiscount']) ?? 0;
    if (catalogUnit > 0) {
      // Real bazada `calculatedPrice` ba'zan noto'g'ri faqat chegirma summasi bo'lib keladi.
      // Shuning uchun katalog narxi va qator chegirmasidan hisoblash ustun.
      final discountedUnit = (catalogUnit * qty - lineDiscount) / qty;
      if (discountedUnit > 0) return discountedUnit;
    }

    // `total` ishonchsiz (buyurtma jami aralashishi mumkin) — ishlatilmaydi.
    final calculated = _num(
      m['calculatedPrice'] ??
          m['calculated_price'] ??
          m['line_total'] ??
          m['lineTotal'] ??
          m['lineTotalAmount'],
    );
    if (calculated != null && calculated > 0) {
      return calculated / qty;
    }

    // Ayrim endpointlar faqat shu maydonlarni qaytaradi.
    final fallbackExplicit = _num(
      m['salePrice'] ??
          m['sale_price'] ??
          m['sellingPrice'] ??
          m['selling_price'],
    );
    if (fallbackExplicit != null && fallbackExplicit > 0) return fallbackExplicit;
    return 0;
  }

  static double? _num(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    final s = v.toString().trim();
    if (s.isEmpty) return null;
    // "10,000" / "10.000" → 10000 (eski replaceAll(',', '.') 10 qilib yuborardi).
    return parseAmountFromApiDouble(v);
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
