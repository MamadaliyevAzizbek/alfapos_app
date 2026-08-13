import 'package:alfapos_app/utils/api_receipt_html_parser.dart';
import 'package:flutter_test/flutter_test.dart';

/// Foydalanuvchi skrinshotidagi noto‘g‘ri HTML holatlari.
void main() {
  test('8 ustunli bitta tr — header + mahsulot (API)', () {
    const html = '''
<div>Alfa market</div>
<div>2026-05-20 | 17:17:52</div>
<div>Chek raqami: 10322</div>
<div>Sotuvchi: Azizbek</div>
<table>
<tr>
  <td>Mahsulot</td><td>Miqdor</td><td>Narx</td><td>Summa</td>
  <td>sprite</td><td>4шт</td><td>2,000</td><td>8,000</td>
</tr>
</table>
''';
    final lines = ApiReceiptHtmlParser.toPrintLines(html);
    expect(lines.any((l) => l.contains('Alfa market')), isTrue);
    expect(lines, contains('^2026-05-20 | 17:17:52'));
    expect(lines.any((l) => l.contains('1) sprite')), isTrue);
    expect(lines.any((l) => l.contains('4шт') && l.contains('2,000')), isTrue);
    expect(lines.any((l) => l.contains('8,000') && l.contains("so'm")), isTrue);
    expect(lines.join('\n'), isNot(contains('Mahsulot Miqdor')));
    expect(lines, isNot(contains('Mahsulot')));
  });

  test('bitta td ichida yopishib ketgan matn + alohida narx qatorlari', () {
    const html = '''
<div>Alfa market</div>
<div>2026-05-20 | 17:17:52</div>
<table>
<tr><td>Mahsulot Miqdor Narx Summa sprite 4шт</td></tr>
<tr><td>2,000</td></tr>
<tr><td>8,000</td></tr>
</table>
''';
    final data = ApiReceiptHtmlParser.toPrintData(html);
    expect(data.storeName, 'Alfa market');
    expect(data.products.length, 1);
    expect(data.products.first.name, 'sprite');
    expect(data.products.first.quantity, '4шт');

    final lines = ApiReceiptHtmlParser.toPrintLines(html);
    expect(lines.any((l) => l.contains('Alfa market')), isTrue);
    expect(lines.any((l) => l.contains('1) sprite')), isTrue);
    expect(lines.join('\n'), isNot(contains('Mahsulot Miqdor Narx Summa')));
  });

  test('vertikal 8 tr — PDF format', () {
    const html = '''
<div>Alfa market</div>
<div>2026-05-19 | 19:59:38</div>
<div>Chek raqami: 10301</div>
<div>Sotuvchi: Murod</div>
<div>Sotuvchi nomeri: 911003205</div>
<table>
<tr><td>Mahsulot</td></tr>
<tr><td>Miqdor</td></tr>
<tr><td>Narx</td></tr>
<tr><td>Summa</td></tr>
<tr><td>sprite</td></tr>
<tr><td>4шт</td></tr>
<tr><td>2,000</td></tr>
<tr><td>8,000</td></tr>
</table>
''';
    final lines = ApiReceiptHtmlParser.toPrintLines(html);
    expect(lines.any((l) => l.contains('Alfa market')), isTrue);
    expect(lines, contains('Chek raqami: 10301'));
    expect(lines, contains('Sotuvchi nomeri: 911003205'));
    expect(lines.any((l) => l.contains('1) sprite')), isTrue);
    expect(
      lines.any((l) => l.contains('Umumiy summa') || l.contains('!TOTAL!')),
      isTrue,
    );
  });
}
