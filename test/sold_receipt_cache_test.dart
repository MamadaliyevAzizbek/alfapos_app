import 'package:alfapos_app/models/cart_item.dart';
import 'package:alfapos_app/models/product.dart';
import 'package:alfapos_app/services/sold_receipt_cache.dart';
import 'package:alfapos_app/utils/sold_receipt_payload_builder.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  test('payload builder includes products payments and totals', () {
    final items = [
      CartItem(
        product: Product(id: '10', name: 'Non', priceUzs: 4000, unit: 'sht'),
        quantity: 2,
      ),
      CartItem(
        product: Product(id: '11', name: 'Sut', priceUzs: 12000, unit: 'l'),
        quantity: 1,
        salePriceOverride: 10000,
        priceLocked: true,
      ),
    ];
    final sub = items.fold<num>(0, (s, e) => s + e.total);
    final detail = SoldReceiptPayloadBuilder.buildInvoiceDetail(
      items: items,
      subTotal: 8000 + 12000,
      grandTotal: sub,
      discountUzs: (8000 + 12000) - sub,
      payments: [
        {'paymentID': 1, 'paymentName': 'Naqd pul', 'paid': sub},
      ],
    );
    final rows = detail['datarows'] as List;
    expect(rows.any((r) => r['title'] == 'Non' && r['quantity'] == 2), isTrue);
    expect(rows.any((r) => r['title'] == 'Sut'), isTrue);
    expect(rows.any((r) => r['title'] == 'Total' && r['total'] == sub), isTrue);
    expect(rows.any((r) => r['title'] == 'Naqd pul'), isTrue);
    expect(detail['_localCached'], isTrue);

    final sale = SoldReceiptPayloadBuilder.buildSaleRow(
      orderId: 420100,
      invoiceId: 'POS10100',
      subTotal: 20000,
      grandTotal: sub,
      discountUzs: 2000,
      items: items,
      sellerName: 'Kassir',
    );
    expect(sale['id'], 420100);
    expect(sale['invoice_id'], 'POS10100');
    expect(sale['total'], sub);
  });

  test('cache save and getDetail roundtrip', () async {
    final items = [
      CartItem(
        product: Product(id: '1', name: 'Choy', priceUzs: 5000, unit: 'sht'),
        quantity: 1,
      ),
    ];
    final sale = SoldReceiptPayloadBuilder.buildSaleRow(
      orderId: 99,
      invoiceId: 'POS99',
      subTotal: 5000,
      grandTotal: 5000,
      discountUzs: 0,
      items: items,
    );
    final detail = SoldReceiptPayloadBuilder.buildInvoiceDetail(
      items: items,
      subTotal: 5000,
      grandTotal: 5000,
      discountUzs: 0,
      payments: [
        {'paymentName': 'Naqd', 'paid': 5000},
      ],
    );
    await SoldReceiptCache.save(
      orderId: 99,
      invoiceId: 'POS99',
      sale: sale,
      invoiceDetail: detail,
    );
    final loaded = await SoldReceiptCache.getDetail(99);
    expect(loaded, isNotNull);
    expect((loaded!['datarows'] as List).first['title'], 'Choy');

    final merged = await SoldReceiptCache.mergeIntoSalesList([]);
    expect(merged.length, 1);
    expect(merged.first['invoice_id'], 'POS99');
  });
}
