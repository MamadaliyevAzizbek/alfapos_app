import '../core/seller_preferences.dart';
import '../models/receipt_design_config.dart';
import '../providers/sales_session_provider.dart';
import '../services/receipt_design_storage.dart';
import '../utils/cash_register_shift_x_report_print.dart';
import '../widgets/receipt_widget.dart';

/// Sozlamalar va test uchun namuna mahalliy chek.
class LocalReceiptSample {
  LocalReceiptSample._();

  /// Printerga ketadigan qatorlar (sotuv cheki namunasi).
  static Future<List<String>> sampleSalePrintLines({
    ReceiptDesignConfig? design,
  }) async {
    final sess = SalesSessionProvider.instance;
    final branchName = sess.branchName.trim();
    final seller = await getSellerName();
    final phone = await getSellerPhone();
    final cfg = design ?? await ReceiptDesignStorage.load();

    final widget = ReceiptWidget(
      dateTime: DateTime.now(),
      receiptNumber: 'POS12345',
      sellerName: seller,
      sellerPhone: phone,
      branchName: branchName,
      clientName: 'Mijoz namunasi',
      clientPhone: '+998 90 123 45 67',
      productRows: const [
        ReceiptRow(
          productName: 'Non',
          quantityStr: '1 dona',
          price: 4000,
          sum: 4000,
          catalogPrice: 5000,
          catalogSum: 5000,
        ),
      ],
      paymentRows: const [
        ReceiptPaymentRow(methodName: 'Naqd pul', sum: 4000),
      ],
      discount: 1000,
      totalSum: 4000,
      barcodeData: 'POS12345',
      design: cfg,
    );
    return widget.toThermalPrintLines();
  }

  /// Restoran rejimi — katta navbat raqami bilan namuna chek.
  static Future<List<String>> sampleRestaurantSalePrintLines({
    ReceiptDesignConfig? design,
    int queueNumber = 42,
  }) async {
    final sess = SalesSessionProvider.instance;
    final branchName = sess.branchName.trim();
    final seller = await getSellerName();
    final phone = await getSellerPhone();
    final cfg = design ?? await ReceiptDesignStorage.load();

    final widget = ReceiptWidget(
      dateTime: DateTime.now(),
      receiptNumber: 'POS12345',
      sellerName: seller,
      sellerPhone: phone,
      branchName: branchName,
      productRows: const [
        ReceiptRow(
          productName: 'Latte',
          quantityStr: '2 dona',
          price: 25000,
          sum: 50000,
        ),
      ],
      paymentRows: const [
        ReceiptPaymentRow(methodName: 'Naqd pul', sum: 50000),
      ],
      discount: 0,
      totalSum: 50000,
      barcodeData: 'POS12345',
      queueNumber: queueNumber,
      isRestaurantLayout: true,
      design: cfg,
    );
    return widget.toThermalPrintLines();
  }

  /// Kassa smenasi X-otchoti — printerga chiqadigan namuna.
  static Future<List<String>> sampleXReportPrintLines({
    ReceiptDesignConfig? design,
  }) async {
    final sess = SalesSessionProvider.instance;
    final branchName = sess.branchName.trim();
    final seller = await getSellerName();
    final cfg = design ?? await ReceiptDesignStorage.load();

    final shiftInfo = <String, dynamic>{
      'cash_register_title': 'Kassa 1',
      'opened_by_name': seller.isNotEmpty ? seller : 'Murod Qodirov',
      'shift_staff_names': seller.isNotEmpty ? seller : 'Murod Qodirov, Azizbek Mamadaliyev',
      'status': 'open',
      'log': {
        'opening_time': '2026-05-29T21:55:00',
        'status': 'open',
      },
    };
    final shiftAnalytics = <String, dynamic>{
      'total_payment': 13425043,
      'payment_types': [
        {'payment_method': 'Naqd pul', 'total_amount': 12312043},
        {'payment_method': 'Qarz', 'total_amount': 4619000},
        {'payment_method': "To'lovsiz", 'total_amount': 4275000},
        {'payment_method': 'Click', 'total_amount': 62000},
        {'payment_method': 'Terminal', 'total_amount': 20000},
        {'payment_method': 'Mijoz balansi', 'total_amount': -7863000},
      ],
      'shift_orders_count': 47,
      'current_amount_by_payment_type': [
        {'payment_method': 'Naqd pul', 'total_amount': 12312043},
      ],
      'shift_returns_total': 72118000,
      'total_incomes': 200000,
      'total_expenses': 200000,
      'shift_avg_check': 285639,
    };

    return CashRegisterShiftXReportPrint.buildPrintLines(
      shiftInfo: shiftInfo,
      shiftAnalytics: shiftAnalytics,
      design: cfg,
      cashRegisterTitle: 'Kassa 1',
      branchName: branchName,
    );
  }
}
