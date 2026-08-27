import '../models/cart_item.dart';

/// POST /sales/store body — hold va done (web POS bilan mos).
class SalesStoreBody {
  SalesStoreBody._();

  static List<Map<String, dynamic>> cartLines(List<CartItem> items, {bool includeCartItemNote = false}) {
    return items.map((item) {
      final p = item.product;
      final isPack = item.sellByPack && p.canSellByPack;
      final linePricing = item.salesStoreLinePricing;
      final soldUnit = item.unitPriceForLine;
      final lineTotal = linePricing.lineTotal;
      final recomputed =
          CartItem.quantizeLineTotal(soldUnit * item.quantity.toDouble());
      final hasLineTotalLock = item.lineTotalOverride != null ||
          (lineTotal - recomputed).abs() >= 0.001;
      final noteNeeded = includeCartItemNote ||
          (soldUnit - item.defaultLineUnitPrice).abs() > 0.5 ||
          hasLineTotalLock;
      return {
        'productID': int.tryParse(p.id) ?? 0,
        'variantID': p.variantId ?? 1,
        'quantity': item.quantity,
        'price': linePricing.catalogUnitPrice,
        'productTitle': p.name,
        'variantTitle': 'default_variant',
        'orderType': 'sales',
        'discount': _soldUnitPayload(linePricing.lineDiscount),
        'taxID': null,
        'calculatedPrice': _soldUnitPayload(lineTotal),
        // Backend markup (katalogdan qimmat) ni saqlamaydi — hold/done uchun zaxira.
        'soldUnitPrice': _soldUnitPayload(soldUnit),
        // Holdda majburiy; done/markup/kerakli-summa da ham yozamiz.
        'cartItemNote': noteNeeded
            ? cartItemNote(
                soldUnit,
                lineTotal: hasLineTotalLock ? lineTotal : null,
              )
            : '',
        if (isPack) 'isPackage': true,
        if (isPack) 'unitsPerPackage': p.quantityPerPack,
      };
    }).toList();
  }

  /// Hold/done `cartItemNote` — birlik narxi va (ixtiyoriy) qator summasi.
  static String cartItemNote(num soldUnit, {num? lineTotal}) {
    final parts = <String>['alfapos_sold_unit=${formatSoldUnitNote(soldUnit)}'];
    if (lineTotal != null && lineTotal > 0) {
      parts.add('alfapos_line_total=${formatSoldUnitNote(lineTotal)}');
    }
    return parts.join(';');
  }

  /// Kasrli birlik narxi (0.687) yaxlitlanmasin.
  static String formatSoldUnitNote(num soldUnit) {
    final d = soldUnit.toDouble();
    if ((d - d.roundToDouble()).abs() < 1e-9) return d.round().toString();
    return d
        .toStringAsFixed(6)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  static num _soldUnitPayload(num soldUnit) {
    final d = soldUnit.toDouble();
    if ((d - d.roundToDouble()).abs() < 1e-9) return d.round();
    return d;
  }

  /// Eski chaqiriqlar uchun.
  static String soldUnitNote(num soldUnit, {num? lineTotal}) =>
      cartItemNote(soldUnit, lineTotal: lineTotal);

  static double? parseSoldUnitNote(String? note) {
    if (note == null || note.trim().isEmpty) return null;
    final match =
        RegExp(r'alfapos_sold_unit=(-?\d+(?:[.,]\d+)?)').firstMatch(note);
    if (match == null) return null;
    return double.tryParse(match.group(1)!.replaceAll(',', '.'));
  }

  static num? parseLineTotalNote(String? note) {
    if (note == null || note.trim().isEmpty) return null;
    final match =
        RegExp(r'alfapos_line_total=(-?\d+(?:[.,]\d+)?)').firstMatch(note);
    if (match == null) return null;
    return double.tryParse(match.group(1)!.replaceAll(',', '.'));
  }

  static int estimateCostUzs(List<CartItem> items) {
    var cost = 0;
    for (final item in items) {
      final p = item.product;
      if (item.sellByPack && p.canSellByPack && p.costPricePerPack != null) {
        cost += (p.costPricePerPack! * item.quantity).round();
      } else {
        cost += ((p.costPriceUzs ?? 0) * item.quantity).round();
      }
    }
    return cost;
  }

  static Map<String, dynamic> build({
    required List<CartItem> items,
    required num subTotal,
    required num grandTotal,
    required String status,
    int discountPercent = 0,
    int? customerId,
    int? cashRegisterId,
    int? registerLogId,
    bool isCashRegisterBranch = false,
    int? branchId,
    int? orderId,
    String? invoiceId,
    int? editOrderId,
    String? editReason,
    List<Map<String, dynamic>>? payments,
    num dueAmount = 0,
    num? profit,
    String? note,
  }) {
    final discountUzs = subTotal - grandTotal;
    final isHold = status == 'hold';

    // Pauza (hold): web POS kabi — chegirma faqat summa, payments yuborilmaydi.
    final Object discountValue;
    if (isHold) {
      discountValue = discountUzs > 0 ? discountUzs : 0;
    } else if (discountPercent > 0) {
      discountValue = discountPercent;
    } else if (discountPercent < 0) {
      discountValue = 0;
    } else {
      discountValue = discountUzs > 0 ? discountUzs : 0;
    }

    final cost = estimateCostUzs(items);
    final body = <String, dynamic>{
      'orderType': 'sales',
      'salesOrReceivingType': 'customer',
      'status': status,
      'cart': cartLines(items, includeCartItemNote: isHold),
      'subTotal': subTotal,
      'tax': 0,
      'discount': discountValue,
      'grandTotal': grandTotal,
      'dueAmount': dueAmount,
      'profit': profit ?? (grandTotal - cost),
      'customer': customerId != null ? {'id': customerId} : null,
      'isCashRegisterBranch': cashRegisterId != null ? true : isCashRegisterBranch,
      'time': DateTime.now().toIso8601String().substring(0, 19).replaceFirst('T', ' '),
    };
    if (cashRegisterId != null) body['cashRagisterId'] = cashRegisterId;
    if (registerLogId != null) body['register_log_id'] = registerLogId;
    if (branchId != null) body['selectedBranchID'] = branchId;
    if (editOrderId != null) {
      body['editOrderId'] = editOrderId;
      if (editReason != null && editReason.isNotEmpty) body['editReason'] = editReason;
    } else if (orderId != null) {
      body['orderID'] = orderId;
      body['orderId'] = orderId;
      body['id'] = orderId;
    }
    if (editOrderId == null && invoiceId != null && invoiceId.isNotEmpty) {
      body['invoice_id'] = invoiceId;
    }
    if (!isHold && payments != null) body['payments'] = payments;
    final noteText = note?.trim() ?? '';
    if (noteText.isNotEmpty) {
      body['description'] = noteText;
      body['note'] = noteText;
    }
    return body;
  }
}
