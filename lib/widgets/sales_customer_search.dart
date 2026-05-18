import 'dart:async';

import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../providers/clients_provider.dart';
import '../providers/sales_session_provider.dart';
import 'customer_debt_balance_badge.dart';

/// Sotuv paneli: mijozlarni API orqali qidirish (POST /sales/customers).
class SalesCustomerSearch extends StatefulWidget {
  final Client? selected;
  final ValueChanged<Client?> onSelected;
  final VoidCallback onAddNew;
  /// Desktop tezkor kirim/chiqim: kattaroq qator balandligi va tugmalar.
  final bool largeButtons;

  const SalesCustomerSearch({
    super.key,
    this.selected,
    required this.onSelected,
    required this.onAddNew,
    this.largeButtons = false,
  });

  @override
  State<SalesCustomerSearch> createState() => _SalesCustomerSearchState();
}

class _SalesCustomerSearchState extends State<SalesCustomerSearch> {
  double get _fieldHeight => widget.largeButtons ? 52 : 48;

  final _controller = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;
  List<Client> _results = [];
  bool _loading = false;
  bool _showList = false;
  int? _hoverIndex;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didUpdateWidget(covariant SalesCustomerSearch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected == null && oldWidget.selected != null) {
      _controller.clear();
    }
    if (widget.selected?.id != oldWidget.selected?.id && widget.selected == null) {
      _controller.clear();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _search(String q) {
    _debounce?.cancel();
    if (q.trim().length < 2) {
      setState(() {
        _results = [];
        _showList = false;
        _loading = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () async {
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
    _controller.clear();
    _focus.unfocus();
    setState(() {
      _showList = false;
      _results = [];
      _hoverIndex = null;
    });
    widget.onSelected(c);
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

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    if (selected != null) {
      return _SelectedCustomerCard(client: selected, onClear: _clear);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SizedBox(
                height: _fieldHeight,
                child: TextField(
                  controller: _controller,
                  focusNode: _focus,
                  onChanged: _search,
                  onTap: () {
                    if (_controller.text.trim().length >= 2) _search(_controller.text);
                  },
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Mijozlarni qidirish',
                    filled: true,
                    fillColor: const Color(0xFFF0F2F5),
                    prefixIcon: const Icon(Icons.person_search_rounded, color: AppTheme.textSecondary, size: 22),
                    suffixIcon: _loading
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : _controller.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close_rounded, size: 20),
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
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppTheme.primary, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: _fieldHeight,
              child: FilledButton.icon(
                onPressed: widget.onAddNew,
                icon: Icon(Icons.person_add_alt_1_rounded, size: widget.largeButtons ? 22 : 20),
                label: Text(
                  'Yangi mijoz',
                  style: TextStyle(
                    fontSize: widget.largeButtons ? 15 : 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: FilledButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: widget.largeButtons ? 18 : 14),
                  minimumSize: widget.largeButtons ? const Size(0, 52) : null,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
        if (_showList && _results.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            constraints: const BoxConstraints(maxHeight: 240),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.divider),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: _results.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final c = _results[i];
                final highlighted = _hoverIndex == i;
                return MouseRegion(
                  onEnter: (_) => setState(() => _hoverIndex = i),
                  onExit: (_) => setState(() => _hoverIndex = null),
                  child: Material(
                    color: highlighted ? const Color(0xFF4B5563) : Colors.white,
                    child: InkWell(
                      onTap: () => _pick(c),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        child: _CustomerResultRow(
                          client: c,
                          onDark: highlighted,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _CustomerResultRow extends StatelessWidget {
  final Client client;
  final bool onDark;

  const _CustomerResultRow({required this.client, this.onDark = false});

  @override
  Widget build(BuildContext context) {
    final titleColor = onDark ? Colors.white : AppTheme.textPrimary;
    final subColor = onDark ? Colors.white70 : AppTheme.textSecondary;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                client.name,
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: titleColor),
              ),
              if (client.phone != null && client.phone!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.phone_outlined, size: 14, color: subColor),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        client.phone!,
                        style: TextStyle(fontSize: 13, color: subColor),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 6),
              CustomerDebtBalanceBadge(client: client),
            ],
          ),
        ),
      ],
    );
  }
}

class _SelectedCustomerCard extends StatelessWidget {
  final Client client;
  final VoidCallback onClear;

  const _SelectedCustomerCard({required this.client, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  client.name,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                if (client.phone != null && client.phone!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.phone_outlined, size: 15, color: AppTheme.textSecondary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          client.phone!,
                          style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                CustomerDebtBalanceBadge(client: client),
              ],
            ),
          ),
          IconButton(
            onPressed: onClear,
            icon: const Icon(Icons.close_rounded, size: 22),
            color: AppTheme.textSecondary,
            tooltip: 'Mijozni olib tashlash',
          ),
        ],
      ),
    );
  }
}
