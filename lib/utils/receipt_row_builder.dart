import '../core/input_formatters.dart';
import '../models/cart_item.dart';
import '../models/product.dart';
import '../utils/product_weight.dart';
import '../widgets/receipt_widget.dart';

/// Chek qatorlari — katalog narxi, chegirmali narx va umumiy chegirma.
class ReceiptRowBuilder {
  ReceiptRowBuilder._();

  static ReceiptRow fromCartItem(CartItem item) {
    final p = item.product;
    final unitLabel = item.sellByPack ? 'pachka' : Product.unitDisplayShort(p.unit);
    final catalogUnit = item.defaultLineUnitPrice.round();
    final actualUnit = item.unitPriceDisplay;
    final catalogSum = (item.defaultLineUnitPrice * item.quantity).round();
    final actualSum = item.total;

    return ReceiptRow(
      productName: p.name,
      quantityStr: '${item.quantity} $unitLabel',
      price: actualUnit,
      sum: actualSum,
      catalogPrice: actualUnit < catalogUnit ? catalogUnit : null,
      catalogSum: actualSum < catalogSum ? catalogSum : null,
      lineWeightKg: ProductWeight.lineKgFromCartItem(item),
    );
  }

  static List<ReceiptRow> fromCartItems(List<CartItem> items) =>
      items.map(fromCartItem).toList();

  /// Katalog narxlari bo'yicha jami (chegirmasiz).
  static int catalogSubtotalFromCart(List<CartItem> items) => items.fold<int>(
        0,
        (s, e) => s + (e.defaultLineUnitPrice * e.quantity).round(),
      );

  /// Qator + savatcha chegirmasi: katalog jami − to'langan jami.
  static int totalDiscountUzs({
    required List<CartItem> items,
    required int totalAfterDiscount,
  }) {
    final catalog = catalogSubtotalFromCart(items);
    final diff = catalog - totalAfterDiscount;
    return diff > 0 ? diff : 0;
  }

  static ReceiptRow fromInvoiceRow(Map<String, dynamic> r) {
    final title = (r['title'] ?? r['product_title'] ?? r['productTitle'] ?? r['name'] ?? '—')
        .toString();
    final qtyStr = _invoiceQtyLabel(r);
    final catalogUnit = parseAmountFromApi(r['price'] ?? r['unit_price'] ?? 0);
    var lineTotal = parseAmountFromApi(r['total'] ?? r['calculatedPrice'] ?? r['sum'] ?? 0);
    final lineDiscount = parseAmountFromApi(r['discount'] ?? 0);
    final qtyNum = _invoiceQtyNum(r);

    var actualUnit = catalogUnit;
    if (lineTotal > 0 && qtyNum > 0) {
      actualUnit = (lineTotal / qtyNum).round();
    } else if (lineDiscount > 0 && qtyNum > 0 && catalogUnit > 0) {
      lineTotal = (catalogUnit * qtyNum - lineDiscount).round().clamp(0, 0x7FFFFFFF);
      actualUnit = (lineTotal / qtyNum).round();
    } else if (catalogUnit > 0 && qtyNum > 0) {
      lineTotal = (catalogUnit * qtyNum).round();
    }

    final catalogSum = qtyNum > 0 ? (catalogUnit * qtyNum).round() : catalogUnit;
    final hasUnitDiscount = catalogUnit > 0 && actualUnit < catalogUnit;
    final hasSumDiscount = catalogSum > 0 && lineTotal > 0 && lineTotal < catalogSum;
    final unitWeight = ProductWeight.parse(r['weight'] ?? r['product_weight']);
    final lineWeight = ProductWeight.lineKgFromUnit(unitWeight, qtyNum);

    return ReceiptRow(
      productName: title,
      quantityStr: qtyStr,
      price: actualUnit,
      sum: lineTotal > 0 ? lineTotal : catalogSum,
      catalogPrice: hasUnitDiscount ? catalogUnit : null,
      catalogSum: hasSumDiscount ? catalogSum : null,
      lineWeightKg: lineWeight,
    );
  }

  static List<ReceiptRow> fromInvoiceRows(List<Map<String, dynamic>> rows) =>
      rows.map(fromInvoiceRow).toList();

  static int catalogSubtotalFromInvoiceRows(List<Map<String, dynamic>> rows) =>
      rows.fold<int>(0, (s, r) {
        final unit = parseAmountFromApi(r['price'] ?? r['unit_price'] ?? 0);
        final qty = _invoiceQtyNum(r);
        if (unit <= 0 || qty <= 0) return s;
        return s + (unit * qty).round();
      });

  static String _invoiceQtyLabel(Map<String, dynamic> r) {
    final qty = (r['quantity'] ?? r['qty'] ?? '').toString().trim();
    if (qty.isEmpty) return '—';
    final unit = (r['unit_name'] ?? r['unit'] ?? r['unitName'] ?? r['measure'] ?? '')
        .toString()
        .trim();
    if (unit.isEmpty) return qty;
    return '$qty $unit';
  }

  static num _invoiceQtyNum(Map<String, dynamic> r) {
    final raw = (r['quantity'] ?? r['qty'] ?? '1').toString().trim();
    final first = raw.split(RegExp(r'\s+')).first.replaceAll(',', '.');
    return num.tryParse(first) ?? 1;
  }
}
