import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../utils/platform_layout.dart';
import 'ios_style_modals.dart';

/// Dropdown varianti — barcha stil shu yerda markazlashgan.
enum AppDropdownVariant {
  /// Forma maydoni (label + border).
  field,

  /// Ixcham forma.
  compact,

  /// Sotuv navbar (ikkita qatorli label/value).
  navbar,

  /// Inline (underline yo‘q, navbar kabi oq kartocha).
  inline,
}

/// Markaziy dropdown UI.
/// Stilni shu faylda o‘zgartirsangiz — dasturdagi barcha dropdownlar yangilanadi.
class AppDropdownField<T> extends StatelessWidget {
  final String? label;
  final String? hint;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final FormFieldValidator<T>? validator;
  final bool isExpanded;
  final double? menuMaxHeight;
  final bool enabled;
  final AppDropdownVariant variant;
  final Widget? icon;
  final EdgeInsetsGeometry? contentPadding;
  final Color? fillColor;

  const AppDropdownField({
    super.key,
    this.label,
    this.hint,
    required this.value,
    required this.items,
    this.onChanged,
    this.validator,
    this.isExpanded = true,
    this.menuMaxHeight,
    this.enabled = true,
    this.variant = AppDropdownVariant.field,
    this.icon,
    this.contentPadding,
    this.fillColor,
  });

  static BorderRadius get radius => BorderRadius.circular(10);
  static Color get menuColor => const Color(0xFFE9EEF5);
  static Color get iconColor => AppTheme.textSecondary;
  static Color get labelColor => AppTheme.textSecondary;
  static Color get valueColor => AppTheme.textPrimary;

  static double get fieldFontSize => 14;
  static double get compactFontSize => 13;
  static double get navbarLabelFontSize => 11;
  static double get navbarValueFontSize => 13;

  @override
  Widget build(BuildContext context) {
    if (!isDesktopPosLayout) {
      return _buildMobileSheetField(context);
    }
    return switch (variant) {
      AppDropdownVariant.navbar => _buildNavbar(context),
      AppDropdownVariant.inline => _buildInline(context),
      AppDropdownVariant.compact || AppDropdownVariant.field => _buildFormField(context),
    };
  }

  String _labelOf(DropdownMenuItem<T> item) {
    final child = item.child;
    if (child is Text) return child.data ?? child.toString();
    return item.value?.toString() ?? '';
  }

  Future<void> _openPicker(BuildContext context) async {
    if (!enabled || onChanged == null || items.isEmpty) return;
    final picked = await IosStyleModals.showPicker<T>(
      context: context,
      title: label ?? hint ?? 'Tanlang',
      options: [
        for (final item in items)
          if (item.enabled && item.value is T) (value: item.value as T, label: _labelOf(item)),
      ],
      selected: _safeValue(),
    );
    if (picked != null) onChanged!(picked);
  }

