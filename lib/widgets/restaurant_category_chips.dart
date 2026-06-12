import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Restoran rejimi: qidiruv ostida gorizontal kategoriya tugmalari.
class RestaurantCategoryChips extends StatelessWidget {
  final List<Map<String, dynamic>> categories;
  final String? selectedCategoryId;
  final ValueChanged<String?> onCategorySelected;
  final int? Function(String categoryId)? productCount;

  const RestaurantCategoryChips({
    super.key,
    required this.categories,
    required this.selectedCategoryId,
    required this.onCategorySelected,
    this.productCount,
  });

  static const Color _chipBorder = Color(0xFFDDE5F0);
  static const double _chipHeight = 48;

  @override
  Widget build(BuildContext context) {
    final visible = categories.where((c) {
      final id = c['id']?.toString();
      if (id == null || id.isEmpty) return false;
      final count = productCount?.call(id);
      return count == null || count > 0;
    }).toList();

    return SizedBox(
      height: _chipHeight + 6,
      child: Scrollbar(
        thumbVisibility: true,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
          children: [
            _chip(
              label: 'Barcha Mahsulotlar',
              selected: selectedCategoryId == null,
              onTap: () => onCategorySelected(null),
            ),
            for (final cat in visible) ...[
              const SizedBox(width: 10),
              _chip(
                label: cat['name']?.toString().trim() ?? 'Kategoriya',
                selected: selectedCategoryId == cat['id']?.toString(),
                onTap: () => onCategorySelected(cat['id']?.toString()),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          height: _chipHeight,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppTheme.primary : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? AppTheme.primary : _chipBorder,
              width: 1.2,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: 0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
        ),
      ),
    );
  }
}
