import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../providers/sales_session_provider.dart';
import '../../services/sales_ui_scale_settings.dart';
import '../../utils/platform_layout.dart';
import '../../widgets/ios_style_modals.dart';
import '../../widgets/pos_modal_actions.dart';

/// Sotuv filtri — kategoriya, brend, qoldiq, narx rejimi.
class SalesFilterDialog extends StatefulWidget {
  /// Mobil pastki varaq: tugmalar ustma-ust.
  final bool compactActions;
  final ScrollController? scrollController;

  static const double _menuItemHeight = 48;
  static const int _visibleMenuItems = 4;
  static double get menuMaxHeight => _menuItemHeight * _visibleMenuItems;

  static Future<bool?> show(BuildContext context) {
    if (isDesktopPosLayout) {
      return showGeneralDialog<bool>(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'Filtr',
        barrierColor: Colors.black38,
        transitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (_, __, ___) => const Align(
          alignment: Alignment.centerRight,
          child: SalesFilterDialog(),
        ),
        transitionBuilder: (context, animation, _, child) {
          final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
          return SlideTransition(
            position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(curved),
            child: child,
          );
        },
      );
    }
    return _showMobileSheet(context);
  }

  static Future<bool?> _showMobileSheet(BuildContext context) {
    return IosStyleModals.showDraggableSheet<bool>(
      context: context,
      initialChildSize: 0.72,
      minChildSize: 0.4,
      maxChildSize: 0.88,
      header: Column(
        children: [
          const SizedBox(height: 10),
          IosStyleModals.grabber(),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 4, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Filtr',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      builder: (_, scrollController) => SalesFilterDialog(
        compactActions: true,
        scrollController: scrollController,
      ),
    );
  }

  const SalesFilterDialog({
    super.key,
    this.compactActions = false,
    this.scrollController,
  });

  @override
  State<SalesFilterDialog> createState() => _SalesFilterDialogState();
}

class _SalesFilterDialogState extends State<SalesFilterDialog> {
  late String? _categoryId;
  late String? _brandId;
  late bool _hideZeroStock;
  late bool _sellAtWholesale;
  late bool _sellAtPurchase;
  late bool _showPurchasePrice;
  late bool _showUsdEquivalent;
  bool _loadingLists = false;

  SalesSessionProvider get _sales => SalesSessionProvider.instance;

  @override
  void initState() {
    super.initState();
    _categoryId = _sales.categoryId;
    _brandId = _sales.brandId;
    _hideZeroStock = _sales.hideZeroStock;
    _sellAtWholesale = _sales.sellAtWholesalePrice;
    _sellAtPurchase = _sales.sellAtPurchasePrice;
    _showPurchasePrice = _sales.showPurchasePrice;
    _showUsdEquivalent = _sales.showUsdEquivalent;
    if (isDesktopPosLayout && (_sales.categories.isEmpty || _sales.brands.isEmpty)) {
      unawaited(_reloadLists());
    }
  }

  Future<void> _reloadLists() async {
    setState(() => _loadingLists = true);
    await _sales.reloadFilterLists();
    if (mounted) setState(() => _loadingLists = false);
  }

  void _reset() {
    setState(() {
      _categoryId = null;
      _brandId = null;
      _hideZeroStock = false;
      _sellAtWholesale = false;
      _sellAtPurchase = false;
      _showPurchasePrice = false;
      _showUsdEquivalent = false;
    });
  }

  void _clearAndApply() {
    _reset();
    _applyLive();
  }

  void _apply() {
    final cat = isDesktopPosLayout ? _categoryId : null;
    final brand = isDesktopPosLayout ? _brandId : null;
    unawaited(_sales.applySalesFilters(
      category: cat,
      brand: brand,
      hideZero: _hideZeroStock,
      sellWholesale: _sellAtWholesale,
      sellPurchase: _sellAtPurchase,
      showPurchaseOnCards: _showPurchasePrice,
      showUsdOnCards: _showUsdEquivalent,
    ));
    Navigator.pop(context, true);
  }

