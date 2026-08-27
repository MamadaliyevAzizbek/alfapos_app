import 'package:alfapos_app/utils/sale_customer_label.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SaleCustomerLabel', () {
    test('uses real customer string from sale row', () {
      expect(
        SaleCustomerLabel.displayName({'customer': 'Jamol Karimov'}),
        'Jamol Karimov',
      );
    });

    test('joins first_name and last_name from customer map', () {
      expect(
        SaleCustomerLabel.displayName({
          'customer': {'first_name': 'Ali', 'last_name': 'Valiyev'},
        }),
        'Ali Valiyev',
      );
    });

    test('treats generic Mijoz as unusable until id resolve', () {
      expect(SaleCustomerLabel.isUsableName('Mijoz'), isFalse);
      expect(SaleCustomerLabel.isUsableName('Jamol'), isTrue);
      expect(
        SaleCustomerLabel.displayName({
          'customer': 'Mijoz',
          'customer_id': 5,
        }, resolvedById: {'5': 'Jamol Karimov'}),
        'Jamol Karimov',
      );
    });

    test('reads customer_name top-level field', () {
      expect(
        SaleCustomerLabel.displayName({
          'customer': 'Mijoz',
          'customer_name': 'Dilshod',
        }),
        'Dilshod',
      );
    });
  });
}
