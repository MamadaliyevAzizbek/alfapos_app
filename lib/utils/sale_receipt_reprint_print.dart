import 'dart:io';

import '../core/input_formatters.dart';
import '../core/seller_preferences.dart';
import '../models/receipt_design_config.dart';
import '../providers/sales_session_provider.dart';
import '../services/desktop_sales_layout_settings.dart';
import '../services/printer_settings.dart';
import '../services/receipt_design_storage.dart';
import '../services/thermal_receipt_printer.dart';
import '../utils/receipt_row_builder.dart';
import '../widgets/receipt_widget.dart';
import 'hold_orders_response.dart';

/// Tranzaksiyalar / hisobotlardan eski sotuv chekini qayta chop etish.
class SaleReceiptReprintPrint {
  SaleReceiptReprintPrint._();

  static Future<ThermalPrintResult> print({
    required Map<String, dynamic> sale,
    required Map<String, dynamic> invoiceDetail,
  }) async {
    if (!Platform.isWindows && !Platform.isMacOS) {
      return ThermalPrintResult.fail(
        'Termal chop etish faqat Windows yoki macOS desktop ilovasida',
      );
    }

    final data = _collect(sale, invoiceDetail);
    if (data.invoiceProductRows.isEmpty) {
      final orderId = getOrderIdFromSale(sale);
      if (orderId != null) {
        final directOnly = await PrinterSettings.isPrinterReady();
        return ThermalReceiptPrinter.printFromApiOrder(orderId, directOnly: directOnly);
      }
      return ThermalPrintResult.fail('Chek mahsulotlari topilmadi');
    }

    final results = await Future.wait([
      ReceiptDesignStorage.load(),
      getSellerPhone(),
      DesktopSalesLayoutSettings.getMode(),
    ]);
    final design = results[0] as ReceiptDesignConfig;
    final sellerPhone = results[1] as String?;
    final isRestaurant = results[2] == DesktopSalesLayoutMode.restaurant;
    var queueNumber = HoldOrdersResponse.resolveQueueNumber(sale) ??
        HoldOrdersResponse.resolveQueueNumber(invoiceDetail);
    if (isRestaurant && (queueNumber == null || queueNumber <= 0)) {
      queueNumber = await SalesSessionProvider.instance.fetchKitchenQueueNumber(
        orderId: getOrderIdFromSale(sale),
        invoiceId: data.posTitle,
      );
    }

    final widget = ReceiptWidget(
      dateTime: data.dateTime,
      receiptNumber: data.posTitle,
      sellerName: data.sellerName,
      sellerPhone: sellerPhone,
      branchName: SalesSessionProvider.instance.branchName.trim(),
      clientName: data.clientName.isEmpty ? null : data.clientName,
      productRows: ReceiptRowBuilder.fromInvoiceRows(data.invoiceProductRows),
      paymentRows: data.paymentRows,
      discount: data.discountUzs,
      totalSum: data.totalUzs,
      barcodeData: data.posTitle,
      queueNumber: queueNumber,
      isRestaurantLayout: isRestaurant,
      design: design,
    );

    final directOnly = await PrinterSettings.isPrinterReady();
    return ThermalReceiptPrinter.printLocalReceipt(
      widget.toThermalPrintLines(),
      directOnly: directOnly,
      design: design,
    );
  }

