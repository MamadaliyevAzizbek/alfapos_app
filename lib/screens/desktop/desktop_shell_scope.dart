import 'package:flutter/material.dart';

import '../../services/app_data_sync.dart';

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

  /// Eski API — endi to‘liq sinxronlash [AppDataSync.syncAll] orqali.
  static Future<void> run(int tabIndex, {bool force = true}) async {
    if (force && AppDataSync.isForceSyncBlocked) return;
    await AppDataSync.syncAll(force: force);
  }
}

/// StatefulWidget ekranlari — shell sinxronlashidan keyin qayta yuklash.
mixin DesktopShellSyncMixin<T extends StatefulWidget> on State<T> {
  int _desktopSyncGen = 0;
  bool _desktopSyncReady = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = DesktopShellScope.maybeOf(context);
    if (scope == null) return;
    if (!_desktopSyncReady) {
      _desktopSyncReady = true;
      _desktopSyncGen = scope.syncGeneration;
      return;
    }
    if (scope.syncGeneration == _desktopSyncGen) return;
    _desktopSyncGen = scope.syncGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) onDesktopShellSync();
    });
  }

  @protected
  Future<void> onDesktopShellSync();
}
