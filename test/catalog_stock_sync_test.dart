import 'package:alfapos_app/models/product.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('preferServerStock: ro‘yxat yangilanganda server miqdori (0 ham) saqlanadi', () {
    const fromApi = Product(
      id: '1',
      name: 'A',
      priceUzs: 1000,
      initialQuantity: 0,
      quantityInfo: '0 dona',
    );
    const cached = Product(
      id: '1',
      name: 'A',
      priceUzs: 1000,
      initialQuantity: 25,
      quantityInfo: '25 dona',
    );
    final mergedDefault = fromApi.mergeWithLocalFallback(cached);
    expect(mergedDefault.initialQuantity, 25);

    final mergedServer = fromApi.mergeWithLocalFallback(cached, preferServerStock: true);
    expect(mergedServer.initialQuantity, 0);
  });

  test('katalog miqdori kirim API ustidan — merge yo‘nalishi', () {
    const catalog = Product(
      id: '5',
      name: 'Cola',
      priceUzs: 15000,
      initialQuantity: 120,
      quantityInfo: '120 dona',
    );
    const fromReceive = Product(
      id: '5',
      name: 'Cola',
      priceUzs: 15000,
      initialQuantity: 80,
      quantityInfo: '80 dona',
    );
    final aligned = catalog.mergeWithLocalFallback(fromReceive);
    expect(aligned.initialQuantity, 120);
    expect(aligned.availableStockQuantity, 120);
  });
}
