import 'package:alfapos_app/models/cart_item.dart';
import 'package:alfapos_app/models/product.dart';
import 'package:alfapos_app/providers/clients_provider.dart';
import 'package:alfapos_app/utils/cart_discount_percent.dart';
import 'package:alfapos_app/utils/customer_group_discount.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('kelish narxi −10% saqlanadi — afterCustomerPricing bekor qilmaydi', () {
    final product = Product(
      id: '1',
      name: 'Fanta',
      priceUzs: 21000,
      costPriceUzs: 15000,
    );
    final item = CartItem(product: product, quantity: 1);
    final client = Client(
      id: '1',
      name: 'Mijoz',
      customerGroupDiscountPriceType: 'purchase',
      customerGroupDiscount: -10,
    );

    CustomerGroupDiscount.applyCustomerPricingToCart([item], client);
    expect(item.unitPriceDisplay, 13000); // 15000 × 0.9 = 13500 → pastga 13000

    CartDiscountPercent.afterCustomerPricing([item], 0);
    expect(item.unitPriceDisplay, 13000);
    expect(product.pieceSellPriceNum, 21000);
    expect(product.costPriceUzs, 15000); // kelish narxi katalogda o'zgarmaydi
  });
}
