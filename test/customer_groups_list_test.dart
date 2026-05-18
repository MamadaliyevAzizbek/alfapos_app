import 'package:flutter_test/flutter_test.dart';
import 'package:alfapos_app/utils/customer_groups_list.dart';

void main() {
  test('parseRows — guruhlar, mijozlar aralashmasin', () {
    final rows = CustomerGroupsListParser.parseRows({
      'datarows': [
        {'id': 1, 'title': 'VIP', 'discount': 5, 'is_default': 1},
        {'id': 2, 'first_name': 'Ali', 'phone_number': '+998'},
      ],
    });
    expect(rows.length, 1);
    expect(CustomerGroupsListParser.groupTitle(rows.first), 'VIP');
    expect(CustomerGroupsListParser.groupDiscount(rows.first), 5);
    expect(CustomerGroupsListParser.groupIsDefault(rows.first), true);
  });

  test('groupsFromResponse — foiz bilan', () {
    final rows = CustomerGroupsListParser.groupsFromResponse({
      'groups': [
        {'id': 1, 'title': 'shohiborlar', 'discount': -10},
        {'id': 2, 'title': 'Doimiy', 'discount': 5},
      ],
    });
    expect(rows.length, 2);
    expect(CustomerGroupsListParser.groupDiscount(rows.first), -10);
  });

  test('unwrapGroupPayload', () {
    final g = CustomerGroupsListParser.unwrapGroupPayload({
      'group': {'id': 3, 'title': 'Doimiy', 'discount': 10},
    });
    expect(CustomerGroupsListParser.groupIdFrom(g), 3);
    expect(CustomerGroupsListParser.groupDiscount(g), 10);
  });
}
