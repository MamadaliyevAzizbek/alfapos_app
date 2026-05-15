import 'dart:io';
import 'package:flutter/material.dart';
import '../core/product_image_utils.dart';
import '../core/theme.dart';
import '../models/product.dart';
import '../widgets/auth_network_image.dart';

/// Mahsulot haqida ma'lumotlar: rasm, o'lchov birlik, kategoriya, shtrix kod, narxlar
class MahsulotDetailScreen extends StatelessWidget {
  final Product product;

  const MahsulotDetailScreen({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    final previewW = MediaQuery.sizeOf(context).width - 32;
    final rawImage = (product.imageUrl ?? '').trim();
    final bool isLocalFile = rawImage.isNotEmpty && File(rawImage).existsSync();
    final imageUrl = rawImage.isEmpty ? '' : ProductImageUtils.resolveToUrl(rawImage);
    final imagePlaceholder = Center(
      child: Icon(
        Icons.image_not_supported_rounded,
        size: 64,
        color: AppTheme.textSecondary.withValues(alpha: 0.5),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text("Mahsulot haqida"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Mahsulot rasmi
            Container(
              height: 220,
              decoration: BoxDecoration(
                color: AppTheme.cardBg,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: imageUrl.isNotEmpty
                    ? isLocalFile
                        ? Image.file(
                            File(rawImage),
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: 220,
                            errorBuilder: (_, __, ___) => imagePlaceholder,
                          )
                        : AuthNetworkImage(
                            url: imageUrl,
                            width: previewW,
                            height: 220,
                            fit: BoxFit.cover,
                            placeholder: imagePlaceholder,
                          )
                    : imagePlaceholder,
              ),
            ),
            const SizedBox(height: 24),
            // Ma'lumotlar jadvali
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.divider),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _detailRow(context, "O'lchov birlik", product.unit ?? '—'),
                  _divider(),
                  _detailRow(context, "Ombordagi miqdor", '${product.initialQuantity} ${product.unit ?? 'dona'}'),
                  _divider(),
                  _detailRow(context, "Mahsulot turi", product.category ?? 'Standart'),
                  _divider(),
                  _detailRow(context, "Shtrix kod", product.barcode ?? '—'),
                  if (product.additionalBarcodes != null && product.additionalBarcodes!.isNotEmpty) ...[
                    _divider(),
                    _detailRow(
                      context,
                      "Qo'shimcha shtrix kodlar",
                      product.additionalBarcodes!.join(', '),
                    ),
                  ],
                  _divider(),
                  _detailRow(
                    context,
                    "Sotuv narxi",
                    product.priceFormatted,
                    valueColor: const Color(0xFF2E7D32),
                  ),
                  _divider(),
                  _detailRow(
                    context,
                    "Kirim narxi",
                    product.purchasePriceDisplayText,
                    valueColor: const Color(0xFF2E7D32),
                  ),
                  // API: pachka — units_per_package > 1 bo'lganda; package_selling_price, package_purchase_price
                  if (product.quantityInPack && product.quantityPerPack > 1) ...[
                    _divider(),
                    _detailRow(context, "1 pachkada (dona)", '${product.quantityPerPack}'),
                    _divider(),
                    _detailRow(
                      context,
                      "Pachka sotuv narxi",
                      product.sellPricePerPack != null && product.sellPricePerPack! > 0
                          ? _formatPrice(product.sellPricePerPack!)
                          : '—',
                      valueColor: product.sellPricePerPack != null && product.sellPricePerPack! > 0 ? const Color(0xFF2E7D32) : null,
                    ),
                    _divider(),
                    _detailRow(
                      context,
                      "Pachka kirim narxi",
                      product.costPricePerPack != null && product.costPricePerPack! > 0
                          ? _formatPrice(product.costPricePerPack!)
                          : '—',
                      valueColor: product.costPricePerPack != null && product.costPricePerPack! > 0 ? const Color(0xFF2E7D32) : null,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(BuildContext context, String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: valueColor ?? AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return const Divider(height: 1, indent: 16, endIndent: 16, color: AppTheme.divider);
  }

  String _formatPrice(int sum) {
    final s = sum.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}
