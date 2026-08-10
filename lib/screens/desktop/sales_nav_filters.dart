import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../providers/sales_session_provider.dart';
import '../../services/sales_ui_scale_settings.dart';

/// Sotuv navbar: kategoriya va brend — tugmalar bilan bir xil balandlik/border.
class SalesNavCategoryBrandFilters extends StatelessWidget {
  static double get menuMaxHeight => SalesUiScaleSettings.scaled(48 * 4);
  static double get navbarFieldHeight => SalesUiScaleSettings.navbarControlSize();

  static const Color _border = Color(0xFFDDE5F0);
  static const Color _fill = Colors.white;
  static const double _radius = 8;

  final String? categoryId;
  final String? brandId;
  final List<Map<String, dynamic>> categories;
  final List<Map<String, dynamic>> brands;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<String?> onBrandChanged;
  final bool expand;

  const SalesNavCategoryBrandFilters({
    super.key,
    required this.categoryId,
    required this.brandId,
    required this.categories,
    required this.brands,
    required this.onCategoryChanged,
    required this.onBrandChanged,
    this.expand = false,
  });

  bool get _hasCategoryFilter => categoryId != null && categoryId!.isNotEmpty;

  bool get _hasBrandFilter => brandId != null && brandId!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final gap = SalesUiScaleSettings.navbarGap();
    final category = _NavChromeDropdown(
      label: 'Kategoriya',
      value: categoryId,
      options: categories,
      onChanged: onCategoryChanged,
      showClear: _hasCategoryFilter,
      onClear: () => onCategoryChanged(null),
      clearTooltip: 'Kategoriyani tozalash',
    );
    final brand = _NavChromeDropdown(
      label: 'Brend',
      value: brandId,
      options: brands,
      onChanged: onBrandChanged,
      showClear: _hasBrandFilter,
      onClear: () => onBrandChanged(null),
      clearTooltip: 'Brendni tozalash',
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (expand) ...[
          Expanded(child: category),
          SizedBox(width: gap),
          Expanded(child: brand),
        ] else ...[
          SizedBox(width: SalesUiScaleSettings.scaled(180), child: category),
          SizedBox(width: gap),
          SizedBox(width: SalesUiScaleSettings.scaled(170), child: brand),
        ],
      ],
    );
  }
}

/// Navbar uchun: floating label yo‘q — ichki 2 qator (label + qiymat), fixed height.
class _NavChromeDropdown extends StatelessWidget {
  final String label;
  final String? value;
  final List<Map<String, dynamic>> options;
  final ValueChanged<String?> onChanged;
  final bool showClear;
  final VoidCallback onClear;
  final String clearTooltip;

