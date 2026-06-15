import 'package:flutter/material.dart';

/// Kichik tezkor klavish yozuvi (masalan F7) — fon va chegarasiz, joy egallamaydi.
class SalesShortcutKeyBadge extends StatelessWidget {
  final String label;
  final bool onDark;

  const SalesShortcutKeyBadge({
    super.key,
    required this.label,
    this.onDark = false,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 9,
        fontWeight: FontWeight.w600,
        color: onDark ? Colors.white.withValues(alpha: 0.45) : const Color(0xFF94A3B8),
        height: 1,
        letterSpacing: 0.1,
      ),
    );
  }
}

/// Input maydoni ichida o‘ng pastki burchakda klavish yozuvi (klikka xalaqit bermaydi).
class SalesFieldShortcutOverlay extends StatelessWidget {
  final Widget child;
  final String? keyLabel;
  final bool visible;

  const SalesFieldShortcutOverlay({
    super.key,
    required this.child,
    this.keyLabel,
    this.visible = true,
  });

  @override
  Widget build(BuildContext context) {
    final showBadge = visible && keyLabel != null && keyLabel!.isNotEmpty;

    // Stack tuzilmasini doim saqlash — query bo‘shdan to‘ldiq o‘tganda TextField
    // qayta mount bo‘lib fokus yo‘qolmasin (desktop qidiruv).
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        if (showBadge)
          Positioned(
            right: 10,
            bottom: 7,
            child: IgnorePointer(
              child: SalesShortcutKeyBadge(label: keyLabel!),
            ),
          ),
      ],
    );
  }
}
