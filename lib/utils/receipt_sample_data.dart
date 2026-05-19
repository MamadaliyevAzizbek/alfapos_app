import '../widgets/receipt_widget.dart';

/// Sozlamalarda ko‘rib chiqish va test chop etish uchun namuna chek.
class ReceiptSampleData {
  ReceiptSampleData._();

  static List<ReceiptRow> get products => const [
        ReceiptRow(
          productName: 'aaaaaa',
          quantityStr: '1',
          price: 38000,
          sum: 38000,
        ),
        ReceiptRow(
          productName: 'test miqdor',
          quantityStr: '1',
          price: 70000,
          sum: 70000,
        ),
        ReceiptRow(
          productName: 'salom',
          quantityStr: '1шт',
          price: 3000,
          sum: 3000,
        ),
        ReceiptRow(
          productName: 'Fanta 0.5L',
          quantityStr: '1kg',
          price: 21000,
          sum: 21000,
        ),
      ];

  static List<ReceiptPaymentRow> get payments => const [
        ReceiptPaymentRow(methodName: 'Naqd pul', sum: 135000),
      ];

  static const int discount = 0;
  static const int total = 135000;
  static const String receiptNumber = '10301';
  static const String sellerName = 'Murod Qodirov';
  static const String sellerPhone = '911003205';
}
