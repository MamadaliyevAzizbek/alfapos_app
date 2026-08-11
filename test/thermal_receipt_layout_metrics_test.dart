import 'package:alfapos_app/utils/thermal_receipt_formatter.dart';
import 'package:alfapos_app/utils/thermal_receipt_layout_metrics.dart';
import 'package:alfapos_app/utils/thermal_receipt_large_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('height grows with product count beyond screen size', () {
    final few = ThermalReceiptFormatter.toPrintLines(
      ThermalReceiptPrintData(
        storeName: 'Test',
        dateTime: DateTime(2026, 6, 11),
        receiptNumber: '100',
        sellerName: 'Sotuvchi',
        products: List.generate(
          5,
          (i) => ThermalReceiptProductLine(
            name: 'Mahsulot $i',
            quantity: '1 dona',
            unitPrice: '10 000',
            lineTotal: '10 000',
          ),
        ),
        totalAmount: '50 000',
      ),
    );
    final many = ThermalReceiptFormatter.toPrintLines(
      ThermalReceiptPrintData(
        storeName: 'Test',
        dateTime: DateTime(2026, 6, 11),
        receiptNumber: '100',
        sellerName: 'Sotuvchi',
        products: List.generate(
          25,
          (i) => ThermalReceiptProductLine(
            name: 'Mahsulot $i uzun nom bilan',
            quantity: '2 dona',
            unitPrice: '125 000',
            lineTotal: '250 000',
          ),
        ),
        totalAmount: '6 250 000',
      ),
    );

    final hFew = ThermalReceiptLayoutMetrics.estimateHeight(lines: few);
    final hMany = ThermalReceiptLayoutMetrics.estimateHeight(lines: many);

    expect(hMany, greaterThan(hFew));
    expect(hMany, greaterThan(900));
    expect(hMany, greaterThan(hFew * 2));
  });

  test('logo adds extra height for medium receipts', () {
    final lines = List.generate(12, (i) => 'Mahsulot $i — 12 000 so\'m');
    final without = ThermalReceiptLayoutMetrics.estimateHeight(lines: lines);
    final withLogo = ThermalReceiptLayoutMetrics.estimateHeight(
      lines: lines,
      showLogo: true,
    );
    expect(withLogo, greaterThan(without));
    expect(withLogo - without, greaterThan(50));
  });

  test('large queue line increases height', () {
    final baseLines = List.generate(8, (i) => 'Mahsulot $i');
    final base = ThermalReceiptLayoutMetrics.estimateHeight(lines: baseLines);
    final withQueue = ThermalReceiptLayoutMetrics.estimateHeight(
      lines: [...baseLines, ThermalReceiptLargeText.line('42')],
    );
    expect(withQueue, greaterThan(base + 20));
  });
}
