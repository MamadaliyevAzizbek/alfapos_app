import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Material 3 uslubidagi modallar: yumaloq dialoglar, shaffof fon, pastki varaq.
class AppModals {
  AppModals._();

  static const double dialogCornerRadius = 20;
  static const double sheetCornerRadius = 20;

  static Color _barrier() => Colors.black.withValues(alpha: 0.45);

  static Widget sheetSurface({
    required Widget child,
    Color color = Colors.white,
  }) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(sheetCornerRadius)),
      child: Material(
        color: color,
        elevation: 0,
        shadowColor: Colors.transparent,
        type: MaterialType.canvas,
        child: child,
      ),
    );
  }

  /// Pastki varaq — oq fon, tutqich chizig'i, soyasiz (iOS uslubi).
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
      elevation: 0,
      builder: (ctx) {
        final bottom = MediaQuery.viewInsetsOf(ctx).bottom;
        final maxSheetHeight = MediaQuery.sizeOf(ctx).height * 0.82;
        return Padding(
          padding: EdgeInsets.only(bottom: bottom),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: sheetSurface(
              child: SafeArea(
                top: false,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxSheetHeight),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (showGrabber) grabber(),
                      child,
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Suriladigan pastki varaq (filtr, tarix) — qora soya animatsiyasiz.
  static Future<T?> showDraggableSheet<T>({
    required BuildContext context,
    required Widget Function(BuildContext context, ScrollController scrollController) builder,
    double initialChildSize = 0.82,
    double minChildSize = 0.45,
    double maxChildSize = 0.92,
    Widget? header,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      barrierColor: _barrier(),
      elevation: 0,
      builder: (ctx) {
        final bottom = MediaQuery.paddingOf(ctx).bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: bottom),
          child: DraggableScrollableSheet(
            initialChildSize: initialChildSize,
            minChildSize: minChildSize,
            maxChildSize: maxChildSize,
            expand: false,
            builder: (sheetCtx, scrollController) {
              return sheetSurface(
                child: Column(
                  children: [
                    if (header != null) header,
                    Expanded(child: builder(sheetCtx, scrollController)),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  static const EdgeInsets sheetHorizontalPadding = EdgeInsets.symmetric(horizontal: 16);
  static const EdgeInsets sheetBodyPadding = EdgeInsets.fromLTRB(16, 8, 16, 0);
  static const EdgeInsets sheetActionsPadding = EdgeInsets.fromLTRB(16, 12, 16, 16);

  /// Klaviatura ochilganda tugmalar varaq bilan birga ko'tariladi (showSheet padding).
  /// Maydonlar scroll, tugmalar pastda qotilgan.
  static Widget sheetKeyboardForm({
    required BuildContext context,
    required List<Widget> body,
    Widget? middle,
    Widget? bottomBar,
    VoidCallback? onCancel,
    VoidCallback? onSave,
    String cancelLabel = 'Bekor qilish',
    String saveLabel = 'Saqlash',
    Color? saveBackgroundColor,
    Color? saveForegroundColor,
    bool isSaving = false,
    double maxScrollHeightFactor = 0.5,
  }) {
    final maxH = MediaQuery.sizeOf(context).height * maxScrollHeightFactor;
    final actions = bottomBar ??
        (onCancel != null && onSave != null
            ? sheetPillCancelSaveRow(
                onCancel: onCancel,
                onSave: onSave,
                cancelLabel: cancelLabel,
                saveLabel: saveLabel,
                saveBackgroundColor: saveBackgroundColor,
                saveForegroundColor: saveForegroundColor,
                isSaving: isSaving,
              )
            : null);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxH),
          child: SingleChildScrollView(
            padding: sheetBodyPadding,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: body,
            ),
          ),
        ),
        if (middle != null) middle,
        if (actions != null)
          Padding(
            padding: sheetActionsPadding,
            child: actions,
          ),
      ],
    );
  }

  /// Qisqa tasdiq / xabar — scrollsiz, tugmalar kontent ostida.
  static Widget sheetConfirm({
    required List<Widget> body,
    required VoidCallback onCancel,
    required VoidCallback onConfirm,
    String cancelLabel = 'Bekor qilish',
    String confirmLabel = 'Saqlash',
    Color? confirmBackgroundColor,
    Color? confirmForegroundColor,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...body,
          const SizedBox(height: 14),
          sheetPillCancelSaveRow(
            onCancel: onCancel,
            onSave: onConfirm,
            cancelLabel: cancelLabel,
            saveLabel: confirmLabel,
            saveBackgroundColor: confirmBackgroundColor,
            saveForegroundColor: confirmForegroundColor,
          ),
        ],
      ),
    );
  }

  /// Ro'yxatdan bitta qiymat (kategoriya, o'lchov birligi). Scroll — overflow bo'lmaydi.
  static Future<void> showChoiceList({
    required BuildContext context,
    required String title,
    required List<String> options,
    required ValueChanged<String> onSelect,
  }) {
    return showSheet<void>(
      context: context,
      isScrollControlled: true,
      showGrabber: true,
      child: Builder(
        builder: (sheetCtx) {
          const tileHeight = 56.0;
          final bottom = MediaQuery.paddingOf(sheetCtx).bottom;
          final maxListH = MediaQuery.sizeOf(sheetCtx).height * 0.58;
          final contentH = options.length * tileHeight + 8;
          final listH = contentH.clamp(tileHeight, maxListH);

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
              const Divider(height: 1),
              SizedBox(
                height: listH,
                child: ListView.builder(
                  itemCount: options.length,
                  itemBuilder: (_, i) {
                    final label = options[i];
                    return ListTile(
                      title: Text(label),
                      onTap: () {
                        onSelect(label);
                        Navigator.pop(sheetCtx);
                      },
                    );
                  },
                ),
              ),
              SizedBox(height: bottom > 0 ? bottom : 12),
            ],
          );
        },
      ),
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
    VoidCallback? onCancel,
    VoidCallback? onSave,
    String cancelLabel = 'Bekor qilish',
    String saveLabel = 'Saqlash',
    Color? saveBackgroundColor,
    Color? saveForegroundColor,
    bool isSaving = false,
  }) {
    const radius = 28.0;
    final saveBg = saveBackgroundColor ?? AppTheme.primary;
    final saveFg = saveForegroundColor ?? Colors.white;
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: isSaving ? null : onCancel,
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
            onPressed: isSaving ? null : onSave,
            style: FilledButton.styleFrom(
              backgroundColor: saveBg,
              foregroundColor: saveFg,
              padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 14),
              minimumSize: const Size(0, 50),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
            ),
            child: isSaving
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: saveFg),
                  )
                : Text(
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

  static InputDecoration desktopField(String label, {String? suffix, String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      suffixText: suffix,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppTheme.divider),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      labelStyle: const TextStyle(fontSize: 15),
    );
  }

  /// Markazdagi forma — faqat desktop (Windows/macOS).
  static Future<T?> showDesktopFormPanel<T>({
    required BuildContext context,
    required String title,
    required List<Widget> children,
    required T? Function() trySubmit,
    String? subtitle,
    double width = 500,
    String cancelLabel = 'Bekor qilish',
    String saveLabel = 'Saqlash',
    Color? saveBackgroundColor,
  }) {
    return showPopupPanel<T>(
      context: context,
      insetPadding: const EdgeInsets.symmetric(horizontal: 48, vertical: 40),
      child: Builder(
        builder: (ctx) => SizedBox(
          width: width,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 24, 28, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                    if (subtitle != null && subtitle.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(subtitle, style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 20, 28, 24),
                child: sheetPillCancelSaveRow(
                  onCancel: () => Navigator.pop(ctx),
                  onSave: () {
                    final value = trySubmit();
                    if (value != null) Navigator.pop(ctx, value);
                  },
                  cancelLabel: cancelLabel,
                  saveLabel: saveLabel,
                  saveBackgroundColor: saveBackgroundColor,
                ),
              ),
            ],
          ),
        ),
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
