import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../providers/clients_provider.dart';
import '../providers/sales_session_provider.dart';
import '../services/sales_ui_scale_settings.dart';
import 'customer_debt_balance_badge.dart';
import 'sales_pos_search_field.dart';
import 'sales_shortcut_key_badge.dart';

/// Sotuv paneli: mijozlarni API orqali qidirish (POST /sales/customers).
class SalesCustomerSearch extends StatefulWidget {
  final Client? selected;
  final ValueChanged<Client?> onSelected;
  final VoidCallback onAddNew;
  /// Desktop tezkor kirim/chiqim: kattaroq qator balandligi va tugmalar.
  final bool largeButtons;
  /// POS savatcha: faqat «+» tugmasi (matnsiz).
  final bool iconOnlyAddButton;
  /// Desktop sotuv: o‘tkir burchaklar (border-radius yo‘q).
  final bool sharpCorners;
  /// Tashqi fokus (masalan F2 tezkor klavish).
  final FocusNode? searchFocusNode;
  /// Tezkor klavish belgisi (masalan F2).
  final String? shortcutKeyLabel;
  /// Urg‘u rangi — qaytarish rejimida to‘q sariq.
  final Color accentColor;

  const SalesCustomerSearch({
    super.key,
    this.selected,
    required this.onSelected,
    required this.onAddNew,
    this.largeButtons = false,
    this.iconOnlyAddButton = false,
    this.sharpCorners = false,
    this.searchFocusNode,
    this.shortcutKeyLabel,
    this.accentColor = AppTheme.primary,
  });

  @override
  State<SalesCustomerSearch> createState() => _SalesCustomerSearchState();
}

class _SalesCustomerSearchState extends State<SalesCustomerSearch> {
  /// Desktop POS/tezkor: scale; mobile: fixed (desktop zoom mobilni buzmasin).
  bool get _desktopChrome =>
      widget.iconOnlyAddButton || widget.largeButtons || widget.sharpCorners;

  double _sz(double base) =>
      _desktopChrome ? SalesUiScaleSettings.scaled(base) : base;

  double get _fieldHeight {
    if (widget.largeButtons) return _sz(52);
    if (widget.iconOnlyAddButton) return SalesPosSearchField.height;
    return 48;
  }

  final _controller = TextEditingController();
  FocusNode? _ownedFocus;
  Timer? _debounce;

  FocusNode get _focus => widget.searchFocusNode ?? _ownedFocus!;
  List<Client> _results = [];
  bool _loading = false;
  bool _showList = false;
  int? _hoverIndex;

  @override
  void initState() {
    super.initState();
    if (widget.searchFocusNode == null) {
      _ownedFocus = FocusNode();
    }
    _focus.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(covariant SalesCustomerSearch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchFocusNode != widget.searchFocusNode) {
      oldWidget.searchFocusNode?.removeListener(_onFocusChanged);
      _ownedFocus?.removeListener(_onFocusChanged);
      _focus.addListener(_onFocusChanged);
    }
    if (widget.selected == null && oldWidget.selected != null) {
      _controller.clear();
      _hideResults();
    }
    if (widget.selected?.id != oldWidget.selected?.id && widget.selected == null) {
      _controller.clear();
      _hideResults();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _focus.removeListener(_onFocusChanged);
    _controller.dispose();
    _ownedFocus?.dispose();
    super.dispose();
  }

  bool _picking = false;

  void _onFocusChanged() {
    if (!_focus.hasFocus) {
      Future<void>.delayed(const Duration(milliseconds: 220), () {
        if (!mounted || _focus.hasFocus || _picking) return;
        _hideResults();
      });
    } else if (_results.isNotEmpty) {
      setState(() => _showList = true);
    }
  }

  void _hideResults() {
    if (!_showList && _hoverIndex == null) return;
    setState(() {
      _showList = false;
      _hoverIndex = null;
    });
  }

  void _search(String q) {
    _debounce?.cancel();
    if (q.trim().length < 2) {
      setState(() {
        _results = [];
        _loading = false;
        _showList = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 550), () async {
      setState(() => _loading = true);
      final list = await SalesSessionProvider.instance.searchCustomers(q);
      if (!mounted) return;
      setState(() {
        _results = list;
        _loading = false;
        _showList = list.isNotEmpty;
        _hoverIndex = null;
      });
    });
  }

  void _pick(Client c) {
    _picking = true;
    _controller.clear();
    setState(() {
      _showList = false;
      _results = [];
      _hoverIndex = null;
    });
    widget.onSelected(c);
    // Fokusni keyinroq yopamiz — hide race bo‘lmasin.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _picking = false;
      if (mounted) _focus.unfocus();
    });
  }

  /// Test: natijalar paneli ochish (API yo‘q).
  @visibleForTesting
  void debugShowResults(List<Client> clients) {
    setState(() {
      _results = List<Client>.from(clients);
      _showList = clients.isNotEmpty;
      _hoverIndex = null;
      _loading = false;
    });
  }

