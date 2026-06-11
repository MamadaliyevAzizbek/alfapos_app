import '../models/product.dart';
import '../services/product_catalog_sort_settings.dart';

/// Mahsulot ro‘yxatini sotuv sozlamasi bo‘yicha saralash.
class ProductCatalogSort {
  ProductCatalogSort._();

  static List<Product> apply(
    List<Product> products, {
    ProductCatalogSortMode mode = ProductCatalogSortMode.defaultOrder,
    double usdRate = 12600,
  }) {
    if (mode == ProductCatalogSortMode.defaultOrder || products.length < 2) {
      return List<Product>.from(products);
    }

    final indexed = products.asMap().entries.toList();
    indexed.sort((a, b) {
      final cmp = _compare(a.value, b.value, mode, usdRate);
      return cmp != 0 ? cmp : a.key.compareTo(b.key);
    });
    return indexed.map((e) => e.value).toList();
  }

  static int _compare(
    Product a,
    Product b,
    ProductCatalogSortMode mode,
    double usdRate,
  ) {
    switch (mode) {
      case ProductCatalogSortMode.defaultOrder:
        return 0;
      case ProductCatalogSortMode.newestFirst:
        return _idSortKey(b).compareTo(_idSortKey(a));
      case ProductCatalogSortMode.oldestFirst:
        return _idSortKey(a).compareTo(_idSortKey(b));
      case ProductCatalogSortMode.priceLowFirst:
        return _sellPriceSom(a, usdRate).compareTo(_sellPriceSom(b, usdRate));
      case ProductCatalogSortMode.priceHighFirst:
        return _sellPriceSom(b, usdRate).compareTo(_sellPriceSom(a, usdRate));
    }
  }

  static int _idSortKey(Product p) {
    final raw = p.id.trim();
    final numeric = int.tryParse(raw.replaceFirst(RegExp(r'^local_'), ''));
    if (numeric != null) return numeric;
    return raw.hashCode;
  }

  static int _sellPriceSom(Product p, double usdRate) {
    if (p.sellingPriceCurrency.toLowerCase() == 'usd' && usdRate > 0) {
      return (p.pieceSellPriceNum * usdRate).round();
    }
    return p.pieceSellPriceNum.round();
  }
}
