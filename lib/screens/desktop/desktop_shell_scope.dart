import 'package:flutter/material.dart';

import '../../core/api_pacing.dart';
import '../../core/api_sync_throttle.dart';
import '../../core/seller_preferences.dart';
import '../../providers/cash_register_shift_provider.dart';
import '../../providers/clients_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/products_provider.dart';
import '../../providers/receive_session_provider.dart';
import '../../providers/sales_session_provider.dart';
import '../../providers/categories_provider.dart';

/// Desktop shell: global «Sinxronlash» — bo‘lim bo‘yicha ma’lumotlarni yangilash.
class DesktopShellScope extends InheritedWidget {
  final int syncGeneration;
  final bool syncing;

  const DesktopShellScope({
    super.key,
    required this.syncGeneration,
    required this.syncing,
    required super.child,
  });

  static DesktopShellScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<DesktopShellScope>();
  }

  @override
  bool updateShouldNotify(DesktopShellScope oldWidget) {
    return syncGeneration != oldWidget.syncGeneration || syncing != oldWidget.syncing;
  }
}

class DesktopShellSync {
  DesktopShellSync._();

  static Future<void> run(int tabIndex) async {
    if (!ApiSyncThrottle.shouldRun('desktop_shell_sync_$tabIndex', const Duration(seconds: 45))) {
      return;
    }
    ApiSyncThrottle.markRan('desktop_shell_sync_$tabIndex');

    await CashRegisterShiftProvider.instance.syncWithServer();
    await syncSellerNameFromApi();
    await ApiPacing.staggerPause();

    switch (tabIndex) {
      case 0:
        await DashboardProvider.instance.loadFromApi();
        break;
      case 1:
        await ClientsProvider.instance.loadFromApi(force: false);
        break;
      case 2:
        await ProductsProvider.instance.loadFromStorage(refreshInBackground: true);
        await ApiPacing.staggerPause();
        await CategoriesProvider.instance.loadFromApiIfStale();
        break;
      case 3:
        await ProductsProvider.instance.loadFromStorage(refreshInBackground: true);
        SalesSessionProvider.instance.applyCatalogStock();
        await SalesSessionProvider.instance.syncFromServerInBackground();
        break;
      case 4:
        await ReceiveSessionProvider.instance.loadInit();
        break;
      case 5:
      case 6:
      case 7:
        break;
    }

    SalesSessionProvider.instance.syncFromShift();
  }
}

/// StatefulWidget ekranlari — shell sinxronlashidan keyin qayta yuklash.
mixin DesktopShellSyncMixin<T extends StatefulWidget> on State<T> {
  int _desktopSyncGen = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = DesktopShellScope.maybeOf(context);
    if (scope == null || scope.syncGeneration == _desktopSyncGen) return;
    _desktopSyncGen = scope.syncGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) onDesktopShellSync();
    });
  }

  @protected
  Future<void> onDesktopShellSync();
}
