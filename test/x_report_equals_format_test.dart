import 'package:alfapos_app/models/receipt_design_config.dart';
import 'package:alfapos_app/utils/cash_register_shift_x_report_print.dart';
import 'package:alfapos_app/utils/thermal_receipt_compact_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('X-otchot uses label = value alignment', () {
    final lines = CashRegisterShiftXReportPrint.buildPrintLines(
      shiftInfo: {
        'cash_register_title': 'AI-CHA guliston kassa',
        'opened_by_name': 'AI-CHA guliston',
        'status': 'open',
        'log': {'opening_time': '2026-06-29T02:05:00', 'status': 'open'},
      },
      shiftAnalytics: {
        'total_payment': 64000,
        'payment_types': [
          {'payment_method': 'Naqd pul', 'total_amount': 4000},
          {'payment_method': 'Plastik', 'total_amount': 60000},
        ],
        'total_incomes': 0,
        'total_expenses': 0,
      },
      design: ReceiptDesignConfig.defaults,
      branchName: 'AI-CHA guliston - Asosiy filial',
    );

    String plain(String line) {
      if (ThermalReceiptCompactText.isAnyCompactLine(line)) {
        return ThermalReceiptCompactText.unwrap(line);
      }
      return line.startsWith('^') ? line.substring(1) : line;
    }

    final equalsLines = lines.map(plain).where((l) => l.contains(' = ')).toList();
    expect(equalsLines.length, 7);
    expect(equalsLines[0], contains('Jami savdo'));
    expect(equalsLines[0], contains('64 000'));
    expect(equalsLines[1], contains('Naqd pul'));
    expect(equalsLines[1], contains('4 000'));
    expect(equalsLines[2], contains('Plastik'));
    expect(equalsLines[2], contains('60 000'));
    expect(equalsLines[3], contains('Sotilgan che'));
    expect(equalsLines[4], contains('Umumiy og'));
    expect(equalsLines[5], contains('Kassa kirim'));
    expect(equalsLines[6], contains('Kassa chiqim'));

    final eqPositions = equalsLines.map((l) => l.indexOf(' = ')).toSet();
    expect(eqPositions.length, 1, reason: 'equals signs should align');
  });
}
