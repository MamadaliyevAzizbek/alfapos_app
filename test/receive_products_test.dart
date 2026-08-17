import 'package:alfapos_app/models/product.dart';
import 'package:alfapos_app/utils/receive_products.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
      'mergeProductsWithVariants keeps product title when variant has default_variant',
      () {
    final res = {
      'products': [
        {
          'productID': 42,
          'title': 'Coca Cola 1.5L',
          'purchase_price': 10000,
          'selling_price': 12000,
        },
      ],
      'variants': [
        {
          'product_id': 42,
          'id': 7,
          'title': 'default_variant',
          'availableQuantity': 5,
          'purchase_price': 10000,
          'wholesale_price': 11000,
          'selling_price': 12000,
        },
      ],
    };
    final list = ReceiveProducts.productsFromApiResponse(res);
    expect(list, hasLength(1));
    expect(list.first.id, '42');
    expect(list.first.name, 'Coca Cola 1.5L');
    expect(list.first.variantId, 7);
    expect(list.first.wholesalePriceUzs, 11000);
  });

  test('fromApiJson prefers productTitle when title is variant slug', () {
    final p = Product.fromApiJson({
      'productID': 1,
      'title': 'default_variant',
      'productTitle': 'Non',
    });
    expect(p.name, 'Non');
  });
}
