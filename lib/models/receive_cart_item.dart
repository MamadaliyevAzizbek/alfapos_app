import 'product.dart';

class ReceiveCartItem {
  final Product product;
  num quantity;
  int purchasePriceUzs;
  int wholesalePriceUzs;
  int sellPriceUzs;
  String purchaseCurrency;
  String wholesaleCurrency;
  String sellCurrency;
  num? purchasePriceApi;
  num? wholesalePriceApi;
  num? sellPriceApi;

  ReceiveCartItem({
    required this.product,
    this.quantity = 1,
    int? purchasePriceUzs,
    int? wholesalePriceUzs,
    int? sellPriceUzs,
    String? purchaseCurrency,
    String? wholesaleCurrency,
    String? sellCurrency,
    num? purchasePriceApi,
    num? wholesalePriceApi,
    num? sellPriceApi,
  })  : purchasePriceUzs = purchasePriceUzs ?? product.costPriceUzs ?? 0,
        wholesalePriceUzs = wholesalePriceUzs ?? product.wholesalePriceUzs ?? 0,
        sellPriceUzs = sellPriceUzs ?? product.priceUzs,
        purchaseCurrency =
            (purchaseCurrency ?? product.purchasePriceCurrency).toLowerCase(),
        wholesaleCurrency =
            (wholesaleCurrency ?? product.wholesalePriceCurrency).toLowerCase(),
        sellCurrency =
            (sellCurrency ?? product.sellingPriceCurrency).toLowerCase(),
        purchasePriceApi = purchasePriceApi ?? product.purchasePriceApi,
        wholesalePriceApi = wholesalePriceApi ?? product.wholesalePriceApi,
        sellPriceApi = sellPriceApi ?? product.sellingPriceApi;

  int get lineTotalUzs => lineTotalInUzs();

  int lineTotalInUzs({double usdRate = 1}) =>
      (unitPurchaseInUzs(usdRate: usdRate) * quantity).round();

  int unitPurchaseInUzs({double usdRate = 1}) =>
      _toUzs(purchasePriceUzs, purchaseCurrency, purchasePriceApi, usdRate);

  int unitWholesaleInUzs({double usdRate = 1}) =>
      _toUzs(wholesalePriceUzs, wholesaleCurrency, wholesalePriceApi, usdRate);

  int unitSellInUzs({double usdRate = 1}) =>
      _toUzs(sellPriceUzs, sellCurrency, sellPriceApi, usdRate);

  static int _toUzs(int display, String currency, num? api, double usdRate) {
    if (currency.toLowerCase() != 'usd') return display;
    final v = api ?? display;
    if (usdRate > 0) return (v * usdRate).round();
    return v.round();
  }

  ReceiveCartItem copyWith({
    num? quantity,
    int? purchasePriceUzs,
    int? wholesalePriceUzs,
    int? sellPriceUzs,
    String? purchaseCurrency,
    String? wholesaleCurrency,
    String? sellCurrency,
    num? purchasePriceApi,
    num? wholesalePriceApi,
    num? sellPriceApi,
  }) {
    return ReceiveCartItem(
      product: product,
      quantity: quantity ?? this.quantity,
      purchasePriceUzs: purchasePriceUzs ?? this.purchasePriceUzs,
      wholesalePriceUzs: wholesalePriceUzs ?? this.wholesalePriceUzs,
      sellPriceUzs: sellPriceUzs ?? this.sellPriceUzs,
      purchaseCurrency: purchaseCurrency ?? this.purchaseCurrency,
      wholesaleCurrency: wholesaleCurrency ?? this.wholesaleCurrency,
      sellCurrency: sellCurrency ?? this.sellCurrency,
      purchasePriceApi: purchasePriceApi ?? this.purchasePriceApi,
      wholesalePriceApi: wholesalePriceApi ?? this.wholesalePriceApi,
      sellPriceApi: sellPriceApi ?? this.sellPriceApi,
    );
  }
}
