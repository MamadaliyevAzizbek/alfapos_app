import '../core/input_formatters.dart';
import '../models/product.dart';

/// Katalog kartochkasi narxi (sotuv filtri: kelish / ulgurji / oddiy).
class CatalogProductPriceLabel {
  CatalogProductPriceLabel._();

  static String primary(
    Product p, {
    String? sellType,
    double usdRate = 12600,
    bool showUsdEquivalent = false,
  }) {
    switch (sellType) {
      case 'purchase':
        final cost = p.costPriceUzs;
        if (cost != null && cost > 0) {
          return '${formatThousands(cost)} so\'m';
        }
        break;
      case 'wholesale':
        return '${formatThousands(p.wholesalePiecePriceNum.round())} so\'m';
    }

    if (p.sellingPriceCurrency.toLowerCase() == 'usd') {
      if (showUsdEquivalent) {
        return p.priceFormatted;
      }
      if (usdRate > 0) {
        final som = (p.sellUnitPriceNum * usdRate).round();
        return '${formatThousands(som)} so\'m';
      }
      return p.priceFormatted;
    }

    final sell = p.sellUnitPriceNum.round();
    if (showUsdEquivalent && usdRate > 0) {
      final usd = p.sellUnitPriceNum / usdRate;
      return '${formatThousands(sell)} (\$${usd.toStringAsFixed(2)})';
    }
    return '${formatThousands(sell)} so\'m';
  }

  static String? purchaseLine(Product p) {
    final c = p.costPriceUzs;
    if (c == null || c <= 0) return null;
    return 'Kelish: ${formatThousands(c)}';
  }
}
