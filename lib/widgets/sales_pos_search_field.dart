import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../services/sales_ui_scale_settings.dart';
import 'sales_shortcut_key_badge.dart';

/// Sotuv POS: mahsulot / mijoz qidiruv — bir xil balandlik, border, radius.
class SalesPosSearchField extends StatelessWidget {
  static const Color borderColor = Color(0xFFDDE5F0);
  static const BorderRadius radius = BorderRadius.all(Radius.circular(8));

  final TextEditingController controller;
  final FocusNode? focusNode;
  final String hintText;
  final IconData prefixIcon;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction textInputAction;
  final String? shortcutKeyLabel;
  final bool loading;
  final Key? fieldKey;

  const SalesPosSearchField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.prefixIcon,
    this.focusNode,
    this.onChanged,
    this.onSubmitted,
    this.textInputAction = TextInputAction.search,
    this.shortcutKeyLabel,
    this.loading = false,
    this.fieldKey,
  });

  static double get height => SalesUiScaleSettings.navbarControlSize();

  @override
  Widget build(BuildContext context) {
    final h = height;
    final iconSize = SalesUiScaleSettings.scaled(20);
    final fontSize = SalesUiScaleSettings.scaled(14);
    final showClear = controller.text.isNotEmpty && !loading;

    return SizedBox(
      height: h,
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) {
          final empty = value.text.isEmpty;
          return SalesFieldShortcutOverlay(
            keyLabel: shortcutKeyLabel,
            visible: empty && !loading,
            child: TextField(
              key: fieldKey,
              controller: controller,
              focusNode: focusNode,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              textInputAction: textInputAction,
              style: TextStyle(
                fontSize: fontSize,
                height: 1.2,
                fontWeight: FontWeight.w500,
                color: AppTheme.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondary,
                ),
                filled: true,
                fillColor: Colors.white,
                hoverColor: Colors.transparent,
                isDense: true,
                prefixIcon: Icon(prefixIcon, size: iconSize, color: AppTheme.textSecondary),
                prefixIconConstraints: BoxConstraints(
                  minWidth: SalesUiScaleSettings.scaled(40),
                  minHeight: h,
                  maxHeight: h,
                ),
                suffixIcon: loading
                    ? Padding(
                        padding: EdgeInsets.all(SalesUiScaleSettings.scaled(12)),
                        child: SizedBox(
                          width: SalesUiScaleSettings.scaled(16),
                          height: SalesUiScaleSettings.scaled(16),
                          child: const CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : showClear
                        ? IconButton(
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                            tooltip: 'Tozalash',
                            icon: Icon(Icons.close_rounded, size: iconSize),
                            onPressed: () {
                              controller.clear();
                              onChanged?.call('');
                            },
                          )
                        : null,
                suffixIconConstraints: BoxConstraints(
                  minWidth: SalesUiScaleSettings.scaled(40),
                  minHeight: h,
                  maxHeight: h,
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: SalesUiScaleSettings.scaled(12),
                  vertical: 0,
                ),
                border: const OutlineInputBorder(
                  borderRadius: radius,
                  borderSide: BorderSide(color: borderColor),
                ),
                enabledBorder: const OutlineInputBorder(
                  borderRadius: radius,
                  borderSide: BorderSide(color: borderColor),
                ),
                disabledBorder: const OutlineInputBorder(
                  borderRadius: radius,
                  borderSide: BorderSide(color: borderColor),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderRadius: radius,
                  borderSide: BorderSide(color: AppTheme.primary, width: 1.5),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Toolbar kvadrat tugma — qidiruv balandligi bilan bir xil.
class SalesPosToolbarIconButton extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final Color? borderColor;
  final Color? backgroundColor;
  final VoidCallback? onTap;
  final String? tooltip;
  final Widget? badge;

  const SalesPosToolbarIconButton({
    super.key,
    required this.icon,
    this.iconColor,
    this.borderColor,
    this.backgroundColor,
    this.onTap,
    this.tooltip,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final size = SalesPosSearchField.height;
    final child = SizedBox(
      width: size,
      height: size,
      child: Material(
        color: backgroundColor ?? Colors.white,
        borderRadius: SalesPosSearchField.radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: SalesPosSearchField.radius,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: SalesPosSearchField.radius,
              border: Border.all(color: borderColor ?? SalesPosSearchField.borderColor),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  icon,
                  size: SalesUiScaleSettings.scaled(22),
                  color: iconColor ?? AppTheme.primary,
                ),
                if (badge != null)
                  Positioned(right: 5, bottom: 5, child: IgnorePointer(child: badge!)),
              ],
            ),
          ),
        ),
      ),
    );
    if (tooltip == null) return child;
    return Tooltip(message: tooltip!, child: child);
  }
}
