import 'dart:io';

import '../models/receipt_design_config.dart';
import '../providers/sales_session_provider.dart';
import '../services/printer_settings.dart';
import '../services/receipt_design_storage.dart';
import '../services/thermal_receipt_printer.dart';
import '../utils/cash_register_utils.dart';
import '../utils/receipt_store_title.dart';
import 'thermal_receipt_compact_text.dart';
import 'thermal_receipt_formatter.dart' show ThermalReceiptFormatter;
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
    const amountCol = ThermalReceiptFormatter.kReceiptAmountColumnWidth;

    void center(String s) => lines.add('^${s.trim()}');
    void left(String s) {
      for (final part in ThermalReceiptLineWrap.wrapLine(s)) {
        lines.add(part);
      }
    }

    void twoCol(String label, String value) {
      lines.addAll(
        ThermalReceiptLineWrap.formatTwoColumnRows(
          label,
          value,
          rightWidth: amountCol,
        ),
      );
    }

    void boldTwoCol(String label, String value) {
      final rows = ThermalReceiptLineWrap.formatTwoColumnRows(
        label,
        value,
        rightWidth: amountCol,
      );
      for (final row in rows) {
        final text = ThermalReceiptCompactText.isAnyCompactLine(row)
            ? ThermalReceiptCompactText.unwrap(row)
            : row;
        lines.add(ThermalReceiptCompactText.boldLine(text));
      }
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
    boldTwoCol(
      'JAMI SAVDO',
      formatShiftMoney(analytics['total_payment'] ?? analytics['total_sales']),
    );
    for (final p in paymentTypes) {
      twoCol(
        (p['payment_method'] ?? p['name'] ?? '—').toString(),
        formatShiftMoney(p['total_amount'] ?? p['amount']),
      );
    }

    lines.add(sep);
    twoCol('Kassa kirim', formatShiftMoney(analytics['total_incomes']));
    twoCol('Kassa chiqim', formatShiftMoney(analytics['total_expenses']));

    lines.add('');
    center('---');

    return ThermalReceiptLineWrap.wrapAll(lines);
  }
}
