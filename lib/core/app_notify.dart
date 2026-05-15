import 'dart:async';

import 'package:flutter/material.dart';

import 'app_navigator.dart';

enum AppNotifyKind {
  success,
  error,
  warning,
  info,
}

/// Rasmdagidek yuqori «pill» bildirishnoma — tepadan sillab tushadi.
abstract class AppNotify {
  static OverlayEntry? _entry;
  static Timer? _timer;
  static _AppTopBannerState? _activeState;

  static OverlayState? _overlayFor(BuildContext? context) {
    if (context != null && context.mounted) {
      try {
        final o = Overlay.maybeOf(context, rootOverlay: true);
        if (o != null) return o;
      } catch (_) {}
    }
    return appNavigatorKey.currentState?.overlay;
  }

  static void _cancelCurrent() {
    _timer?.cancel();
    _timer = null;
    _activeState = null;
    _entry?.remove();
    _entry = null;
  }

  /// [context] ixtiyoriy: berilsa, shu oynaning overlay'i; aks holda [appNavigatorKey].
  static void show(
    BuildContext? context,
    String message, {
    AppNotifyKind kind = AppNotifyKind.success,
    Duration display = const Duration(milliseconds: 2800),
  }) {
    final overlay = _overlayFor(context);
    if (overlay == null || message.isEmpty) return;

    _cancelCurrent();

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => _AppTopBanner(
        message: message,
        kind: kind,
        displayDuration: display,
        onReady: (s) => _activeState = s,
        onDisposeLayer: () {
          entry.remove();
          if (_entry == entry) {
            _entry = null;
            _activeState = null;
          }
        },
      ),
    );
    _entry = entry;
    overlay.insert(entry);

    _timer = Timer(display, () {
      _activeState?.dismiss();
    });
  }

  static void success(BuildContext? context, String message, {Duration? duration}) {
    show(context, message, kind: AppNotifyKind.success, display: duration ?? const Duration(milliseconds: 2800));
  }

  static void error(BuildContext? context, String message, {Duration? duration}) {
    show(context, message, kind: AppNotifyKind.error, display: duration ?? const Duration(milliseconds: 3400));
  }

  static void warning(BuildContext? context, String message, {Duration? duration}) {
    show(context, message, kind: AppNotifyKind.warning, display: duration ?? const Duration(milliseconds: 3000));
  }

  static void info(BuildContext? context, String message, {Duration? duration}) {
    show(context, message, kind: AppNotifyKind.info, display: duration ?? const Duration(milliseconds: 2800));
  }
}

class _AppTopBanner extends StatefulWidget {
  const _AppTopBanner({
    required this.message,
    required this.kind,
    required this.displayDuration,
    required this.onReady,
    required this.onDisposeLayer,
  });

  final String message;
  final AppNotifyKind kind;
  final Duration displayDuration;
  final void Function(_AppTopBannerState state) onReady;
  final VoidCallback onDisposeLayer;

  @override
  State<_AppTopBanner> createState() => _AppTopBannerState();
}

class _AppTopBannerState extends State<_AppTopBanner> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slide;
  late Animation<double> _opacity;

  static const _green = Color(0xFF22C55E);
  static const _red = Color(0xFFEF4444);
  static const _amber = Color(0xFFF59E0B);
  static const _blue = Color(0xFF2563EB);

  Color get _background {
    switch (widget.kind) {
      case AppNotifyKind.success:
        return _green;
      case AppNotifyKind.error:
        return _red;
      case AppNotifyKind.warning:
        return _amber;
      case AppNotifyKind.info:
        return _blue;
    }
  }

  (Color iconOnWhite, IconData icon) get _badge {
    switch (widget.kind) {
      case AppNotifyKind.success:
        return (_green, Icons.check_rounded);
      case AppNotifyKind.error:
        return (_red, Icons.close_rounded);
      case AppNotifyKind.warning:
        return (_amber, Icons.warning_rounded);
      case AppNotifyKind.info:
        return (_blue, Icons.info_outline_rounded);
    }
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, -1.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _opacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0, 0.55, curve: Curves.easeOut)),
    );
    _controller.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onReady(this);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> dismiss() async {
    if (!mounted) return;
    try {
      await _controller.reverse();
    } catch (_) {
      // Overlay boshqa bildirishnoma bilan olib tashlanganda controller dispose bo'lishi mumkin.
    }
    if (!mounted) return;
    widget.onDisposeLayer();
  }

  @override
  Widget build(BuildContext context) {
    final (iconColor, iconData) = _badge;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
          child: SlideTransition(
            position: _slide,
            child: FadeTransition(
              opacity: _opacity,
              child: Material(
                color: Colors.transparent,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: _background,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(iconData, color: iconColor, size: 17),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            widget.message,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              height: 1.25,
                            ),
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
