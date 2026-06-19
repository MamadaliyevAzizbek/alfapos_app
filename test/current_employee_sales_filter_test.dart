import 'package:alfapos_app/utils/current_employee_sales_filter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('saleBelongsToUser matches user_id', () {
    final sale = {'user_id': 5, 'created_by': 'Ali Valiyev'};
    expect(CurrentEmployeeSalesFilter.saleBelongsToUser(sale, userId: 5), isTrue);
    expect(CurrentEmployeeSalesFilter.saleBelongsToUser(sale, userId: 6), isFalse);
  });

  test('saleBelongsToUser matches created_by name', () {
    final sale = {'created_by': 'Ali Valiyev'};
    expect(
      CurrentEmployeeSalesFilter.saleBelongsToUser(sale, userId: null, sellerName: 'Ali Valiyev'),
      isTrue,
    );
  });

  test('employeeOptionsFromFilterResponse parses list', () {
    final options = CurrentEmployeeSalesFilter.employeeOptionsFromFilterResponse({
      'employee': [
        {'value': 3, 'text': 'Ali Valiyev'},
      ],
    });
    expect(options.length, 1);
    expect(options.first['value'], '3');
    expect(options.first['label'], 'Ali Valiyev');
  });
}
