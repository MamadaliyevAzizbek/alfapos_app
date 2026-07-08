import 'dart:io';

import '../models/receipt_design_config.dart';
import '../providers/sales_session_provider.dart';
import '../services/printer_settings.dart';
import '../services/receipt_design_storage.dart';
import '../services/thermal_receipt_printer.dart';
import '../utils/cash_register_utils.dart';
import '../utils/receipt_store_title.dart';
import 'thermal_receipt_line_wrap.dart';

/// Kassa smenasi X-otchoti (smenani yopmasdan kassa hisoboti).
class CashRegisterShiftXReportPrint {
  CashRegisterShiftXReportPrint._();

  static Future<ThermalPrintResult> print({
    required Map<String, dynamic> shiftInfo,
    required Map<String, dynamic> shiftAnalytics,
    String? cashRegisterTitle,
  }) async {
    if (!Platform.isWindows && !Platform.isMacOS) {
      return ThermalPrintResult.fail(
        'Termal chop etish faqat Windows yoki macOS desktop ilovasida',
      );
    }

    final design = await ReceiptDesignStorage.load();
    final lines = buildPrintLines(
      shiftInfo: shiftInfo,
      shiftAnalytics: shiftAnalytics,
      design: design,
      cashRegisterTitle: cashRegisterTitle,
      branchName: SalesSessionProvider.instance.branchName,
    );
    if (lines.isEmpty) {
      return ThermalPrintResult.fail('Hisobot ma\'lumoti bo\'sh');
    }

    final directOnly = await PrinterSettings.isPrinterReady();
    return ThermalReceiptPrinter.printLocalReceipt(
      lines,
      directOnly: directOnly,
      openCashDrawer: false,
    );
  }

  static List<String> buildPrintLines({
    required Map<String, dynamic> shiftInfo,
    required Map<String, dynamic> shiftAnalytics,
    ReceiptDesignConfig? design,
    String? cashRegisterTitle,
    String branchName = '',
  }) {
    final cfg = design ?? const ReceiptDesignConfig();
    final info = shiftInfo;
    final analytics = shiftAnalytics;
    final log = info['log'] is Map ? Map<String, dynamic>.from(info['log'] as Map) : <String, dynamic>{};
    final paymentTypes = parseApiList(analytics['payment_types']);
    final status = (info['status'] ?? log['status'] ?? 'open').toString();
    final statusLabel = status.toLowerCase() == 'open' ? 'Ochiq' : 'Yopilgan';

    final lines = <String>[];
    final sep = ThermalReceiptLineWrap.fullSeparator(kThermalChars80mm);

    void center(String s) => lines.add('^${s.trim()}');
    void left(String s) {
      for (final part in ThermalReceiptLineWrap.wrapLine(s)) {
        lines.add(part);
      }
    }

    void equalsRows(
      List<({String label, String value})> rows, {
      Set<int> boldIndices = const {},
      int? labelWidth,
      int? valueWidth,
    }) {
      lines.addAll(
        ThermalReceiptLineWrap.formatEqualsRows(
          rows,
          boldIndices: boldIndices,
          labelWidth: labelWidth,
          valueWidth: valueWidth,
        ),
      );
    }

    final storeTitle = ReceiptStoreTitle.resolve(
      design: cfg,
      branchName: branchName,
    );
    center(storeTitle);
    center('X-OTCHOT');
    center('Kassa hisoboti');

    final now = DateTime.now();
    center(
      '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
      '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
    );
    lines.add('');

    left('Kassa: ${(info['cash_register_title'] ?? cashRegisterTitle ?? '—').toString()}');
    left('Kassir: ${(info['opened_by_name'] ?? '—').toString()}');
    left('Ochilish: ${formatShiftDateTime(log['opening_time'])}');
    left('Holat: $statusLabel');

    final staffLine = (info['shift_staff_names'] ?? '').toString().trim();
    if (staffLine.isNotEmpty) {
      left('Smenada: $staffLine');
    }

    lines.add(sep);
    final salesRows = <({String label, String value})>[
      (
        label: 'Jami savdo',
        value: formatShiftMoney(analytics['total_payment'] ?? analytics['total_sales']),
      ),
      ...paymentTypes.map(
        (p) => (
          label: (p['payment_method'] ?? p['name'] ?? '—').toString(),
          value: formatShiftMoney(p['total_amount'] ?? p['amount']),
        ),
      ),
    ];
    final cashRows = <({String label, String value})>[
      (
        label: 'Kassa kirim',
        value: formatShiftMoney(analytics['total_incomes']),
      ),
      (
        label: 'Kassa chiqim',
        value: formatShiftMoney(analytics['total_expenses']),
      ),
    ];
    final cols = ThermalReceiptLineWrap.equalsColumnWidths([...salesRows, ...cashRows]);

    equalsRows(
      salesRows,
      boldIndices: const {0},
      labelWidth: cols.labelWidth,
      valueWidth: cols.valueWidth,
    );

    lines.add(sep);
    equalsRows(
      [
        (
          label: 'Sotilgan cheklar soni',
          value: '${analytics['shift_orders_count'] ?? 0}',
        ),
        (
          label: 'Umumiy og\'irlik (kg)',
          value: formatShiftWeight(analytics['shift_total_weight']),
        ),
      ],
      labelWidth: cols.labelWidth,
      valueWidth: cols.valueWidth,
    );

    lines.add(sep);
    equalsRows(
      cashRows,
      labelWidth: cols.labelWidth,
      valueWidth: cols.valueWidth,
    );

    return ThermalReceiptLineWrap.wrapAll(lines);
  }
}
