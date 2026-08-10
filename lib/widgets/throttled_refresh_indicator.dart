import 'package:flutter/material.dart';

import '../core/app_notify.dart';

/// Pull-to-refresh: ketma-ket tortib API ni bosib yubormaslik.
class PullRefreshGuard {
  PullRefreshGuard._();

  /// Barcha ekranlar uchun bitta cooldown (IP throttle / 429).
  static const cooldown = Duration(seconds: 25);

  static DateTime? _lastPullAt;
  static bool _busy = false;

  /// [true] — yangilandi; [false] — cooldown yoki band.
  static Future<bool> run(
    Future<void> Function() action, {
    BuildContext? context,
    bool notifyIfBlocked = true,
  }) async {
    if (_busy) return false;

    final left = remainingCooldown;
    if (left != null) {
      if (notifyIfBlocked && context != null && context.mounted) {
        final sec = left.inSeconds.clamp(1, cooldown.inSeconds);
        AppNotify.warning(
          context,
          'Tez-tez yangilash cheklangan. $sec soniyadan keyin qayta urinib ko\'ring.',
        );
      }
      return false;
    }

    _busy = true;
    _lastPullAt = DateTime.now();
    try {
      await action();
      return true;
    } finally {
      _busy = false;
    }
  }

  static Duration? get remainingCooldown {
    final last = _lastPullAt;
    if (last == null) return null;
    final elapsed = DateTime.now().difference(last);
    if (elapsed >= cooldown) return null;
    return cooldown - elapsed;
  }

  static void reset() {
    _lastPullAt = null;
    _busy = false;
  }
}

/// [RefreshIndicator] + global pull cooldown.
class ThrottledRefreshIndicator extends StatelessWidget {
  final Future<void> Function() onRefresh;
  final Widget child;
  final Color? color;
  final Color? backgroundColor;
  final double displacement;
  final double edgeOffset;
  final ScrollNotificationPredicate notificationPredicate;

  const ThrottledRefreshIndicator({
    super.key,
    required this.onRefresh,
    required this.child,
    this.color,
    this.backgroundColor,
    this.displacement = 40.0,
    this.edgeOffset = 0.0,
    this.notificationPredicate = defaultScrollNotificationPredicate,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: color,
      backgroundColor: backgroundColor,
      displacement: displacement,
      edgeOffset: edgeOffset,
      notificationPredicate: notificationPredicate,
      onRefresh: () async {
        await PullRefreshGuard.run(onRefresh, context: context);
      },
      child: child,
    );
  }
}
