import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Sotuv katalogidagi mahsulotlar tartibi.
enum ProductCatalogSortMode {
  /// API / katalogdagi joriy tartib (o‘zgartirilmaydi).
  defaultOrder,
  newestFirst,
  oldestFirst,
  priceLowFirst,
  priceHighFirst,
}

class ProductCatalogSortSettings {
  ProductCatalogSortSettings._();

  static const _key = 'product_catalog_sort_mode_v1';

  static final ValueNotifier<ProductCatalogSortMode> sortMode =
      ValueNotifier(ProductCatalogSortMode.defaultOrder);

  static Future<ProductCatalogSortMode> getMode() async {
    final prefs = await SharedPreferences.getInstance();
    return _parse(prefs.getString(_key));
  }

  static Future<void> setMode(ProductCatalogSortMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
    sortMode.value = mode;
  }

  static Future<void> load() async {
    sortMode.value = await getMode();
  }

  static String modeLabel(ProductCatalogSortMode mode) {
    switch (mode) {
      case ProductCatalogSortMode.defaultOrder:
        return 'Hozirgi tartib';
      case ProductCatalogSortMode.newestFirst:
        return 'Yangilar birinchi';
      case ProductCatalogSortMode.oldestFirst:
        return 'Eskilar birinchi';
      case ProductCatalogSortMode.priceLowFirst:
        return 'Narxi arzonlar birinchi';
      case ProductCatalogSortMode.priceHighFirst:
        return 'Narxi qimmatlar birinchi';
    }
  }

  static ProductCatalogSortMode _parse(String? raw) {
    switch (raw) {
      case 'newestFirst':
        return ProductCatalogSortMode.newestFirst;
      case 'oldestFirst':
        return ProductCatalogSortMode.oldestFirst;
      case 'priceLowFirst':
        return ProductCatalogSortMode.priceLowFirst;
      case 'priceHighFirst':
        return ProductCatalogSortMode.priceHighFirst;
      default:
        return ProductCatalogSortMode.defaultOrder;
    }
  }
}
