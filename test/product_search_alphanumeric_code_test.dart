import 'package:alfapos_app/models/product.dart';
import 'package:alfapos_app/utils/product_search.dart';
import 'package:flutter_test/flutter_test.dart';

/// Harf-raqamli shtrix / SKU (masalan `SK51D25120407`) sotuvda topilishi kerak.
void main() {
  const codeInBarcode = Product(
    id: '1',
    name: 'IBA 7612',
    barcode: 'SK51D25120407',
    priceUzs: 338000,
  );
  const codeInSku = Product(
    id: '2',
    name: 'IBA 7612 sku',
    sku: 'SK51D25120407',
    priceUzs: 338000,
  );
  const other = Product(
    id: '3',
    name: 'Cola',
    barcode: '5449000000996',
    priceUzs: 8000,
  );

  group('looksLikeBarcodeInput', () {
    test('harf-raqamli kod shtrix deb qabul qilinadi', () {
      expect(looksLikeBarcodeInput('SK51D25120407'), isTrue);
      expect(looksLikeAlphanumericCodeInput('SK51D25120407'), isTrue);
    });

    test('mahsulot nomi shtrix deb qabul qilinmaydi', () {
      expect(looksLikeBarcodeInput('Coca cola 0.5'), isFalse);
      expect(looksLikeBarcodeInput('kley 8'), isFalse);
      expect(looksLikeBarcodeInput('bolgarka'), isFalse);
      // Qisqa (8 dan kam) yoki raqamsiz kodlar ham nom deb qoladi.
      expect(looksLikeBarcodeInput('IBA7612'), isFalse);
      expect(looksLikeBarcodeInput('bolgarkatosh'), isFalse);
    });
  });

  group('matchesCodeExact', () {
    test('shtrix va SKU dagi harfli kod topiladi', () {
      expect(codeInBarcode.matchesCodeExact('SK51D25120407'), isTrue);
      expect(codeInSku.matchesCodeExact('SK51D25120407'), isTrue);
    });

    test('kichik harf va ajratgichlar farq qilmaydi', () {
      expect(codeInBarcode.matchesCodeExact('sk51d25120407'), isTrue);
      expect(codeInBarcode.matchesCodeExact('SK51D-2512-0407'), isTrue);
      expect(codeInBarcode.matchesCodeExact('  SK51D25120407 '), isTrue);
    });

    test('qisman kod yolg‘on moslik bermaydi', () {
      expect(codeInBarcode.matchesCodeExact('SK51D'), isFalse);
      expect(codeInBarcode.matchesCodeExact('25120407'), isFalse);
      expect(other.matchesCodeExact('SK51D25120407'), isFalse);
    });
  });

  group('filterProductsByQuery', () {
    test('harfli shtrix kod bo‘yicha mahsulot topiladi', () {
      final result = filterProductsByQuery([other, codeInBarcode], 'SK51D25120407');
      expect(result, hasLength(1));
      expect(result.single.name, 'IBA 7612');
    });

    test('harfli SKU bo‘yicha mahsulot topiladi', () {
      final result = filterProductsByQuery([other, codeInSku], 'SK51D25120407');
      expect(result, hasLength(1));
      expect(result.single.name, 'IBA 7612 sku');
    });

    test('mos kelmagan mahsulot chiqmaydi', () {
      expect(filterProductsByQuery([other], 'SK51D25120407'), isEmpty);
    });
  });

  group('filterProductsByBarcodeQuery', () {
    test('harfli kod avtomatik qo‘shish zanjirida ham topiladi', () {
      final hits = filterProductsByBarcodeQuery(
        [other, codeInBarcode],
        'SK51D25120407',
      );
      expect(hits, hasLength(1));
      expect(hits.single.id, '1');
    });
  });

  group('qisman raqamli shtrix', () {
    test('boshi va oxiri bo‘yicha topiladi', () {
      final products = [other];
      expect(filterProductsByQuery(products, '5449000000996'), hasLength(1));
      expect(filterProductsByQuery(products, '544900'), hasLength(1));
      expect(filterProductsByQuery(products, '0996'), hasLength(1));
    });

    test('shtrixi yo‘q mahsulot raqamli qidiruvda chiqmaydi', () {
      const noBarcode = Product(id: '9', name: 'Nobarcode', priceUzs: 1000);
      expect(filterProductsByQuery([noBarcode], '123456'), isEmpty);
    });
  });
}
