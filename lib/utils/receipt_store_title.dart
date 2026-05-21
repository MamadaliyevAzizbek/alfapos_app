import '../models/receipt_design_config.dart';

/// Chek sarlavhasi: sozlamalardagi do'kon nomi ustuvor.
class ReceiptStoreTitle {
  ReceiptStoreTitle._();

  static String resolve({
    required ReceiptDesignConfig design,
    String branchName = '',
  }) {
    final custom = design.storeTitle.trim();
    final branch = branchName.trim();

    // Foydalanuvchi yozgan do'kon nomi — doim birinchi (4-rasm: Alfa market).
    if (custom.isNotEmpty) return custom;

    if (design.useBranchNameAsTitle && branch.isNotEmpty) return branch;
    if (branch.isNotEmpty) return branch;
    return 'Alfa market';
  }
}
