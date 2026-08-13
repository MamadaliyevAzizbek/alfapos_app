import 'package:alfapos_app/utils/kitchen_status.dart';
import 'package:alfapos_app/utils/tv_orders_response.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses tv-orders into preparing/ready columns', () {
    final snap = TvOrdersResponse.parse({
      'success': true,
      'branch_id': 5,
      'branch_name': 'Asosiy filial',
      'server_time': '2026-08-11 23:10:00',
      'orders': [
        {
          'orderID': 1,
          'kitchenStatus': 'preparing',
          'queueNumber': 12,
          'checkNumber': 12,
        },
        {
          'orderID': 2,
          'kitchen_status': 'ready',
          'checkNumber': 7,
        },
        {
          'orderID': 3,
          'kitchenStatus': 'served',
          'queueNumber': 3,
        },
        {
          'orderID': 4,
          'kitchenStatus': null,
          'queueNumber': 4,
        },
      ],
    });

    expect(snap.branchId, 5);
    expect(snap.branchName, 'Asosiy filial');
    expect(snap.preparing.map((e) => e.queueNumber), [12]);
    expect(snap.ready.map((e) => e.queueNumber), [7]);
    expect(snap.orders.where((e) => e.kitchenStatus == KitchenStatus.completed).length, 1);
  });

  test('kitchen status parse maps legacy and TV visibility', () {
    expect(KitchenStatus.tryParse('preparing')?.isVisibleOnTv, isTrue);
    expect(KitchenStatus.tryParse('new'), KitchenStatus.preparing);
    expect(KitchenStatus.tryParse('ready')?.isVisibleOnTv, isTrue);
    expect(KitchenStatus.tryParse('served'), KitchenStatus.completed);
    expect(KitchenStatus.tryParse('completed')?.isVisibleOnTv, isFalse);
    expect(KitchenStatus.tryParse(null), isNull);
    expect(KitchenStatus.tryParse(''), isNull);
  });
}
