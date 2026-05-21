import 'package:alfapos_app/utils/api_receipt_html_parser.dart';
import 'package:alfapos_app/utils/thermal_receipt_line_wrap.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('div with table does not duplicate full receipt as one line', () {
    const html = '''
<div class="invoice">
  <div class="store">Do\'kon nomi</div>
  <table>
    <tr><td>Mahsulot</td><td>2</td><td>30 000</td></tr>
    <tr><td>Jami</td><td></td><td>30 000</td></tr>
  </table>
</div>
''';
    final data = ApiReceiptHtmlParser.toPrintData(html);
    expect(data.products.map((p) => p.name), contains('Mahsulot'));

    final lines = ApiReceiptHtmlParser.toPrintLines(html);
    expect(lines, isNot(contains(contains('Do\'kon nomi Mahsulot'))));
    expect(lines.any((l) => l.contains('Do\'kon nomi') || l.contains('^Do\'kon nomi')), isTrue);
    expect(lines, contains('1) Mahsulot'), reason: lines.join('\n'));
  });

  test('long line is wrapped for thermal width', () {
    final long = 'A' * 60;
    final wrapped = ThermalReceiptLineWrap.wrapLine(long, maxWidth: 48);
    expect(wrapped.length, greaterThan(1));
    for (final w in wrapped) {
      expect(w.length, lessThanOrEqualTo(48));
    }
  });
}
