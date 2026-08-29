import 'package:alfapos_app/models/barcode_label_config.dart';
import 'package:alfapos_app/models/product.dart';
import 'package:alfapos_app/services/barcode_label_tspl_builder.dart';
import 'package:alfapos_app/services/raw_printer_send.dart';
import 'package:alfapos_app/utils/escpos_text_codec.dart';
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

  test('native TSPL selects CP1251 for Russian product names', () async {
    const russianProduct = Product(
      id: 'test-ru',
      name: 'МОЛОКО РОССИЯ',
      priceUzs: 12000,
      barcode: '4708058113616',
    );
    const cfg = BarcodeLabelConfig(widthMm: 40, heightMm: 30, copies: 1);
    final tspl = await BarcodeLabelTsplBuilder.buildNative(
      product: russianProduct,
      barcode: '4708058113616',
      config: cfg,
    );
    final ascii = String.fromCharCodes(tspl.where((b) => b >= 32 && b < 127));
    final russianBytes = EscPosTextCodec.encodeSync(
      'МОЛОКО РОССИЯ',
      codePage: 'CP1251',
    );

    expect(ascii.contains('CODEPAGE 1251'), isTrue);
    expect(_containsBytes(tspl, russianBytes), isTrue);
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

bool _containsBytes(List<int> bytes, List<int> needle) {
  for (var i = 0; i <= bytes.length - needle.length; i++) {
    var matches = true;
    for (var j = 0; j < needle.length; j++) {
      if (bytes[i + j] != needle[j]) {
        matches = false;
        break;
      }
    }
    if (matches) return true;
  }
  return false;
}
