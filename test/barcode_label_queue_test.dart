import 'package:alfapos_app/models/barcode_label_config.dart';
import 'package:alfapos_app/models/product.dart';
import 'package:alfapos_app/services/barcode_label_tspl_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('queue concatenates TSPL jobs in order', () async {
    const a = Product(
      id: '1',
      name: 'Cola',
      priceUzs: 10000,
      barcode: '4708058113616',
    );
    const b = Product(
      id: '2',
      name: 'Aprel',
      priceUzs: 5000,
      barcode: '1402131924535',
    );

    final first = await BarcodeLabelTsplBuilder.buildNative(
      product: a,
      barcode: '4708058113616',
      config: const BarcodeLabelConfig(widthMm: 40, heightMm: 30, copies: 5),
    );
    final second = await BarcodeLabelTsplBuilder.buildNative(
      product: b,
      barcode: '1402131924535',
      config: const BarcodeLabelConfig(
        widthMm: 40,
        heightMm: 30,
        copies: 2,
        template: BarcodeLabelTemplate.shopName,
        shopName: 'ALFA MARKET',
      ),
    );
    final combined = <int>[...first, ...second];
    final ascii = String.fromCharCodes(combined.where((c) => c >= 32 && c < 127));
    expect(ascii.indexOf('PRINT 1,5'), lessThan(ascii.indexOf('PRINT 1,2')));
    expect(ascii.contains('ALFA MARKET'), isTrue);
    expect(ascii.contains('COLA'), isTrue);
  });
}
