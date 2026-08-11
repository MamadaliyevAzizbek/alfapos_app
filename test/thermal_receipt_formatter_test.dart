import 'package:alfapos_app/models/receipt_design_config.dart';
import 'package:alfapos_app/utils/api_receipt_html_parser.dart';
import 'package:alfapos_app/utils/thermal_receipt_formatter.dart';
import 'package:alfapos_app/utils/thermal_receipt_compact_text.dart';
import 'package:alfapos_app/utils/thermal_receipt_large_text.dart';
import 'package:alfapos_app/utils/thermal_receipt_total_text.dart';
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
    expect(lines.any((l) => l.contains('Alfa market')), isFalse);
    expect(lines.any((l) => l.startsWith('1) sprite')), isTrue);
    expect(lines.any((l) => l.contains('sprite')), isTrue);
    expect(lines.any((l) => l.contains('x') && l.contains("so'm")), isTrue);
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

  test('long product and price rows keep structure with auto scale', () {
    final lines = ThermalReceiptFormatter.toPrintLines(
      ThermalReceiptPrintData(
        storeName: 'Do\'kon',
        dateTime: DateTime(2026, 6, 10, 14, 30),
        receiptNumber: 'POS100',
        sellerName: 'Kassir',
        products: const [
          ThermalReceiptProductLine(
            name: 'Juda uzun mahsulot nomi restoran menyusi uchun maxsus taom',
            quantity: '99 dona',
            unitPrice: '1,250,000',
            lineTotal: '123,750,000',
          ),
        ],
        totalAmount: '123,750,000',
      ),
    );
    final productIdx = lines.indexWhere((l) => l.contains('Juda uzun mahsulot'));
    expect(productIdx, greaterThanOrEqualTo(0));
    expect(lines.any((l) => l.contains('99 dona x 1,250,000')), isTrue);
    expect(
      lines.any(
        (l) => l.contains('123,750,000') &&
            (ThermalReceiptCompactText.isCompactLine(l) || l.contains('so\'m')),
      ),
      isTrue,
    );
  });

  test('shop and restaurant totals use large total marker not compact bold', () {
    List<String> build({required bool restaurant}) {
      return ThermalReceiptFormatter.toPrintLines(
        ThermalReceiptPrintData(
          storeName: restaurant ? 'Restoran' : "Do'kon",
          dateTime: DateTime(2026, 6, 10, 14, 30),
          receiptNumber: 'POS1',
          sellerName: 'Kassir',
          products: const [
            ThermalReceiptProductLine(
              name: 'Non',
              quantity: '1 dona',
              unitPrice: '4,000',
              lineTotal: '4,000',
            ),
          ],
          payments: const [
            ThermalReceiptPaymentLine(method: 'Naqd pul', amount: '4,000'),
          ],
          totalAmount: '4,000',
          isRestaurantLayout: restaurant,
        ),
      );
    }

    for (final lines in [build(restaurant: false), build(restaurant: true)]) {
      expect(lines.any(ThermalReceiptTotalText.isTotalLine), isTrue);
      expect(
        lines.any(
          (l) =>
              ThermalReceiptCompactText.isCompactBoldLine(l) &&
              ThermalReceiptCompactText.unwrap(l).toLowerCase().contains('umumiy'),
        ),
        isFalse,
      );
    }
  });

  test('payment and total use aligned dash rows on receipt', () {
    final lines = ThermalReceiptFormatter.toPrintLines(
      ThermalReceiptPrintData(
        storeName: 'AI-CHA',
        dateTime: DateTime(2026, 6, 30, 14, 25, 31),
        receiptNumber: 'POS258512',
        sellerName: 'Kassir',
        products: const [
          ThermalReceiptProductLine(
            name: 'Stakan 400g',
            quantity: '1 шт',
            unitPrice: '1',
            lineTotal: '1',
          ),
        ],
        payments: const [
          ThermalReceiptPaymentLine(method: 'Naqd pul', amount: '1'),
        ],
        totalAmount: '1',
        queueNumber: 112,
        isRestaurantLayout: true,
      ),
    );

    String plain(String line) {
      if (ThermalReceiptTotalText.isTotalLine(line)) {
        final t = ThermalReceiptTotalText.parse(line);
        return '${t.label} - ${t.value}';
      }
      return ThermalReceiptCompactText.isAnyCompactLine(line)
          ? ThermalReceiptCompactText.unwrap(line)
          : line;
    }

    final payments = lines.map(plain).where((l) => l.contains('Naqd pul')).toList();
    expect(payments.any((l) => l.contains(' - ') && l.contains('1')), isTrue);
    expect(lines.any(ThermalReceiptTotalText.isTotalLine), isTrue);
    final total = ThermalReceiptTotalText.parse(
      lines.firstWhere(ThermalReceiptTotalText.isTotalLine),
    );
    expect(total.label.toLowerCase(), contains('umumiy summa'));
    expect(total.value, contains('1'));
  });

  test('receipt lines do not waste empty paper after total', () {
    final lines = ThermalReceiptFormatter.toPrintLines(
      ThermalReceiptPrintData(
        storeName: 'AI-CHA',
        dateTime: DateTime(2026, 6, 30, 14, 25, 31),
        receiptNumber: 'POS258512',
        sellerName: 'Kassir',
        payments: const [
          ThermalReceiptPaymentLine(method: 'Naqd pul', amount: '1'),
        ],
        totalAmount: '1',
      ),
    );

    expect(lines, isNotEmpty);
    expect(lines.last.trim(), isNotEmpty);
    expect(lines.any(ThermalReceiptTotalText.isTotalLine), isTrue);
  });

  test('restaurant layout matches shop receipt with queue number only', () {
    final config = ReceiptDesignConfig.defaults.copyWith(
      showRestaurantQueueNumber: true,
      restaurantQueueLabel: 'Navbat raqami',
    );
    final lines = ThermalReceiptFormatter.toPrintLines(
      ThermalReceiptPrintData(
        storeName: 'Restoran',
        dateTime: DateTime(2026, 6, 10, 14, 30),
        receiptNumber: 'POS99',
        sellerName: 'Kassir',
        products: const [
          ThermalReceiptProductLine(
            name: 'Choy',
            quantity: '1 dona',
            unitPrice: '10,000',
            lineTotal: '10,000',
          ),
          ThermalReceiptProductLine(
            name: 'Non',
            quantity: '2 dona',
            unitPrice: '5,000',
            lineTotal: '10,000',
          ),
        ],
        payments: const [
          ThermalReceiptPaymentLine(method: 'Naqd pul', amount: '20,000'),
        ],
        discountAmount: '0',
        totalAmount: '20,000',
        queueNumber: 7,
        isRestaurantLayout: true,
      ),
      config: config,
    );
    expect(lines.any((l) => l.contains('Navbat raqami')), isTrue);
    expect(lines.any((l) => l.contains('Kassir')), isTrue);
    expect(lines.any((l) => l.contains('Chek raqami')), isTrue);
    expect(lines.any((l) => l.contains('Naqd pul')), isTrue);
    expect(
      lines.any(
        (l) =>
            ThermalReceiptTotalText.isTotalLine(l) ||
            l.contains('Umumiy summa'),
      ),
      isTrue,
    );
    expect(lines.any(ThermalReceiptLargeText.isLargeLine), isTrue);
    expect(
      lines.any((l) => ThermalReceiptLargeText.isLargeLine(l) && ThermalReceiptLargeText.unwrap(l) == '7'),
      isTrue,
    );
    expect(lines.any((l) => l.contains('1) Choy') || l.contains('Choy')), isTrue);
    expect(lines.any((l) => l.contains('1 dona x 10,000=10,000')), isTrue);
    expect(lines.any((l) => l.contains("so'm")), isFalse);
    expect(lines.any((l) => ThermalReceiptCompactText.unwrap(l).contains('Mahsulot')), isFalse);
  });

  test('receipt omits store title and keeps date', () {
    final lines = ThermalReceiptFormatter.toPrintLines(
      ThermalReceiptPrintData(
        storeName: 'GULISTON YEMLARI - Asosiy filial',
        dateTime: DateTime(2026, 8, 11, 18, 43, 51),
        receiptNumber: 'POS10009',
        sellerName: 'Kassir',
        products: const [
          ThermalReceiptProductLine(
            name: 'Non',
            quantity: '1 dona',
            unitPrice: '4,000',
            lineTotal: '4,000',
          ),
        ],
        payments: const [
          ThermalReceiptPaymentLine(method: 'Naqd pul', amount: '4,000'),
        ],
        totalAmount: '4,000',
      ),
    );
    expect(lines.any((l) => l.contains('GULISTON')), isFalse);
    expect(lines.any((l) => l.contains('2026-08-11') && l.contains('18:43')), isTrue);
  });

  test('client lines appear only when a client is selected', () {
    ThermalReceiptPrintData base({String? name, String? phone, String? address}) {
      return ThermalReceiptPrintData(
        storeName: 'Filial',
        dateTime: DateTime(2026, 8, 11, 18, 0),
        receiptNumber: 'POS1',
        sellerName: 'Kassir',
        clientName: name,
        clientPhone: phone,
        clientAddress: address,
        products: const [
          ThermalReceiptProductLine(
            name: 'Non',
            quantity: '1 dona',
            unitPrice: '4,000',
            lineTotal: '4,000',
          ),
        ],
        payments: const [
          ThermalReceiptPaymentLine(method: 'Naqd pul', amount: '4,000'),
        ],
        totalAmount: '4,000',
      );
    }

    final without = ThermalReceiptFormatter.toPrintLines(base());
    expect(without.any((l) => l.toLowerCase().contains('mijoz')), isFalse);

    final withClient = ThermalReceiptFormatter.toPrintLines(
      base(name: 'Ali', phone: '+99890', address: 'Toshkent'),
    );
    expect(withClient.any((l) => l.contains('Mijoz: Ali')), isTrue);
    expect(withClient.any((l) => l.contains('+99890')), isTrue);
    expect(withClient.any((l) => l.contains('Toshkent')), isTrue);
  });
}
