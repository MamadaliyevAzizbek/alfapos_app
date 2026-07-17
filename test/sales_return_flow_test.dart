import 'package:alfapos_app/utils/sales_return_flow.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SalesReturnFlow', () {
    test('saleDueAmount reads due_amount from sale or invoice', () {
      expect(
        SalesReturnFlow.saleDueAmount({'due_amount': 10000}),
        10000,
      );
      expect(
        SalesReturnFlow.saleDueAmount(
          {'total': 5000},
          invoiceDetail: {'due_amount': '7500.00'},
        ),
        7500,
      );
      expect(SalesReturnFlow.saleDueAmount({'total': 100}), 0);
    });

    test('customerIdFromSale from nested customer or customer_id', () {
      expect(
        SalesReturnFlow.customerIdFromSale({'customer_id': 42}),
        42,
      );
      expect(
        SalesReturnFlow.customerIdFromSale({
          'customer': {'id': '7', 'name': 'Ali'},
        }),
        7,
      );
      expect(SalesReturnFlow.customerIdFromSale({'total': 1}), isNull);
    });

    test('normalizeInvoiceId prefixes POS', () {
      expect(SalesReturnFlow.normalizeInvoiceId('POS10502', 10502), 'POS10502');
      expect(SalesReturnFlow.normalizeInvoiceId('10502', 10502), 'POS10502');
      expect(SalesReturnFlow.normalizeInvoiceId('', 99), 'POS99');
    });
  });
}
