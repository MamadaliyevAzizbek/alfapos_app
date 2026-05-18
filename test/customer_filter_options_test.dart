import 'package:alfapos_app/utils/customer_filter_options.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parseGroupsFromResponse reads customerGroups', () {
    final groups = CustomerFilterOptionsParser.parseGroupsFromResponse({
      'customerGroups': [
        {'id': 1, 'title': 'Oddiy'},
        {'id': 2, 'title': 'VIP'},
      ],
    });
    expect(groups.length, 2);
    expect(groups[0].value, '1');
    expect(groups[0].label, 'Oddiy');
  });

  test('fromResponses merges groups and debt defaults', () {
    final meta = CustomerFilterOptionsParser.fromResponses(
      groupsResponse: {
        'customerGroups': [{'id': 3, 'name': 'Ulgurji'}],
      },
    );
    expect(meta.groups.first.value, 'all');
    expect(meta.groups.any((g) => g.value == '3'), isTrue);
    expect(meta.debtBalances.length, 3);
  });

  test('parseGroupsFromResponse ignores mijozlar datarows', () {
    final groups = CustomerFilterOptionsParser.parseGroupsFromResponse({
      'datarows': [
        {'id': 5, 'first_name': 'Azizbek', 'phone_number': '+99890'},
      ],
    });
    expect(groups, isEmpty);
  });

  test('parseGroupList skips customer rows keeps groups', () {
    final groups = CustomerFilterOptionsParser.parseGroupList([
      {'id': 5, 'first_name': 'Azizbek', 'phone_number': '+99890'},
      {'id': 1, 'title': 'Doimiy'},
    ]);
    expect(groups.length, 1);
    expect(groups.first.label, 'Doimiy');
  });
}
