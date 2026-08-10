import 'package:alfapos_app/models/product.dart';
import 'package:alfapos_app/utils/product_search.dart';
import 'package:alfapos_app/utils/scale_barcode.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('looksLikePossibleScaleBarcode', () {
    test('13 digit EAN including 01 prefix (tarvuz label)', () {
      expect(looksLikePossibleScaleBarcode('0100087004509'), isTrue);
    });
    test('scanner dropped leading zero', () {
      expect(looksLikePossibleScaleBarcode('100087004509'), isTrue);
    });
    test('short sku not scale', () {
      expect(looksLikePossibleScaleBarcode('1234567'), isFalse);
    });
  });

  group('extractScaleWeightKg', () {
    test('tarvuz label 0.450 kg', () {
      expect(extractScaleWeightKg('0100087004509'), 0.450);
    });
    test('spaces in barcode', () {
      expect(extractScaleWeightKg('0100087 004509'), 0.450);
    });
  });

  group('extractScalePluCandidates', () {
    test('PLU 00087 from tarvuz label', () {
      final plu = extractScalePluCandidates('0100087004509');
      expect(plu, contains('00087'));
      expect(plu, contains('87'));
    });
  });

  group('ScaleBarcode.parseSuccess', () {
    test('parses product quantity as kg weight', () {
      final hit = ScaleBarcode.parseSuccess({
        'success': true,
        'is_scale_barcode': true,
        'normalized_barcode': '0100087004509',
        'plu_code': '00087',
        'quantity': 0.450,
        'scale_weight': 0.450,
        'product': {
          'productID': 123,
          'productTitle': 'tarvuz',
          'variantID': 82143,
          'price': 2800,
          'selling_price': 2800,
          'quantity': 0.450,
          'scaleWeight': 0.450,
          'isScaleItem': true,
          'pluCode': '00087',
        },
      });

      expect(hit, isNotNull);
      expect(hit!.product.name, 'tarvuz');
      expect(hit.quantity, 0.450);
      expect(hit.isScaleItem, isTrue);
      expect(hit.pluCode, '00087');
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

  group('Product PLU match', () {
    test('matches scale label via plu_code', () {
      final p = Product(
        id: '1',
        name: 'tarvuz',
        priceUzs: 2800,
        pluCode: '00087',
      );
      expect(p.matchesBarcode('0100087004509'), isTrue);
      expect(p.matchesPlu('87'), isTrue);
    });

    test('looksLikeBarcodeOrPluInput', () {
      expect(looksLikeBarcodeOrPluInput('0100087004509'), isTrue);
      expect(looksLikeBarcodeOrPluInput('1001'), isTrue);
      expect(looksLikeBarcodeOrPluInput('fanta'), isFalse);
    });
  });
}
