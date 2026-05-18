import 'package:alfapos_app/models/cart_item.dart';
import 'package:alfapos_app/models/product.dart';
import 'package:alfapos_app/providers/sales_session_provider.dart';
import 'package:alfapos_app/utils/sales_filter_cart_price.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('kelish narxida sotish — savat chegirmali narxiga', () {
    final sales = SalesSessionProvider.instance;
    sales.clearSalesFilters();
    sales.setSellAtPurchasePrice(true);

    final product = Product(
      id: '1',
      name: 'salom',
      priceUzs: 3000,
      costPriceUzs: 1000,
    );
    final item = CartItem(product: product, quantity: 1);
    SalesFilterCartPrice.applySessionPriceToItem(item, sales);

    expect(item.unitPriceDisplay, 1000);
    expect(product.priceUzs, 3000);
    sales.clearSalesFilters();
  });

  test('ulgurji va kelish bir vaqtda yoqilmaydi', () {
    final sales = SalesSessionProvider.instance;
    sales.clearSalesFilters();
    sales.setSellAtWholesalePrice(true);
    expect(sales.sellAtWholesalePrice, isTrue);
    expect(sales.sellAtPurchasePrice, isFalse);

    sales.setSellAtPurchasePrice(true);
    expect(sales.sellAtPurchasePrice, isTrue);
    expect(sales.sellAtWholesalePrice, isFalse);
    sales.clearSalesFilters();
  });
}
