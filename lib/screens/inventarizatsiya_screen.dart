import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_notify.dart';
import '../core/constants.dart';
import '../core/theme.dart';
import '../core/user_permissions.dart';
import '../models/inventory.dart';
import '../services/api_service.dart';
import '../widgets/app_dropdown.dart';
import '../widgets/ios_style_modals.dart';
import '../widgets/throttled_refresh_indicator.dart';
import 'inventarizatsiya_count_screen.dart';

/// Inventarizatsiya ro‘yxati — POST /api/v1/inventories.
class InventarizatsiyaScreen extends StatefulWidget {
  const InventarizatsiyaScreen({super.key});

  @override
  State<InventarizatsiyaScreen> createState() => _InventarizatsiyaScreenState();
}

class _InventarizatsiyaScreenState extends State<InventarizatsiyaScreen> {
  static const int _pageSize = 50;

  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  Timer? _searchDebounce;

  int _requestSeq = 0;
  bool _loading = true;
  bool _querying = false;
  bool _loadingMore = false;
  bool _hasMore = false;
  bool _hasSearchText = false;
  String? _error;
  String _appliedQuery = '';
  List<InventoryDocument> _docs = [];

  @override
  void initState() {
    super.initState();
    if (!UserPermissionsStore.instance.canAccessInventory) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        AppNotify.error(context, 'Inventarizatsiyaga ruxsat yo‘q');
        Navigator.of(context).maybePop();
      });
      return;
    }
    _scrollCtrl.addListener(_onScroll);
    _searchCtrl.addListener(() {
      final has = _searchCtrl.text.isNotEmpty;
      if (has != _hasSearchText) setState(() => _hasSearchText = has);
    });
    _load();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _scrollCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetch({bool more = false}) async {
    final seq = ++_requestSeq;
    final query = _searchCtrl.text.trim();
    final res = await InventoryApi.listDocuments(
      searchValue: query,
      rowLimit: _pageSize,
      rowOffset: more ? _docs.length : 0,
    );
    if (seq != _requestSeq || !mounted) return;

    final page = InventoryDocument.listFromResponse(res);
    final total = _asInt(res['count']);
    final docs = more ? <InventoryDocument>[..._docs, ...page] : page;

    _docs = docs;
    _appliedQuery = query;
    _hasMore =
        page.length >= _pageSize && (total == null || docs.length < total);
  }

  Future<void> _load() async {
    setState(() {
      if (_docs.isEmpty) _loading = true;
      _querying = true;
      _error = null;
    });
    try {
      await _fetch();
    } catch (e) {
      _error = e.toString();
      _docs = [];
    }
    if (mounted) {
      setState(() {
        _loading = false;
        _querying = false;
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
      await _fetch(more: true);
    } catch (e) {
      if (mounted) AppNotify.error(context, '$e');
    }
    if (mounted) setState(() => _loadingMore = false);
  }

  void _onSearchChanged(String _) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      if (_searchCtrl.text.trim() == _appliedQuery) return;
      _load();
    });
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    if (_searchCtrl.text.isEmpty && _appliedQuery.isEmpty) return;
    _searchCtrl.clear();
    _load();
  }

  static int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.round();
    return int.tryParse(v.toString());
  }

  Future<void> _openCreateWizard() async {
    List<InventoryCategoryOption> categories = const [];
    try {
      final filter = await InventoryApi.getFilterOptions();
      categories = InventoryCategoryOption.fromFilterResponse(filter);
    } catch (e) {
      if (mounted) AppNotify.error(context, 'Kategoriyalar: $e');
      return;
    }
    if (!mounted) return;

    String selected = 'all';
    final notesCtrl = TextEditingController();

    final ok = await IosStyleModals.showSheet<bool>(
      context: context,
      isScrollControlled: true,
      showGrabber: true,
      child: StatefulBuilder(
        builder: (ctx, setModal) {
          final items = <DropdownMenuItem<String>>[
            const DropdownMenuItem(
              value: 'all',
              child: Text('Barcha kategoriyalar'),
            ),
            ...categories.where((c) => c.value != 'all').map(
                  (c) => DropdownMenuItem(
                    value: c.value,
                    child: Text(c.text.isEmpty ? c.value : c.text),
                  ),
                ),
          ];
          return IosStyleModals.sheetKeyboardForm(
            context: ctx,
            onCancel: () => Navigator.pop(ctx, false),
            onSave: () => Navigator.pop(ctx, true),
            cancelLabel: Strings.bekorQilish,
            saveLabel: 'Boshlash',
            body: [
              const Text(
                'Yangi inventarizatsiya',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
              ),
              const SizedBox(height: 6),
              const Text(
                'Kategoriya tanlang — o‘sha kategoriyadagi mahsulotlar '
                'sanash ro‘yxatiga tushadi.',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              AppDropdownField<String>(
                label: 'Kategoriya',
                value: selected,
                items: items,
                onChanged: (v) {
                  if (v == null) return;
                  setModal(() => selected = v);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Izoh (ixtiyoriy)',
                ),
              ),
            ],
          );
        },
      ),
    );

    if (ok != true || !mounted) {
      notesCtrl.dispose();
      return;
    }

    try {
      final res = await InventoryApi.create(
        categoryId: selected,
        notes: notesCtrl.text,
      );
      notesCtrl.dispose();
      final data = res['data'];
      if (data is! Map) {
        throw StateError(res['message']?.toString() ?? 'Hujjat yaratilmadi');
      }
      final doc = InventoryDocument.fromJson(Map<String, dynamic>.from(data));
      if (!mounted) return;
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => InventarizatsiyaCountScreen(document: doc),
        ),
      );
      if (mounted) _load();
    } catch (e) {
      notesCtrl.dispose();
      if (mounted) AppNotify.error(context, '$e');
    }
  }

  Future<void> _openDoc(InventoryDocument doc) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => InventarizatsiyaCountScreen(document: doc),
      ),
    );
    if (mounted) _load();
  }

  // ------------------------------------------------------------------- UI

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(Strings.inventarizatsiya)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              textInputAction: TextInputAction.search,
              onChanged: _onSearchChanged,
              onSubmitted: (_) {
                _searchDebounce?.cancel();
                _load();
              },
              decoration: InputDecoration(
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                hintText: 'Hujjat raqami yoki izoh',
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
          SizedBox(
            height: 2,
            child: _querying && !_loading
                ? const LinearProgressIndicator(
                    minHeight: 2,
                    color: AppTheme.primary,
                    backgroundColor: Colors.transparent,
                  )
                : null,
          ),
          Expanded(
            child: ThrottledRefreshIndicator(
              onRefresh: _load,
              child: _buildBody(),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            onPressed: _openCreateWizard,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Yangi inventarizatsiya'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _docs.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 160),
          Center(child: CircularProgressIndicator(color: AppTheme.primary)),
        ],
      );
    }

    if (_error != null && _docs.isEmpty) {
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
              onPressed: _load,
              child: const Text('Qayta yuklash'),
            ),
          ),
        ],
      );
    }

    if (_docs.isEmpty) {
      final searching = _appliedQuery.isNotEmpty;
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 80),
          Icon(
            searching ? Icons.search_off_rounded : Icons.fact_check_outlined,
            size: 64,
            color: AppTheme.textSecondary.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            searching ? 'Hujjat topilmadi' : 'Inventarizatsiya yo‘q',
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
                ? 'Boshqa raqam yoki izoh bilan urinib ko‘ring'
                : 'Pastdagi «Yangi inventarizatsiya» tugmasidan boshlang',
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
      itemCount: _docs.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, i) {
        if (i >= _docs.length) {
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
        return _InventoryDocCard(
          doc: _docs[i],
          onTap: () => _openDoc(_docs[i]),
        );
      },
    );
  }
}

