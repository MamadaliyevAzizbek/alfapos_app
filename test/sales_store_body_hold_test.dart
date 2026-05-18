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
    expect(cart.first['cartItemNote'], '');
  });
}
