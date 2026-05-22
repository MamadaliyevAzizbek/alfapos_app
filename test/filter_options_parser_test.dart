import 'package:alfapos_app/utils/filter_options_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parseIdNameList reads datarows id+name', () {
    final list = FilterOptionsParser.parseIdNameList({
      'datarows': [
        {'id': 2, 'name': 'Pepsi'},
        {'id': 1, 'name': 'Coca-Cola'},
      ],
      'count': 2,
    });
    expect(list.length, 2);
    expect(list.first['id'], '1');
    expect(list.first['name'], 'Coca-Cola');
  });

  test('parseBrandsFromResponse reads filter-options brand text+value', () {
    final list = FilterOptionsParser.parseBrandsFromResponse({
      'category': [{'text': 'Ichimlik', 'value': 3}],
      'brand': [
        {'text': 'Coca-Cola', 'value': 1},
        {'text': 'Pepsi', 'value': 2},
      ],
    });
    expect(list.length, 2);
    expect(list.any((e) => e['name'] == 'Coca-Cola' && e['id'] == '1'), isTrue);
  });

  test('parseBrandsFromResponse ignores categories in supporting-data', () {
    final list = FilterOptionsParser.parseBrandsFromResponse({
      'brands': [
        {'id': 5, 'name': 'Nestle'},
      ],
      'categories': [
        {'id': 1, 'name': 'Food'},
      ],
    });
    expect(list.length, 1);
    expect(list.first['name'], 'Nestle');
  });

  test('parseIdNameList reads root list wrapped as data', () {
    final list = FilterOptionsParser.parseIdNameList({
      'data': [
        {'id': 9, 'name': 'Fanta'},
      ],
    });
    expect(list.length, 1);
    expect(list.first['id'], '9');
  });
}
