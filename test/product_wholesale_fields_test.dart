import 'package:alfapos_app/models/cart_item.dart';
import 'package:alfapos_app/models/product.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('API wholesalePrice faqat dona — pachka hisoblangan', () {
    final p = Product.fromApiJson({
      'productID': 1,
      'title': 'Test',
      'selling_price': 15000,
      'wholesalePrice': 7000,
      'wholesalePriceCurrency': 'uzs',
      'variants': [
        {
          'id': 10,
          'units_per_package': 20,
          'package_selling_price': '8000',
          'package_purchase_price': '5000',
        },
      ],
    });
    expect(p.wholesalePriceUzs, 7000);
    expect(p.wholesalePackUnitPriceNum, 140000);
    expect(p.purchasePackUnitPriceNum, 5000);

    final item = CartItem(product: p, quantity: 1, sellByPack: true);
    expect(item.defaultLineUnitPrice, 8000);
  });

  test('edit-data variantDetails wholesalePrice parse', () {
    final p = Product.fromApiJson({
      'productDetails': {
        'productID': 5,
        'title': 'Test',
        'selling_price': 10000,
      },
      'variantDetails': [
        {
          'id': 10,
          'wholesalePrice': 6500,
          'wholesalePriceCurrency': 'uzs',
        },
      ],
    });
    expect(p.wholesalePriceUzs, 6500);
    expect(p.wholesalePriceDisplayText, contains('6'));
    expect(p.wholesalePriceDisplayText, contains('so'));
  });

  test('mergeWithLocalFallback keeps local fields when API response is partial', () {
    const fromApi = Product(
      id: '42',
      name: 'default_variant',
      priceUzs: 0,
      quantityInfo: '0 dona',
    );
    const local = Product(
      id: 'local_1',
      name: 'Cola 0.5',
      priceUzs: 15000,
      costPriceUzs: 10000,
      barcode: '8600123456789',
      additionalBarcodes: ['8600999888777'],
      quantityInfo: '25 dona',
      unit: 'dona',
      category: 'Ichimliklar',
      initialQuantity: 25,
      wholesalePriceUzs: 12000,
      wholesalePriceCurrency: 'uzs',
    );
    final merged = fromApi.mergeWithLocalFallback(local);
    expect(merged.id, '42');
    expect(merged.name, 'Cola 0.5');
    expect(merged.priceUzs, 15000);
    expect(merged.costPriceUzs, 10000);
    expect(merged.barcode, '8600123456789');
    expect(merged.additionalBarcodes, ['8600999888777']);
    expect(merged.initialQuantity, 25);
    expect(merged.wholesalePriceUzs, 12000);
    expect(merged.category, 'Ichimliklar');
  });

  test('ulgurji narx — barcha variantlardan parse', () {
    final p = Product.fromApiJson({
      'productID': 9,
      'title': 'Test',
      'selling_price': 20000,
      'variants': [
        {'id': 1, 'selling_price': 20000},
        {'id': 2, 'wholesalePrice': 11000, 'wholesalePriceCurrency': 'uzs'},
      ],
    });
    expect(p.wholesalePriceUzs, 11000);
  });

  test('mergePreservingPrices keeps local wholesale when list row lacks it', () {
    const fromList = Product(
      id: '1',
      name: 'A',
      priceUzs: 10000,
    );
    const withWholesale = Product(
      id: '1',
      name: 'A',
      priceUzs: 10000,
      wholesalePriceUzs: 7500,
      wholesalePriceCurrency: 'uzs',
    );
    final merged = fromList.mergePreservingPrices(withWholesale);
    expect(merged.wholesalePriceUzs, 7500);
    expect(merged.wholesalePriceDisplayText, isNot('—'));
  });
}
