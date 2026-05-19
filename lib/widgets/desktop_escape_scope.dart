import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_navigator.dart';
import '../utils/platform_layout.dart';

/// Desktop: Escape — dialog yoki oldingi ekranga qaytish.
class DesktopEscapeScope extends StatelessWidget {
  final Widget child;

  const DesktopEscapeScope({super.key, required this.child});

  static bool handleEscape(BuildContext context) {
    final focus = FocusManager.instance.primaryFocus;
    if (focus != null && focus.hasFocus) {
      final editable = focus.context?.findAncestorWidgetOfExactType<EditableText>();
      if (editable != null) {
        focus.unfocus();
        return true;
      }
    }

    final rootNav = Navigator.of(context, rootNavigator: true);
    if (rootNav.canPop()) {
      rootNav.maybePop();
      return true;
    }

    final nav = Navigator.maybeOf(context);
    if (nav != null && nav.canPop()) {
      nav.maybePop();
      return true;
    }

    final appNav = appNavigatorKey.currentState;
    if (appNav != null && appNav.canPop()) {
      appNav.maybePop();
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    if (!isDesktopPosLayout) return child;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () => handleEscape(context),
      },
      child: Focus(
        autofocus: true,
        canRequestFocus: true,
        child: child,
      ),
    );
  }
}
