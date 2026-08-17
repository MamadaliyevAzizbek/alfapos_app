import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_notify.dart';
import '../core/constants.dart';
import '../core/theme.dart';
import '../models/inventory.dart';
import '../services/api_service.dart';
import '../widgets/magnet_icon.dart';
import '../widgets/throttled_refresh_indicator.dart';
import 'scanner_screen.dart' show showCompactScanner;

/// Inventar sanash — search-products + update-quantity + save/complete.
class InventarizatsiyaCountScreen extends StatefulWidget {
  const InventarizatsiyaCountScreen({super.key, required this.document});

  final InventoryDocument document;

  @override
  State<InventarizatsiyaCountScreen> createState() =>
      _InventarizatsiyaCountScreenState();
}

class _InventarizatsiyaCountScreenState
    extends State<InventarizatsiyaCountScreen> {
  static const int _pageSize = 50;

  late InventoryDocument _doc;
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final Map<int, TextEditingController> _qtyCtrls = {};
  final Map<int, FocusNode> _qtyFocus = {};
  final Map<int, Timer> _saveDebounce = {};
  final Set<int> _savingVariants = {};
  Timer? _searchDebounce;

  /// Kech kelgan javob yangisini bosib ketmasligi uchun.
  int _requestSeq = 0;

  bool _loading = true;
  bool _hasSearchText = false;
  bool _querying = false;
  bool _loadingMore = false;
  bool _busy = false;
  bool _hasMore = false;
  String? _error;
  String _countFilter = 'all'; // all | counted | pending
  String _appliedQuery = '';
  List<InventoryProductRow> _rows = [];
  InventoryStats _stats = const InventoryStats();

  bool get _readOnly => _doc.isCompleted;

  @override
  void initState() {
    super.initState();
    _doc = widget.document;
    _scrollCtrl.addListener(_onScroll);
    _searchCtrl.addListener(() {
      final has = _searchCtrl.text.isNotEmpty;
      if (has != _hasSearchText) setState(() => _hasSearchText = has);
    });
    _bootstrap();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    for (final t in _saveDebounce.values) {
      t.cancel();
    }
    _scrollCtrl.dispose();
    _searchCtrl.dispose();
    for (final c in _qtyCtrls.values) {
      c.dispose();
    }
    for (final f in _qtyFocus.values) {
      f.dispose();
    }
    super.dispose();
  }

  // ---------------------------------------------------------------- yuklash

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Hujjatni yangilab olish (status / kategoriya).
      try {
        final detail = await InventoryApi.getDocument(_doc.id);
        final data = detail['data'];
        if (data is Map) {
          _doc = InventoryDocument.fromJson(Map<String, dynamic>.from(data));
        }
      } catch (_) {}
      await Future.wait([_loadProducts(), _loadStats()]);
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadProducts({bool more = false}) async {
    final seq = ++_requestSeq;
    final query = _searchCtrl.text.trim();
    final offset = more ? _rows.length : 0;

    final res = await InventoryApi.searchProducts(
      inventoryId: _doc.id,
      searchValue: query,
      countFilter: _countFilter,
      categoryId: _doc.categoryId,
      rowLimit: _pageSize,
      rowOffset: offset,
    );

    // Eskirgan javob — e'tiborsiz qoldiramiz.
    if (seq != _requestSeq || !mounted) return;

    final page = InventoryProductRow.listFromResponse(res);
    final total = _asInt(res['count']);
    final rows = more ? <InventoryProductRow>[..._rows, ...page] : page;

    _rows = rows;
    _appliedQuery = query;
    _hasMore = page.length >= _pageSize &&
        (total == null || rows.length < total);
    _syncControllers(rows);
  }

  Future<void> _loadStats() async {
    final res = await InventoryApi.getItems(inventoryId: _doc.id);
    final statsRaw = res['stats'];
    _stats = InventoryStats.fromJson(
      statsRaw is Map ? Map<String, dynamic>.from(statsRaw) : null,
    );
  }

  /// Ro‘yxatni qayta so‘rash (qidiruv / filtr / pull-to-refresh).
  Future<void> _reloadList({bool withStats = false}) async {
    // Kutayotgan miqdorlar yo‘qolib ketmasligi uchun avval saqlaymiz.
    await _flushPending();
    if (!mounted) return;
    setState(() {
      _querying = true;
      _error = null;
    });
    try {
      await _loadProducts();
      if (withStats) await _loadStats();
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) {
      setState(() {
        _querying = false;
        _loading = false;
      });
    }
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients || !_hasMore || _loadingMore || _querying) {
      return;
    }
    final pos = _scrollCtrl.position;
    if (pos.pixels >= pos.maxScrollExtent - 300) _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      await _loadProducts(more: true);
    } catch (e) {
      if (mounted) AppNotify.error(context, '$e');
    }
    if (mounted) setState(() => _loadingMore = false);
  }

  // --------------------------------------------------------------- qidiruv

  void _onSearchChanged(String _) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      // Matn o‘zgarmagan bo‘lsa qayta so‘ramaymiz.
      if (_searchCtrl.text.trim() == _appliedQuery) return;
      _reloadList();
    });
  }

  void _submitSearch() {
    _searchDebounce?.cancel();
    _reloadList();
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    if (_searchCtrl.text.isEmpty && _appliedQuery.isEmpty) return;
    _searchCtrl.clear();
    _reloadList();
  }

  void _openScanner() {
    showCompactScanner(context, onResult: (code) async {
      final q = (code ?? '').trim();
      if (q.isEmpty || !mounted) return;
      _searchDebounce?.cancel();
      _searchCtrl.text = q;
      // Skanerdan kelgan kod filtrga tushib qolmasligi uchun.
      if (_countFilter != 'all') _countFilter = 'all';
      await _reloadList();
      if (!mounted) return;
      if (_rows.length == 1) {
        _focusQuantity(_rows.first);
      } else if (_rows.isEmpty) {
        AppNotify.warning(context, 'Bu shtrix-kod hujjatda topilmadi');
      }
    });
  }

  void _focusQuantity(InventoryProductRow row) {
    final ctrl = _qtyCtrls[row.variantId];
    final node = _qtyFocus[row.variantId];
    if (ctrl == null || node == null || _readOnly) return;
    node.requestFocus();
    ctrl.selection = TextSelection(
      baseOffset: 0,
      extentOffset: ctrl.text.length,
    );
  }

  void _setFilter(String filter) {
    if (_countFilter == filter) return;
    setState(() => _countFilter = filter);
    _reloadList();
  }

  // -------------------------------------------------------------- miqdorlar

  void _syncControllers(List<InventoryProductRow> rows) {
    final ids = rows.map((r) => r.variantId).toSet();
    for (final id in _qtyCtrls.keys.toList()) {
      if (ids.contains(id)) continue;
      _saveDebounce.remove(id)?.cancel();
      _qtyCtrls.remove(id)?.dispose();
      _qtyFocus.remove(id)?.dispose();
    }
    for (final row in rows) {
      final text = row.countedQuantity == null
          ? ''
          : _formatQty(row.countedQuantity!);
      final existing = _qtyCtrls[row.variantId];
      if (existing == null) {
        _qtyCtrls[row.variantId] = TextEditingController(text: text);
        _qtyFocus[row.variantId] = FocusNode();
        continue;
      }
      // Foydalanuvchi yozayotgan yoki saqlanayotgan maydonga tegmaymiz.
      final focused = _qtyFocus[row.variantId]?.hasFocus ?? false;
      final saving = _savingVariants.contains(row.variantId);
      if (!focused && !saving && existing.text != text) {
        existing.text = text;
      }
    }
  }

  static int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.round();
    return int.tryParse(v.toString());
  }

  static String _formatQty(num n) {
    if (n == n.roundToDouble()) return n.round().toString();
    var s = n.toStringAsFixed(3);
    s = s.replaceFirst(RegExp(r'0+$'), '');
    s = s.replaceFirst(RegExp(r'\.$'), '');
    return s;
  }

  static num? _parseQty(String raw) {
    final t = raw.trim().replaceAll(' ', '').replaceAll(',', '.');
    if (t.isEmpty) return null;
    return num.tryParse(t);
  }

  InventoryProductRow? _rowFor(int variantId) {
    for (final r in _rows) {
      if (r.variantId == variantId) return r;
    }
    return null;
  }

  void _onQtyChanged(InventoryProductRow row, String raw) {
    if (_readOnly) return;
    _saveDebounce[row.variantId]?.cancel();
    _saveDebounce[row.variantId] = Timer(
      const Duration(milliseconds: 500),
      () {
        // Ishlagan taymer ro‘yxatda qolsa, _flushPending uni ikkinchi marta
        // yuborib yuboradi.
        _saveDebounce.remove(row.variantId);
        _persistQuantity(row, raw);
      },
    );
  }

  /// Magnit: tizimdagi (kutilayotgan) miqdorni maydonga qo‘yadi.
  void _applySystemQuantity(InventoryProductRow row) {
    if (_readOnly) return;
    final ctrl = _qtyCtrls[row.variantId];
    if (ctrl == null) return;
    final text = _formatQty(row.systemQuantity);
    ctrl.text = text;
    ctrl.selection = TextSelection.collapsed(offset: text.length);
    _saveDebounce.remove(row.variantId)?.cancel();
    _persistQuantity(row, text);
  }

  Future<void> _persistQuantity(InventoryProductRow row, String raw) async {
    if (_readOnly || !mounted) return;
    final parsed = _parseQty(raw);
    if (raw.trim().isNotEmpty && parsed == null) {
      AppNotify.info(context, 'Miqdor noto‘g‘ri');
      return;
    }
    // Qiymat o‘zgarmagan bo‘lsa serverni bezovta qilmaymiz.
    if (parsed == row.countedQuantity) return;
    setState(() => _savingVariants.add(row.variantId));
    try {
      final res = await InventoryApi.updateQuantity(
        inventoryId: _doc.id,
        variantId: row.variantId,
        countedQuantity: parsed,
      );
      final data = res['data'];
      if (data is Map) {
        final item = data['inventory_item'];
        if (item is Map) {
          final m = Map<String, dynamic>.from(item);
          final counted = m['counted_quantity'];
          row.countedQuantity = counted == null || counted == ''
              ? null
              : num.tryParse(counted.toString());
          row.isChecked = m['is_checked'] == true ||
              m['is_checked'] == 1 ||
              row.countedQuantity != null;
        }
      } else {
        row.countedQuantity = parsed;
        row.isChecked = parsed != null;
      }
      await _loadStats();
    } catch (e) {
      if (mounted) AppNotify.error(context, '$e');
    } finally {
      _savingVariants.remove(row.variantId);
      if (mounted) setState(() {});
    }
  }

  Future<void> _flushPending() async {
    final pending = Map<int, Timer>.from(_saveDebounce);
    _saveDebounce.clear();
    for (final entry in pending.entries) {
      entry.value.cancel();
      final row = _rowFor(entry.key);
      final ctrl = _qtyCtrls[entry.key];
      if (row != null && ctrl != null) {
        await _persistQuantity(row, ctrl.text);
      }
    }
  }

  // ---------------------------------------------------------------- amallar

  Future<void> _saveContinue() async {
    if (_readOnly || _busy) return;
    setState(() => _busy = true);
    try {
      await _flushPending();
      await InventoryApi.save(_doc.id);
      if (!mounted) return;
      AppNotify.success(context, 'Saqlandi — keyin davom ettirishingiz mumkin');
      Navigator.pop(context);
    } catch (e) {
      if (mounted) AppNotify.error(context, '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _complete() async {
    if (_readOnly || _busy) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Inventarni yakunlash'),
        content: Text(
          _stats.pending > 0
              ? '${_stats.pending} ta mahsulot hali sanalmagan.\n'
                  'Sanalgan miqdorlar bo‘yicha ombor to‘g‘rilanadi. '
                  'Bu amalni bekor qilib bo‘lmaydi. Davom etasizmi?'
              : 'Sanalgan miqdorlar bo‘yicha ombor to‘g‘rilanadi. '
                  'Bu amalni bekor qilib bo‘lmaydi. Davom etasizmi?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(Strings.bekorQilish),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yakunlash'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await _flushPending();
      final res = await InventoryApi.complete(_doc.id);
      final data = res['data'];
      if (data is Map) {
        _doc = InventoryDocument.fromJson(Map<String, dynamic>.from(data));
      }
      if (!mounted) return;
      AppNotify.success(context, 'Inventarizatsiya yakunlandi');
      Navigator.pop(context);
    } catch (e) {
      if (mounted) AppNotify.error(context, '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ------------------------------------------------------------------- UI

  @override
  Widget build(BuildContext context) {
    final title = _doc.documentNumber.isEmpty
        ? 'Inventar #${_doc.id}'
        : _doc.documentNumber;
    final subtitle = [
      if ((_doc.categoryName ?? '').isNotEmpty) _doc.categoryName!,
      if (_stats.total > 0) '${_stats.counted}/${_stats.total} sanalgan',
    ].join(' · ');

    return Scaffold(
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: const TextStyle(fontSize: 17)),
            if (subtitle.isNotEmpty)
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: AppTheme.textSecondary,
                ),
              ),
          ],
        ),
        actions: [
          if (_readOnly)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Center(
                child: Text(
                  'Yakunlangan',
                  style: TextStyle(
                    color: Color(0xFF166534),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildFilters(),
          SizedBox(
            height: 2,
            child: _querying
                ? const LinearProgressIndicator(
                    minHeight: 2,
                    color: AppTheme.primary,
                    backgroundColor: Colors.transparent,
                  )
                : null,
          ),
          Expanded(
            child: ThrottledRefreshIndicator(
              onRefresh: () => _reloadList(withStats: true),
              child: _buildList(),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _readOnly ? null : _buildBottomBar(),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              textInputAction: TextInputAction.search,
              onChanged: _onSearchChanged,
              onSubmitted: (_) => _submitSearch(),
              decoration: InputDecoration(
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                hintText: Strings.artikulShtrixIsm,
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: AppTheme.textSecondary,
                ),
                suffixIcon: !_hasSearchText
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        color: AppTheme.textSecondary,
                        onPressed: _clearSearch,
                      ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: AppTheme.primary,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              onTap: _openScanner,
              borderRadius: BorderRadius.circular(10),
              child: const Padding(
                padding: EdgeInsets.all(11),
                child: Icon(
                  Icons.qr_code_scanner_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: _StatBadge(
              label: 'Sanalgan',
              value: _stats.counted,
              color: const Color(0xFF166534),
              bg: const Color(0xFFDCFCE7),
              selected: _countFilter == 'counted',
              onTap: () => _setFilter('counted'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _StatBadge(
              label: 'Sanalmagan',
              value: _stats.pending,
              color: const Color(0xFF9A3412),
              bg: const Color(0xFFFFEDD5),
              selected: _countFilter == 'pending',
              onTap: () => _setFilter('pending'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _StatBadge(
              label: 'Jami',
              value: _stats.total,
              color: AppTheme.primary,
              bg: AppTheme.primaryLight,
              selected: _countFilter == 'all',
              onTap: () => _setFilter('all'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_loading && _rows.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 160),
          Center(child: CircularProgressIndicator(color: AppTheme.primary)),
        ],
      );
    }

    if (_error != null && _rows.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 80),
          Icon(
            Icons.error_outline_rounded,
            size: 56,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 16),
          Center(
            child: FilledButton(
              onPressed: _bootstrap,
              child: const Text('Qayta yuklash'),
            ),
          ),
        ],
      );
    }

    if (_rows.isEmpty) {
      final searching = _appliedQuery.isNotEmpty;
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 80),
          Icon(
            searching ? Icons.search_off_rounded : Icons.inventory_2_outlined,
            size: 64,
            color: AppTheme.textSecondary.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            searching ? 'Mahsulot topilmadi' : 'Ro‘yxat bo‘sh',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            searching
                ? 'Boshqa nom, SKU yoki shtrix-kod bilan urinib ko‘ring'
                : 'Bu filtrda mahsulot yo‘q',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
          ),
        ],
      );
    }

    return ListView.builder(
      controller: _scrollCtrl,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: _rows.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, i) {
        if (i >= _rows.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: _loadingMore
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : OutlinedButton.icon(
                      onPressed: _loadMore,
                      icon: const Icon(Icons.expand_more_rounded),
                      label: const Text('Yana yuklash'),
                    ),
            ),
          );
        }
        final row = _rows[i];
        return _CountRowCard(
          row: row,
          controller: _qtyCtrls[row.variantId]!,
          focusNode: _qtyFocus[row.variantId]!,
          saving: _savingVariants.contains(row.variantId),
          readOnly: _readOnly,
          formatQty: _formatQty,
          onChanged: (v) => _onQtyChanged(row, v),
          onSubmitted: () {
            _saveDebounce.remove(row.variantId)?.cancel();
            _persistQuantity(row, _qtyCtrls[row.variantId]!.text);
            FocusScope.of(context).unfocus();
          },
          onMagnet: () => _applySystemQuantity(row),
        );
      },
    );
  }

  Widget _buildBottomBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _busy ? null : _saveContinue,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('Saqlash'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                onPressed: _busy ? null : _complete,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Yakunlash'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bitta mahsulot qatori: nom, meta, miqdor maydoni (magnit bilan) va farq.
class _CountRowCard extends StatelessWidget {
  const _CountRowCard({
    required this.row,
    required this.controller,
    required this.focusNode,
    required this.saving,
    required this.readOnly,
    required this.formatQty,
    required this.onChanged,
    required this.onSubmitted,
    required this.onMagnet,
  });

  final InventoryProductRow row;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool saving;
  final bool readOnly;
  final String Function(num) formatQty;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmitted;
  final VoidCallback onMagnet;

  @override
  Widget build(BuildContext context) {
    final diff = row.isCounted ? row.difference : null;
    final meta = [
      if ((row.barcode ?? '').isNotEmpty) row.barcode!,
      if ((row.sku ?? '').isNotEmpty) 'SKU ${row.sku}',
      'Tizim: ${formatQty(row.systemQuantity)}',
    ].join(' · ');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              row.displayName,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              meta,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    enabled: !readOnly,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                    ],
                    onChanged: onChanged,
                    onEditingComplete: onSubmitted,
                    decoration: InputDecoration(
                      labelText: 'Haqiqiy miqdor',
                      isDense: true,
                      filled: true,
                      fillColor: AppTheme.cardBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppTheme.divider),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: AppTheme.primary, width: 2),
                      ),
                      floatingLabelStyle: const TextStyle(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                      suffixIconConstraints: const BoxConstraints(
                        minWidth: 0,
                        minHeight: 0,
                      ),
                      suffixIcon: Padding(
                        padding: const EdgeInsets.only(left: 6, right: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (saving)
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            else if (row.isCounted)
                              const Icon(
                                Icons.check_circle_rounded,
                                color: Color(0xFF16A34A),
                                size: 18,
                              ),
                            if (!readOnly) ...[
                              const SizedBox(width: 6),
                              _MagnetButton(
                                onTap: onMagnet,
                                tooltip:
                                    'Tizim miqdorini qo‘yish (${formatQty(row.systemQuantity)})',
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (diff != null) ...[
                  const SizedBox(width: 12),
                  Column(
                    children: [
                      const Text(
                        'Farq',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        diff > 0 ? '+${formatQty(diff)}' : formatQty(diff),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: diff == 0
                              ? AppTheme.textSecondary
                              : (diff > 0
                                  ? const Color(0xFF16A34A)
                                  : const Color(0xFFDC2626)),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Miqdor maydoni ichidagi magnit tugmasi — tizim miqdorini tortib oladi.
class _MagnetButton extends StatelessWidget {
  const _MagnetButton({required this.onTap, required this.tooltip});

  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppTheme.primaryLight,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: const Padding(
            padding: EdgeInsets.all(6),
            child: MagnetIcon(size: 18, color: AppTheme.primary),
          ),
        ),
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  const _StatBadge({
    required this.label,
    required this.value,
    required this.color,
    required this.bg,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int value;
  final Color color;
  final Color bg;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? color : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Text(
                '$value',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: color,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
