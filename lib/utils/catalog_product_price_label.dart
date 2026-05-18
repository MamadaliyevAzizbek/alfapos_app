import '../core/input_formatters.dart';
import '../models/product.dart';

/// Katalog kartochkasi narxi (sotuv filtri: kelish / ulgurji / oddiy).
class CatalogProductPriceLabel {
  CatalogProductPriceLabel._();

  static String primary(
    Product p, {
    String? sellType,
    double usdRate = 12600,
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
      return p.priceFormatted;
    }
    final sell = p.sellUnitPriceNum.round();
    if (usdRate > 0) {
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
