import '../models/product.dart';
import '../providers/sales_session_provider.dart';

/// Katalogda mahsulot saqlangandan keyin sotuv sessiyasini yangilash.
class ProductCatalogSalesBridge {
  ProductCatalogSalesBridge._();

  static Future<void> afterProductSaved(Product product) {
    return SalesSessionProvider.instance.onCatalogProductSaved(product);
  }
}
