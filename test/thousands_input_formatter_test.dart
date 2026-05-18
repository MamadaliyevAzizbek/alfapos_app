import 'package:alfapos_app/core/input_formatters.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

TextEditingValue _fmt(String oldText, String newText, int newCursor) {
  final formatter = ThousandsInputFormatter();
  return formatter.formatEditUpdate(
    TextEditingValue(text: oldText, selection: TextSelection.collapsed(offset: oldText.length)),
    TextEditingValue(text: newText, selection: TextSelection.collapsed(offset: newCursor)),
  );
}

void main() {
  test('cursor stays at end when extending 300 to 3000', () {
    final result = _fmt('300', '3000', 4);
    expect(result.text, '3 000');
    expect(result.selection.end, 5);
  });

  test('cursor at end when typing space-separated input', () {
    final result = _fmt('3 00', '3 000', 5);
    expect(result.text, '3 000');
    expect(result.selection.end, 5);
  });

  test('cursor after first digit when inserting at start', () {
    final formatter = ThousandsInputFormatter();
    final result = formatter.formatEditUpdate(
      const TextEditingValue(text: '000', selection: TextSelection.collapsed(offset: 0)),
      const TextEditingValue(text: '3000', selection: TextSelection.collapsed(offset: 1)),
    );
    expect(result.text, '3 000');
    expect(result.selection.end, 1);
  });

  test('empty input clears text', () {
    final result = _fmt('300', '', 0);
    expect(result.text, '');
    expect(result.selection.end, 0);
  });
}
