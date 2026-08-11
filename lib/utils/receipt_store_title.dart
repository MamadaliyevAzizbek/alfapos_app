import '../models/receipt_design_config.dart';

/// Chek sarlavhasi: API filial nomi (qo‘lda do‘kon nomi yo‘q).
class ReceiptStoreTitle {
  ReceiptStoreTitle._();

  static String resolve({
    required ReceiptDesignConfig design,
    String branchName = '',
  }) {
    final branch = branchName.trim();
    if (branch.isNotEmpty) return branch;
    return 'Alfa market';
  }
}
