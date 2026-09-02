import 'dart:typed_data';

import 'package:alfapos_app/models/barcode_label_config.dart';
import 'package:alfapos_app/models/product.dart';
import 'package:alfapos_app/services/barcode_label_tspl_builder.dart';
import 'package:alfapos_app/services/mobile_printer_relay.dart';
import 'package:alfapos_app/services/raw_printer_send.dart';
import 'package:flutter_test/flutter_test.dart';

@TestOn('mac-os')
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await BarcodeLabelTsplBuilder.buildNative(
      product: const Product(
        id: 'font-warmup',
        name: 'М',
        priceUzs: 1,
        barcode: '4708058113616',
      ),
      barcode: '4708058113616',
      config: const BarcodeLabelConfig(widthMm: 40, heightMm: 30, copies: 1),
    );
  });

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
    final barcodeStart = ascii.indexOf('BARCODE ');
    final barcodeEnd = ascii.indexOf('TEXT ', barcodeStart);
    final barcodeCommand = ascii.substring(barcodeStart, barcodeEnd);
    expect(barcodeCommand.contains('"470805811361"'), isTrue);
    expect(barcodeCommand.contains('"4708058113616"'), isFalse);
    expect(ascii.contains('PRINT 1,5'), isTrue);
    expect(ascii.contains('BITMAP'), isFalse);
  });

  test('native TSPL renders Russian product name as BITMAP raster', () async {
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
    expect(ascii.contains('CODEPAGE 1251'), isTrue);
    expect(ascii.contains('BITMAP'), isTrue);
    expect(ascii.contains('BARCODE'), isTrue);
    expect(_bitmapPayloadHasInk(tspl), isTrue);
  });

  test('native TSPL renders Cyrillic shop name as BITMAP raster', () async {
    const cfg = BarcodeLabelConfig(
      widthMm: 40,
      heightMm: 30,
      copies: 1,
      template: BarcodeLabelTemplate.shopName,
      shopName: 'САНТЕХНИКА ZEBO',
    );
    final tspl = await BarcodeLabelTsplBuilder.buildNative(
      product: product,
      barcode: '4708058113616',
      config: cfg,
    );
    final ascii = String.fromCharCodes(tspl.where((b) => b >= 32 && b < 127));
    expect(ascii.contains('BITMAP'), isTrue);
    expect(ascii.contains('BARCODE'), isTrue);
    expect(_bitmapPayloadHasInk(tspl), isTrue);
  });

  test('bitmap packer uses TSC polarity (0 = black)', () {
    final rgba = Uint8List.fromList([
      0, 0, 0, 255, 255, 255, 255, 255,
      255, 255, 255, 255, 0, 0, 0, 255,
    ]);
    final packed = BarcodeLabelTsplBuilder.packBitmapRgbaForTest(
      rgba: rgba,
      width: 2,
      widthBytes: 1,
      height: 2,
    );
    expect(packed, [0x7F, 0xBF]);
    expect(BarcodeLabelTsplBuilder.countBlackPixelsForTest(packed), 2);
  });

  test('relay detects TSPL when PRINT follows large BITMAP payload', () {
    final header =
        'SIZE 40 mm,30 mm\r\nCLS\r\nBARCODE 10,10,"EAN13",80,0,0,2,3,"470805811361"\r\n'
        'BITMAP 10,100,20,26,0,';
    final payload = <int>[
      ...header.codeUnits,
      ...List<int>.filled(600, 0),
      ...'PRINT 1,1\r\n'.codeUnits,
    ];
    expect(MobilePrinterRelay.looksLikeTspl(payload), isTrue);
  });

  test('relay detects TSPL when CLS is after the first 96 bytes', () {
    final payload = <int>[
      ...'SIZE 40 mm,30 mm\r\n'
              'GAP 2 mm,0 mm\r\n'
              'DENSITY 12\r\n'
              'SPEED 3\r\n'
              'DIRECTION 0\r\n'
              'REFERENCE 0,0\r\n'
              'CODEPAGE 1251\r\n'
          .codeUnits,
      ...List<int>.filled(30, 32),
      ...'CLS\r\nBARCODE 10,10,"EAN13",80,0,0,2,3,"470805811361"\r\n'
              'PRINT 1,1\r\n'
          .codeUnits,
    ];
    expect(payload.length, greaterThan(96));
    expect(MobilePrinterRelay.looksLikeTspl(payload), isTrue);
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
    expect(ascii.contains('BITMAP'), isFalse);
  });

  test('native TSPL prints 2 copies', () async {
    const cfg = BarcodeLabelConfig(widthMm: 40, heightMm: 30, copies: 2);
    const russianProduct = Product(
      id: 'test-ru-print',
      name: 'САНТЕХНИКА ZEBO',
      priceUzs: 50000,
      barcode: '4708058113616',
    );
    final tspl = await BarcodeLabelTsplBuilder.buildNative(
      product: russianProduct,
      barcode: '4708058113616',
      config: cfg,
    );
    final ascii = String.fromCharCodes(tspl.where((b) => b >= 32 && b < 127));
    expect(ascii.contains('BITMAP'), isTrue);
    expect(ascii.contains('BARCODE'), isTrue);
    final result = await RawPrinterSend.send(
      tspl,
      printerName: 'Xprinter_XP_365B',
    );
    expect(result.ok, isTrue, reason: result.message);
  });
}

bool _bitmapPayloadHasInk(List<int> tspl) {
  final marker = 'BITMAP '.codeUnits;
  final start = _indexOfSublist(tspl, marker);
  if (start < 0) return false;
  final comma = tspl.indexOf(44, start); // after mode
  if (comma < 0) return false;
  final headerEnd = tspl.indexOf(10, comma);
  if (headerEnd < 0) return false;
  final payloadStart = headerEnd + 1;
  if (payloadStart >= tspl.length) return false;
  final payloadEnd = tspl.indexOf(10, payloadStart);
  final end = payloadEnd < 0 ? tspl.length : payloadEnd;
  final packed = Uint8List.fromList(tspl.sublist(payloadStart, end));
  return BarcodeLabelTsplBuilder.countBlackPixelsForTest(packed) >= 8;
}

int _indexOfSublist(List<int> haystack, List<int> needle) {
  if (needle.isEmpty || haystack.length < needle.length) return -1;
  for (var i = 0; i <= haystack.length - needle.length; i++) {
    var found = true;
    for (var j = 0; j < needle.length; j++) {
      if (haystack[i + j] != needle[j]) {
        found = false;
        break;
      }
    }
    if (found) return i;
  }
  return -1;
}
