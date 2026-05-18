import 'package:flutter_test/flutter_test.dart';
import 'package:alfapos_app/utils/sale_return_utils.dart';

void main() {
  setUp(SaleReturnGuard.clearSessionForTesting);

  test('qaytarilgan status — tugma ko‘rinmasin', () {
    final sale = {'id': 100, 'total': 50000, 'status': 'returned'};
    expect(isSaleAlreadyReturned(sale), true);
    expect(canShowReturnSaleButton(sale), false);
  });

  test('manfiy summa — qaytarish cheki', () {
    final sale = {'id': 101, 'total': -50000, 'orderType': 'sales'};
    expect(isSaleAlreadyReturned(sale), true);
    expect(canShowReturnSaleButton(sale), false);
  });

  test('orderType return', () {
    final sale = {'id': 102, 'total': 1000, 'orderType': 'sales_return'};
    expect(canShowReturnSaleButton(sale), false);
  });

  test('oddiy sotuv — qaytarish mumkin', () {
    final sale = {'id': 103, 'total': 50000, 'status': 'done', 'orderType': 'sales'};
    expect(canShowReturnSaleButton(sale), true);
  });

  test('sessiyada qaytarilgan — ikkinchi marta emas', () {
    SaleReturnGuard.markReturned(200);
    final sale = {'id': 200, 'total': 50000, 'status': 'done'};
    expect(isSaleAlreadyReturned(sale), true);
    expect(canShowReturnSaleButton(sale), false);
  });

  test('item_purchased matnida qaytarilgan', () {
    final sale = {'id': 201, 'total': 1000, 'item_purchased': 'Qaytarilgan mahsulotlar'};
    expect(isSaleAlreadyReturned(sale), true);
  });
}