  void _applyLive() {
    final cat = isDesktopPosLayout ? _categoryId : null;
    final brand = isDesktopPosLayout ? _brandId : null;
    unawaited(_sales.applySalesFilters(
      category: cat,
      brand: brand,
      hideZero: _hideZeroStock,
      sellWholesale: _sellAtWholesale,
      sellPurchase: _sellAtPurchase,
      showPurchaseOnCards: _showPurchasePrice,
      showUsdOnCards: _showUsdEquivalent,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: SalesUiScaleSettings.scale,
      builder: (context, scale, _) {
        final form = _buildForm();
        final actions = _buildActions();

        if (widget.compactActions) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: SalesUiScaleSettings.textScaler(scale)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: form),
                const Divider(height: 1),
                actions,
              ],
            ),
          );
        }

        return Align(
          alignment: Alignment.centerRight,
          child: SafeArea(
            child: Material(
              color: Colors.transparent,
              child: MediaQuery(
                data: MediaQuery.of(context).copyWith(textScaler: SalesUiScaleSettings.textScaler(scale)),
                child: Container(
                  width: SalesUiScaleSettings.chromeScaled(480),
                  height: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(left: BorderSide(color: const Color(0xFFE2E8F0), width: SalesUiScaleSettings.chromeScaled(1))),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0x2E0F172A),
                        blurRadius: SalesUiScaleSettings.chromeScaled(28),
                        offset: Offset(SalesUiScaleSettings.chromeScaled(-8), 0),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          SalesUiScaleSettings.chromeScaled(24),
                          SalesUiScaleSettings.chromeScaled(18),
                          SalesUiScaleSettings.chromeScaled(12),
                          SalesUiScaleSettings.chromeScaled(16),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: SalesUiScaleSettings.chromeScaled(42),
                              height: SalesUiScaleSettings.chromeScaled(42),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEAF2FF),
                                borderRadius: BorderRadius.circular(SalesUiScaleSettings.chromeScaled(12)),
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                Icons.tune_rounded,
                                size: SalesUiScaleSettings.chromeScaled(24),
                                color: AppTheme.primary,
                              ),
                            ),
                            SizedBox(width: SalesUiScaleSettings.chromeScaled(10)),
                            Expanded(
                              child: Text(
                                'Filtr',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ),
                            Container(
                              width: SalesUiScaleSettings.chromeScaled(44),
                              height: SalesUiScaleSettings.chromeScaled(44),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3F6FB),
                                borderRadius: BorderRadius.circular(SalesUiScaleSettings.chromeScaled(22)),
                              ),
                              child: IconButton(
                                onPressed: () => Navigator.pop(context, false),
                                icon: Icon(
                                  Icons.close_rounded,
                                  color: const Color(0xFF64748B),
                                  size: SalesUiScaleSettings.chromeScaled(24),
                                ),
                                padding: EdgeInsets.zero,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1, color: Color(0xFFE2E8F0)),
                      Expanded(child: form),
                      const Divider(height: 1, color: Color(0xFFE2E8F0)),
                      actions,
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

  Widget _buildForm() {
    final edgePad = SalesUiScaleSettings.chromeScaled(22);
    final bottomPad = SalesUiScaleSettings.chromeScaled(widget.compactActions ? 12 : 16);

    return SingleChildScrollView(
      controller: widget.scrollController,
      padding: EdgeInsets.fromLTRB(edgePad, SalesUiScaleSettings.chromeScaled(4), edgePad, bottomPad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_loadingLists)
            Padding(
              padding: EdgeInsets.symmetric(vertical: SalesUiScaleSettings.chromeScaled(8)),
              child: Center(
                child: SizedBox(
                  width: SalesUiScaleSettings.chromeScaled(22),
                  height: SalesUiScaleSettings.chromeScaled(22),
                  child: const CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                ),
              ),
            ),
          if (isDesktopPosLayout) ...[
            Padding(
              padding: EdgeInsets.only(bottom: SalesUiScaleSettings.chromeScaled(12)),
              child: Text(
                'Kategoriya va brend — yuqori panelda (kassa nomi yonida).',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                  height: 1.35,
                ),
              ),
            ),
          ],
          _FilterSection(
            desktop: !widget.compactActions,
            child: Column(
              children: [
                _FilterZoomControl(desktop: !widget.compactActions),
                _FilterToggle(
                  label: '0 qoldiqni yashirish',
                  value: _hideZeroStock,
                  onChanged: (v) => setState(() {
                    _hideZeroStock = v;
                    if (!widget.compactActions) _applyLive();
                  }),
                  desktop: !widget.compactActions,
                ),
                _FilterToggle(
                  label: 'Ulgurji narx',
                  value: _sellAtWholesale,
                  onChanged: (v) => setState(() {
                    _sellAtWholesale = v;
                    if (v) _sellAtPurchase = false;
                    if (!widget.compactActions) _applyLive();
                  }),
                  desktop: !widget.compactActions,
                ),
                _FilterToggle(
                  label: 'Kelish narx',
                  value: _sellAtPurchase,
                  onChanged: (v) => setState(() {
                    _sellAtPurchase = v;
                    if (v) _sellAtWholesale = false;
                    if (!widget.compactActions) _applyLive();
                  }),
                  desktop: !widget.compactActions,
                ),
                _FilterToggle(
                  label: "Kelish narxini ko'rsatish",
                  value: _showPurchasePrice,
                  onChanged: (v) => setState(() {
                    _showPurchasePrice = v;
                    if (!widget.compactActions) _applyLive();
                  }),
                  desktop: !widget.compactActions,
                ),
                _FilterToggle(
                  label: 'Dollar ekvivalentini ko\'rsatish (\$)',
                  value: _showUsdEquivalent,
                  onChanged: (v) => setState(() {
                    _showUsdEquivalent = v;
                    if (!widget.compactActions) _applyLive();
                  }),
                  desktop: !widget.compactActions,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    if (widget.compactActions) {
      return PosModalActions(
        onSave: _apply,
        onCancel: () => Navigator.pop(context, false),
        onClear: _clearAndApply,
      );
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(
        SalesUiScaleSettings.chromeScaled(22),
        SalesUiScaleSettings.chromeScaled(18),
        SalesUiScaleSettings.chromeScaled(22),
        SalesUiScaleSettings.chromeScaled(22),
      ),
      child: Row(
        children: [
          OutlinedButton(
            onPressed: _clearAndApply,
            style: OutlinedButton.styleFrom(
              minimumSize: Size(SalesUiScaleSettings.chromeScaled(150), SalesUiScaleSettings.chromeScaled(48)),
              foregroundColor: const Color(0xFFDC2626),
              backgroundColor: Colors.white,
              side: BorderSide(color: const Color(0xFFF87171), width: SalesUiScaleSettings.chromeScaled(1.4)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: const Text('Tozalash'),
          ),
        ],
      ),
    );
  }
}

class _FilterZoomControl extends StatelessWidget {
  final bool desktop;

  const _FilterZoomControl({required this.desktop});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: SalesUiScaleSettings.scale,
      builder: (context, scale, _) {
        final labelStyle = TextStyle(
          fontSize: desktop ? 16 : 14,
          color: AppTheme.textPrimary,
          fontWeight: desktop ? FontWeight.w500 : FontWeight.w400,
        );
        final percentStyle = TextStyle(
          fontSize: desktop ? 17 : 14,
          fontWeight: FontWeight.w700,
          color: AppTheme.primary,
          fontFeatures: const [FontFeature.tabularFigures()],
        );

        final controls = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ZoomStepButton(
              icon: Icons.remove_rounded,
              enabled: SalesUiScaleSettings.canZoomOut,
              onTap: () => unawaited(SalesUiScaleSettings.zoomOut()),
              desktop: desktop,
            ),
            SizedBox(width: SalesUiScaleSettings.chromeScaled(desktop ? 14 : 10)),
            SizedBox(
              width: SalesUiScaleSettings.chromeScaled(desktop ? 72 : 56),
              child: Text(
                SalesUiScaleSettings.percentLabel(scale),
                textAlign: TextAlign.center,
                style: percentStyle,
              ),
            ),
            SizedBox(width: SalesUiScaleSettings.chromeScaled(desktop ? 14 : 10)),
            _ZoomStepButton(
              icon: Icons.add_rounded,
              enabled: SalesUiScaleSettings.canZoomIn,
              onTap: () => unawaited(SalesUiScaleSettings.zoomIn()),
              desktop: desktop,
            ),
          ],
        );

        if (!desktop) {
          return Padding(
            padding: EdgeInsets.only(bottom: SalesUiScaleSettings.chromeScaled(12)),
            child: Row(
              children: [
                Expanded(child: Text('Masshtab', style: labelStyle)),
                controls,
              ],
            ),
          );
        }

        return Container(
          margin: EdgeInsets.only(bottom: SalesUiScaleSettings.chromeScaled(10)),
          padding: EdgeInsets.symmetric(
            horizontal: SalesUiScaleSettings.chromeScaled(14),
            vertical: SalesUiScaleSettings.chromeScaled(12),
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(SalesUiScaleSettings.chromeScaled(14)),
            border: Border.all(color: const Color(0xFFE2E8F0), width: SalesUiScaleSettings.chromeScaled(1)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text('Masshtab', style: labelStyle),
              ),
              controls,
            ],
          ),
        );
      },
    );
  }
}

class _ZoomStepButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  final bool desktop;

  const _ZoomStepButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
    required this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    final size = SalesUiScaleSettings.chromeScaled(desktop ? 40.0 : 36.0);
    final iconSize = SalesUiScaleSettings.chromeScaled(desktop ? 22.0 : 18.0);
    final color = enabled ? AppTheme.primary : const Color(0xFFCBD5E1);
    final radius = SalesUiScaleSettings.chromeScaled(12);

    return Material(
      color: const Color(0xFFF8FAFC),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: BorderSide(
          color: enabled ? const Color(0xFFBFDBFE) : const Color(0xFFE2E8F0),
          width: SalesUiScaleSettings.chromeScaled(1),
        ),
      ),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(radius),
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, size: iconSize, color: color),
        ),
      ),
    );
  }
}

