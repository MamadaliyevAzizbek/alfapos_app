import 'package:alfapos_app/models/product.dart';
import 'package:alfapos_app/services/barcode_label_printer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('resolvePrintCode uses barcode, not sku or plu', () {
    const withBarcode = Product(
      id: '1',
      name: 'Cola',
      priceUzs: 10000,
      barcode: '1402131924535',
      sku: '57',
      pluCode: '57',
    );
    expect(BarcodeLabelPrinter.resolvePrintCode(withBarcode), '1402131924535');

    const skuOnly = Product(
      id: '2',
      name: 'Usluga',
      priceUzs: 1000,
      sku: '57',
      pluCode: '57',
    );
    expect(skuOnly.hasBarcodeForPrint, isFalse);
    expect(BarcodeLabelPrinter.resolvePrintCode(skuOnly), isNull);

    const extraOnly = Product(
      id: '3',
      name: 'Extra',
      priceUzs: 1000,
      additionalBarcodes: ['4780151102501'],
    );
    expect(BarcodeLabelPrinter.resolvePrintCode(extraOnly), '4780151102501');
  });
}
