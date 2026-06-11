import '../core/seller_preferences.dart';
import '../models/receipt_design_config.dart';
import '../providers/sales_session_provider.dart';
import '../services/receipt_design_storage.dart';
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
      design: cfg,
    );
    return widget.toThermalPrintLines();
  }
}
