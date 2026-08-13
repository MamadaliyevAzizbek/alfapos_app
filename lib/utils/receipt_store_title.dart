import '../models/receipt_design_config.dart';

/// Chek sarlavhasi: sozlamalardagi do'kon nomi yoki API filial.
class ReceiptStoreTitle {
  ReceiptStoreTitle._();

  static String resolve({
    required ReceiptDesignConfig design,
    String branchName = '',
  }) {
    if (!design.useBranchNameAsTitle) {
      final custom = design.storeTitle.trim();
      return custom.isEmpty ? 'Alfa market' : custom;
    }
    final branch = branchName.trim();
    if (branch.isNotEmpty) return branch;
    final fallback = design.storeTitle.trim();
    return fallback.isEmpty ? 'Alfa market' : fallback;
  }
}
