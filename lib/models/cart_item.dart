import 'product.dart';

class CartItem {
  final Product product;
  num quantity; // dona yoki pachka soni; o'nli bo'lishi mumkin (masalan 1.8 kg)
  bool sellByPack; // true = pachkada sotilmoqda

  /// Shu savatcha / sotuv uchun 1 dona yoki 1 pachka narxi; null = katalogdagi narx
  double? salePriceOverride;

  /// «Foiz qo'shish» qo'llanishidan oldingi birlik narxi (mijoz chegirmasi keyin).
  double? unitPriceBaseForCartPercent;

  CartItem({
    required this.product,
    this.quantity = 1,
    this.sellByPack = false,
    this.salePriceOverride,
    this.unitPriceBaseForCartPercent,
  });

  CartItem copy() => CartItem(
        product: product,
        quantity: quantity,
        sellByPack: sellByPack,
        salePriceOverride: salePriceOverride,
        unitPriceBaseForCartPercent: unitPriceBaseForCartPercent,
      );

  /// Katalog bo'yicha 1 dona yoki 1 pachka narxi (override siz)
  num get defaultLineUnitPrice {
    if (sellByPack) {
      final pack = product.packSellUnitPriceNum;
      if (pack != null) return pack;
    }
    return product.pieceSellPriceNum;
  }

  /// Qator uchun ishlatiladigan birlik narxi
  double get unitPriceForLine => salePriceOverride ?? defaultLineUnitPrice.toDouble();

  int get unitPriceDisplay => unitPriceForLine.round();

  bool get hasSalePriceOverride => salePriceOverride != null;

  int get total => (unitPriceForLine * quantity).round();

  /// sales/store: bazadagi narx o'zgarmasligi uchun katalog narxi + qator chegirmasi.
  ({int catalogUnitPrice, int lineDiscount, int lineTotal}) get salesStoreLinePricing {
    final catalogUnitPrice = defaultLineUnitPrice.round();
    final lineTotal = total;
    final catalogLineTotal = (defaultLineUnitPrice * quantity).round();
    final diff = catalogLineTotal - lineTotal;
    return (
      catalogUnitPrice: catalogUnitPrice,
      lineDiscount: diff > 0 ? diff : 0,
      lineTotal: lineTotal,
    );
  }

  /// Qator summasi (USD o'nlik uchun)
  double get lineSubtotal => unitPriceForLine * quantity.toDouble();

  /// Ombor dan olib tashlanadigan dona soni (yaxlitlangan)
  int get quantityToDeduct {
    if (sellByPack && product.canSellByPack) {
      return (quantity * product.quantityPerPack).round();
    }
    return quantity.round();
  }
}
