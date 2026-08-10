import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../services/sales_ui_scale_settings.dart';

/// Sotuv navbaridagi oynalar — alohida kvadrat tugmalar (menu/sync bilan bir xil).
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
  static const Color _border = Color(0xFFDDE5F0);
  static const double _radius = 8;

  bool get _addEnabled => canAddWindow && windowCount < maxWindows;

  String get _addTooltip {
    if (!canAddWindow) return 'Yangi oyna uchun savatga mahsulot qo\'shing';
    if (windowCount >= maxWindows) return 'Maksimum $maxWindows ta oyna';
    return 'Yangi sotuv oynasi';
  }

  @override
  Widget build(BuildContext context) {
    final size = SalesUiScaleSettings.navbarControlSize();
    final gap = SalesUiScaleSettings.navbarGap();

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        for (var i = 0; i < windowCount; i++) ...[
          if (i > 0) SizedBox(width: gap),
          _WindowChip(
            number: i + 1,
            selected: i == activeIndex,
            onTap: () => onWindowSelected(i),
            size: size,
          ),
        ],
        SizedBox(width: gap),
        _AddWindowChip(
          enabled: _addEnabled,
          tooltip: _addTooltip,
          onTap: onAddWindow,
          size: size,
        ),
      ],
    );
  }
}

class _WindowChip extends StatelessWidget {
  final int number;
  final bool selected;
  final VoidCallback onTap;
  final double size;

  const _WindowChip({
    required this.number,
    required this.selected,
    required this.onTap,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Material(
        color: selected ? SalesWindowTabs._activeBg : Colors.white,
        borderRadius: BorderRadius.circular(SalesWindowTabs._radius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(SalesWindowTabs._radius),
          child: Tooltip(
            message: 'Sotuv oynasi $number',
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(SalesWindowTabs._radius),
                border: selected ? null : Border.all(color: SalesWindowTabs._border),
              ),
              child: Center(
                child: Text(
                  '$number',
                  style: TextStyle(
                    fontSize: SalesUiScaleSettings.navbarChipFontSize(),
                    fontWeight: FontWeight.w700,
                    height: 1,
                    color: selected ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AddWindowChip extends StatelessWidget {
  final bool enabled;
  final String tooltip;
  final VoidCallback onTap;
  final double size;

  const _AddWindowChip({
    required this.enabled,
    required this.tooltip,
    required this.onTap,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(SalesWindowTabs._radius),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(SalesWindowTabs._radius),
          child: Tooltip(
            message: tooltip,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(SalesWindowTabs._radius),
                border: Border.all(color: SalesWindowTabs._border),
              ),
              child: Center(
                child: Icon(
                  Icons.add_rounded,
                  size: SalesUiScaleSettings.navbarAccentIconSize(),
                  color: enabled ? SalesWindowTabs._activeBg : const Color(0xFF94A3B8),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
