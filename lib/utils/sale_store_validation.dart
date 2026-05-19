import '../core/api_client.dart';
import '../models/cart_item.dart';
import '../providers/cash_register_shift_provider.dart';
import '../providers/sales_session_provider.dart';
import '../services/api_service.dart';

/// POST /sales/store oldidan — serverga yoziladigan ma’lumotlar to‘g‘riligini tekshirish.
class SaleStoreValidation {
  SaleStoreValidation._();

  static void validateCart(List<CartItem> items) {
    if (items.isEmpty) {
      throw ApiException('Savat bo\'sh', 400);
    }
    for (final item in items) {
      final pid = int.tryParse(item.product.id) ?? 0;
      if (pid <= 0) {
        throw ApiException(
          '«${item.product.name}» serverda ro\'yxatdan o\'tmagan (mahsulot ID yo\'q). '
          'Avval «Mahsulotlar» bo\'limida sinxronlang yoki mahsulotni qayta saqlang.',
          422,
        );
      }
    }
  }

  static void validateCashShift() {
    final shift = CashRegisterShiftProvider.instance;
    if (shift.requiresCashRegister && !shift.isShiftOpen) {
      throw ApiException(
        'Kassa smenasi ochiq emas. Sotuv serverga yozilmaydi — avval smenani oching yoki birlashing.',
        422,
      );
    }
  }

  /// Filial server sessiyasida tanlangan bo‘lishi kerak.
  static Future<void> ensureBranchOnServer() async {
    final sess = SalesSessionProvider.instance;
    final bid = sess.branchId;
    if (bid == null) return;
    try {
      await SalesApi.setBranch(branchID: bid, orderType: 'sales');
    } catch (_) {}
  }
}
