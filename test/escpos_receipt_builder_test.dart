import 'package:alfapos_app/services/escpos_receipt_builder.dart';
import 'package:alfapos_app/utils/receipt_strikethrough_text.dart';
import 'package:alfapos_app/utils/thermal_receipt_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('buildReceipt encodes catalog discount strikethrough line', () async {
    final lines = ThermalReceiptFormatter.toPrintLines(
      ThermalReceiptPrintData(
        storeName: 'Alfa market',
        dateTime: DateTime(2026, 6, 11, 12, 0),
        receiptNumber: '10322',
        sellerName: 'Begzod Hamdamov',
        products: [
          ThermalReceiptProductLine(
            name: 'Муфта 20 Asiya Plast',
            quantity: '2 шт',
            unitPrice: '6,890',
            lineTotal: '13,780',
            catalogUnitPrice: '5,750',
          ),
        ],
        totalAmount: '13,780',
      ),
    );

    expect(
      lines.any(ReceiptStrikethroughText.containsMarker),
      isTrue,
      reason: 'chegirmali narx qatorida § marker bo‘lishi kerak',
    );

    final bytes = await EscPosReceiptBuilder.buildReceipt(lines: lines);
    expect(bytes, isNotEmpty);
    expect(bytes.length, greaterThan(20));
  });
}
