import 'package:alfapos_app/models/cart_item.dart';
import 'package:alfapos_app/models/product.dart';
import 'package:alfapos_app/utils/cart_discount_percent.dart';
import 'package:alfapos_app/utils/sales_return_checkout.dart';
import 'package:flutter_test/flutter_test.dart';

Product _product() => const Product(id: '10', name: 'Cola', priceUzs: 50000);

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

    test('chegirmali qatorlar chegirma narxida qaytariladi', () {
      // 10% chegirma: katalog 50 000 × 3 = 150 000 → 135 000.
      final line = CartItem(product: _product(), quantity: 3);
      CartDiscountPercent.applyToItem(
        line,
        CartDiscountPercent.discountPercentFromUi(10),
      );
      final pricing = line.salesStoreLinePricing;

      final out = SalesReturnCheckout.applyReturnToStoreBody(
        {
          'subTotal': pricing.lineTotal,
          'grandTotal': pricing.lineTotal,
          'discount': pricing.lineDiscount,
          'cart': [
            {
              'productID': 10,
              'quantity': line.quantity,
              'price': pricing.catalogUnitPrice,
              'discount': pricing.lineDiscount,
              'calculatedPrice': pricing.lineTotal,
            },
          ],
          'payments': [
            {'paymentID': 1, 'paid': pricing.lineTotal, 'paymentType': 'cash'},
          ],
        },
        creditPaymentUsed: false,
      );

      expect(pricing.lineTotal, 135000);
      expect(pricing.lineDiscount, 15000);
      expect(out['grandTotal'], -135000);
      expect(out['subTotal'], 135000);
      expect(out['discount'], 15000);

      final cartLine = (out['cart'] as List).first as Map;
      expect(cartLine['quantity'], -3);
      expect(cartLine['price'], 50000);
      expect(cartLine['discount'], 15000);
      expect(cartLine['calculatedPrice'], 135000);
      expect((out['payments'] as List).first['paid'], -135000);
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
