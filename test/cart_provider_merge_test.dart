import 'package:alfapos_app/models/cart_item.dart';
import 'package:alfapos_app/models/product.dart';
import 'package:alfapos_app/providers/cart_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final cart = CartProvider.instance;

  setUp(() => cart.clear());

  test('bir xil mahsulot miqdor ustiga qo\'shiladi', () {
    final product = Product(id: '42', name: 'salom', priceUzs: 1000);
    cart.add(CartItem(product: product, quantity: 1));
    cart.add(CartItem(product: product, quantity: 1));
    expect(cart.items.length, 1);
    expect(cart.items.first.quantity, 2);
  });

  test('mijoz chegirmasi (salePriceOverride) bo\'lsa ham birlashtiriladi', () {
    final product = Product(id: '42', name: 'salom', priceUzs: 1000);
    cart.add(CartItem(product: product, quantity: 1));
    cart.items.first.salePriceOverride = 900;
    cart.add(CartItem(product: product, quantity: 1));
    expect(cart.items.length, 1);
    expect(cart.items.first.quantity, 2);
    expect(cart.items.first.salePriceOverride, 900);
  });

  test('dona va pachka alohida qator', () {
    final product = Product(
      id: '42',
      name: 'salom',
      priceUzs: 1000,
      quantityInPack: true,
      quantityPerPack: 6,
      sellPricePerPack: 5000,
    );
    cart.add(CartItem(product: product, quantity: 1, sellByPack: false));
    cart.add(CartItem(product: product, quantity: 1, sellByPack: true));
    expect(cart.items.length, 2);
  });
}
