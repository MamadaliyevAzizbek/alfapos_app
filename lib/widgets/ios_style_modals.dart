import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Material 3 uslubidagi modallar: yumaloq dialoglar, shaffof fon, pastki varaq.
class AppModals {
  AppModals._();

  static const double dialogCornerRadius = 20;
  static const double sheetCornerRadius = 20;

  static Color _barrier() => Colors.black.withValues(alpha: 0.45);

  /// Pastki varaq — oq fon, tutqich chizig'i.
  static Future<T?> showSheet<T>({
    required BuildContext context,
    required Widget child,
    bool isScrollControlled = false,
    bool showGrabber = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      barrierColor: _barrier(),
      builder: (ctx) {
        final bottom = MediaQuery.viewInsetsOf(ctx).bottom;
        final maxSheetHeight = MediaQuery.sizeOf(ctx).height * 0.82;
        return Padding(
          padding: EdgeInsets.only(bottom: bottom),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(sheetCornerRadius)),
              child: Material(
                color: Colors.white,
                elevation: 12,
                shadowColor: Colors.black.withValues(alpha: 0.12),
                child: SafeArea(
                  top: false,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: maxSheetHeight),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (showGrabber) grabber(),
                        Flexible(
                          fit: FlexFit.loose,
                          child: child,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  static Widget grabber() {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 8),
      child: Center(
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: AppTheme.divider,
            borderRadius: BorderRadius.circular(100),
          ),
        ),
      ),
    );
  }

  /// Pastki varaq: chap — kontur + ko'k matn, o'ng — to'ldirilgan (iOS pill).
  /// [saveBackgroundColor] / [saveForegroundColor] — masalan xavfli amal uchun qizil.
  static Widget sheetPillCancelSaveRow({
    required VoidCallback onCancel,
    required VoidCallback onSave,
    String cancelLabel = 'Bekor qilish',
    String saveLabel = 'Saqlash',
    Color? saveBackgroundColor,
    Color? saveForegroundColor,
  }) {
    const radius = 28.0;
    final saveBg = saveBackgroundColor ?? AppTheme.primary;
    final saveFg = saveForegroundColor ?? Colors.white;
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: onCancel,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primary,
              padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 14),
              minimumSize: const Size(0, 50),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              side: const BorderSide(color: AppTheme.divider, width: 1),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
            ),
            child: Text(
              cancelLabel,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton(
            onPressed: onSave,
            style: FilledButton.styleFrom(
              backgroundColor: saveBg,
              foregroundColor: saveFg,
              padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 14),
              minimumSize: const Size(0, 50),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
            ),
            child: Text(
              saveLabel,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
          ),
        ),
      ],
    );
  }

  /// Oddiy xabar (bitta tugma).
  static Future<void> showOkAlert(
    BuildContext context, {
    String? title,
    required String message,
    String okLabel = 'OK',
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: _barrier(),
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(dialogCornerRadius)),
        backgroundColor: Colors.white,
        title: title != null ? Text(title, style: const TextStyle(fontWeight: FontWeight.w700)) : null,
        content: Text(message, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(okLabel),
          ),
        ],
      ),
    );
  }

  /// Katta kontent (chek, forma).
  static Future<T?> showPopupPanel<T>({
    required BuildContext context,
    required Widget child,
    EdgeInsets insetPadding = const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
    bool barrierDismissible = true,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierColor: _barrier(),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: insetPadding,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(dialogCornerRadius),
          child: Material(
            color: Colors.white,
            elevation: 16,
            shadowColor: Colors.black.withValues(alpha: 0.18),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Eski importlar bilan moslik.
typedef IosStyleModals = AppModals;
