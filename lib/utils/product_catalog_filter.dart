import '../models/product.dart';
import '../providers/categories_provider.dart';

/// Sotuv katalogi — kategoriya / brend bo‘yicha mahalliy filtrlash.
class ProductCatalogFilter {
  ProductCatalogFilter._();

  static List<Product> apply(
    List<Product> items, {
    String? categoryId,
    String? brandId,
    List<Map<String, dynamic>> categories = const [],
    List<Map<String, dynamic>> brands = const [],
  }) {
    final cat = categoryId?.trim();
    final br = brandId?.trim();
    if ((cat == null || cat.isEmpty) && (br == null || br.isEmpty)) {
      return items;
    }
    return items.where((p) {
      if (!_matchesCategory(p, cat, categories)) return false;
      if (!_matchesBrand(p, br, brands)) return false;
      return true;
    }).toList();
  }

  static bool _matchesCategory(
    Product p,
    String? filterId,
    List<Map<String, dynamic>> options,
  ) {
    if (filterId == null || filterId.isEmpty) return true;
    if (p.categoryId == filterId) return true;
    final cat = p.category?.trim();
    if (cat == filterId) return true;
    final name = _optionName(options, filterId);
    if (name != null && cat != null && cat.toLowerCase() == name.toLowerCase()) {
      return true;
    }
    if (cat != null) {
      final idFromName = CategoriesProvider.instance.getCategoryIdByName(cat);
      if (idFromName?.toString() == filterId) return true;
    }
    return false;
  }

  static bool _matchesBrand(
    Product p,
    String? filterId,
    List<Map<String, dynamic>> options,
  ) {
    if (filterId == null || filterId.isEmpty) return true;
    if (p.brandId == filterId) return true;
    final brand = p.brand?.trim();
    if (brand == filterId) return true;
    final name = _optionName(options, filterId);
    if (name != null && brand != null && brand.toLowerCase() == name.toLowerCase()) {
      return true;
    }
    return false;
  }

  static String? _optionName(List<Map<String, dynamic>> options, String id) {
    for (final o in options) {
      if (o['id']?.toString() == id) {
        final n = o['name']?.toString().trim();
        return (n == null || n.isEmpty) ? null : n;
      }
    }
    return null;
  }
}
