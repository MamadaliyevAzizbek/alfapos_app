import 'package:alfapos_app/utils/sales_return_checkout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SalesReturnCheckout', () {
    test('applyReturnToStoreBody — SALES_RETURNS_API: returns + manfiy grandTotal', () {
      final body = {
        'orderType': 'sales',
        'subTotal': 150000,
        'grandTotal': 150000,
        'profit': 50000,
        'dueAmount': 50000,
        'selectedBranchID': 1,
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

      final out = SalesReturnCheckout.applyReturnToStoreBody(
        body,
        creditPaymentUsed: false,
        invoiceReturnId: 'POS10502',
        returnSourceOrderId: 10502,
      );

      expect(out['salesOrReturnType'], 'returns');
      expect(out['dueAmount'], 0);
      expect(out['subTotal'], 150000);
      expect(out['grandTotal'], -150000);
      expect(out['profit'], -50000);
      expect(out['invoiceReturnId'], 'POS10502');
      expect(out['branchId'], 1);
      expect(out['currentBranch'], 1);

      final cartLine = (out['cart'] as List).first as Map;
      expect(cartLine['quantity'], -3);
      expect(cartLine['calculatedPrice'], 150000);
      expect(cartLine['invoiceReturnId'], 'POS10502');
      expect(cartLine['returnSourceOrderId'], 10502);

      expect((out['payments'] as List).first['paid'], -150000);
    });

    test('applyInlineReturnToStoreBody — returns alias (API §7)', () {
      final out = SalesReturnCheckout.applyInlineReturnToStoreBody(
        {
          'subTotal': 10000,
          'grandTotal': 10000,
          'cart': [
            {'productID': 1, 'quantity': 1, 'calculatedPrice': 10000},
          ],
          'payments': [
            {'paymentID': 7, 'paid': '10000.00', 'paymentType': 'tolovsiz'},
          ],
        },
        creditPaymentUsed: false,
        invoiceReturnId: 'POS10502',
      );

      expect(out['salesOrReturnType'], 'returns');
      expect(out['subTotal'], 10000);
      expect(out['grandTotal'], -10000);
      expect((out['payments'] as List).first['paid'], '-10000.00');
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
