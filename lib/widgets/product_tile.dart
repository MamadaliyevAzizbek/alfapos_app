import 'dart:io';
import 'package:flutter/material.dart';
import '../core/product_image_utils.dart';
import '../core/theme.dart';
import '../models/product.dart';
import 'auth_network_image.dart';

/// Mahsulot kartasi: rasm, nom, narx, miqdor (ixtiyoriy: barkod, menyu)
class ProductTile extends StatelessWidget {
  final Product product;
  final VoidCallback? onTap;
  final VoidCallback? onMenu;
  final bool showBarcode;
  final bool showMenu;
  /// Agar berilsa, `product.priceFormatted` o‘rnida ko‘rsatiladi (sotuv filtri).
  final String? primaryPriceLabel;
  final String? secondaryPriceLabel;

  const ProductTile({
    super.key,
    required this.product,
    this.onTap,
    this.onMenu,
    this.showBarcode = true,
    this.showMenu = true,
    this.primaryPriceLabel,
    this.secondaryPriceLabel,
  });

  static Widget _placeholder(double boxSize) {
    return Icon(
      Icons.image_not_supported_rounded,
      color: AppTheme.textSecondary,
      size: boxSize * 0.45,
    );
  }

  /// Katalog kartochkasi: butun maydonni to‘ldiradi (ichki alohida ramka yo‘q).
  static Widget buildProductImageCover(
    Product product, {
    required double width,
    required double height,
  }) {
    final iconSize = (width < height ? width : height) * 0.38;
    final ph = Center(
      child: Icon(Icons.image_not_supported_rounded, color: AppTheme.textSecondary, size: iconSize),
    );

    Widget imageBox(Widget child) => SizedBox(width: width, height: height, child: child);

    final raw = (product.imageUrl ?? '').trim();
    if (raw.isEmpty) {
      return imageBox(ColoredBox(color: const Color(0xFFF0F2F5), child: ph));
    }

    final localFile = File(raw);
    if (localFile.existsSync()) {
      return imageBox(
        Image.file(
          localFile,
          width: width,
          height: height,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => ColoredBox(color: const Color(0xFFF0F2F5), child: ph),
        ),
      );
    }

    final url = ProductImageUtils.resolveToUrl(raw);
    if (url.isEmpty) {
      return imageBox(ColoredBox(color: const Color(0xFFF0F2F5), child: ph));
    }

    return imageBox(
      AuthNetworkImage(
        url: url,
        width: width,
        height: height,
        fit: BoxFit.cover,
        placeholder: ColoredBox(color: const Color(0xFFF0F2F5), child: ph),
      ),
    );
  }

  static Widget buildProductImage(Product product, {double boxSize = 72}) {
    final raw = (product.imageUrl ?? '').trim();
    final ph = _placeholder(boxSize);
    if (raw.isEmpty) return ph;

    final localFile = File(raw);
    if (localFile.existsSync()) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.file(
          localFile,
          fit: BoxFit.cover,
          width: boxSize,
          height: boxSize,
          errorBuilder: (_, __, ___) => ph,
        ),
      );
    }

    final url = ProductImageUtils.resolveToUrl(raw);
    if (url.isEmpty) return ph;

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: AuthNetworkImage(
        url: url,
        width: boxSize,
        height: boxSize,
        fit: BoxFit.cover,
        placeholder: ph,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppTheme.cardBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                clipBehavior: Clip.antiAlias,
                child: ProductTile.buildProductImage(product),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      primaryPriceLabel ?? product.priceFormatted,
                      style: const TextStyle(
                        fontSize: 15,
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (secondaryPriceLabel != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        secondaryPriceLabel!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    const SizedBox(height: 2),
                    Text(
                      'Miqdor: ${product.initialQuantity} ${product.unit ?? 'dona'}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    if (showBarcode) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Barcode: ${product.barcode != null && product.barcode!.isNotEmpty ? product.barcode! : '—'}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (product.additionalBarcodes != null && product.additionalBarcodes!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          "Qo'shimcha: ${product.additionalBarcodes!.take(3).join(', ')}${product.additionalBarcodes!.length > 3 ? '…' : ''}",
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ],
                ),
              ),
              if (showMenu)
                IconButton(
                  icon: const Icon(Icons.more_vert_rounded),
                  onPressed: onMenu,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
