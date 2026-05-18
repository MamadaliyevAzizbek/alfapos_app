import 'dart:async';

import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../providers/sales_session_provider.dart';
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
      return showDialog<bool>(
        context: context,
        barrierDismissible: true,
        barrierColor: Colors.black38,
        builder: (_) => const SalesFilterDialog(),
      );
    }
    return _showMobileSheet(context);
  }

  static Future<bool?> _showMobileSheet(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (ctx) {
        final bottom = MediaQuery.paddingOf(ctx).bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: bottom),
          child: DraggableScrollableSheet(
            initialChildSize: 0.82,
            minChildSize: 0.45,
            maxChildSize: 0.92,
            expand: false,
            builder: (_, scrollController) {
              return ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: Material(
                  color: Colors.white,
                  child: Column(
                    children: [
                      const SizedBox(height: 10),
                      IosStyleModals.grabber(),
                      const Padding(
                        padding: EdgeInsets.fromLTRB(20, 4, 12, 0),
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
                      Expanded(
                        child: SalesFilterDialog(
                          compactActions: true,
                          scrollController: scrollController,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
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
    if (_sales.categories.isEmpty || _sales.brands.isEmpty) {
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
    _apply();
  }

  void _apply() {
    _sales.applySalesFilters(
      category: _categoryId,
      brand: _brandId,
      hideZero: _hideZeroStock,
      sellWholesale: _sellAtWholesale,
      sellPurchase: _sellAtPurchase,
      showPurchaseOnCards: _showPurchasePrice,
      showUsdOnCards: _showUsdEquivalent,
    );
    Navigator.pop(context, true);
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

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 420, maxWidth: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Filtr',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context, false),
                    icon: const Icon(Icons.close_rounded, color: AppTheme.textSecondary),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                  ),
                ],
              ),
            ),
            form,
            const Divider(height: 1),
            actions,
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      controller: widget.scrollController,
      padding: EdgeInsets.fromLTRB(20, 0, 20, widget.compactActions ? 12 : 8),
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
            )
          else if (_sales.categories.isEmpty && _sales.brands.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TextButton.icon(
                onPressed: _reloadLists,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Kategoriya va brendlarni yuklash'),
              ),
            ),
          _FilterDropdown(
            label: 'Kategoriya',
            value: _categoryId,
            options: _sales.categories,
            onChanged: (v) => setState(() => _categoryId = v),
          ),
          const SizedBox(height: 12),
          _FilterDropdown(
            label: 'Brend',
            value: _brandId,
            options: _sales.brands,
            onChanged: (v) => setState(() => _brandId = v),
          ),
          const SizedBox(height: 8),
          const Divider(height: 24),
          _FilterToggle(
            label: '0 qoldiqni yashirish',
            value: _hideZeroStock,
            onChanged: (v) => setState(() => _hideZeroStock = v),
          ),
          _FilterToggle(
            label: 'Ulgurji narx',
            value: _sellAtWholesale,
            onChanged: (v) => setState(() {
              _sellAtWholesale = v;
              if (v) _sellAtPurchase = false;
            }),
          ),
          _FilterToggle(
            label: 'Kelish narx',
            value: _sellAtPurchase,
            onChanged: (v) => setState(() {
              _sellAtPurchase = v;
              if (v) _sellAtWholesale = false;
            }),
          ),
          _FilterToggle(
            label: "Kelish narxini ko'rsatish",
            value: _showPurchasePrice,
            onChanged: (v) => setState(() => _showPurchasePrice = v),
          ),
          _FilterToggle(
            label: 'Dollar ekvivalentini ko\'rsatish (\$)',
            value: _showUsdEquivalent,
            onChanged: (v) => setState(() => _showUsdEquivalent = v),
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Row(
        children: [
          OutlinedButton(
            onPressed: _clearAndApply,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFDC2626),
              backgroundColor: const Color(0xFFFEF2F2),
              side: const BorderSide(color: Color(0xFFDC2626)),
            ),
            child: const Text('Tozalash'),
          ),
          const Spacer(),
          OutlinedButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Bekor qilish'),
          ),
          const SizedBox(width: 10),
          FilledButton(
            onPressed: _apply,
            child: const Text('Saqlash'),
          ),
        ],
      ),
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  final String label;
  final String? value;
  final List<Map<String, dynamic>> options;
  final ValueChanged<String?> onChanged;

  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final items = <DropdownMenuItem<String?>>[
      const DropdownMenuItem(
        value: null,
        child: _DropdownLabel('Hammasi'),
      ),
      ...options.map(
        (o) => DropdownMenuItem(
          value: o['id']?.toString(),
          child: _DropdownLabel((o['name'] ?? '').toString()),
        ),
      ),
    ];

    return DropdownButtonFormField<String?>(
      value: _safeValue(value, options),
      isExpanded: true,
      menuMaxHeight: SalesFilterDialog.menuMaxHeight,
      borderRadius: BorderRadius.circular(8),
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppTheme.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppTheme.divider),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
      selectedItemBuilder: (context) => [
        const Align(
          alignment: AlignmentDirectional.centerStart,
          child: _DropdownLabel('Hammasi', dense: true),
        ),
        ...options.map(
          (o) => Align(
            alignment: AlignmentDirectional.centerStart,
            child: _DropdownLabel((o['name'] ?? '').toString(), dense: true),
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

class _DropdownLabel extends StatelessWidget {
  final String text;
  final bool dense;

  const _DropdownLabel(this.text, {this.dense = false});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: dense ? 14 : 15,
        fontWeight: dense ? FontWeight.w500 : FontWeight.normal,
      ),
    );
  }
}

class _FilterToggle extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _FilterToggle({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 15, color: AppTheme.textPrimary),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppTheme.primary,
          ),
        ],
      ),
    );
  }
}
