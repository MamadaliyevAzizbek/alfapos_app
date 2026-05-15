import '../models/product.dart';

/// Mahsulotlarni nom / SKU / shtrix-kod (asosiy + qo'shimcha) bo'yicha qidirish.
///
/// Eslatma: qidiruv logikasi bitta joyda bo'lishi uchun Katalog va Savatcha shu funksiyani ishlatadi.
List<Product> filterProductsByQuery(List<Product> products, String query) {
  final raw = query.trim();
  if (raw.isEmpty) return products;
  final q = raw.toLowerCase();
  final rawNorm = Product.normalizeBarcode(raw);
  return products.where((p) {
    if (p.name.toLowerCase().contains(q)) return true;
    if (rawNorm.isNotEmpty && p.matchesBarcode(raw)) return true;
    if (p.sku != null && p.sku!.toLowerCase().contains(q)) return true;
    return false;
  }).toList();
}

