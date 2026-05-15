import 'package:flutter_test/flutter_test.dart';
import 'package:alfapos_app/models/product.dart';
import 'package:alfapos_app/screens/katalog_screen.dart';

void main() {
  Product productWithBarcode(String name, String barcode) => Product(
        id: 'id-$name',
        name: name,
        barcode: barcode,
        priceUzs: 1000,
        initialQuantity: 1,
      );

  group('KatalogScreen.filterProductsByQuery barcode', () {
    test('barcode aniq yozilganda mahsulot topiladi', () {
      final products = [
        productWithBarcode('Cola', '5449000000996'),
        productWithBarcode('Suv', '4601234567890'),
      ];
      final result = KatalogScreen.filterProductsByQuery(products, '5449000000996');
      expect(result.length, 1);
      expect(result.first.name, 'Cola');
      expect(result.first.barcode, '5449000000996');
    });

    test('barcode qisman yozilganda ham topiladi', () {
      final products = [
        productWithBarcode('Cola', '5449000000996'),
      ];
      expect(KatalogScreen.filterProductsByQuery(products, '5449000000996').length, 1);
      expect(KatalogScreen.filterProductsByQuery(products, '544900').length, 1);
      expect(KatalogScreen.filterProductsByQuery(products, '0996').length, 1);
    });

    test('barcode bo\'shliq va tire bilan yozilsa topiladi', () {
      final products = [
        productWithBarcode('Cola', '5449000000996'),
      ];
      expect(KatalogScreen.filterProductsByQuery(products, '5449 0000 00996').length, 1);
      expect(KatalogScreen.filterProductsByQuery(products, '5449-0000-00996').length, 1);
    });

    test('nom bilan qidirish ishlaydi', () {
      final products = [
        productWithBarcode('Cola', '5449000000996'),
      ];
      final result = KatalogScreen.filterProductsByQuery(products, 'Cola');
      expect(result.length, 1);
      expect(result.first.name, 'Cola');
    });

    test('barcode bo\'lmagan mahsulot barcode qidiruvida chiqmaydi', () {
      final products = [
        Product(id: '1', name: 'Nobarcode', priceUzs: 1000, initialQuantity: 1),
      ];
      expect(KatalogScreen.filterProductsByQuery(products, '123456').length, 0);
    });

    test('bo\'sh qidiruv barcha mahsulotlarni qaytaradi', () {
      final products = [
        productWithBarcode('A', '111'),
        productWithBarcode('B', '222'),
      ];
      expect(KatalogScreen.filterProductsByQuery(products, '').length, 2);
      expect(KatalogScreen.filterProductsByQuery(products, '   ').length, 2);
    });
  });
}
