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

  static void _invalidateSyncThrottles() {
    ApiSyncThrottle.invalidate(_syncAllKey);
    ApiSyncThrottle.invalidate('products_full_catalog');
    ApiSyncThrottle.invalidate('categories_api');
    ApiSyncThrottle.invalidate('cash_register_sync');
    for (var i = 0; i < 9; i++) {
      ApiSyncThrottle.invalidate('desktop_shell_sync_$i');
    }
  }

  /// Navbatdagi mahsulotlarni serverga yuboradi, keyin serverdan yangilaydi.
  /// [force]: foydalanuvchi «Sinxronlash» bosganda — throttle o‘tkazib yuboriladi.
  static Future<void> syncAll({bool force = false}) async {
    if (_running) return;
    if (!force && !ApiSyncThrottle.shouldRun(_syncAllKey, _syncAllMinInterval)) return;

    _running = true;
    if (force) _invalidateSyncThrottles();
    ApiSyncThrottle.markRan(_syncAllKey);
    try {
      await ProductsProvider.instance.flushPendingSyncToServer();
      await ApiPacing.staggerPause();

      await CashRegisterShiftProvider.instance.syncWithServer(force: force);
      await ApiPacing.staggerPause();

      await syncSellerNameFromApi();
      await ApiPacing.staggerPause();

      await ProductsProvider.instance.refreshFromServer(force: force);
      await ApiPacing.staggerPause();

      if (force) {
        await CategoriesProvider.instance.loadFromApi();
      } else {
        await CategoriesProvider.instance.loadFromApiIfStale();
      }
      await ApiPacing.staggerPause();

      await ClientsProvider.instance.loadFromApi(force: force);
      await ApiPacing.staggerPause();

      await DashboardProvider.instance.loadFromApi();
      await ApiPacing.staggerPause();

      try {
        if (force) {
          await SalesSessionProvider.instance.init(localFirst: false);
        } else {
          await SalesSessionProvider.instance.init(localFirst: true);
        }
      } catch (_) {}
    } finally {
      _running = false;
    }
  }
}
