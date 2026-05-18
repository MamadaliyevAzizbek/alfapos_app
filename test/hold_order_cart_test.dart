import 'package:alfapos_app/utils/hold_order_cart.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HoldOrderCart.parse', () {
    test('parses embedded cart lines', () {
      final resume = HoldOrderCart.parse({
        'orderID': 42,
        'invoice_id': 'POS10042',
        'grandTotal': 55000,
        'cart': [
          {
            'productID': 7,
            'variantID': 1,
            'quantity': 2,
            'price': 15000,
            'productTitle': 'Non',
            'orderType': 'sales',
            'calculatedPrice': 30000,
          },
        ],
      });
      expect(resume, isNotNull);
      expect(resume!.orderId, 42);
      expect(resume.items.length, 1);
      expect(resume.items.first.product.id, '7');
      expect(resume.items.first.quantity, 2);
    });

    test('reads order_items key', () {
      final resume = HoldOrderCart.parse({
        'id': 99,
        'order_items': [
          {
            'product_id': 3,
            'quantity': 1,
            'price': 21000,
            'productTitle': 'Fanta 0.5L',
            'orderType': 'sales',
          },
        ],
      });
      expect(resume, isNotNull);
      expect(resume!.items.single.product.name, 'Fanta 0.5L');
    });

    test('returns null when cart missing', () {
      expect(HoldOrderCart.parse({'orderID': 1, 'grandTotal': 0}), isNull);
    });

    test('skips discount orderType rows', () {
      final resume = HoldOrderCart.parse({
        'cart': [
          {'orderType': 'discount', 'productID': 1, 'quantity': 1, 'price': 100},
          {
            'productID': 2,
            'quantity': 1,
            'price': 5000,
            'productTitle': 'Choy',
            'orderType': 'sales',
          },
        ],
      });
      expect(resume!.items.length, 1);
      expect(resume.items.first.product.id, '2');
    });
  });
}
