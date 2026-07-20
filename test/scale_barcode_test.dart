import 'package:alfapos_app/utils/scale_barcode.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('looksLikePossibleScaleBarcode', () {
    test('13 digit EAN', () {
      expect(looksLikePossibleScaleBarcode('0100012002167'), isTrue);
    });
    test('scanner dropped leading zero', () {
      expect(looksLikePossibleScaleBarcode('100012002167'), isTrue);
    });
    test('short sku not scale', () {
      expect(looksLikePossibleScaleBarcode('1234567'), isFalse);
    });
    test('name not scale', () {
      expect(looksLikePossibleScaleBarcode('un'), isFalse);
    });
  });

  group('ScaleBarcode.parseSuccess', () {
    test('parses product quantity as kg weight', () {
      final hit = ScaleBarcode.parseSuccess({
        'success': true,
        'is_scale_barcode': true,
        'normalized_barcode': '0100012002167',
        'plu_code': '00012',
        'quantity': 0.216,
        'scale_weight': 0.216,
        'product': {
          'productID': 123,
          'productTitle': 'un',
          'variantID': 82143,
          'price': 4000,
          'selling_price': 4000,
          'quantity': 0.216,
          'scaleWeight': 0.216,
          'isScaleItem': true,
          'pluCode': '00012',
        },
      });

      expect(hit, isNotNull);
      expect(hit!.product.id, '123');
      expect(hit.product.name, 'un');
      expect(hit.product.priceUzs, 4000);
      expect(hit.quantity, 0.216);
      expect(hit.isScaleItem, isTrue);
      expect(hit.pluCode, '00012');
    });

    test('barcodeResultValue fallback', () {
      final hit = ScaleBarcode.parseSuccess({
        'success': true,
        'is_scale_barcode': true,
        'quantity': 1.5,
        'barcodeResultValue': {
          'productID': 10,
          'productTitle': 'guruch',
          'variantID': 1,
          'price': 12000,
          'isScaleItem': true,
          'scaleWeight': 1.5,
        },
      });
      expect(hit, isNotNull);
      expect(hit!.quantity, 1.5);
      expect(hit.product.name, 'guruch');
    });

    test('null when no product', () {
      expect(
        ScaleBarcode.parseSuccess({
          'success': false,
          'is_scale_barcode': true,
          'product': null,
        }),
        isNull,
      );
    });
  });

  test('isScaleBarcodeResponse', () {
    expect(ScaleBarcode.isScaleBarcodeResponse({'is_scale_barcode': true}), isTrue);
    expect(ScaleBarcode.isScaleBarcodeResponse({'is_scale_barcode': false}), isFalse);
  });
}
