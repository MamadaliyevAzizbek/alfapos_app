import 'package:flutter/material.dart';

/// Sotuv ekranida fokus qoldiriladigan maydonlar (mijoz qidiruv, foiz, miqdor, dialoglar).
/// Qidiruv inputiga avtofokus qaytarishda bu ichidagi TextField lar buzilmaydi.
class PosEditableFocusScope extends StatelessWidget {
  const PosEditableFocusScope({super.key, required this.child});

  final Widget child;

  static bool contains(FocusNode? node) {
    final ctx = node?.context;
    if (ctx == null) return false;
    return ctx.findAncestorWidgetOfExactType<PosEditableFocusScope>() != null;
  }

  /// Dialog, bottom sheet va boshqa overlay ichidagi fokusni saqlash.
  static bool shouldPreserveFocus(FocusNode? node) {
    if (contains(node)) return true;
    final ctx = node?.context;
    if (ctx == null) return false;
    final route = ModalRoute.of(ctx);
    if (route is PopupRoute) return true;
    return false;
  }

  @override
  Widget build(BuildContext context) => child;
}
