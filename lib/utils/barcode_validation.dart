import '../models/product.dart';

/// Shtrix kod dublikatini tekshirish (yangi mahsulot / tahrirlash).
class BarcodeValidation {
  BarcodeValidation._();

  /// Forma ichida yoki katalogda dublikat bo'lsa xabar; yo'q bo'lsa null.
  static String? validateForSave({
    required List<String> barcodes,
    required List<Product> catalog,
    String? excludeProductId,
  }) {
    final trimmed = barcodes.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (trimmed.isEmpty) return null;

    final within = _findWithinListDuplicate(trimmed);
    if (within != null) return within;

    for (final bc in trimmed) {
      for (final p in catalog) {
        if (excludeProductId != null && p.id == excludeProductId) continue;
        if (p.matchesBarcode(bc)) {
          return 'Dublikat shtrix kod: $bc («${p.name}» mahsulotida mavjud). Boshqa kod kiriting.';
        }
      }
    }
    return null;
  }

  /// Bir xil mahsulot ichidagi barcha kodlar (asosiy + qo'shimcha).
  static List<String> collectFromProduct(Product product) {
    final list = <String>[];
    final main = product.barcode?.trim();
    if (main != null && main.isNotEmpty) list.add(main);
    final adds = Product.parseAdditionalBarcodes(product.additionalBarcodes);
    list.addAll(adds);
    return list;
  }

  static String? _findWithinListDuplicate(List<String> barcodes) {
    final seen = <String, String>{};
    for (final raw in barcodes) {
      final key = _matchKey(raw);
      if (key.isEmpty) continue;
      if (seen.containsKey(key)) {
        return 'Dublikat shtrix kod: $raw (forma ichida takror — ${seen[key]})';
      }
      seen[key] = raw;
    }
    return null;
  }

  static String _matchKey(String raw) {
    final digits = Product.normalizeBarcode(raw);
    if (digits.isEmpty) return raw.toLowerCase();
    final trimmed = digits.replaceFirst(RegExp(r'^0+'), '');
    return trimmed.isEmpty ? '0' : trimmed;
  }
}
