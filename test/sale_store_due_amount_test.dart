import 'package:flutter_test/flutter_test.dart';
import 'package:alfapos_app/utils/sale_store_due_amount.dart';

bool _isQarz(Map<String, dynamic> e) {
  final name = (e['name'] ?? '').toString().toLowerCase();
  final type = (e['type'] ?? '').toString().toLowerCase();
  return name.contains('qarz') || type == 'credit' || type == 'debt' || type == 'qarz';
}

void main() {
  test('aralash: balans 200k + jami 212k → qarz 12k', () {
    final types = [
      {'id': 1, 'name': 'Mijoz balansi', 'type': 'balance'},
      {'id': 2, 'name': 'Qarz', 'type': 'credit'},
    ];
    final allocated = {'1': 200000, '2': 12000};
    expect(
      computeStoreDueAmount(
        grandTotal: 212000,
        paymentTypes: types,
        allocated: allocated,
        isQarzPayment: _isQarz,
      ),
      12000,
    );
  });

  test('faqat balans: qoldiq qarz sifatida', () {
    final types = [
      {'id': 1, 'name': 'Mijoz balansi', 'type': 'balance'},
      {'id': 2, 'name': 'Qarz', 'type': 'credit'},
    ];
    final allocated = {'1': 200000};
    expect(
      computeStoreDueAmount(
        grandTotal: 212000,
        paymentTypes: types,
        allocated: allocated,
        isQarzPayment: _isQarz,
      ),
      12000,
    );
  });

  test('qarz qatori bo‘lsa — shu summa', () {
    final types = [
      {'id': 2, 'name': 'Qarz', 'type': 'credit'},
    ];
    expect(
      computeStoreDueAmount(
        grandTotal: 50000,
        paymentTypes: types,
        allocated: {'2': 50000},
        isQarzPayment: _isQarz,
      ),
      50000,
    );
  });
}
