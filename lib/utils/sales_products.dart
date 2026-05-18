import '../models/product.dart';
import 'receive_products.dart';

/// POST /sales/products va barcode-search javoblarini Product ga aylantirish.
class SalesProducts {
  SalesProducts._();

  static List<Product> fromSalesResponse(Map<String, dynamic> res) {
    return ReceiveProducts.productsFromApiResponse(res);
  }

  static Product? fromBarcodeResult(Map<String, dynamic> res) {
    final raw = res['barcodeResultValue'];
    return ReceiveProducts.productFromBarcodeResult(raw);
  }

  /// Faqat aniq shtrix javobi yoki [allowSingleResult] bo'lsa bitta qator.
  static Product? pickAutoAddBarcode(
    Map<String, dynamic> res, {
    bool allowSingleResult = false,
  }) {
    final fromBarcode = fromBarcodeResult(res);
    if (fromBarcode != null) return fromBarcode;
    if (!allowSingleResult) return null;
    final list = fromSalesResponse(res);
    return list.length == 1 ? list.first : null;
  }
}
