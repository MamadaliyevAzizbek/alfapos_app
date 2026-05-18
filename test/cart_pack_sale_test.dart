import 'package:flutter_test/flutter_test.dart';
import 'package:alfapos_app/models/cart_item.dart';
import 'package:alfapos_app/models/product.dart';

Product _packProduct() => Product(
      id: '1',
      name: 'Test pachkali',
      priceUzs: 70000,
      costPriceUzs: 60000,
      barcode: '076950450479',
      quantityInPack: true,
      quantityPerPack: 20,
      sellPricePerPack: 8000,
      costPricePerPack: 500,
      initialQuantity: 100,
    );

void main() {
  group('pachka / dona sotish narxlari', () {
    test('dona tanlanganda dona narxi, pachkada pachka narxi', () {
      final p = _packProduct();
      expect(p.pieceSellPriceNum, 70000);
      expect(p.packSellUnitPriceNum, 8000);
      expect(p.sellUnitPriceNum, 8000);

      final dona = CartItem(product: p, quantity: 2, sellByPack: false);
      final pachka = CartItem(product: p, quantity: 1, sellByPack: true);

      expect(dona.defaultLineUnitPrice, 70000);
      expect(pachka.defaultLineUnitPrice, 8000);
      expect(dona.total, 140000);
      expect(pachka.total, 8000);
    });

    test('dona sotishda ombordan dona soni, pachkada ko‘paytiriladi', () {
      final p = _packProduct();
      expect(CartItem(product: p, quantity: 3, sellByPack: false).quantityToDeduct, 3);
      expect(CartItem(product: p, quantity: 2, sellByPack: true).quantityToDeduct, 40);
    });

    test('pachkasiz mahsulotda faqat dona', () {
      final p = Product(
        id: '2',
        name: 'Oddiy',
        priceUzs: 5000,
        initialQuantity: 10,
      );
      expect(p.canSellByPack, false);
      final item = CartItem(product: p, sellByPack: false);
      expect(item.defaultLineUnitPrice, 5000);
    });

    test('sellByPack true lekin pachka yo‘q — dona narxi', () {
      final p = Product(
        id: '3',
        name: 'No pack',
        priceUzs: 3000,
        initialQuantity: 1,
      );
      final item = CartItem(product: p, sellByPack: true);
      expect(item.defaultLineUnitPrice, 3000);
    });
  });
}
