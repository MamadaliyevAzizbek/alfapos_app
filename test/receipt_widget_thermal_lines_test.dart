import 'package:alfapos_app/widgets/receipt_widget.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sale receipt thermal lines match cart layout not API html', () {
    final w = ReceiptWidget(
      dateTime: DateTime(2026, 5, 20, 14, 30),
      receiptNumber: 'POS99',
      sellerName: 'Aziz',
      productRows: const [
        ReceiptRow(
          productName: 'Non',
          quantityStr: '2 dona',
          price: 15000,
          sum: 30000,
        ),
      ],
      paymentRows: const [
        ReceiptPaymentRow(methodName: 'Naqd', sum: 30000),
      ],
      discount: 0,
      totalSum: 30000,
    );
    final lines = w.toThermalPrintLines();
    expect(lines.any((l) => l.contains('Alfa market')), isTrue);
    expect(lines.any((l) => l.contains('2026-05-20')), isTrue);
    expect(lines, contains('Chek raqami: POS99'));
    expect(lines.any((l) => l.contains('1) Non')), isTrue);
    expect(lines.any((l) => l.contains('2 dona') && l.contains("so'm")), isTrue);
    expect(lines.any((l) => l.contains('Naqd')), isTrue);
    expect(lines, isNot(contains('Mahsulot')));
    expect(lines.join('\n').length, lessThan(800));
  });
}
