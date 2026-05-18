import 'package:alfapos_app/models/cart_item.dart';
import 'package:alfapos_app/models/product.dart';
import 'package:alfapos_app/providers/sales_session_provider.dart';
import 'package:alfapos_app/utils/customer_group_discount.dart';
import 'package:alfapos_app/utils/sales_filter_cart_price.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('pachka kelish narxi — package_purchase_price', () {
    final product = Product.fromApiJson({
      'id': 1,
      'title': 'Test',
      'selling_price': 70000,
      'purchase_price': 1000,
      'variants': [
        {
          'id': 10,
          'units_per_package': 20,
          'package_selling_price': '8000',
          'package_purchase_price': '5000',
        },
      ],
    });
    final item = CartItem(product: product, quantity: 1, sellByPack: true);
    expect(CustomerGroupDiscount.catalogUnitPriceForItem(item, 'purchase'), 5000);
    expect(item.defaultLineUnitPrice, 8000);

    final sales = SalesSessionProvider.instance;
    sales.clearSalesFilters();
    sales.setSellAtPurchasePrice(true);
    SalesFilterCartPrice.applySessionPriceToItem(item, sales);
    expect(item.unitPriceDisplay, 5000);
    sales.clearSalesFilters();
  });

  test('pachka kelish — faqat dona kirim narxi bo‘lsa, dona × pachka', () {
    final product = Product(
      id: '1',
      name: 'Test',
      priceUzs: 8000,
      costPriceUzs: 500,
      quantityInPack: true,
      quantityPerPack: 20,
      sellPricePerPack: 8000,
    );
    expect(product.purchasePackUnitPriceNum, 10000);
    final item = CartItem(product: product, quantity: 1, sellByPack: true);
    expect(CustomerGroupDiscount.catalogUnitPriceForItem(item, 'purchase'), 10000);
  });
}
