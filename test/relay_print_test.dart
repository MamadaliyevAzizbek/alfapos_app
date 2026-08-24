import 'package:alfapos_app/services/escpos_receipt_builder.dart';
import 'package:alfapos_app/services/network_printer_send.dart';
import 'package:alfapos_app/services/raw_printer_send.dart';
import 'package:flutter_test/flutter_test.dart';

@TestOn('mac-os')
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('RAW lp file print', () async {
    final bytes = await EscPosReceiptBuilder.buildReceipt(
      lines: [
        '^AlfaPOS',
        'Relay test',
        'Jami: 125 000 so\'m',
        DateTime.now().toString().substring(0, 19),
      ],
      openCashDrawer: false,
    );
    final result = await RawPrinterSend.send(bytes, printerName: 'Xprinter_XP_365B');
    expect(result.ok, isTrue, reason: result.message);
  });

  test('TCP relay accepts PNG payload', () async {
    // Minimal valid PNG (1x1) — relay PNG yo‘lini tekshiradi.
    const png = <int>[
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
      0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
      0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
      0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
      0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
      0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
      0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
      0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
      0x42, 0x60, 0x82,
    ];
    final result = await NetworkPrinterSend.send(
      png,
      host: '127.0.0.1',
      port: 9100,
    );
    expect(result.ok, isTrue, reason: result.message);
  });
}
