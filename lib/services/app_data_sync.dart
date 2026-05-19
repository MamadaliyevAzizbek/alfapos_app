import '../core/api_pacing.dart';
import '../core/api_sync_throttle.dart';
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

  static const _syncAllKey = 'app_data_sync_all';
  static const _syncAllMinInterval = Duration(minutes: 3);

  static bool _running = false;
  static bool get isRunning => _running;

  /// Navbatdagi mahsulotlarni serverga yuboradi, keyin asta-sekin yangilaydi.
  static Future<void> syncAll({bool force = false}) async {
    if (_running) return;
    if (!force && !ApiSyncThrottle.shouldRun(_syncAllKey, _syncAllMinInterval)) return;

    _running = true;
    ApiSyncThrottle.markRan(_syncAllKey);
    try {
      await ProductsProvider.instance.flushPendingSyncToServer();
      await ApiPacing.staggerPause();

      await ApiSyncThrottle.runIfDue(
        'cash_shift_sync',
        const Duration(minutes: 2),
        () => CashRegisterShiftProvider.instance.syncWithServer(),
      );
      await ApiPacing.staggerPause();

      await syncSellerNameFromApi();
      await ApiPacing.staggerPause();

      await ProductsProvider.instance.loadFromStorage(refreshInBackground: true);
      await ApiPacing.staggerPause();

      await CategoriesProvider.instance.loadFromApiIfStale();
      await ApiPacing.staggerPause();

      await ClientsProvider.instance.loadFromApi(force: false);
      await ApiPacing.staggerPause();

      await DashboardProvider.instance.loadFromApi();
      await ApiPacing.staggerPause();

      try {
        await SalesSessionProvider.instance.init(localFirst: true);
      } catch (_) {}
    } finally {
      _running = false;
    }
  }
}
