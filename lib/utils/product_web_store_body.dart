import '../models/product.dart';

/// Web `POST /products/store` va `POST /products/{id}/edit` body (MOBILE_PRODUCTS_API_UZ.md §3.2).
class ProductWebStoreBody {
  ProductWebStoreBody._();

  static Map<String, dynamic> build(
    Product product, {
    required int? unitId,
    int? categoryId,
    int? branchId,
    int? variantId,
    bool deleteImage = false,
    bool isCreate = true,
  }) {
    final sellNum = product.sellingPriceApi ?? product.priceUzs;
    final recv = product.purchasePriceApi ?? product.costPriceUzs;

    final body = <String, dynamic>{
      'name': product.name.trim(),
      'title': product.name.trim(),
      'alternateTitle': '',
      'nakladnoyTitle': '',
      'type': 0,
      'taxID': 'no-tax',
      'unit': unitId,
      'unit_id': unitId,
      'sallingPrice': sellNum,
      'selling_price': sellNum,
      'sell_price': sellNum,
      'sellingPriceCurrency': product.sellingPriceCurrency.toLowerCase(),
      'purchasePriceCurrency': product.purchasePriceCurrency.toLowerCase(),
      'description': product.description?.trim() ?? '',
      'sku': product.sku?.trim() ?? '',
      'barcode': product.barcode?.trim() ?? '',
      'reorder': product.reorderLevel,
      'reorderLevel': product.reorderLevel,
      'enabled': true,
      'chipValues': <dynamic>[],
      'relatedProducts': <dynamic>[],
    };

    if (isCreate && product.initialQuantity > 0) {
      body['quantity'] = product.initialQuantity;
    }
    if (categoryId != null) {
      body['category'] = categoryId;
      body['category_id'] = categoryId;
    }
    if (branchId != null) {
      body['branch'] = branchId;
      body['branch_id'] = branchId;
    }
    if (recv != null && recv != 0) {
      body['receivingPrice'] = recv;
      body['receiving_price'] = recv;
      body['purchase_price'] = recv;
    }

    final barcodes = product.additionalBarcodes != null
        ? Product.parseAdditionalBarcodes(product.additionalBarcodes)
        : <String>[];
    if (barcodes.isNotEmpty) {
      body['additionalBarcodes'] = barcodes;
      body['additional_barcodes'] = barcodes;
    }

    applyWholesaleFields(body, product);
    applyPackFields(body, product);
    applyWeightField(body, product);

    if (deleteImage) {
      body['image'] = 'DELETE';
    }

    if (isCreate) {
      body['variantDetails'] = <dynamic>[];
    } else if (variantId != null && variantId > 0) {
      body['variantID'] = variantId;
      body['variantDetails'] = [variantDetailEntry(variantId, product)];
    } else {
      body['variantDetails'] = <dynamic>[];
    }

    return body;
  }

  static void applyWholesaleFields(Map<String, dynamic> target, Product product) {
    final cur = product.wholesalePriceCurrency.toLowerCase();
    target['wholesalePriceCurrency'] = cur;
    target['wholesale_price_currency'] = cur;
    final hasWholesale = product.wholesalePriceApi != null ||
        (product.wholesalePriceUzs != null && product.wholesalePriceUzs! > 0);
    if (hasWholesale) {
      final num price = product.wholesalePriceApi ?? product.wholesalePriceUzs ?? 0;
      target['wholesalePrice'] = price;
      target['wholesale_price'] = price;
    } else {
      target['wholesalePrice'] = '';
      target['wholesale_price'] = '';
    }
  }

  static void applyWeightField(Map<String, dynamic> target, Product product) {
    final w = product.weightKg;
    if (w == null || w <= 0) {
      target['weight'] = null;
      return;
    }
    target['weight'] = w;
  }

  static void applyPackFields(Map<String, dynamic> target, Product product) {
    if (!product.quantityInPack || product.quantityPerPack <= 1) {
      target['unitsPerPackage'] = null;
      target['units_per_package'] = null;
      target['packageLabel'] = null;
      target['packagePurchasePrice'] = null;
      target['packageSellingPrice'] = null;
      target['package_purchase_price'] = null;
      target['package_selling_price'] = null;
      return;
    }

    final purchaseCur = product.purchasePriceCurrency.toLowerCase();
    final sellCur = product.sellingPriceCurrency.toLowerCase();
    target['unitsPerPackage'] = product.quantityPerPack;
    target['units_per_package'] = product.quantityPerPack;
    target['packageLabel'] = 'Pachka';
    target['packagePurchasePriceCurrency'] = purchaseCur;
    target['packageSellingPriceCurrency'] = sellCur;
    target['package_purchase_price_currency'] = purchaseCur;
    target['package_selling_price_currency'] = sellCur;

    if (product.sellPricePerPack != null && product.sellPricePerPack! > 0) {
      target['packageSellingPrice'] = product.sellPricePerPack;
      target['package_selling_price'] = product.sellPricePerPack;
    }
    if (product.costPricePerPack != null && product.costPricePerPack! > 0) {
      target['packagePurchasePrice'] = product.costPricePerPack;
      target['package_purchase_price'] = product.costPricePerPack;
    }
  }

  /// `variantDetails[]` — tahrirda variant qatori (web jadvali).
  static Map<String, dynamic> variantDetailEntry(int variantId, Product product) {
    final sellNum = product.sellingPriceApi ?? product.priceUzs;
    final recv = product.purchasePriceApi ?? product.costPriceUzs;
    final row = <String, dynamic>{
      'id': variantId,
      'enabled': true,
      'selling_price': sellNum,
      'sellingPrice': sellNum,
      'purchasePriceCurrency': product.purchasePriceCurrency.toLowerCase(),
      'sellingPriceCurrency': product.sellingPriceCurrency.toLowerCase(),
      'reOrder': product.reorderLevel,
    };
    if (recv != null && recv != 0) {
      row['purchase_price'] = recv;
      row['purchasePrice'] = recv;
      row['receivingPrice'] = recv;
    }
    final bc = product.barcode?.trim();
    if (bc != null && bc.isNotEmpty) {
      row['barcode'] = bc;
      row['bar_code'] = bc;
    }
    if (product.sku != null && product.sku!.trim().isNotEmpty) {
      row['sku'] = product.sku!.trim();
    }
    applyPackFields(row, product);
    applyWholesaleFields(row, product);
    return row;
  }
}