  static _ReprintData _collect(Map<String, dynamic> sale, Map<String, dynamic> inv) {
    final invoiceId = sale['invoice_id'] ?? sale['order_id'] ?? sale['id'];
    final idStr = invoiceId?.toString() ?? '—';
    final posTitle = idStr.startsWith('POS') ? idStr : 'POS$idStr';

    final dateRaw = sale['date'] ?? sale['created_at'] ?? inv['date'] ?? '';
    DateTime dt = DateTime.tryParse(dateRaw.toString().replaceFirst(' ', 'T')) ?? DateTime.now();

    final sellerName = (sale['created_by'] ?? inv['created_by'] ?? 'Sotuvchi').toString();
    final customer = sale['customer'] ?? inv['customer'];
    final clientName = customer is String
        ? customer
        : (customer is Map ? (customer['name'] ?? '').toString() : '');

    List<dynamic> datarows = inv['datarows'] as List<dynamic>? ??
        inv['data'] as List<dynamic>? ??
        inv['items'] as List<dynamic>? ??
        inv['products'] as List<dynamic>? ??
        inv['invoice_items'] as List<dynamic>? ??
        inv['rows'] as List<dynamic>? ??
        [];
    if (datarows is! List && inv['data'] is Map) {
      final d = inv['data'] as Map;
      datarows = d['datarows'] as List<dynamic>? ?? d['items'] as List<dynamic>? ?? [];
    }
    if (datarows is! List) datarows = [];
    final rawRows = datarows.where((e) => e is Map).map((e) => Map<String, dynamic>.from(e as Map)).toList();

    final parsed = _parseInvoiceDetailRows(rawRows);
    var payments = parsed.paymentRows;
    if (payments.isEmpty) {
      final paymentsRaw = inv['payments'] as List<dynamic>? ?? inv['payment_types'] as List<dynamic>? ?? [];
      if (paymentsRaw is List && paymentsRaw.isNotEmpty) {
        payments = paymentsRaw.where((e) => e is Map).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    }

    final totalUzs = parsed.total > 0
        ? parsed.total
        : parseAmountFromApi(sale['total'] ?? inv['total'] ?? inv['grand_total']);
    final catalogSub = parsed.subTotal > 0
        ? parsed.subTotal
        : ReceiptRowBuilder.catalogSubtotalFromInvoiceRows(parsed.productRows);
    var discountUzs = parsed.discount > 0
        ? parsed.discount
        : parseAmountFromApi(sale['discount'] ?? inv['discount'] ?? 0);
    if (discountUzs == 0 && catalogSub > 0 && totalUzs > 0 && catalogSub > totalUzs) {
      discountUzs = catalogSub - totalUzs;
    }

    return _ReprintData(
      posTitle: posTitle,
      dateTime: dt,
      sellerName: sellerName,
      clientName: clientName.trim(),
      invoiceProductRows: parsed.productRows,
      paymentRows: _paymentReceiptRows(payments),
      discountUzs: discountUzs,
      totalUzs: totalUzs,
    );
  }

  static List<ReceiptPaymentRow> _paymentReceiptRows(List<Map<String, dynamic>> payments) {
    return [
      for (final p in payments)
        ReceiptPaymentRow(
          methodName: (p['payment_name'] ??
                  p['name'] ??
                  p['payment_method'] ??
                  p['payment_type'] ??
                  p['title'] ??
                  p['method'] ??
                  p['type'] ??
                  '—')
              .toString(),
          sum: parseAmountFromApi(p['total'] ?? p['paid'] ?? p['amount'] ?? 0),
        ),
    ];
  }

  static _ParsedInvoiceRows _parseInvoiceDetailRows(List<Map<String, dynamic>> rawRows) {
    final productRows = <Map<String, dynamic>>[];
    final paymentRows = <Map<String, dynamic>>[];
    int subTotal = 0, tax = 0, discount = 0, total = 0;
    const summaryTitles = ['sub total', 'tax', 'total', 'discount', 'chegirma'];
    const notPaymentTitles = ['sub total', 'tax', 'total', 'discount', 'chegirma', 'umumiy summa', 'umumiy', 'soliq'];
    for (final r in rawRows) {
      final title = (r['title'] ?? r['name'] ?? '').toString().trim();
      final titleLower = title.toLowerCase();
      if (titleLower == 'sub total') {
        subTotal = parseAmountFromApi(r['total']);
        continue;
      }
      if (titleLower == 'tax') {
        tax = parseAmountFromApi(r['total']);
        continue;
      }
      if (titleLower == 'discount' || titleLower == 'chegirma') {
        discount = parseAmountFromApi(r['total'] ?? r['discount'] ?? r['amount']);
        continue;
      }
      if (titleLower == 'total') {
        total = parseAmountFromApi(r['total']);
        continue;
      }
      final hasQty = r.containsKey('quantity') || r.containsKey('qty');
      final hasPrice = r.containsKey('price') || r.containsKey('unit_price');
      final hasAmount = r['total'] != null || r['paid'] != null || r['amount'] != null;
      if (hasQty || (hasPrice && title.isNotEmpty && !summaryTitles.contains(titleLower))) {
        productRows.add(r);
        continue;
      }
      if (title.isNotEmpty &&
          hasAmount &&
          !notPaymentTitles.any((t) => titleLower == t || titleLower.startsWith('$t ') || titleLower.startsWith('$t:'))) {
        paymentRows.add(r);
      }
    }
    return _ParsedInvoiceRows(productRows, paymentRows, subTotal, tax, discount, total);
  }
}

class _ReprintData {
  final String posTitle;
  final DateTime dateTime;
  final String sellerName;
  final String clientName;
  final List<Map<String, dynamic>> invoiceProductRows;
  final List<ReceiptPaymentRow> paymentRows;
  final int discountUzs;
  final int totalUzs;

  const _ReprintData({
    required this.posTitle,
    required this.dateTime,
    required this.sellerName,
    required this.clientName,
    required this.invoiceProductRows,
    required this.paymentRows,
    required this.discountUzs,
    required this.totalUzs,
  });
}

class _ParsedInvoiceRows {
  final List<Map<String, dynamic>> productRows;
  final List<Map<String, dynamic>> paymentRows;
  final int subTotal;
  final int tax;
  final int discount;
  final int total;

  const _ParsedInvoiceRows(
    this.productRows,
    this.paymentRows,
    this.subTotal,
    this.tax,
    this.discount,
    this.total,
  );
}
