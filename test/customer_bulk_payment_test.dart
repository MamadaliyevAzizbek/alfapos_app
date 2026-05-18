import 'package:alfapos_app/utils/customer_bulk_payment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('totalDueFromDueOrdersResponse sums orders and avoids double standalone', () {
    final total = CustomerBulkPayment.totalDueFromDueOrdersResponse({
      'orders': [
        {'due_amount': 1500000, 'is_standalone_debt': false},
        {'due_amount': 500000, 'is_standalone_debt': true, 'standalone_debt_id': 12},
      ],
      'standalone_debt': 500000,
    });
    expect(total, 2000000);
  });

  test('totalDueFromDueOrdersResponse adds standalone_debt when not in orders', () {
    final total = CustomerBulkPayment.totalDueFromDueOrdersResponse({
      'orders': [
        {'due_amount': 100000, 'is_standalone_debt': false},
      ],
      'standalone_debt': 50000,
    });
    expect(total, 150000);
  });

  test('isExcludedBulkPaymentType filters credit and balance types', () {
    expect(
      CustomerBulkPayment.isExcludedBulkPaymentType({'id': 1, 'type': 'cash'}),
      false,
    );
    expect(
      CustomerBulkPayment.isExcludedBulkPaymentType({'id': 2, 'type': 'credit'}),
      true,
    );
    expect(
      CustomerBulkPayment.isExcludedBulkPaymentType({'id': 3, 'type': 'customer_balance'}),
      true,
    );
  });
}
