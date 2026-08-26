import '../models/receipt_design_config.dart';

/// Chek sarlavhasi: sozlamalardagi do'kon nomi yoki API filial.
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
    String pick(String raw) {
      final t = raw.trim();
      if (t.isEmpty) return '';
      if (_placeholderTitles.contains(t.toLowerCase())) return '';
      return t;
    }

    if (!design.useBranchNameAsTitle) {
      return pick(design.storeTitle);
    }
    final branch = pick(branchName);
    if (branch.isNotEmpty) return branch;
    return pick(design.storeTitle);
  }
}
