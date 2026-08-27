import 'product.dart';

class CartItem {
  final Product product;
  num quantity; // dona yoki pachka soni; o'nli bo'lishi mumkin (masalan 1.8 kg)
  bool sellByPack; // true = pachkada sotilmoqda

  /// Shu savatcha / sotuv uchun 1 dona yoki 1 pachka narxi; null = katalogdagi narx
  double? salePriceOverride;

  /// «Foiz qo'shish» qo'llanishidan oldingi birlik narxi (mijoz chegirmasi keyin).
  double? unitPriceBaseForCartPercent;

  /// Qo‘lda / pauza-tahrirlashdan tiklangan narx — mijoz guruhi qayta yozmasin.
  bool priceLocked;

  /// «Kerakli summa» dan: miqdor yaxlitlansa ham qator summasi o‘zgarmasin.
  int? lineTotalOverride;

  CartItem({
    required this.product,
    this.quantity = 1,
    this.sellByPack = false,
    this.salePriceOverride,
    this.unitPriceBaseForCartPercent,
    this.priceLocked = false,
    this.lineTotalOverride,
  });

  CartItem copy() => CartItem(
        product: product,
        quantity: quantity,
        sellByPack: sellByPack,
        salePriceOverride: salePriceOverride,
        unitPriceBaseForCartPercent: unitPriceBaseForCartPercent,
        priceLocked: priceLocked,
        lineTotalOverride: lineTotalOverride,
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

  /// Qator jami — kasrli birlik narxi yaxlitlanmasin (`0.678 * 1 = 0.678`).
  num get total {
    if (lineTotalOverride != null) return lineTotalOverride!;
    return quantizeLineTotal(unitPriceForLine * quantity.toDouble());
  }

  /// Hisob/UI uchun 3 xonagacha; butun qiymat `int` qilib qaytariladi.
  static num quantizeLineTotal(double raw) {
    if (raw.isNaN || raw.isInfinite) return 0;
    final q = double.parse(raw.toStringAsFixed(3));
    if ((q - q.roundToDouble()).abs() < 1e-9) return q.round();
    return q;
  }

  void clearLineTotalOverride() => lineTotalOverride = null;

  /// «Kerakli summa»: kilo 3 xonaga yaxlitlanadi, qator summasi [sum] bo‘lib qoladi.
  void applyTargetSum(int sum) {
    if (sum <= 0) return;
    final unit = unitPriceForLine;
    if (unit <= 0) return;
    final qty = double.parse((sum / unit).toStringAsFixed(3));
    if (qty <= 0) return;
    quantity = qty;
    lineTotalOverride = sum;
  }

  /// sales/store: bazadagi narx o'zgarmasligi uchun katalog narxi + qator chegirmasi.
  ({int catalogUnitPrice, num lineDiscount, num lineTotal}) get salesStoreLinePricing {
    final catalogUnitPrice = defaultLineUnitPrice.round();
    final lineTotal = total;
    final catalogLineTotal =
        quantizeLineTotal(defaultLineUnitPrice.toDouble() * quantity.toDouble());
    final diff = catalogLineTotal - lineTotal;
    return (
      catalogUnitPrice: catalogUnitPrice,
      lineDiscount: diff > 0 ? quantizeLineTotal(diff.toDouble()) : 0,
      lineTotal: lineTotal,
    );
  }

  /// Qator summasi (double)
  double get lineSubtotal => total.toDouble();

  /// Ombor dan olib tashlanadigan dona soni (yaxlitlangan)
  int get quantityToDeduct {
    if (sellByPack && product.canSellByPack) {
      return (quantity * product.quantityPerPack).round();
    }
    return quantity.round();
  }
}