  void _clear() {
    _controller.clear();
    widget.onSelected(null);
    setState(() {
      _results = [];
      _showList = false;
      _hoverIndex = null;
    });
  }

  BorderRadius get _cornerRadius =>
      widget.sharpCorners ? BorderRadius.zero : BorderRadius.circular(SalesUiScaleSettings.scaled(8));

  Widget _buildResultsPanel() {
    return TextFieldTapRegion(
      child: Material(
        key: const ValueKey('customer-search-results'),
        elevation: 12,
        shadowColor: Colors.black38,
        color: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: SalesPosSearchField.radius,
          side: BorderSide(color: SalesPosSearchField.borderColor),
        ),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: SalesUiScaleSettings.scaled(180)),
          child: ListView.separated(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            // Dropdown ichida scroll fokusni o‘g‘irlamasin.
            primary: false,
            itemCount: _results.length,
            separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.divider),
            itemBuilder: (context, i) {
              final c = _results[i];
              final highlighted = _hoverIndex == i;
              return MouseRegion(
                onEnter: (_) => setState(() => _hoverIndex = i),
                onExit: (_) {
                  if (_hoverIndex == i) setState(() => _hoverIndex = null);
                },
                child: Material(
                  color: highlighted ? AppTheme.primaryLight : Colors.white,
                  child: InkWell(
                    onTap: () => _pick(c),
                    onTapDown: (_) {
                      _picking = true;
                    },
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: _sz(12),
                        vertical: _sz(8),
                      ),
                      child: _CustomerResultRow(
                        client: c,
                        compact: true,
                        useDesktopScale: _desktopChrome,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// POS: dropdown faqat input kengligida; + tugmasidan mustaqil.
  Widget _buildPosToolbar() {
    final h = SalesPosSearchField.height;
    final gap = SalesUiScaleSettings.navbarGap();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: h,
                child: SalesPosSearchField(
                  controller: _controller,
                  focusNode: _focus,
                  hintText: 'Mijozlarni qidirish',
                  prefixIcon: Icons.person_search_rounded,
                  onChanged: (q) {
                    setState(() {});
                    _search(q);
                  },
                  shortcutKeyLabel: widget.shortcutKeyLabel,
                  loading: _loading,
                ),
              ),
              if (_showList && _results.isNotEmpty) ...[
                SizedBox(height: SalesUiScaleSettings.scaled(4)),
                // Input bilan bir xil kenglik (Expanded Column stretch).
                _buildResultsPanel(),
              ],
            ],
          ),
        ),
        SizedBox(width: gap),
        SizedBox(
          width: h,
          height: h,
          child: FilledButton(
            onPressed: widget.onAddNew,
            style: FilledButton.styleFrom(
              backgroundColor: widget.accentColor,
              padding: EdgeInsets.zero,
              minimumSize: Size(h, h),
              shape: const RoundedRectangleBorder(
                borderRadius: SalesPosSearchField.radius,
              ),
              elevation: 0,
            ),
            child: Icon(
              Icons.person_add_alt_1_rounded,
              size: SalesUiScaleSettings.scaled(20),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    if (selected != null) {
      return _SelectedCustomerCard(
        client: selected,
        onClear: _clear,
        borderRadius: widget.iconOnlyAddButton
            ? SalesPosSearchField.radius
            : _cornerRadius,
        compact: widget.sharpCorners || widget.iconOnlyAddButton,
        fixedHeight: widget.iconOnlyAddButton ? SalesPosSearchField.height : null,
        useDesktopScale: _desktopChrome,
      );
    }

    if (widget.iconOnlyAddButton) {
      return _buildPosToolbar();
    }

    final fieldFill = widget.sharpCorners ? Colors.white : const Color(0xFFF0F2F5);
    final fieldBorder = widget.sharpCorners
        ? const BorderSide(color: Color(0xFFDDE5F0))
        : BorderSide.none;
    final gap = _sz(8);
    final iconSize = _sz(widget.largeButtons ? 22 : 20);
    final fontSize = _sz(14);
    final cornerRadius = _cornerRadius;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: SizedBox(
                height: _fieldHeight,
                child: SalesFieldShortcutOverlay(
                  keyLabel: widget.shortcutKeyLabel,
                  visible: !_loading && _controller.text.isEmpty,
                  child: TextField(
                    controller: _controller,
                    focusNode: _focus,
                    onChanged: _search,
                    onTap: () {
                      if (_controller.text.trim().length >= 2) {
                        _search(_controller.text);
                      }
                    },
                    style: TextStyle(fontSize: fontSize, height: 1.2),
                    decoration: InputDecoration(
                      hintText: 'Mijozlarni qidirish',
                      hintStyle: TextStyle(
                        fontSize: fontSize,
                        color: AppTheme.textSecondary,
                      ),
                      filled: true,
                      fillColor: fieldFill,
                      isDense: true,
                      prefixIcon: Icon(
                        Icons.person_search_rounded,
                        color: AppTheme.textSecondary,
                        size: _sz(20),
                      ),
                      suffixIcon: _loading
                          ? Padding(
                              padding: EdgeInsets.all(_sz(12)),
                              child: SizedBox(
                                width: _sz(16),
                                height: _sz(16),
                                child: const CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : _controller.text.isNotEmpty
                              ? IconButton(
                                  icon: Icon(
                                    Icons.close_rounded,
                                    size: _sz(18),
                                  ),
                                  onPressed: () {
                                    _controller.clear();
                                    setState(() {
                                      _results = [];
                                      _showList = false;
                                    });
                                  },
                                  tooltip: 'Qidiruvni tozalash',
                                )
                              : null,
                      border: OutlineInputBorder(
                        borderRadius: cornerRadius,
                        borderSide: fieldBorder,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: cornerRadius,
                        borderSide: fieldBorder,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: cornerRadius,
                        borderSide: BorderSide(
                          color: widget.accentColor,
                          width: _sz(1.5).clamp(1.0, 2.0),
                        ),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: _sz(12),
                        vertical: _sz(12),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(width: gap),
            SizedBox(
              height: _fieldHeight,
              child: FilledButton.icon(
                onPressed: widget.onAddNew,
                icon: Icon(Icons.person_add_alt_1_rounded, size: iconSize),
                label: Text(
                  'Yangi mijoz',
                  style: TextStyle(
                    fontSize: _sz(widget.largeButtons ? 15 : 13),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: widget.accentColor,
                  padding: EdgeInsets.symmetric(
                    horizontal: _sz(widget.largeButtons ? 18 : 12),
                  ),
                  minimumSize: widget.largeButtons ? Size(0, _sz(52)) : null,
                  shape: RoundedRectangleBorder(borderRadius: cornerRadius),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
        if (_showList && _results.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(top: _sz(4)),
            child: _buildResultsPanel(),
          ),
      ],
    );
  }
}

class _CustomerResultRow extends StatelessWidget {
  final Client client;
  final bool compact;
  final bool useDesktopScale;

  const _CustomerResultRow({
    required this.client,
    this.compact = false,
    this.useDesktopScale = false,
  });

  double _sz(double base) =>
      useDesktopScale ? SalesUiScaleSettings.scaled(base) : base;

  @override
  Widget build(BuildContext context) {
    final nameSize = _sz(compact ? 13 : 14);
    final phoneSize = _sz(12);
    final hasPhone = client.phone != null && client.phone!.isNotEmpty;
    final hasBadge = CustomerDebtBalanceBadge.debtAmount(client) > 0 ||
        CustomerDebtBalanceBadge.balanceAmount(client) > 0;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                client.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: nameSize,
                  height: 1.2,
                  color: AppTheme.textPrimary,
                ),
              ),
              if (hasPhone) ...[
                SizedBox(height: _sz(2)),
                Text(
                  client.phone!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: phoneSize,
                    height: 1.2,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (hasBadge) ...[
          SizedBox(width: _sz(8)),
          CustomerDebtBalanceBadge(client: client, compact: true),
        ],
      ],
    );
  }
}

class _SelectedCustomerCard extends StatelessWidget {
  final Client client;
  final VoidCallback onClear;
  final BorderRadius borderRadius;
  final bool compact;
  final double? fixedHeight;
  final bool useDesktopScale;

  const _SelectedCustomerCard({
    required this.client,
    required this.onClear,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
    this.compact = false,
    this.fixedHeight,
    this.useDesktopScale = false,
  });

  double _sz(double base) =>
      useDesktopScale ? SalesUiScaleSettings.scaled(base) : base;

  @override
  Widget build(BuildContext context) {
    final nameSize = _sz(compact ? 13 : 14);
    final phoneSize = _sz(12);
    final padH = _sz(compact ? 10 : 12);
    final padV = _sz(compact ? 8 : 10);
    final hasPhone = client.phone != null && client.phone!.isNotEmpty;

    return Container(
      height: fixedHeight,
      padding: EdgeInsets.fromLTRB(
        padH,
        fixedHeight != null ? 0 : padV,
        _sz(4),
        fixedHeight != null ? 0 : padV,
      ),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: AppTheme.primaryLight,
        borderRadius: borderRadius,
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.person_rounded,
            size: _sz(18),
            color: AppTheme.primary,
          ),
          SizedBox(width: _sz(8)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  client.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: nameSize,
                    height: 1.2,
                    color: AppTheme.textPrimary,
                  ),
                ),
                if (hasPhone && fixedHeight == null)
                  Text(
                    client.phone!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: phoneSize,
                      height: 1.2,
                      color: AppTheme.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          if (fixedHeight == null) CustomerDebtBalanceBadge(client: client, compact: true),
          IconButton(
            onPressed: onClear,
            visualDensity: VisualDensity.compact,
            constraints: BoxConstraints(
              minWidth: _sz(36),
              minHeight: _sz(36),
            ),
            icon: Icon(Icons.close_rounded, size: _sz(18)),
            color: AppTheme.textSecondary,
            tooltip: 'Mijozni olib tashlash',
          ),
        ],
      ),
    );
  }
}
