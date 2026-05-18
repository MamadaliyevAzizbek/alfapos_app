import '../core/seller_preferences.dart';
import '../providers/cash_register_shift_provider.dart';
import '../providers/categories_provider.dart';
import '../providers/clients_provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/products_provider.dart';
import '../providers/sales_session_provider.dart';

/// Barcha bo‘limlar uchun umumiy sinxronlash (server ↔ lokal kesh).
class AppDataSync {
  AppDataSync._();

  static bool _running = false;
  static bool get isRunning => _running;

  /// Navbatdagi mahsulotlarni serverga yuboradi, keyin katalogni va sotuvni yangilaydi.
  static Future<void> syncAll() async {
    if (_running) return;
    _running = true;
    try {
      await CashRegisterShiftProvider.instance.syncWithServer();
      await syncSellerNameFromApi();

      await ProductsProvider.instance.flushPendingSyncToServer();

      await Future.wait([
        ProductsProvider.instance.loadFromApi(),
        CategoriesProvider.instance.loadFromApi(),
        ClientsProvider.instance.loadFromApi(force: true),
        DashboardProvider.instance.loadFromApi(),
      ]);

      try {
        await SalesSessionProvider.instance.init();
        await SalesSessionProvider.instance.loadProducts(reset: true, searchValue: '');
      } catch (_) {}
    } finally {
      _running = false;
    }
  }
}
