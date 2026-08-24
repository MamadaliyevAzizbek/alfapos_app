import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/product.dart';
import '../providers/categories_provider.dart';
import '../utils/catalog_product_price_label.dart';
import 'product_tile.dart';

/// Desktop mahsulotlar ro‘yxati — ustunli jadval (mobil grid emas).
class DesktopCatalogProductTable extends StatelessWidget {
  const DesktopCatalogProductTable({
    super.key,
    required this.products,
    required this.usdRate,
    required this.onProductTap,
    required this.onEdit,
    required this.onDelete,
    required this.canDeleteProducts,
  });

  final List<Product> products;
  final double usdRate;
  final ValueChanged<Product> onProductTap;
  final ValueChanged<Product> onEdit;
  final ValueChanged<Product> onDelete;
  final bool canDeleteProducts;

  static const _thStyle = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w700,
    color: AppTheme.textSecondary,
    letterSpacing: 0.3,
  );

  static const _priceGreen = Color(0xFF16A34A);
  static const _titleBlue = Color(0xFF2563EB);
  static const _actionColWidth = 60.0;
  static const _imageColWidth = 72.0;

  static String _resolveCategoryLabel(Product p) {
    final cat = p.category?.trim();
    if (cat != null && cat.isNotEmpty && !RegExp(r'^\d+$').hasMatch(cat)) {
      return cat;
    }
    final id = (p.categoryId?.trim().isNotEmpty == true ? p.categoryId : cat)?.trim();
    if (id != null && id.isNotEmpty) {
      for (final row in CategoriesProvider.instance.rawList) {
        if (row['id']?.toString() == id) {
          final name = (row['name'] as String? ??
                  row['title'] as String? ??
                  row['category_name'] as String? ??
                  '')
              .trim();
          if (name.isNotEmpty) return name;
        }
      }
    }
    if (cat != null && cat.isNotEmpty) return cat;
    return '—';
  }

  static String _cellText(String? value) {
    final v = value?.trim();
    if (v == null || v.isEmpty) return '—';
    return v;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppTheme.divider),
          borderRadius: BorderRadius.circular(8),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Column(
            children: [
              Container(
                color: const Color(0xFFF8FAFC),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Row(
                  children: [
                    const SizedBox(
                      width: _imageColWidth,
                      child: Text('RASM', style: _thStyle),
                    ),
                    const Expanded(flex: 4, child: Text('SARLAVHA', style: _thStyle)),
                    const Expanded(flex: 2, child: Text('KATEGORIYA', style: _thStyle)),
                    const Expanded(flex: 2, child: Text('BREND', style: _thStyle)),
                    const Expanded(flex: 2, child: Text('TAMINOTCHI', style: _thStyle)),
                    const Expanded(
                      flex: 2,
                      child: Text('XARID NARXI', style: _thStyle, textAlign: TextAlign.end),
                    ),
                    const Expanded(
                      flex: 2,
                      child: Text('SOTUV NARXI', style: _thStyle, textAlign: TextAlign.end),
                    ),
                    const Expanded(
                      flex: 1,
                      child: Text('MIQDORI', style: _thStyle, textAlign: TextAlign.center),
                    ),
                    const SizedBox(
                      width: _actionColWidth,
                      child: Text('AMAL', style: _thStyle, textAlign: TextAlign.center),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final p = products[index];
                    return _DesktopCatalogProductRow(
                      product: p,
                      index: index,
                      usdRate: usdRate,
                      categoryLabel: _resolveCategoryLabel(p),
                      onTap: () => onProductTap(p),
                      onEdit: () => onEdit(p),
                      onDelete: () => onDelete(p),
                      canDeleteProducts: canDeleteProducts,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DesktopCatalogProductRow extends StatelessWidget {
  const _DesktopCatalogProductRow({
    required this.product,
    required this.index,
    required this.usdRate,
    required this.categoryLabel,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.canDeleteProducts,
  });

  final Product product;
  final int index;
  final double usdRate;
  final String categoryLabel;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool canDeleteProducts;

  static const _cellFont = 15.0;

  @override
  Widget build(BuildContext context) {
    final bg = index.isEven ? Colors.white : const Color(0xFFFAFBFC);
    final purchaseLabel = _purchaseLabel(product);
    final sellLabel = CatalogProductPriceLabel.primary(
      product,
      usdRate: usdRate,
      showUsdEquivalent: true,
    );

    return Material(
      color: bg,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppTheme.divider)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: DesktopCatalogProductTable._imageColWidth,
                height: 72,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: ProductTile.buildProductImageCover(
                    product,
                    width: DesktopCatalogProductTable._imageColWidth,
                    height: 72,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 4,
                child: Text(
                  product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: _cellFont,
                    color: DesktopCatalogProductTable._titleBlue,
                    height: 1.25,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  categoryLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: _cellFont, color: AppTheme.textPrimary),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  DesktopCatalogProductTable._cellText(product.brand),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: _cellFont, color: AppTheme.textPrimary),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  '—',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: _cellFont, color: AppTheme.textSecondary),
                ),
              ),
              Expanded(
                flex: 2,
                child: purchaseLabel == null
                    ? const Text(
                        '—',
                        textAlign: TextAlign.end,
                        style: TextStyle(fontSize: _cellFont, color: AppTheme.textSecondary),
                      )
                    : CatalogProductPriceLabel.text(
                        purchaseLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                        style: const TextStyle(
                          fontSize: _cellFont,
                          fontWeight: FontWeight.w600,
                          color: DesktopCatalogProductTable._priceGreen,
                        ),
                      ),
              ),
              Expanded(
                flex: 2,
                child: CatalogProductPriceLabel.text(
                  sellLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    fontSize: _cellFont,
                    fontWeight: FontWeight.w600,
                    color: DesktopCatalogProductTable._priceGreen,
                  ),
                ),
              ),
              Expanded(
                flex: 1,
                child: Center(
                  child: Text(
                    '${product.availableStockQuantity}',
                    style: const TextStyle(
                      fontSize: _cellFont,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: DesktopCatalogProductTable._actionColWidth,
                child: PopupMenuButton<String>(
                  tooltip: 'Amallar',
                  color: Colors.white,
                  elevation: 8,
                  surfaceTintColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: AppTheme.divider),
                  ),
                  icon: const Icon(
                    Icons.more_vert_rounded,
                    color: AppTheme.textSecondary,
                  ),
                  onSelected: (value) {
                    if (value == 'edit') onEdit();
                    if (value == 'delete') onDelete();
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem<String>(
                      value: 'edit',
                      child: Text('Tahrirlash'),
                    ),
                    if (canDeleteProducts)
                      const PopupMenuItem<String>(
                        value: 'delete',
                        child: Text('O\'chirish'),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _purchaseLabel(Product p) {
    final cost = p.costPriceUzs;
    if (cost == null || cost <= 0) return null;
    return CatalogProductPriceLabel.primary(
      p,
      sellType: 'purchase',
      usdRate: usdRate,
      showUsdEquivalent: true,
    );
  }
}
