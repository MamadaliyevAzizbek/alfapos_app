import 'product.dart';

class CartItem {
  final Product product;
  num quantity; // dona yoki pachka soni; o'nli bo'lishi mumkin (masalan 1.8 kg)
  final bool sellByPack; // true = pachkada sotilmoqda

  /// Shu savatcha / sotuv uchun 1 dona yoki 1 pachka narxi; null = katalogdagi narx
  double? salePriceOverride;

  CartItem({
    required this.product,
    this.quantity = 1,
    this.sellByPack = false,
    this.salePriceOverride,
  });

  /// Katalog bo'yicha 1 dona yoki 1 pachka narxi (override siz)
  num get defaultLineUnitPrice {
    if (sellByPack && product.quantityInPack && product.sellPricePerPack != null) {
      return product.sellPricePerPack!;
    }
    return product.sellUnitPriceNum;
  }

  /// Qator uchun ishlatiladigan birlik narxi
  double get unitPriceForLine => salePriceOverride ?? defaultLineUnitPrice.toDouble();

  int get unitPriceDisplay => unitPriceForLine.round();

  bool get hasSalePriceOverride => salePriceOverride != null;

  int get total => (unitPriceForLine * quantity).round();

  /// Qator summasi (USD o'nlik uchun)
  double get lineSubtotal => unitPriceForLine * quantity.toDouble();

  /// Ombor dan olib tashlanadigan dona soni (yaxlitlangan)
  int get quantityToDeduct {
    if (sellByPack && product.quantityInPack && product.quantityPerPack > 0) {
      return (quantity * product.quantityPerPack).round();
    }
    return quantity.round();
  }
}
