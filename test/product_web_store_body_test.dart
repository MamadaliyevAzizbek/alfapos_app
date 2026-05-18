import 'package:alfapos_app/models/product.dart';
import 'package:alfapos_app/utils/product_web_store_body.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('store body includes wholesale and pack fields', () {
    const product = Product(
      id: '1',
      name: 'Test mahsulot',
      priceUzs: 15000,
      costPriceUzs: 10000,
      quantityInfo: '0 dona',
      quantityInPack: true,
      quantityPerPack: 12,
      costPricePerPack: 110000,
      sellPricePerPack: 165000,
      wholesalePriceUzs: 14000,
      wholesalePriceCurrency: 'uzs',
    );

    final body = ProductWebStoreBody.build(
      product,
      unitId: 2,
      categoryId: 3,
      branchId: 1,
      isCreate: true,
    );

    expect(body['wholesalePrice'], 14000);
    expect(body['wholesalePriceCurrency'], 'uzs');
    expect(body['unitsPerPackage'], 12);
    expect(body['packagePurchasePrice'], 110000);
    expect(body['packageSellingPrice'], 165000);
    expect(body['packageLabel'], 'Pachka');
    expect(body['packagePurchasePriceCurrency'], 'uzs');
    expect(body['packageSellingPriceCurrency'], 'uzs');
    expect(body['variantDetails'], isEmpty);
    expect(body['branch'], 1);
  });

  test('edit body clears pack when disabled', () {
    const product = Product(
      id: '5',
      name: 'Oddiy',
      priceUzs: 5000,
      quantityInfo: '0 dona',
      quantityInPack: false,
      quantityPerPack: 0,
    );

    final body = ProductWebStoreBody.build(
      product,
      unitId: 1,
      variantId: 10,
      isCreate: false,
    );

    expect(body['unitsPerPackage'], isNull);
    expect(body['wholesalePrice'], '');
    expect(body['variantDetails'], isNotEmpty);
    expect(body['variantDetails'][0]['id'], 10);
    expect(body['variantDetails'][0]['wholesalePrice'], '');
  });
}