class _InventoryDocCard extends StatelessWidget {
  const _InventoryDocCard({required this.doc, required this.onTap});

  final InventoryDocument doc;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = doc.documentNumber.isEmpty
        ? 'Inventar #${doc.id}'
        : doc.documentNumber;
    final meta = [
      if ((doc.categoryName ?? '').isNotEmpty) doc.categoryName!,
      if ((doc.creatorName ?? '').isNotEmpty) doc.creatorName!,
    ].join(' · ');

    final total = doc.totalCount;
    final progress = total > 0 ? doc.checkedCount / total : 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _StatusChip(label: doc.statusLabel, status: doc.status),
                ],
              ),
              if (meta.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  meta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
              if ((doc.notes ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  doc.notes!.trim(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
              if (total > 0) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress.clamp(0.0, 1.0),
                          minHeight: 6,
                          backgroundColor: AppTheme.cardBg,
                          color: doc.isCompleted
                              ? const Color(0xFF16A34A)
                              : AppTheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${doc.checkedCount}/$total',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.status});

  final String label;
  final String status;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    switch (status) {
      case 'completed':
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF166534);
        break;
      case 'draft':
        bg = const Color(0xFFF1F5F9);
        fg = const Color(0xFF475569);
        break;
      default:
        bg = const Color(0xFFDBEAFE);
        fg = const Color(0xFF1D4ED8);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}
