import 'package:alfapos_app/utils/sales_return_checkout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SalesReturnCheckout', () {
    test('applyInlineReturnToStoreBody negates totals cart and payments', () {
      final body = {
        'orderType': 'sales',
        'subTotal': 150000,
        'grandTotal': 150000,
        'profit': 50000,
        'dueAmount': 50000,
        'cart': [
          {
            'productID': 10,
            'quantity': 3,
            'calculatedPrice': 150000,
            'orderType': 'sales',
          },
        ],
        'payments': [
          {'paymentID': 1, 'paid': 150000, 'paymentType': 'cash'},
        ],
      };

      final out = SalesReturnCheckout.applyInlineReturnToStoreBody(
        body,
        creditPaymentUsed: false,
      );

      expect(out['salesOrReturnType'], 'sales');
      expect(out['dueAmount'], 0);
      expect(out['subTotal'], -150000);
      expect(out['grandTotal'], -150000);
      expect(out['profit'], -50000);
      expect((out['cart'] as List).first['quantity'], -3);
      expect((out['cart'] as List).first['calculatedPrice'], -150000);
      expect((out['payments'] as List).first['paid'], -150000);
    });

    test('usesGeneralDebtCredit when credit without invoice selection', () {
      expect(
        SalesReturnCheckout.usesGeneralDebtCredit(hasCreditPayment: true),
        isTrue,
      );
      expect(
        SalesReturnCheckout.usesGeneralDebtCredit(
          hasCreditPayment: true,
          invoiceReturnIds: ['INV-1'],
        ),
        isFalse,
      );
      expect(
        SalesReturnCheckout.usesGeneralDebtCredit(hasCreditPayment: false),
        isFalse,
      );
    });
  });
}