class _FilterToggle extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool desktop;

  const _FilterToggle({
    required this.label,
    required this.value,
    required this.onChanged,
    this.desktop = false,
  });

  @override
  Widget build(BuildContext context) {
    final labelStyle = TextStyle(
      fontSize: desktop ? 16 : 14,
      color: AppTheme.textPrimary,
      fontWeight: desktop ? FontWeight.w500 : FontWeight.w400,
    );

    final row = Row(
      children: [
        Expanded(
          child: Text(label, style: labelStyle),
        ),
        Transform.scale(
          scale: 1.1 * SalesUiScaleSettings.scale.value,
          child: CupertinoSwitch(
            value: value,
            onChanged: onChanged,
          ),
        ),
      ],
    );

    if (!desktop) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: SalesUiScaleSettings.chromeScaled(10)),
        child: row,
      );
    }

    return Container(
      margin: EdgeInsets.symmetric(vertical: SalesUiScaleSettings.chromeScaled(5)),
      padding: EdgeInsets.symmetric(
        horizontal: SalesUiScaleSettings.chromeScaled(14),
        vertical: SalesUiScaleSettings.chromeScaled(12),
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(SalesUiScaleSettings.chromeScaled(14)),
        border: Border.all(color: const Color(0xFFE2E8F0), width: SalesUiScaleSettings.chromeScaled(1)),
      ),
      child: row,
    );
  }
}

class _FilterSection extends StatelessWidget {
  final Widget child;
  final bool desktop;

  const _FilterSection({
    required this.child,
    required this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    if (!desktop) return child;
    return Container(
      padding: EdgeInsets.all(SalesUiScaleSettings.chromeScaled(18)),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(SalesUiScaleSettings.chromeScaled(18)),
        border: Border.all(color: const Color(0xFFE2E8F0), width: SalesUiScaleSettings.chromeScaled(1)),
      ),
      child: child,
    );
  }
}