  const _NavChromeDropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    required this.showClear,
    required this.onClear,
    required this.clearTooltip,
  });

  String? _safeValue() {
    if (value == null) return null;
    final ids = options.map((e) => e['id']?.toString()).toSet();
    return ids.contains(value) ? value : null;
  }

  String _displayLabel(String? id) {
    if (id == null) return 'Hammasi';
    for (final o in options) {
      if (o['id']?.toString() == id) return (o['name'] ?? '').toString();
    }
    return 'Hammasi';
  }

  @override
  Widget build(BuildContext context) {
    final h = SalesNavCategoryBrandFilters.navbarFieldHeight;
    final safe = _safeValue();
    final items = <DropdownMenuItem<String?>>[
      const DropdownMenuItem(value: null, child: Text('Hammasi')),
      ...options.map(
        (o) => DropdownMenuItem(
          value: o['id']?.toString(),
          child: Text((o['name'] ?? '').toString()),
        ),
      ),
    ];

    return SizedBox(
      height: h,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: SalesNavCategoryBrandFilters._fill,
          borderRadius: BorderRadius.circular(SalesNavCategoryBrandFilters._radius),
          border: Border.all(color: SalesNavCategoryBrandFilters._border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  left: SalesUiScaleSettings.scaled(12),
                  right: showClear ? 0 : SalesUiScaleSettings.scaled(4),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    value: safe,
                    isExpanded: true,
                    isDense: true,
                    borderRadius: BorderRadius.circular(SalesNavCategoryBrandFilters._radius),
                    menuMaxHeight: SalesNavCategoryBrandFilters.menuMaxHeight,
                    icon: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: SalesUiScaleSettings.scaled(22),
                      color: const Color(0xFF64748B),
                    ),
                    style: TextStyle(
                      fontSize: SalesUiScaleSettings.scaled(14),
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                      height: 1.1,
                    ),
                    selectedItemBuilder: (context) {
                      return [
                        for (final _ in items)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: SalesUiScaleSettings.scaled(11),
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF64748B),
                                    height: 1.05,
                                  ),
                                ),
                                Text(
                                  _displayLabel(safe),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: SalesUiScaleSettings.scaled(14),
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF0F172A),
                                    height: 1.1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ];
                    },
                    items: items,
                    onChanged: onChanged,
                  ),
                ),
              ),
            ),
            if (showClear)
              IconButton(
                onPressed: onClear,
                tooltip: clearTooltip,
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(
                  minWidth: SalesUiScaleSettings.scaled(36),
                  minHeight: h,
                ),
                icon: Icon(
                  Icons.close_rounded,
                  size: SalesUiScaleSettings.scaled(18),
                  color: const Color(0xFF64748B),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

enum SalesFilterDropdownSize { compact, normal, navbar }

/// Filtr dialogidagi outlined dropdown (dialog / oddiy formalar).
class SalesFilterDropdownField extends StatelessWidget {
  final String label;
  final String? value;
  final List<Map<String, dynamic>> options;
  final ValueChanged<String?> onChanged;
  final SalesFilterDropdownSize size;

  const SalesFilterDropdownField({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.size = SalesFilterDropdownSize.normal,
  });

  @override
  Widget build(BuildContext context) {
    // Navbar endi alohida `_NavChromeDropdown` — bu yerda faqat dialog/form.
    final radius = size == SalesFilterDropdownSize.compact ? 8.0 : 14.0;
    final labelSize = size == SalesFilterDropdownSize.compact
        ? SalesUiScaleSettings.scaled(12)
        : SalesUiScaleSettings.scaled(14);
    final padV = size == SalesFilterDropdownSize.compact
        ? SalesUiScaleSettings.scaled(10)
        : SalesUiScaleSettings.scaled(14);
    final padH = SalesUiScaleSettings.scaled(12);

    final items = <DropdownMenuItem<String?>>[
      DropdownMenuItem(
        value: null,
        child: _FilterDropdownLabel('Hammasi', size: size),
      ),
      ...options.map(
        (o) => DropdownMenuItem(
          value: o['id']?.toString(),
          child: _FilterDropdownLabel((o['name'] ?? '').toString(), size: size),
        ),
      ),
    ];

    return DropdownButtonFormField<String?>(
      value: _safeValue(value, options),
      isExpanded: true,
      menuMaxHeight: SalesUiScaleSettings.scaled(48 * 4),
      icon: Icon(
        Icons.arrow_drop_down_rounded,
        size: SalesUiScaleSettings.scaled(24),
        color: const Color(0xFF64748B),
      ),
      borderRadius: BorderRadius.circular(radius),
      decoration: InputDecoration(
        labelText: label,
        floatingLabelStyle: TextStyle(
          color: const Color(0xFF64748B),
          fontWeight: FontWeight.w600,
          fontSize: labelSize,
        ),
        labelStyle: TextStyle(
          color: const Color(0xFF64748B),
          fontWeight: FontWeight.w600,
          fontSize: labelSize,
        ),
        filled: true,
        fillColor: Colors.white,
        isDense: size == SalesFilterDropdownSize.compact,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: Color(0xFFDDE5F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: Color(0xFFDDE5F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
      ),
      style: TextStyle(
        fontSize: size == SalesFilterDropdownSize.compact
            ? SalesUiScaleSettings.scaled(13)
            : SalesUiScaleSettings.scaled(15),
        fontWeight: FontWeight.w700,
        color: const Color(0xFF0F172A),
        height: 1.2,
      ),
      items: items,
      onChanged: onChanged,
    );
  }

  String? _safeValue(String? current, List<Map<String, dynamic>> opts) {
    if (current == null) return null;
    final ids = opts.map((e) => e['id']?.toString()).toSet();
    return ids.contains(current) ? current : null;
  }
}

class _FilterDropdownLabel extends StatelessWidget {
  final String text;
  final SalesFilterDropdownSize size;

  const _FilterDropdownLabel(this.text, {this.size = SalesFilterDropdownSize.normal});

  @override
  Widget build(BuildContext context) {
    final fontSize = size == SalesFilterDropdownSize.compact
        ? SalesUiScaleSettings.scaled(14)
        : SalesUiScaleSettings.scaled(16);
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w500,
        color: AppTheme.textPrimary,
      ),
    );
  }
}

/// Qo'shimcha filtr (qoldiq, narx) faolmi.
bool salesAdvancedFiltersActive(SalesSessionProvider sales) {
  return sales.hideZeroStock ||
      sales.sellAtWholesalePrice ||
      sales.sellAtPurchasePrice ||
      sales.showPurchasePrice ||
      sales.showUsdEquivalent;
}
