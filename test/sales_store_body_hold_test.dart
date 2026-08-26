import 'package:alfapos_app/models/cart_item.dart';
import 'package:alfapos_app/models/product.dart';
import 'package:alfapos_app/utils/sales_store_body.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('hold body matches web POS (no payments, discount sum, profit)', () {
    final items = [
      CartItem(
        product: Product(id: '5', name: 'Fanta', priceUzs: 21000, variantId: 1),
        quantity: 1,
      ),
    ];
    final body = SalesStoreBody.build(
      items: items,
      subTotal: 21000,
      grandTotal: 16800,
      status: 'hold',
      discountPercent: -20,
      cashRegisterId: 3,
      registerLogId: 45,
      customerId: 1,
    );

    expect(body['status'], 'hold');
    expect(body.containsKey('payments'), isFalse);
    expect(body['discount'], 4200);
    expect(body['grandTotal'], 16800);
    expect(body['profit'], isA<int>());
    expect(body['customer'], {'id': 1});
    expect(body['cashRagisterId'], 3);
    expect(body['register_log_id'], 45);
    expect(body['isCashRegisterBranch'], true);
    final cart = body['cart'] as List;
    expect(cart.first['cartItemNote'], 'alfapos_sold_unit=21000');
    expect(cart.first['soldUnitPrice'], 21000);
  });

  test('hold cartItemNote keeps discounted sold unit', () {
    final items = [
      CartItem(
        product: Product(id: '5', name: 'Fanta', priceUzs: 21000, variantId: 1),
        quantity: 1,
        salePriceOverride: 16800,
        priceLocked: true,
      ),
    ];
    final body = SalesStoreBody.build(
      items: items,
      subTotal: 21000,
      grandTotal: 16800,
      status: 'hold',
    );
    final cart = body['cart'] as List;
    expect(cart.first['price'], 21000);
    expect(cart.first['discount'], 4200);
    expect(cart.first['calculatedPrice'], 16800);
    expect(cart.first['soldUnitPrice'], 16800);
    expect(cart.first['cartItemNote'], 'alfapos_sold_unit=16800');
  });

  test('done body includes sale note when izoh yozilgan', () {
    final items = [
      CartItem(
        product: Product(id: '5', name: 'Fanta', priceUzs: 21000, variantId: 1),
        quantity: 1,
      ),
    ];
    final body = SalesStoreBody.build(
      items: items,
      subTotal: 21000,
      grandTotal: 21000,
      status: 'done',
      payments: const [],
      note: 'Tez yetkaz',
    );
    expect(body['description'], 'Tez yetkaz');
    expect(body['note'], 'Tez yetkaz');
  });

  test('done body keeps markup sold unit in cartItemNote', () {
    final items = [
      CartItem(
        product: Product(id: '6', name: 'Carp', priceUzs: 3480, variantId: 1),
        quantity: 1,
        salePriceOverride: 5000,
        priceLocked: true,
      ),
    ];
    final body = SalesStoreBody.build(
      items: items,
      subTotal: 3480,
      grandTotal: 5000,
      status: 'done',
      payments: const [],
    );
    final cart = body['cart'] as List;
    expect(cart.first['price'], 3480);
    expect(cart.first['discount'], 0);
    expect(cart.first['calculatedPrice'], 5000);
    expect(cart.first['soldUnitPrice'], 5000);
    expect(cart.first['cartItemNote'], 'alfapos_sold_unit=5000');
  });
}
