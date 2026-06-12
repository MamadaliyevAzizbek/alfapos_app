import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../providers/sales_session_provider.dart';

/// Sotuv navbar: kategoriya va brend (kassa nomi yonida, filtr dialogidagi ko‘rinish).
class SalesNavCategoryBrandFilters extends StatelessWidget {
  static const double menuMaxHeight = 48 * 4;

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

  Widget _categoryField() => SalesFilterDropdownField(
        label: 'Kategoriya',
        value: categoryId,
        options: categories,
        onChanged: onCategoryChanged,
        size: SalesFilterDropdownSize.navbar,
      );

  Widget _brandField() => SalesFilterDropdownField(
        label: 'Brend',
        value: brandId,
        options: brands,
        onChanged: onBrandChanged,
        size: SalesFilterDropdownSize.navbar,
      );

  Widget _clearButton({
    required VoidCallback onPressed,
    required String tooltip,
  }) {
    return IconButton(
      onPressed: onPressed,
      icon: const Icon(Icons.close_rounded, size: 24, color: Color(0xFF64748B)),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 40),
      tooltip: tooltip,
    );
  }

  Widget _filterWithClear({
    required Widget field,
    required bool showClear,
    required VoidCallback onClear,
    required String clearTooltip,
  }) {
    if (!showClear) return field;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: field),
        _clearButton(onPressed: onClear, tooltip: clearTooltip),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final categoryBlock = _filterWithClear(
      field: _categoryField(),
      showClear: _hasCategoryFilter,
      onClear: () => onCategoryChanged(null),
      clearTooltip: 'Kategoriyani tozalash',
    );
    final brandBlock = _filterWithClear(
      field: _brandField(),
      showClear: _hasBrandFilter,
      onClear: () => onBrandChanged(null),
      clearTooltip: 'Brendni tozalash',
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (expand) ...[
          Expanded(child: categoryBlock),
          const SizedBox(width: 16),
          Expanded(child: brandBlock),
        ] else ...[
          SizedBox(width: 180, child: categoryBlock),
          const SizedBox(width: 14),
          SizedBox(width: 170, child: brandBlock),
        ],
      ],
    );
  }
}

enum SalesFilterDropdownSize { compact, normal, navbar }

/// Filtr dialogidagi kabi outlined dropdown (navbar va dialog uchun).
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
    final radius = switch (size) {
      SalesFilterDropdownSize.compact => 8.0,
      SalesFilterDropdownSize.navbar => 12.0,
      SalesFilterDropdownSize.normal => 14.0,
    };
    final labelSize = switch (size) {
      SalesFilterDropdownSize.compact => 12.0,
      SalesFilterDropdownSize.navbar => 14.0,
      SalesFilterDropdownSize.normal => 14.0,
    };
    final padV = switch (size) {
      SalesFilterDropdownSize.compact => 10.0,
      SalesFilterDropdownSize.navbar => 16.0,
      SalesFilterDropdownSize.normal => 14.0,
    };
    final padH = switch (size) {
      SalesFilterDropdownSize.navbar => 16.0,
      _ => 12.0,
    };

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
      menuMaxHeight: SalesNavCategoryBrandFilters.menuMaxHeight,
      icon: Icon(
        Icons.arrow_drop_down_rounded,
        size: size == SalesFilterDropdownSize.navbar ? 28 : 24,
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
        fillColor: const Color(0xFFFBFDFF),
        isDense: size == SalesFilterDropdownSize.compact,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: Color(0xFFDDE5F0), width: 1.2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: Color(0xFFDDE5F0), width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: AppTheme.primary, width: 1.6),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
      ),
      style: TextStyle(
        fontSize: size == SalesFilterDropdownSize.navbar ? 20 : (size == SalesFilterDropdownSize.compact ? 13 : 15),
        fontWeight: FontWeight.w700,
        color: const Color(0xFF0F172A),
        height: 1.2,
      ),
      selectedItemBuilder: (context) => [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: _FilterDropdownLabel('Hammasi', dense: true, size: size),
        ),
        ...options.map(
          (o) => Align(
            alignment: AlignmentDirectional.centerStart,
            child: _FilterDropdownLabel(
              (o['name'] ?? '').toString(),
              dense: true,
              size: size,
            ),
          ),
        ),
      ],
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
  final bool dense;
  final SalesFilterDropdownSize size;

  const _FilterDropdownLabel(
    this.text, {
    this.dense = false,
    this.size = SalesFilterDropdownSize.normal,
  });

  @override
  Widget build(BuildContext context) {
    final fontSize = switch (size) {
      SalesFilterDropdownSize.compact => dense ? 13.0 : 14.0,
      SalesFilterDropdownSize.navbar => dense ? 20.0 : 18.0,
      SalesFilterDropdownSize.normal => dense ? 15.0 : 16.0,
    };
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: dense ? FontWeight.w700 : FontWeight.w500,
        color: dense && size == SalesFilterDropdownSize.navbar
            ? const Color(0xFF0F172A)
            : AppTheme.textPrimary,
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
