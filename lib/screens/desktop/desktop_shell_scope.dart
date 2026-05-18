import 'package:flutter/material.dart';

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
    final tasks = <Future<void>>[
      CashRegisterShiftProvider.instance.syncWithServer(),
      syncSellerNameFromApi(),
    ];

    switch (tabIndex) {
      case 0:
        tasks.add(DashboardProvider.instance.loadFromApi());
        break;
      case 1:
        tasks.add(ClientsProvider.instance.loadFromApi(force: true));
        break;
      case 2:
        tasks.add(ProductsProvider.instance.loadFromApi());
        tasks.add(CategoriesProvider.instance.loadFromApi());
        break;
      case 3:
        tasks.add(SalesSessionProvider.instance.ensurePaymentTypesLoaded());
        tasks.add(ProductsProvider.instance.loadFromApi());
        tasks.add(SalesSessionProvider.instance.loadProducts(reset: true));
        break;
      case 4:
        tasks.add(ReceiveSessionProvider.instance.loadInit());
        break;
      case 5:
      case 6:
      case 7:
        break;
    }

    await Future.wait(tasks);
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
