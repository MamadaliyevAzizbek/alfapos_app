import 'package:alfapos_app/utils/api_receipt_html_parser.dart';
import 'package:alfapos_app/utils/thermal_receipt_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formats API vertical table cells like Alfapos.pdf', () {
    const raw = [
      'Alfa market',
      '2026-05-20 - 17:17:52',
      'Chek raqami: 10322',
      'Sotuvchi: Azizbek Mamadaliyev',
      'Mijoz: Mijoz',
      'Mijoz telefon:',
      'Manzil:',
      'Mahsulot',
      'Miqdor',
      'Narx',
      'Summa',
      'sprite',
      '4шт',
      '2,000',
      '8,000',
      'Naqd pul May 20, 2026 17:17 8,000',
      'Chegirma',
      '0',
      'Umumiy summa',
      '8,000',
    ];
    final lines = ThermalReceiptFormatter.fromApiRawLines(raw);
    expect(lines.any((l) => l.contains('^Alfa market') || l == '^Alfa market'), isTrue);
    expect(lines.any((l) => l.startsWith('1) sprite')), isTrue);
    expect(lines.any((l) => l.contains('4шт') && l.contains("so'm")), isTrue);
    expect(lines, isNot(contains('Mahsulot')));
    expect(lines, isNot(contains('Miqdor')));
  });

  test('html parser applies pdf formatter', () {
    const html = '''
<div>Alfa market</div>
<div>2026-05-20 - 17:17:52</div>
<div>Chek raqami: 1</div>
<table>
<tr><td>Mahsulot</td></tr>
<tr><td>Miqdor</td></tr>
<tr><td>Narx</td></tr>
<tr><td>Summa</td></tr>
<tr><td>sprite</td></tr>
<tr><td>4шт</td></tr>
<tr><td>2000</td></tr>
<tr><td>8000</td></tr>
</table>
''';
    final lines = ApiReceiptHtmlParser.toPrintLines(html);
    expect(lines.any((l) => l.contains('sprite')), isTrue);
    expect(lines, isNot(contains('Mahsulot')));
  });

  test('html horizontal table row becomes one product', () {
    const html = '''
<div>Alfa market</div>
<div>2026-05-19 | 19:59:38</div>
<table>
<tr><th>Mahsulot</th><th>Miqdor</th><th>Narx</th><th>Summa</th></tr>
<tr><td>aaaaaa</td><td>1</td><td>38,000</td><td>38,000</td></tr>
<tr><td>Naqd pul</td><td>135,000</td></tr>
<tr><td>Chegirma</td><td>0</td></tr>
<tr><td>Umumiy summa</td><td>135,000</td></tr>
</table>
''';
    final data = ApiReceiptHtmlParser.toPrintData(html);
    expect(data.products.length, 1);
    expect(data.products.first.name, 'aaaaaa');
    expect(data.payments.first.method, 'Naqd pul');
    final lines = ApiReceiptHtmlParser.toPrintLines(html);
    expect(lines.any((l) => l.startsWith('1) aaaaaa')), isTrue);
    expect(lines.any((l) => l.contains('38,000') && l.contains('so')), isTrue);
  });
}
