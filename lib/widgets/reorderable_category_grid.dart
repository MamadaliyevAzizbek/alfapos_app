import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'category_image_cover.dart';

/// Restoran rejimi: kategoriyalarni uzoq bosib sudrab tartiblash.
class ReorderableCategoryGrid extends StatefulWidget {
  final List<Map<String, dynamic>> categories;
  final int crossAxisCount;
  final double childAspectRatio;
  final int? Function(String categoryId)? productCount;
  final ValueChanged<String> onCategorySelected;
  final Future<void> Function(List<Map<String, dynamic>> reordered) onOrderChanged;

  const ReorderableCategoryGrid({
    super.key,
    required this.categories,
    this.crossAxisCount = 4,
    this.childAspectRatio = 1.05,
    this.productCount,
    required this.onCategorySelected,
    required this.onOrderChanged,
  });

  @override
  State<ReorderableCategoryGrid> createState() => _ReorderableCategoryGridState();
}

class _ReorderableCategoryGridState extends State<ReorderableCategoryGrid> {
  late List<Map<String, dynamic>> _items;
  bool _savingOrder = false;

  @override
  void initState() {
    super.initState();
    _items = List<Map<String, dynamic>>.from(widget.categories);
  }

  @override
  void didUpdateWidget(covariant ReorderableCategoryGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameCategoryIds(oldWidget.categories, widget.categories)) {
      _items = List<Map<String, dynamic>>.from(widget.categories);
    }
  }

  bool _sameCategoryIds(List<Map<String, dynamic>> a, List<Map<String, dynamic>> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i]['id']?.toString() != b[i]['id']?.toString()) return false;
    }
    return true;
  }

  Future<void> _reorder(int from, int to) async {
    if (from == to || _savingOrder) return;
    setState(() {
      final moved = _items.removeAt(from);
      _items.insert(to, moved);
      _savingOrder = true;
    });
    try {
      await widget.onOrderChanged(List<Map<String, dynamic>>.from(_items));
    } finally {
      if (mounted) setState(() => _savingOrder = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) {
      return const Center(
        child: Text(
          'Kategoriya topilmadi',
          style: TextStyle(fontSize: 16, color: AppTheme.textSecondary),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: Row(
            children: [
              const Icon(Icons.touch_app_rounded, size: 16, color: AppTheme.textSecondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _savingOrder
                      ? 'Tartib saqlanmoqda...'
                      : 'Tartibni o‘zgartirish: kategoriyani bosib turing va sudrang',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.3),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final spacing = 12.0;
              final cols = widget.crossAxisCount;
              final cellWidth =
                  (constraints.maxWidth - spacing * (cols - 1) - 24) / cols;
              final cellHeight = cellWidth / widget.childAspectRatio;

              return GridView.builder(
                key: ValueKey(_items.map((e) => e['id']).join(',')),
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  mainAxisSpacing: spacing,
                  crossAxisSpacing: spacing,
                  childAspectRatio: widget.childAspectRatio,
                ),
                itemCount: _items.length,
                itemBuilder: (context, index) {
                  final cat = _items[index];
                  final id = cat['id']!.toString();
                  final name = cat['name']?.toString().trim() ?? 'Kategoriya';
                  final count = widget.productCount?.call(id);
                  final card = _CategoryCard(
                    name: name,
                    imageUrl: cat['imageUrl']?.toString(),
                    productCount: count,
                    onTap: () => widget.onCategorySelected(id),
                  );

                  return LongPressDraggable<int>(
                    data: index,
                    delay: const Duration(milliseconds: 280),
                    feedback: Material(
                      color: Colors.transparent,
                      child: SizedBox(
                        width: cellWidth,
                        height: cellHeight,
                        child: _CategoryCard(
                          name: name,
                          imageUrl: cat['imageUrl']?.toString(),
                          productCount: count,
                          onTap: () {},
                          elevated: true,
                        ),
                      ),
                    ),
                    childWhenDragging: Opacity(opacity: 0.28, child: card),
                    child: DragTarget<int>(
                      onWillAcceptWithDetails: (d) => d.data != index,
                      onAcceptWithDetails: (d) => _reorder(d.data, index),
                      builder: (context, candidate, rejected) {
                        final active = candidate.isNotEmpty;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 120),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: active ? AppTheme.primary : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: card,
                        );
                      },
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final String name;
  final String? imageUrl;
  final int? productCount;
  final VoidCallback onTap;
  final bool elevated;

  const _CategoryCard({
    required this.name,
    this.imageUrl,
    this.productCount,
    required this.onTap,
    this.elevated = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: elevated ? 8 : 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppTheme.divider),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return CategoryImageCover.build(
                    imageUrl,
                    width: constraints.maxWidth,
                    height: constraints.maxHeight,
                    fallbackIcon: Icons.restaurant_menu_rounded,
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  if (productCount != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '$productCount ta',
                      style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
