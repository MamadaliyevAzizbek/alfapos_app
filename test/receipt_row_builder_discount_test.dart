import 'package:alfapos_app/models/cart_item.dart';
import 'package:alfapos_app/models/product.dart';
import 'package:alfapos_app/utils/receipt_row_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('keeps one-time cart sale price in the receipt', () {
    final item = CartItem(
      product: Product(
        id: '1',
        name: 'Bir martalik chegirma',
        priceUzs: 100000,
      ),
      salePriceOverride: 80000,
    );

    final row = ReceiptRowBuilder.fromCartItem(item);

    expect(row.price, 80000);
    expect(row.sum, 80000);
    expect(row.catalogPrice, 100000);
  });

  test('uses line discount when API total is still catalog total', () {
    final row = ReceiptRowBuilder.fromInvoiceRow({
      'title': 'Chegirmali mahsulot',
      'quantity': 1,
      'price': 100000,
      'discount': 20000,
      'total': 100000,
    });

    expect(row.price, 80000);
    expect(row.sum, 80000);
    expect(row.catalogPrice, 100000);
    expect(row.catalogSum, 100000);
  });

  test('keeps an already discounted API line total', () {
    final row = ReceiptRowBuilder.fromInvoiceRow({
      'title': 'Chegirmali mahsulot',
      'quantity': 2,
      'price': 100000,
      'discount': 20000,
      'total': 180000,
    });

    expect(row.price, 90000);
    expect(row.sum, 180000);
    expect(row.catalogPrice, 100000);
    expect(row.catalogSum, 200000);
  });
}
