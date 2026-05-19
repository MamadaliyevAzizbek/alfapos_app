import '../models/receipt_design_config.dart';
import '../widgets/receipt_widget.dart';

/// Chek chop etish uchun ma'lumot (ESC/POS matn — rasm emas).
class ReceiptPrintData {
  final ReceiptDesignConfig design;
  final String storeName;
  final DateTime dateTime;
  final String receiptNumber;
  final String sellerName;
  final String? sellerPhone;
  final String? clientName;
  final String? description;
  final List<ReceiptRow> productRows;
  final List<ReceiptPaymentRow> paymentRows;
  final int discount;
  final int totalSum;
  final String barcodeData;
  final bool isPrecheck;

  const ReceiptPrintData({
    required this.design,
    required this.storeName,
    required this.dateTime,
    required this.receiptNumber,
    required this.sellerName,
    this.sellerPhone,
    this.clientName,
    this.description,
    required this.productRows,
    required this.paymentRows,
    required this.discount,
    required this.totalSum,
    this.barcodeData = '',
    this.isPrecheck = false,
  });
}
