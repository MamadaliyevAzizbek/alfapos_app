import '../models/receipt_design_config.dart';

/// Chek sarlavhasi: faqat qo'lda belgilangan do'kon nomi (API filial chiqmaydi).
class ReceiptStoreTitle {
  ReceiptStoreTitle._();

  static const _placeholderTitles = {
    'alfa market',
    'alfamarket',
  };

  static String resolve({
    required ReceiptDesignConfig design,
    String branchName = '',
  }) {
    // API / filial nomi chekda chiqmasin (logo yetarli).
    if (design.useBranchNameAsTitle) return '';

    final custom = design.storeTitle.trim();
    if (custom.isEmpty) return '';
    if (_placeholderTitles.contains(custom.toLowerCase())) return '';
    return custom;
  }
}
