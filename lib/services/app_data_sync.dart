import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/api_pacing.dart';
import '../core/api_sync_throttle.dart';
import '../core/seller_preferences.dart';
import '../core/sync_domain.dart';
import '../providers/cash_register_shift_provider.dart';
import '../providers/categories_provider.dart';
import '../providers/clients_provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/expenses_provider.dart';
import '../providers/products_provider.dart';
import '../providers/sales_session_provider.dart';

/// Barcha bo‘limlar uchun yagona sinxronizatsiya markazi (server = haqiqat, local = kesh).
class AppDataSync {
  AppDataSync._();

  static const _syncAllKey = 'app_data_sync_all';
  static const _syncAllMinInterval = Duration(minutes: 3);
  static const forceCooldown = Duration(seconds: 10);

  static bool _running = false;
  static bool get isRunning => _running;
  static Future<void>? _afterWriteRefresh;
  static Timer? _forceCooldownTimer;
  static DateTime? _forceCooldownUntil;

  /// Qolgan soniya (0 = tugma ochiq). UI shu notifierga quloq soladi.
  static final ValueNotifier<int> forceCooldownSeconds = ValueNotifier(0);

  static bool get isForceSyncBlocked =>
      _running || forceCooldownSeconds.value > 0;

  static void resetCooldown() {
    _forceCooldownTimer?.cancel();
    _forceCooldownTimer = null;
    _forceCooldownUntil = null;
    forceCooldownSeconds.value = 0;
  }

  static void _startForceCooldown() {
    _forceCooldownUntil = DateTime.now().add(forceCooldown);
    forceCooldownSeconds.value = forceCooldown.inSeconds;
    _forceCooldownTimer?.cancel();
    _forceCooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final until = _forceCooldownUntil;
      if (until == null) {
        timer.cancel();
        _forceCooldownTimer = null;
        forceCooldownSeconds.value = 0;
        return;
      }
      final left = until.difference(DateTime.now()).inSeconds;
      if (left <= 0) {
        timer.cancel();
        _forceCooldownTimer = null;
        _forceCooldownUntil = null;
        forceCooldownSeconds.value = 0;
      } else {
        forceCooldownSeconds.value = left;
      }
    });
  }

  static String throttleKey(SyncDomain domain) => switch (domain) {
        SyncDomain.products => 'products_full_catalog',
        SyncDomain.categories => 'categories_api',
        SyncDomain.clients => 'clients_api',
        SyncDomain.expenses => 'expenses_api',
        SyncDomain.dashboard => 'dashboard_api',
        SyncDomain.salesMeta => 'sales_meta_sync',
        SyncDomain.cashRegister => 'cash_register_sync',
      };

  /// Diskdan xotiraga — tarmoq yo‘q. Login / shell ochilganda.
  static Future<void> warmAll() async {
    await ProductsProvider.instance.warmFromCache();
    await CategoriesProvider.instance.warmFromCache();
    await ClientsProvider.instance.warmFromCache();
    await ExpensesProvider.instance.warmFromCache();
    await SalesSessionProvider.instance.bootstrapFromLocal();
  }

  static void invalidate(SyncDomain domain) {
    ApiSyncThrottle.invalidate(throttleKey(domain));
    if (domain == SyncDomain.products) {
      unawaited(ProductsProvider.instance.clearSyncFingerprint());
    }
  }

  static void invalidateAll() {
    for (final d in SyncDomain.values) {
      invalidate(d);
    }
    ApiSyncThrottle.invalidate(_syncAllKey);
  }

  /// Sotuv / kirim / qaytarish: throttle ochiladi, to‘liq katalog force qilinmaydi (429).
  /// Birinchi sahifa + fingerprint — o‘zgarmasa qolgan sahifalar so‘ralmaydi.
  static Future<void> afterStockChangingWrite({bool refreshNow = true}) async {
    ApiSyncThrottle.invalidate(throttleKey(SyncDomain.dashboard));
    ApiSyncThrottle.invalidate(throttleKey(SyncDomain.products));
    if (!refreshNow || _running) return;

    final existing = _afterWriteRefresh;
    if (existing != null) return existing;

    final future = () async {
      await ApiPacing.staggerPause(const Duration(seconds: 1));
      if (_running) return;
      try {
        await ProductsProvider.instance.loadFromApi(force: false);
      } catch (_) {}
    }();
    _afterWriteRefresh = future;
    try {
      await future;
    } finally {
      if (identical(_afterWriteRefresh, future)) {
        _afterWriteRefresh = null;
      }
    }
  }

  /// Bitta domen: disk (kerak bo‘lsa) + server.
  static Future<void> refresh(SyncDomain domain, {bool force = false}) async {
    switch (domain) {
      case SyncDomain.products:
        await ProductsProvider.instance.refreshFromServer(force: force);
      case SyncDomain.categories:
        if (force) {
          await CategoriesProvider.instance.refreshFromServer(force: true);
        } else {
          await CategoriesProvider.instance.loadFromApiIfStale();
        }
      case SyncDomain.clients:
        await ClientsProvider.instance.refreshFromServer(force: force);
      case SyncDomain.expenses:
        await ExpensesProvider.instance.refreshFromServer(force: force);
      case SyncDomain.dashboard:
        if (force) ApiSyncThrottle.invalidate(throttleKey(SyncDomain.dashboard));
        await DashboardProvider.instance.loadFromApi();
      case SyncDomain.salesMeta:
        await SalesSessionProvider.instance.init(localFirst: !force);
      case SyncDomain.cashRegister:
        await CashRegisterShiftProvider.instance.syncWithServer(force: force);
    }
  }

  /// [force]: foydalanuvchi «Sinxronlash» — throttle o‘tkazib yuboriladi.
  /// Pull-to-refresh da `force: true` ishlatmang (429).
  static Future<void> syncAll({bool force = false}) async {
    if (_running) return;
    if (force && forceCooldownSeconds.value > 0) return;
    if (!force && !ApiSyncThrottle.shouldRun(_syncAllKey, _syncAllMinInterval)) return;

    _running = true;
    // force ham barcha throttle’ni birdan ochmaydi — Laravel 429.
    if (force) {
      ApiSyncThrottle.invalidate(_syncAllKey);
      ApiSyncThrottle.invalidate(throttleKey(SyncDomain.cashRegister));
      ApiSyncThrottle.invalidate(throttleKey(SyncDomain.dashboard));
    }
    ApiSyncThrottle.markRan(_syncAllKey);
    try {
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

      // Mahsulotlar allaqachon yangilandi — sales init qayta to‘liq zanjir qilmasin.
      try {
        await SalesSessionProvider.instance.init(localFirst: true);
      } catch (_) {}
    } finally {
      _running = false;
      if (force) _startForceCooldown();
    }
  }
}
