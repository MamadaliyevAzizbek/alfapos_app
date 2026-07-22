import '../models/product.dart';
import '../providers/products_provider.dart';
import '../services/api_service.dart';
import '../utils/product_search.dart';
import '../utils/sales_products.dart';

/// Shtrix kod bo‘yicha mahsulot — Katalog va Sotuv bir xil zanjir.
class BarcodeProductLookup {
  BarcodeProductLookup._();

  /// 1) To‘liq mahalliy katalog  2) Sotuv ekranidagi ro‘yxat  3) server barcode-search  4) server sales/products qidiruv.
  static Future<Product?> resolve({
    required String query,
    List<Product> salesScreenProducts = const [],
    int branchId = 1,
  }) async {
    final q = query.trim();
    if (q.isEmpty) return null;

    final catalog = ProductsProvider.instance;
    if (!catalog.isLoaded || catalog.items.isEmpty) {
      try {
        await catalog.loadFromStorage();
      } catch (_) {}
    }

    final fromCatalog = filterProductsByBarcodeQuery(catalog.items, q);
    if (fromCatalog.length == 1) return fromCatalog.single;

    if (salesScreenProducts.isNotEmpty) {
      final fromSalesList = filterProductsByBarcodeQuery(salesScreenProducts, q);
      if (fromSalesList.length == 1) return fromSalesList.single;
    }

    try {
      final res = await SalesApi.barcodeSearch(
        searchValue: q,
        branchId: branchId,
      );
      final direct = SalesProducts.fromBarcodeResult(res);
      if (direct != null && direct.matchesBarcode(q)) return direct;
      final picked = SalesProducts.pickAutoAddBarcode(res, allowSingleResult: true);
      if (picked != null && picked.matchesBarcode(q)) return picked;
    } catch (_) {}

    try {
      final fromProductsApi = await catalog.findProductByBarcode(q);
      if (fromProductsApi != null) return fromProductsApi;
    } catch (_) {}

    return null;
  }
}
