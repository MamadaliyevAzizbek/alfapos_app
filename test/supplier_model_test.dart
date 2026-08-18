import 'package:alfapos_app/models/supplier.dart';
import 'package:alfapos_app/utils/supplier_balance_transaction.dart';
import 'package:alfapos_app/utils/supplier_delivery_row.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Supplier.listFromResponse parses datarows and totals', () {
    final res = {
      'datarows': [
        {
          'id': 1,
          'name': 'Acme',
          'phone_number': '+998901234567',
          'balance': 250000,
          'due_amount': 150000,
        },
        {
          'id': 2,
          'first_name': 'Ali',
          'last_name': 'Valiyev',
          'company': 'X Firmasi',
          'balance': '0',
          'due_amount': '1 000',
        },
      ],
      'count': 2,
      'totalDebt': 1000000,
      'totalBalance': 250000,
    };

    final list = Supplier.listFromResponse(res);
    expect(list.length, 2);
    expect(list.first.name, 'Acme');
    expect(list.first.phone, '+998901234567');
    expect(list.first.dueAmount, 150000);
    expect(list[1].name, 'Ali Valiyev');
    expect(list[1].dueAmount, 1000);

    final totals = SupplierListTotals.fromResponse(res);
    expect(totals.count, 2);
    expect(totals.totalDebt, 1000000);
    expect(totals.totalBalance, 250000);
  });

  test('Supplier.fromResponse reads supplierData edit payload', () {
    final s = Supplier.fromResponse({
      'supplierData': {
        'id': 15,
        'first_name': 'Ali',
        'last_name': '',
        'phone_number': '901234567',
        'description': 'Izoh',
        'balance': 0,
        'fullName': 'Ali',
      },
    });
    expect(s, isNotNull);
    expect(s!.id, 15);
    expect(s.name, 'Ali');
    expect(s.description, 'Izoh');
  });

  test('Supplier.fromResponse reads profile due_amount', () {
    final s = Supplier.fromResponse({
      'success': true,
      'supplier': {
        'id': 15,
        'first_name': 'Ali',
        'balance': 10000,
        'due_amount': 500000,
        'orders_due_debt': 300000,
        'journal_net_debt': 200000,
      },
    });
    expect(s!.dueAmount, 500000);
    expect(s.balance, 10000);
    expect(s.ordersDueDebt, 300000);
  });

  test('SupplierDeliveryRow maps merged report types', () {
    final rows = SupplierDeliveryRow.listFromResponse({
      'datarows': [
        {
          'id': 10,
          'invoice_id': 'R-001',
          'date': '2026-05-01 12:00:00',
          'type': 'order',
          'due_amount': 50000,
          'total': 100000,
        },
        {
          'id': 'standalone-debt-3',
          'type': 'loan',
          'amount': 20000,
          'description': 'Oldindan olingan',
        },
      ],
    });
    expect(rows.length, 2);
    expect(rows.first.typeLabel, 'Kirim');
    expect(rows.first.title, 'R-001');
    expect(rows.first.canOpenCheck, isTrue);
    expect(rows.first.orderId, 10);
    expect(rows[1].typeLabel, "Qo'lda qarz");
    expect(rows[1].canOpenCheck, isFalse);
    expect(rows[1].canDeleteJournal, isTrue);
    expect(rows[1].debtId, 3);
  });

  test('SupplierBalanceTransactionRow signs add/used amounts', () {
    final add = SupplierBalanceTransactionRow({
      'id': 1,
      'amount': 100000,
      'type': 'add',
      'created_by_name': 'Admin',
      'created_at': '2026-08-17T10:00:00Z',
    });
    expect(add.signedAmount, 100000);
    expect(add.description, "Balans qo'shildi");

    final used = SupplierBalanceTransactionRow({
      'id': 2,
      'amount': 40000,
      'type': 'used',
      'description': '',
    });
    expect(used.signedAmount, -40000);
  });
}