  Widget _buildMobileSheetField(BuildContext context) {
    final compact = variant == AppDropdownVariant.compact;
    final selected = _safeValue();
    final selectedLabel = _selectedLabel() ?? hint ?? '';

    return FormField<T>(
      initialValue: selected,
      validator: validator,
      builder: (state) {
        return InkWell(
          onTap: enabled ? () => _openPicker(context) : null,
          borderRadius: radius,
          child: InputDecorator(
            decoration: _decoration(compact: compact).copyWith(
              suffixIcon: _dropdownIcon(size: compact ? 20 : 22),
              errorText: state.errorText,
            ),
            isEmpty: selected == null && selectedLabel.isEmpty,
            child: Text(
              selectedLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: compact ? compactFontSize : fieldFontSize,
                fontWeight: FontWeight.w600,
                color: selected == null ? labelColor : valueColor,
                height: 1.2,
              ),
            ),
          ),
        );
      },
    );
  }

  InputDecoration _decoration({required bool compact}) {
    final r = radius;
    final pad = contentPadding ??
        EdgeInsets.symmetric(
          horizontal: 14,
          vertical: compact ? 10 : 14,
        );
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: fillColor ?? Colors.white,
      hoverColor: Colors.transparent,
      isDense: compact,
      floatingLabelStyle: TextStyle(
        color: labelColor,
        fontWeight: FontWeight.w600,
        fontSize: compact ? 12 : 13,
      ),
      labelStyle: TextStyle(
        color: labelColor,
        fontWeight: FontWeight.w600,
        fontSize: compact ? 12 : 13,
      ),
      hintStyle: TextStyle(
        color: labelColor,
        fontWeight: FontWeight.w500,
        fontSize: compact ? compactFontSize : fieldFontSize,
      ),
      contentPadding: pad,
      border: OutlineInputBorder(
        borderRadius: r,
        borderSide: BorderSide(color: AppTheme.divider.withValues(alpha: 0.95)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: r,
        borderSide: BorderSide(color: AppTheme.divider.withValues(alpha: 0.95)),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: r,
        borderSide: BorderSide(color: AppTheme.divider.withValues(alpha: 0.5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: r,
        borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: r,
        borderSide: BorderSide(color: Colors.red.shade400, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: r,
        borderSide: BorderSide(color: Colors.red.shade400, width: 1.5),
      ),
    );
  }

  Widget _dropdownIcon({double size = 22}) {
    return icon ??
        Icon(
          Icons.keyboard_arrow_down_rounded,
          size: size,
          color: enabled ? iconColor : iconColor.withValues(alpha: 0.45),
        );
  }

  Widget _buildFormField(BuildContext context) {
    final compact = variant == AppDropdownVariant.compact;
    return DropdownButtonFormField<T>(
      value: _safeValue(),
      isExpanded: isExpanded,
      menuMaxHeight: menuMaxHeight ?? 280,
      dropdownColor: menuColor,
      borderRadius: radius,
      icon: _dropdownIcon(size: compact ? 20 : 22),
      style: TextStyle(
        fontSize: compact ? compactFontSize : fieldFontSize,
        fontWeight: FontWeight.w600,
        color: valueColor,
        height: 1.2,
      ),
      decoration: _decoration(compact: compact),
      items: items,
      validator: validator,
      onChanged: enabled ? onChanged : null,
    );
  }

  Widget _buildInline(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: fillColor ?? Colors.white,
        borderRadius: radius,
        border: Border.all(color: AppTheme.divider),
      ),
      padding: contentPadding ?? const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.centerLeft,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: _safeValue(),
          isExpanded: isExpanded,
          isDense: true,
          menuMaxHeight: menuMaxHeight ?? 280,
          dropdownColor: menuColor,
          borderRadius: radius,
          icon: _dropdownIcon(size: 20),
          style: TextStyle(
            fontSize: fieldFontSize,
            fontWeight: FontWeight.w600,
            color: valueColor,
            height: 1.2,
          ),
          hint: hint == null
              ? null
              : Text(
                  hint!,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: fieldFontSize,
                    fontWeight: FontWeight.w500,
                    color: labelColor,
                  ),
                ),
          items: items,
          onChanged: enabled ? onChanged : null,
        ),
      ),
    );
  }

  Widget _buildNavbar(BuildContext context) {
    final selectedLabel = _selectedLabel();
    return Container(
      height: contentPadding == null ? 56 : null,
      decoration: BoxDecoration(
        color: fillColor ?? Colors.white,
        borderRadius: radius,
        border: Border.all(color: AppTheme.divider),
      ),
      padding: contentPadding ?? const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: _safeValue(),
          isExpanded: isExpanded,
          isDense: true,
          menuMaxHeight: menuMaxHeight ?? 220,
          dropdownColor: menuColor,
          borderRadius: radius,
          icon: _dropdownIcon(size: 20),
          style: TextStyle(
            fontSize: navbarValueFontSize,
            fontWeight: FontWeight.w700,
            color: valueColor,
            height: 1.1,
          ),
          selectedItemBuilder: (context) {
            return [
              for (final item in items)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (label != null)
                        Text(
                          label!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: navbarLabelFontSize,
                            fontWeight: FontWeight.w600,
                            color: labelColor,
                            height: 1.05,
                          ),
                        ),
                      DefaultTextStyle(
                        style: TextStyle(
                          fontSize: navbarValueFontSize,
                          fontWeight: FontWeight.w700,
                          color: valueColor,
                          height: 1.1,
                        ),
                        child: item.child,
                      ),
                    ],
                  ),
                ),
            ];
          },
          hint: hint == null && selectedLabel == null
              ? null
              : Text(
                  selectedLabel ?? hint ?? '',
                  overflow: TextOverflow.ellipsis,
                ),
          items: items,
          onChanged: enabled ? onChanged : null,
        ),
      ),
    );
  }

  T? _safeValue() {
    if (value == null) return null;
    final exists = items.any((e) => e.value == value);
    return exists ? value : null;
  }

  String? _selectedLabel() {
    for (final item in items) {
      if (item.value == value) {
        if (item.child is Text) return (item.child as Text).data;
        return item.value?.toString();
      }
    }
    return null;
  }
}

/// Qulay item yaratish.
DropdownMenuItem<T> appDropdownItem<T>({
  required T value,
  required String label,
  bool enabled = true,
}) {
  return DropdownMenuItem<T>(
    value: value,
    enabled: enabled,
    child: Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppTheme.textPrimary,
      ),
    ),
  );
}
