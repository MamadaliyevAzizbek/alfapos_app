import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../services/sales_ui_scale_settings.dart';

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
  static const double _radius = 0;

  bool get _addEnabled => canAddWindow && windowCount < maxWindows;

  String get _addTooltip {
    if (!canAddWindow) return 'Yangi oyna uchun savatga mahsulot qo\'shing';
    if (windowCount >= maxWindows) return 'Maksimum $maxWindows ta oyna';
    return 'Yangi sotuv oynasi';
  }

  @override
  Widget build(BuildContext context) {
    final size = SalesUiScaleSettings.navbarControlSize();
    final borderWidth = SalesUiScaleSettings.scaled(1.2);

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: _inactiveBorder, width: borderWidth),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < windowCount; i++)
            _WindowChip(
              number: i + 1,
              selected: i == activeIndex,
              onTap: () => onWindowSelected(i),
              size: size,
              showLeftDivider: i > 0,
              borderWidth: borderWidth,
            ),
          _AddWindowChip(
            enabled: _addEnabled,
            tooltip: _addTooltip,
            onTap: onAddWindow,
            size: size,
            showLeftDivider: windowCount > 0,
            borderWidth: borderWidth,
          ),
        ],
      ),
    );
  }
}

class _WindowChip extends StatelessWidget {
  final int number;
  final bool selected;
  final VoidCallback onTap;
  final double size;
  final bool showLeftDivider;
  final double borderWidth;

  const _WindowChip({
    required this.number,
    required this.selected,
    required this.onTap,
    required this.size,
    required this.showLeftDivider,
    required this.borderWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Tooltip(
          message: 'Sotuv oynasi $number',
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: selected ? SalesWindowTabs._activeBg : const Color(0xFFFBFDFF),
              border: showLeftDivider
                  ? Border(left: BorderSide(color: SalesWindowTabs._inactiveBorder, width: borderWidth))
                  : null,
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: SalesWindowTabs._activeBg.withValues(alpha: 0.15),
                        blurRadius: 0,
                        offset: Offset(0, SalesUiScaleSettings.scaled(1)),
                      ),
                    ]
                  : null,
            ),
            alignment: Alignment.center,
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
    );
  }
}

class _AddWindowChip extends StatelessWidget {
  final bool enabled;
  final String tooltip;
  final VoidCallback onTap;
  final double size;
  final bool showLeftDivider;
  final double borderWidth;

  const _AddWindowChip({
    required this.enabled,
    required this.tooltip,
    required this.onTap,
    required this.size,
    required this.showLeftDivider,
    required this.borderWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Tooltip(
          message: tooltip,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: const Color(0xFFFBFDFF),
              border: showLeftDivider
                  ? Border(left: BorderSide(color: SalesWindowTabs._inactiveBorder, width: borderWidth))
                  : null,
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.add_rounded,
              size: SalesUiScaleSettings.navbarAccentIconSize(),
              color: enabled ? SalesWindowTabs._activeBg : const Color(0xFF94A3B8),
            ),
          ),
        ),
      ),
    );
  }
}
