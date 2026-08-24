import 'package:alfapos_app/models/barcode_label_config.dart';
import 'package:alfapos_app/models/product.dart';
import 'package:alfapos_app/services/barcode_label_tspl_builder.dart';
import 'package:alfapos_app/services/raw_printer_send.dart';
import 'package:flutter_test/flutter_test.dart';

@TestOn('mac-os')
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final product = Product(
    id: 'test-1',
    name: 'OMINA MARMALADE KONFET (2KG)',
    priceUzs: 50000,
    barcode: '4708058113616',
  );

  test('native TSPL standard template', () async {
    const cfg = BarcodeLabelConfig(widthMm: 40, heightMm: 30, copies: 5);
    final tspl = await BarcodeLabelTsplBuilder.buildNative(
      product: product,
      barcode: '4708058113616',
      config: cfg,
    );
    final ascii = String.fromCharCodes(tspl.where((b) => b >= 32 && b < 127));
    expect(ascii.contains('SIZE 40 mm,30 mm'), isTrue);
    expect(ascii.contains('BARCODE'), isTrue);
    expect(ascii.contains(',2,"4708058113616"'), isFalse);
    expect(ascii.contains('PRINT 1,5'), isTrue);
    expect(ascii.contains('BITMAP'), isFalse);
  });

  test('native TSPL shop name template', () async {
    const cfg = BarcodeLabelConfig(
      widthMm: 40,
      heightMm: 30,
      copies: 1,
      template: BarcodeLabelTemplate.shopName,
      shopName: 'ALFA MARKET',
    );
    final tspl = await BarcodeLabelTsplBuilder.buildNative(
      product: product,
      barcode: '4708058113616',
      config: cfg,
    );
    final ascii = String.fromCharCodes(tspl.where((b) => b >= 32 && b < 127));
    expect(ascii.contains('ALFA MARKET'), isTrue);
  });

  test('native TSPL prints 2 copies', () async {
    const cfg = BarcodeLabelConfig(widthMm: 40, heightMm: 30, copies: 2);
    final tspl = await BarcodeLabelTsplBuilder.buildNative(
      product: product,
      barcode: '4708058113616',
      config: cfg,
    );
    final result = await RawPrinterSend.send(
      tspl,
      printerName: 'Xprinter_XP_365B',
    );
    expect(result.ok, isTrue, reason: result.message);
  });
}
