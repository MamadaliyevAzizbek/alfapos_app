import 'package:alfapos_app/models/cart_item.dart';
import 'package:alfapos_app/models/product.dart';
import 'package:alfapos_app/utils/cart_discount_percent.dart';
import 'package:alfapos_app/utils/cart_payment_discount.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('distributeDiscount sums exactly to discount total', () {
    final weights = [100000, 112000];
    const discount = 12000;
    final parts = CartPaymentDiscount.distributeDiscount(weights, discount);
    expect(parts.fold<int>(0, (a, b) => a + b), discount);
  });

  test('applyCustomerPayment reaches exact paid total (212000 -> 200000)', () {
    final items = [
      CartItem(product: Product(id: '1', name: 'A', priceUzs: 100000), quantity: 1),
      CartItem(product: Product(id: '2', name: 'B', priceUzs: 112000), quantity: 1),
    ];
    for (final i in items) {
      CartDiscountPercent.initNewItem(i);
    }
    final before = items.fold<int>(0, (s, e) => s + e.total);
    expect(before, 212000);

    CartPaymentDiscount.applyCustomerPayment(items, 200000);

    final after = items.fold<int>(0, (s, e) => s + e.total);
    expect(after, 200000);
    expect(before - after, 12000);

    final lineDiscounts = items.map((e) => e.salesStoreLinePricing.lineDiscount).toList();
    expect(lineDiscounts.fold<int>(0, (a, b) => a + b), 12000);
  });

  test('applyCustomerPayment with multiple quantities', () {
    final items = [
      CartItem(product: Product(id: '1', name: 'A', priceUzs: 50000), quantity: 2),
      CartItem(product: Product(id: '2', name: 'B', priceUzs: 30000), quantity: 3),
    ];
    for (final i in items) {
      CartDiscountPercent.initNewItem(i);
    }
    const paid = 150000;
    CartPaymentDiscount.applyCustomerPayment(items, paid);
    expect(items.fold<int>(0, (s, e) => s + e.total), paid);
  });
}
