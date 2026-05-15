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

  const ProductTile({
    super.key,
    required this.product,
    this.onTap,
    this.onMenu,
    this.showBarcode = true,
    this.showMenu = true,
  });

  static Widget _placeholder(double boxSize) {
    return Icon(
      Icons.image_not_supported_rounded,
      color: AppTheme.textSecondary,
      size: boxSize * 0.45,
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
                      product.priceFormatted,
                      style: const TextStyle(
                        fontSize: 15,
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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
                          "Qo'shimcha: ${product.additionalBarcodes!.join(', ')}",
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
