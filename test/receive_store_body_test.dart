import 'package:alfapos_app/models/product.dart';
import 'package:alfapos_app/models/receive_cart_item.dart';
import 'package:alfapos_app/services/receive_draft_storage.dart';
import 'package:alfapos_app/utils/receive_store_body.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const product = Product(
    id: '10',
    name: 'Non',
    variantId: 20,
    costPriceUzs: 5000,
    wholesalePriceUzs: 5500,
    priceUzs: 6000,
  );

  test('receive cart initializes wholesale price from API product', () {
    final item = ReceiveCartItem(product: product);

    expect(item.wholesalePriceUzs, 5500);
  });

  test('receive store sends wholesale_price in som', () {
    final item = ReceiveCartItem(
      product: product,
      quantity: 2,
      purchasePriceUzs: 5100,
      wholesalePriceUzs: 5700,
      sellPriceUzs: 6200,
    );

    final body = ReceiveStoreBody.build(
      supplierId: 1,
      cart: [item],
      paymentType: const {
        'id': 1,
        'name': 'Naqd pul',
        'type': 'cash',
      },
      grandTotalUzs: 10200,
      date: '2026-08-15',
    );
    final cartRow = (body['cart'] as List).single as Map<String, dynamic>;

    expect(cartRow['purchase_price'], 5100);
    expect(cartRow['wholesale_price'], 5700);
    expect(cartRow['selling_price'], 6200);
    expect(cartRow['price_currency'], 'uzs');
  });

  test('zero wholesale price is sent to clear existing value', () {
    final item = ReceiveCartItem(
      product: product,
      wholesalePriceUzs: 0,
    );

    final body = ReceiveStoreBody.build(
      supplierId: 1,
      cart: [item],
      paymentType: const {'id': 1, 'name': 'Naqd', 'type': 'cash'},
      grandTotalUzs: 5000,
      date: '2026-08-15',
    );
    final cartRow = (body['cart'] as List).single as Map<String, dynamic>;

    expect(cartRow, containsPair('wholesale_price', 0));
  });

  test('usd prices are converted to som before store', () {
    final item = ReceiveCartItem(
      product: product,
      quantity: 2,
      purchasePriceUzs: 5,
      wholesalePriceUzs: 6,
      sellPriceUzs: 7,
      purchaseCurrency: 'usd',
      wholesaleCurrency: 'usd',
      sellCurrency: 'usd',
      purchasePriceApi: 5.25,
      wholesalePriceApi: 6.5,
      sellPriceApi: 7.1,
    );

    final body = ReceiveStoreBody.build(
      supplierId: 1,
      cart: [item],
      paymentType: const {'id': 1, 'name': 'Naqd', 'type': 'cash'},
      grandTotalUzs: 126000,
      date: '2026-08-15',
      usdRate: 12000,
    );
    final cartRow = (body['cart'] as List).single as Map<String, dynamic>;

    expect(cartRow['purchase_price'], 63000);
    expect(cartRow['wholesale_price'], 78000);
    expect(cartRow['selling_price'], 85200);
    expect(cartRow['calculatedPrice'], 126000);
    expect(cartRow['price_currency'], 'uzs');
  });

  // Qoralama endi serverda saqlanadi (MOBILE_RECEIVES_API_UZ.md §6):
  // narxlar so'mga aylantirilib, web bilan bir xil kalitlar bilan yuboriladi.
  test('receive draft uses api cart format with som prices', () {
    final item = ReceiveCartItem(
      product: product,
      purchasePriceUzs: 5,
      purchaseCurrency: 'usd',
      purchasePriceApi: 5.25,
      wholesalePriceUzs: 6,
      wholesaleCurrency: 'usd',
      wholesalePriceApi: 6.25,
      sellPriceUzs: 7,
      sellCurrency: 'usd',
      sellPriceApi: 7.5,
      quantity: 2,
    );

    final json = item.toDraftJson(usdRate: 12000);

    expect(json['productID'], 10);
    expect(json['variantID'], 20);
    expect(json['quantity'], 2);
    expect(json['priceCurrency'], 'uzs');
    expect(json['price'], 63000);
    expect(json['wholesalePrice'], 75000);
    expect(json['sellingPrice'], 90000);
    expect(json['total'], 126000);
  });

  test('receive draft keeps som prices as is without usd rate', () {
    final item = ReceiveCartItem(
      product: product,
      purchasePriceUzs: 8400,
      wholesalePriceUzs: 10000,
      sellPriceUzs: 12000,
    );

    final json = item.toDraftJson();

    expect(json['price'], 8400);
    expect(json['wholesalePrice'], 10000);
    expect(json['sellingPrice'], 12000);
    expect(json['total'], 8400);
  });
}
