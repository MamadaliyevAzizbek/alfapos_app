import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../providers/sales_session_provider.dart';
import '../../services/sales_stock_limit_settings.dart';
import '../../utils/platform_layout.dart';
import '../../widgets/ios_style_modals.dart';
import '../../widgets/pos_modal_actions.dart';
import 'sales_nav_filters.dart';

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
  late bool _enforceStockLimit;
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
    _enforceStockLimit = SalesStockLimitSettings.enabled.value;
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
    unawaited(SalesStockLimitSettings.setEnabled(_enforceStockLimit));
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
    unawaited(SalesStockLimitSettings.setEnabled(_enforceStockLimit));
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
    final form = _buildForm();
    final actions = _buildActions();

    if (widget.compactActions) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: form),
          const Divider(height: 1),
          actions,
        ],
      );
    }

    return Align(
      alignment: Alignment.centerRight,
      child: SafeArea(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 560,
            height: double.infinity,
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(left: BorderSide(color: Color(0xFFE2E8F0))),
              boxShadow: [
                BoxShadow(
                  color: Color(0x2E0F172A),
                  blurRadius: 28,
                  offset: Offset(-8, 0),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 18, 12, 16),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF2FF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(Icons.tune_rounded, size: 24, color: AppTheme.primary),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Filtr',
                          style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                        ),
                      ),
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F6FB),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: IconButton(
                          onPressed: () => Navigator.pop(context, false),
                          icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
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
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      controller: widget.scrollController,
      padding: EdgeInsets.fromLTRB(22, 4, 22, widget.compactActions ? 12 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_loadingLists)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                ),
              ),
            ),
          if (isDesktopPosLayout) ...[
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                'Kategoriya va brend — yuqori panelda (kassa nomi yonida).',
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.35),
              ),
            ),
          ],
          _FilterSection(
            desktop: !widget.compactActions,
            child: Column(
              children: [
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
                  label: 'Omborda yetarli bo‘lmaganda sotmaslik',
                  value: _enforceStockLimit,
                  onChanged: (v) => setState(() {
                    _enforceStockLimit = v;
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
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
      child: Row(
        children: [
          OutlinedButton(
            onPressed: _clearAndApply,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(180, 58),
              foregroundColor: const Color(0xFFDC2626),
              backgroundColor: Colors.white,
              side: const BorderSide(color: Color(0xFFF87171), width: 1.4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
              textStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            child: const Text('Tozalash'),
          ),
        ],
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
    final row = Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: desktop ? 22 : 16,
              color: AppTheme.textPrimary,
              fontWeight: desktop ? FontWeight.w500 : FontWeight.w400,
            ),
          ),
        ),
        CupertinoSwitch(
          value: value,
          onChanged: onChanged,
        ),
      ],
    );

    if (!desktop) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: row,
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 22,
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Transform.scale(
            scale: 1.28,
            child: CupertinoSwitch(
              value: value,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: child,
    );
  }
}
