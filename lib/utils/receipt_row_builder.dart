import '../core/input_formatters.dart';
import '../models/cart_item.dart';
import '../models/product.dart';
import '../providers/products_provider.dart';
import '../utils/product_weight.dart';
import '../widgets/receipt_widget.dart';

/// Chek qatorlari — katalog narxi, chegirmali narx va umumiy chegirma.
class ReceiptRowBuilder {
  ReceiptRowBuilder._();

  static ReceiptRow fromCartItem(CartItem item) {
    final p = item.product;
    final catalogUnit = item.defaultLineUnitPrice.round();
    final actualUnit = item.unitPriceDisplay;
    final catalogSum = (item.defaultLineUnitPrice * item.quantity).round();
    final actualSum = item.total;

    return ReceiptRow(
      productName: p.name,
      quantityStr: ProductWeight.cartItemQuantityLabel(item),
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
    final qtyStr = ProductWeight.invoiceRowQuantityLabel(
      r,
      catalogProduct: _catalogProductForInvoiceRow(r),
    );
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

  static num _invoiceQtyNum(Map<String, dynamic> r) =>
      ProductWeight.parseInvoiceQtyNum(r);

  static Product? _catalogProductForInvoiceRow(Map<String, dynamic> r) {
    final prov = ProductsProvider.instance;
    if (!prov.isLoaded || prov.items.isEmpty) return null;

    for (final key in ['productID', 'product_id', 'productId', 'pid', 'item_product_id', 'catalog_id']) {
      final raw = r[key];
      if (raw == null) continue;
      final idStr = raw.toString().trim();
      if (idStr.isEmpty || idStr == '0') continue;
      final p = prov.getProductById(idStr);
      if (p != null) return p;
    }

    final productMap = r['product'];
    if (productMap is Map) {
      final pm = Map<String, dynamic>.from(productMap);
      for (final key in ['id', 'productID', 'product_id', 'productId']) {
        final raw = pm[key];
        if (raw == null) continue;
        final idStr = raw.toString().trim();
        if (idStr.isEmpty || idStr == '0') continue;
        final p = prov.getProductById(idStr);
        if (p != null) return p;
      }
    }

    final vidRaw = r['variantID'] ?? r['variant_id'] ?? r['variantId'];
    final vid = vidRaw is int ? vidRaw : int.tryParse(vidRaw?.toString().trim() ?? '');
    if (vid != null && vid != 0) {
      for (final p in prov.items) {
        if (p.variantId == vid) return p;
      }
    }
    return null;
  }
}
