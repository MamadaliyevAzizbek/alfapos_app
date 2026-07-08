import 'package:alfapos_app/models/cart_item.dart';
import 'package:alfapos_app/models/product.dart';
import 'package:alfapos_app/utils/product_weight.dart';
import 'package:alfapos_app/utils/thermal_receipt_formatter.dart';
import 'package:alfapos_app/utils/thermal_receipt_line_wrap.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProductWeight', () {
    test('parse handles string and numeric', () {
      expect(ProductWeight.parse('1.500'), 1.5);
      expect(ProductWeight.parse(0.35), 0.35);
      expect(ProductWeight.parse(''), isNull);
    });

    test('lineKg multiplies by quantity and pack', () {
      final p = Product(
        id: '1',
        name: 'Olma',
        priceUzs: 1000,
        weightKg: 0.5,
        quantityPerPack: 6,
        quantityInPack: true,
        sellPricePerPack: 5000,
      );
      expect(ProductWeight.lineKg(p, 2, sellByPack: true), 6.0);
      expect(ProductWeight.lineKg(p, 3), 1.5);
    });

    test('totalKgFromCart sums lines', () {
      final p = Product(id: '1', name: 'A', priceUzs: 1, weightKg: 0.2);
      final items = [
        CartItem(product: p, quantity: 2),
        CartItem(product: p, quantity: 1),
      ];
      expect(ProductWeight.totalKgFromCart(items), 0.6);
    });
  });

  test('receipt shows per-line and total weight', () {
    final lines = ThermalReceiptFormatter.toPrintLines(
      ThermalReceiptPrintData(
        storeName: 'Do\'kon',
        dateTime: DateTime(2026, 7, 8, 10, 30),
        receiptNumber: 'POS1',
        sellerName: 'Kassir',
        products: const [
          ThermalReceiptProductLine(
            name: 'Non',
            quantity: '2 dona',
            unitPrice: '4,000',
            lineTotal: '8,000',
            lineWeightKg: 0.7,
          ),
        ],
        payments: const [
          ThermalReceiptPaymentLine(method: 'Naqd pul', amount: '8,000'),
        ],
        totalAmount: '8,000',
        totalWeightKg: 0.7,
      ),
      maxWidth: kReceiptPreviewChars,
    );
    expect(lines.any((l) => l.contains('Jami og\'irlik')), isTrue);
    expect(lines.where((l) => l.trim() == '0.7 kg'), isEmpty);
    for (final line in lines.where((l) => RegExp(r'^[-]+$').hasMatch(l.trim()))) {
      expect(line.length, lessThanOrEqualTo(kReceiptPreviewChars));
    }
  });

  test('fitSeparatorsForWidth keeps single line', () {
    final fixed = ThermalReceiptLineWrap.fitSeparatorsForWidth(
      ['${'-' * 48}'],
      kReceiptPreviewChars,
    );
    expect(fixed.length, 1);
    expect(fixed.first.length, kReceiptPreviewChars);
  });
}
