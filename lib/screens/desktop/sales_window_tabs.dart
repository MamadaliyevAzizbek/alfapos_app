import 'package:flutter/material.dart';
import '../../core/theme.dart';
import 'sales_nav_filters.dart';

/// Sotuv bo‘limi navbaridagi raqamli oynalar (1, 2, 3…) va «+» tugmasi.
class SalesWindowTabs extends StatelessWidget {
  final int windowCount;
  final int activeIndex;
  final ValueChanged<int> onWindowSelected;
  final VoidCallback onAddWindow;
  final bool canAddWindow;
  final int maxWindows;

  const SalesWindowTabs({
    super.key,
    required this.windowCount,
    required this.activeIndex,
    required this.onWindowSelected,
    required this.onAddWindow,
    this.canAddWindow = true,
    this.maxWindows = 12,
  });

  static const Color _activeBg = AppTheme.primary;
  static const Color _inactiveBorder = Color(0xFFDDE5F0);
  static const double _height = SalesNavCategoryBrandFilters.navbarFieldHeight;
  static const double _radius = 0;

  bool get _addEnabled => canAddWindow && windowCount < maxWindows;

  String get _addTooltip {
    if (!canAddWindow) return 'Yangi oyna uchun savatga mahsulot qo\'shing';
    if (windowCount >= maxWindows) return 'Maksimum $maxWindows ta oyna';
    return 'Yangi sotuv oynasi';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < windowCount; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          _WindowChip(
            number: i + 1,
            selected: i == activeIndex,
            onTap: () => onWindowSelected(i),
          ),
        ],
        const SizedBox(width: 8),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _addEnabled ? onAddWindow : null,
            borderRadius: BorderRadius.circular(_radius),
            child: Tooltip(
              message: _addTooltip,
              child: Container(
                width: _height,
                height: _height,
                decoration: BoxDecoration(
                  color: const Color(0xFFFBFDFF),
                  border: Border.all(
                    color: _addEnabled ? _activeBg : _inactiveBorder,
                    width: 1.2,
                  ),
                  borderRadius: BorderRadius.circular(_radius),
                ),
                child: Icon(
                  Icons.add_rounded,
                  size: 28,
                  color: _addEnabled ? _activeBg : const Color(0xFF94A3B8),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _WindowChip extends StatelessWidget {
  final int number;
  final bool selected;
  final VoidCallback onTap;

  const _WindowChip({
    required this.number,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(SalesWindowTabs._radius),
        child: Tooltip(
          message: 'Sotuv oynasi $number',
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            constraints: const BoxConstraints(
              minWidth: SalesWindowTabs._height,
              minHeight: SalesWindowTabs._height,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: selected ? SalesWindowTabs._activeBg : const Color(0xFFFBFDFF),
              border: Border.all(
                color: selected ? SalesWindowTabs._activeBg : SalesWindowTabs._inactiveBorder,
                width: 1.2,
              ),
              borderRadius: BorderRadius.circular(SalesWindowTabs._radius),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: SalesWindowTabs._activeBg.withValues(alpha: 0.15),
                        blurRadius: 0,
                        offset: const Offset(0, 1),
                      ),
                    ]
                  : null,
            ),
            alignment: Alignment.center,
            child: Text(
              '$number',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                height: 1.2,
                color: selected ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
