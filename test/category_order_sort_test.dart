import 'package:alfapos_app/utils/category_order_sort.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('applies saved order and appends unknown categories', () {
    final input = [
      {'id': '3', 'name': 'Ichimlik'},
      {'id': '1', 'name': 'Non'},
      {'id': '2', 'name': 'Shirinlik'},
      {'id': '4', 'name': 'Yangi'},
    ];
    final sorted = CategoryOrderSort.apply(input, const ['2', '1']);
    expect(sorted.map((e) => e['id']).toList(), ['2', '1', '3', '4']);
  });

  test('empty order keeps source list', () {
    final input = [
      {'id': '1', 'name': 'A'},
      {'id': '2', 'name': 'B'},
    ];
    final sorted = CategoryOrderSort.apply(input, []);
    expect(sorted, input);
  });
}
