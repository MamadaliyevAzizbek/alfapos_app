import 'package:alfapos_app/utils/customer_balance_transaction.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('subtract is negative signed amount', () {
    final row = CustomerBalanceTransactionRow({
      'type': 'subtract',
      'amount': 280000,
      'description': 'Sotuv: 156971',
    });
    expect(row.signedAmount, -280000);
    expect(CustomerBalanceTransactionRow.formatSignedAmount(row.signedAmount), '-280 000');
  });

  test('add is positive', () {
    final row = CustomerBalanceTransactionRow({
      'type': 'add',
      'amount': 166000,
      'description': "Balans qo'shildi: 200,000.00",
    });
    expect(row.signedAmount, 166000);
  });

  test('formats date without T', () {
    final row = CustomerBalanceTransactionRow({
      'type': 'used',
      'amount': 37000,
      'created_at': '2026-05-17T22:02:14.000000Z',
    });
    expect(row.dateDisplay, matches(RegExp(r'^\d{4}-\d{2}-\d{2} \d{2}:\d{2}$')));
    expect(row.dateDisplay, isNot(contains('T')));
  });
}
