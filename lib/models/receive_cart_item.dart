import 'product.dart';

class ReceiveCartItem {
  final Product product;
  num quantity;
  int purchasePriceUzs;
  int sellPriceUzs;
  final String purchaseCurrency;
  final String sellCurrency;

  ReceiveCartItem({
    required this.product,
    this.quantity = 1,
    int? purchasePriceUzs,
    int? sellPriceUzs,
    String? purchaseCurrency,
    String? sellCurrency,
  })  : purchasePriceUzs = purchasePriceUzs ?? product.costPriceUzs ?? 0,
        sellPriceUzs = sellPriceUzs ?? product.priceUzs,
        purchaseCurrency = (purchaseCurrency ?? product.purchasePriceCurrency).toLowerCase(),
        sellCurrency = (sellCurrency ?? product.sellingPriceCurrency).toLowerCase();

  int get lineTotalUzs => (purchasePriceUzs * quantity).round();

  ReceiveCartItem copyWith({
    num? quantity,
    int? purchasePriceUzs,
    int? sellPriceUzs,
  }) {
    return ReceiveCartItem(
      product: product,
      quantity: quantity ?? this.quantity,
      purchasePriceUzs: purchasePriceUzs ?? this.purchasePriceUzs,
      sellPriceUzs: sellPriceUzs ?? this.sellPriceUzs,
      purchaseCurrency: purchaseCurrency,
      sellCurrency: sellCurrency,
    );
  }
}
