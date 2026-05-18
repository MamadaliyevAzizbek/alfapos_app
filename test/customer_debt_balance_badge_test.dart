import 'package:alfapos_app/providers/clients_provider.dart';
import 'package:alfapos_app/widgets/customer_debt_balance_badge.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('debt takes priority over balance', () {
    final c = Client.fromApiJson({
      'id': 1,
      'first_name': 'Test',
      'due_amount': 1000,
      'balance': 500,
    });
    expect(CustomerDebtBalanceBadge.debtAmount(c), 1000);
    expect(CustomerDebtBalanceBadge.balanceAmount(c), 500);
  });
}
