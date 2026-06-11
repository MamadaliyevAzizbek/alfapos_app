import 'package:alfapos_app/utils/thermal_receipt_compact_text.dart';
import 'package:alfapos_app/utils/thermal_receipt_formatter.dart';
import 'package:alfapos_app/utils/thermal_receipt_line_wrap.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('two column row uses compact font when normal width is not enough', () {
    final left = '25 dona x 1,250,000 so\'m maxsus chegirma';
    final right = '31,250,000 so\'m';
    final rows = ThermalReceiptLineWrap.formatTwoColumnRows(
      left,
      right,
      rightWidth: ThermalReceiptFormatter.kReceiptAmountColumnWidth,
    );
    expect(rows.length, 1);
    expect(ThermalReceiptCompactText.isCompactLine(rows.first), isTrue);
    expect(ThermalReceiptCompactText.unwrap(rows.first), contains('31,250,000'));
  });

  test('two column row splits sum to dedicated line preserving structure', () {
    final left = '99 dona x 1,250,000 so\'m chegirmali narx bilan uzun matn';
    final right = '123,750,000 so\'m';
    final rows = ThermalReceiptLineWrap.formatTwoColumnRows(
      left,
      right,
      rightWidth: ThermalReceiptFormatter.kReceiptAmountColumnWidth,
    );
    expect(rows.length, greaterThan(1));
    expect(rows.last.trim(), '123,750,000 so\'m');
    expect(rows.last.length, kThermalChars80mm);
  });

  test('long product name uses compact before wrapping', () {
    final name = 'Juda uzun mahsulot nomi restoran menyusi uchun maxsus';
    final rows = ThermalReceiptLineWrap.formatProductNameRows(
      name,
      numbered: true,
      index: 1,
    );
    expect(rows.length, 1);
    expect(ThermalReceiptCompactText.isCompactLine(rows.first), isTrue);
  });

  test('wrapAll keeps compact and amount lines intact', () {
    final sumLine = '123,750,000 so\'m'.padLeft(kThermalChars80mm);
    final wrapped = ThermalReceiptLineWrap.wrapAll([
      ThermalReceiptCompactText.line('2 dona x 10,000 so\'m           20,000 so\'m'),
      sumLine,
    ]);
    expect(wrapped.length, 2);
    expect(ThermalReceiptCompactText.isCompactLine(wrapped[0]), isTrue);
    expect(wrapped[1], sumLine);
  });
}
