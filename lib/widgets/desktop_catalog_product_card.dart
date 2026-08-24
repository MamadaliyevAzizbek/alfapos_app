import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/product.dart';
import '../utils/catalog_product_price_label.dart';
import 'product_tile.dart';

/// Desktop katalog kartochkasi (sotuv / mahsulotlar grid).
class DesktopCatalogProductCard extends StatelessWidget {
  const DesktopCatalogProductCard({
    super.key,
    required this.product,
    required this.usdRate,
    required this.onTap,
    this.catalogSellPriceType,
    this.showPurchasePrice = false,
    this.showUsdEquivalent = false,
    this.showSkuInTitle = false,
    this.compact = false,
    this.onBarcodePrint,
  });

  final Product product;
  final double usdRate;
  final String? catalogSellPriceType;
  final bool showPurchasePrice;
  final bool showUsdEquivalent;
  final bool showSkuInTitle;
  final bool compact;
  final VoidCallback onTap;
  final VoidCallback? onBarcodePrint;

  static const _priceGreen = Color(0xFF16A34A);

  @override
  Widget build(BuildContext context) {
    final qty = product.availableStockQuantity;
    final primary = CatalogProductPriceLabel.primary(
      product,
      sellType: catalogSellPriceType,
      usdRate: usdRate,
      showUsdEquivalent: showUsdEquivalent,
    );
    final purchase =
        showPurchasePrice ? CatalogProductPriceLabel.purchaseLine(product) : null;

    return Material(
      color: Colors.white,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
        side: BorderSide(color: AppTheme.divider),
      ),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final image = ProductTile.buildProductImageCover(
                    product,
                    width: constraints.maxWidth,
                    height: constraints.maxHeight,
                  );
                  if (onBarcodePrint == null) return image;
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      image,
                      Positioned(
                        top: compact ? 3 : 5,
                        right: compact ? 3 : 5,
                        child: Material(
                          color: Colors.white.withValues(alpha: 0.94),
                          elevation: 1,
                          borderRadius: BorderRadius.circular(6),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: onBarcodePrint,
                            child: Padding(
                              padding: EdgeInsets.all(compact ? 3 : 4),
                              child: Icon(
                                Icons.barcode_reader,
                                size: compact ? 14 : 16,
                                color: AppTheme.primary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                compact ? 6 : 8,
                compact ? 4 : 6,
                compact ? 6 : 8,
                compact ? 6 : 8,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: compact ? 12 : 14,
                        color: AppTheme.textSecondary,
                      ),
                      SizedBox(width: compact ? 3 : 4),
                      Expanded(
                        child: Text(
                          showSkuInTitle ? product.nameWithSku : product.name,
                          maxLines: compact ? 1 : 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: compact ? 10 : 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                            height: 1.15,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: compact ? 4 : 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CatalogProductPriceLabel.text(
                              primary,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: compact ? 11 : 14,
                                fontWeight: FontWeight.w700,
                                color: _priceGreen,
                              ),
                            ),
                            if (purchase != null)
                              Text(
                                purchase,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: compact ? 9 : 10,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Text(
                        '$qty',
                        style: TextStyle(
                          fontSize: compact ? 10 : 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
