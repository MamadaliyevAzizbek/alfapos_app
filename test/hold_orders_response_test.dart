import 'package:alfapos_app/utils/hold_orders_response.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('empty hold_orders ignores datarows (no mixed sales list)', () {
    final list = HoldOrdersResponse.parseList({
      'hold_orders': [],
      'datarows': [
        {'id': 1, 'status': 'hold', 'grandTotal': 100},
        {'id': 2, 'status': 'hold', 'grandTotal': 200},
      ],
    });
    expect(list, isEmpty);
  });

  test('parses hold_orders with status filter', () {
    final list = HoldOrdersResponse.parseList({
      'hold_orders': [
        {'orderID': 10, 'status': 'hold', 'grand_total': 5000},
        {'orderID': 11, 'status': 'done', 'grand_total': 1},
      ],
    });
    expect(list.length, 1);
    expect(HoldOrdersResponse.orderId(list.single), 10);
  });

  test('rejects done and empty status in datarows fallback', () {
    final list = HoldOrdersResponse.parseList({
      'datarows': [
        {'id': 1, 'status': 'hold', 'total': 100},
        {'id': 2, 'status': 'done', 'total': 200},
        {'id': 3, 'total': 300},
      ],
    });
    expect(list.length, 1);
    expect(HoldOrdersResponse.orderId(list.single), 1);
  });

  test('resolveCashRegisterLabel from nested map and register list', () {
    expect(
      HoldOrdersResponse.resolveCashRegisterLabel({
        'cashRagisterId': {'id': 98, 'title': 'Kassa 2'},
      }),
      'Kassa 2',
    );
    expect(
      HoldOrdersResponse.resolveCashRegisterLabel(
        {'cash_register_id': 1},
        registers: [
          {'id': 1, 'title': 'Asosiy kassa'},
        ],
      ),
      'Asosiy kassa',
    );
    expect(
      HoldOrdersResponse.resolveCashRegisterLabel({'cashRagisterId': 5}),
      'Kassa 5',
    );
  });

  test('belongsToCashRegister filters by register id and log id', () {
    expect(
      HoldOrdersResponse.belongsToCashRegister(
        {'cashRagisterId': 1, 'orderID': 1, 'status': 'hold'},
        cashRegisterId: 1,
        filterByCashRegister: true,
      ),
      isTrue,
    );
    expect(
      HoldOrdersResponse.belongsToCashRegister(
        {'cashRagisterId': 2, 'orderID': 2, 'status': 'hold'},
        cashRegisterId: 1,
        filterByCashRegister: true,
      ),
      isFalse,
    );
    expect(
      HoldOrdersResponse.belongsToCashRegister(
        {'register_log_id': 55, 'orderID': 3, 'status': 'hold'},
        cashRegisterId: 1,
        registerLogId: 55,
        filterByCashRegister: true,
      ),
      isTrue,
    );
    expect(
      HoldOrdersResponse.belongsToCashRegister(
        {'orderID': 4, 'status': 'hold'},
        cashRegisterId: 1,
        localTags: {4: (cashRegisterId: 1, registerLogId: 55)},
        filterByCashRegister: true,
      ),
      isTrue,
    );
    expect(
      HoldOrdersResponse.belongsToCashRegister(
        {'orderID': 4, 'status': 'hold'},
        cashRegisterId: 2,
        localTags: {4: (cashRegisterId: 1, registerLogId: 55)},
        filterByCashRegister: true,
      ),
      isFalse,
    );
    expect(
      HoldOrdersResponse.belongsToCashRegister(
        {'orderID': 5, 'status': 'hold', 'user_id': 10, 'register_log_id': 55},
        cashRegisterId: 2,
        registerLogId: 66,
        filterByCashRegister: true,
      ),
      isFalse,
    );
    expect(
      HoldOrdersResponse.belongsToCashRegister(
        {'orderID': 8, 'status': 'hold', 'user_id': 10},
        cashRegisterId: 1,
        activeRegister: {
          'id': 1,
          'status': 'open',
          'register_log_id': 55,
          'shift_staff': [
            {'id': 10, 'name': 'Ali'},
            {'id': 11, 'name': 'Vali'},
          ],
        },
        filterByCashRegister: true,
      ),
      isTrue,
    );
    expect(
      HoldOrdersResponse.belongsToCashRegister(
        {'orderID': 8, 'status': 'hold', 'user_id': 10},
        cashRegisterId: 2,
        registerLogId: 66,
        localTags: {8: (cashRegisterId: 1, registerLogId: 55)},
        filterByCashRegister: true,
      ),
      isFalse,
    );
    expect(
      HoldOrdersResponse.belongsToCashRegister(
        {'orderID': 6, 'status': 'hold', 'user_id': 20},
        cashRegisterId: 1,
        registerLogId: 55,
        filterByCashRegister: true,
      ),
      isFalse,
    );
    expect(
      HoldOrdersResponse.belongsToCashRegister(
        {'cashRagisterId': 2, 'orderID': 7, 'status': 'hold'},
        cashRegisterId: 1,
        filterByCashRegister: false,
      ),
      isTrue,
    );
  });

  test('falls back to datarows when hold_orders key missing', () {
    final list = HoldOrdersResponse.parseList({
      'datarows': [
        {'id': 3, 'status': 'hold', 'total': 9000},
      ],
    });
    expect(list.length, 1);
    expect(HoldOrdersResponse.displayTotal(list.single), 9000);
  });
}
