import 'package:alfapos_app/utils/cash_register_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formatShiftWeight formats analytics field', () {
    expect(formatShiftWeight(36.75), '36.75 kg');
    expect(formatShiftWeight(40), '40 kg');
    expect(formatShiftWeight(0.125), '0.125 kg');
    expect(formatShiftWeight(null), '0 kg');
    expect(formatShiftWeight('3.800'), '3.8 kg');
  });
}
