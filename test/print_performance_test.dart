import 'package:alfapos_app/models/receipt_design_config.dart';
import 'package:alfapos_app/services/escpos_receipt_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('buildReceipt is fast after warmup', () async {
    await EscPosReceiptBuilder.warmup();

    final lines = [
      '^AlfaPOS',
      'Test chek',
      'Mahsulot 1 x 10 000 = 10 000',
      'Jami: 10 000 so\'m',
    ];
    const design = ReceiptDesignConfig.defaults;

    final first = Stopwatch()..start();
    await EscPosReceiptBuilder.buildReceipt(lines: lines, design: design);
    first.stop();

    final second = Stopwatch()..start();
    await EscPosReceiptBuilder.buildReceipt(lines: lines, design: design);
    second.stop();

    expect(first.elapsedMilliseconds, lessThan(2000),
        reason: 'First ESC/POS build should finish within 2s');
    expect(second.elapsedMilliseconds, lessThan(500),
        reason: 'Cached ESC/POS build should finish within 500ms');
  });
}
