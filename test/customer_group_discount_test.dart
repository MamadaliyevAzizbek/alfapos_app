import 'package:alfapos_app/models/cart_item.dart';
import 'package:alfapos_app/models/product.dart';
import 'package:alfapos_app/providers/clients_provider.dart';
import 'package:alfapos_app/utils/customer_group_discount.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final product = Product(
    id: '1',
    name: 'Test',
    priceUzs: 10000,
    costPriceUzs: 7000,
    wholesalePriceUzs: 8500,
  );

  final productB = Product(
    id: '2',
    name: 'Test B',
    priceUzs: 8000,
  );

  test('purchase price type uses cost price', () {
    final item = CartItem(product: product, quantity: 1);
    final client = Client(
      id: '1',
      name: 'Mijoz',
      customerGroupDiscountPriceType: 'purchase',
    );
    CustomerGroupDiscount.applyCustomerPricingToCart([item], client);
    expect(item.unitPriceDisplay, 7000);
  });

  test('−10% chegirma (ulgruji narxdan)', () {
    final item = CartItem(product: product, quantity: 1);
    final client = Client(
      id: '1',
      name: 'Mijoz',
      customerGroupDiscountPriceType: 'wholesale',
      customerGroupDiscount: -10,
    );
    CustomerGroupDiscount.applyCustomerPricingToCart([item], client);
    expect(item.unitPriceDisplay, 7000); // 8500 × 0.9 = 7650 → pastga 7000
  });

  test('+10% ustiga qo\'shish (sotish narxi)', () {
    final item = CartItem(product: product, quantity: 1);
    final client = Client(
      id: '1',
      name: 'Mijoz',
      customerGroupDiscountPriceType: 'selling',
      customerGroupDiscount: 10,
    );
    CustomerGroupDiscount.applyCustomerPricingToCart([item], client);
    expect(item.unitPriceDisplay, 11000);
  });

  test('guruh foizi mijozda yo\'q — groups ro\'yxatidan', () {
    final a = CartItem(product: product, quantity: 1);
    final b = CartItem(product: productB, quantity: 1);
    final client = Client(
      id: '1',
      name: 'Mijoz',
      customerGroupId: 5,
      customerGroupDiscountPriceType: 'selling',
    );
    CustomerGroupDiscount.applyCustomerPricingToCart(
      [a, b],
      client,
      groups: [
        {'id': 5, 'title': 'VIP', 'discount': -10},
      ],
    );
    expect(a.unitPriceDisplay, 9000);
    expect(b.unitPriceDisplay, 7000);
  });

  test('applyPercentToUnitPrice', () {
    expect(CustomerGroupDiscount.applyPercentToUnitPrice(10000, -20), 8000);
    expect(CustomerGroupDiscount.applyPercentToUnitPrice(10000, 20), 12000);
  });

  test('clearing customer resets override', () {
    final item = CartItem(product: product, quantity: 1);
    final client = Client(id: '1', name: 'M', customerGroupDiscountPriceType: 'purchase');
    CustomerGroupDiscount.applyCustomerPricingToCart([item], client);
    CustomerGroupDiscount.applyCustomerPricingToCart([item], null);
    expect(item.salePriceOverride, isNull);
  });

  test('priceLocked manual override survives customer select', () {
    final item = CartItem(
      product: product,
      quantity: 1,
      salePriceOverride: 8000,
      unitPriceBaseForCartPercent: 8000,
      priceLocked: true,
    );
    final client = Client(
      id: '1',
      name: 'Mijoz',
      customerGroupDiscountPriceType: 'selling',
      customerGroupDiscount: -10,
    );
    CustomerGroupDiscount.applyCustomerPricingToCart([item], client);
    expect(item.unitPriceDisplay, 8000);
    expect(item.priceLocked, isTrue);

    CustomerGroupDiscount.applyCustomerPricingToCart([item], null);
    expect(item.unitPriceDisplay, 8000);
  });
}
