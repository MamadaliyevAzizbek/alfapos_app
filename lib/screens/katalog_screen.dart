import 'dart:async';

import 'package:flutter/material.dart';
import '../core/app_notify.dart';
import '../core/constants.dart';
import '../core/theme.dart';
import '../models/product.dart';
import '../providers/products_provider.dart';
import '../providers/categories_provider.dart';
import '../providers/sales_session_provider.dart';
import '../services/category_order_storage.dart';
import '../utils/category_order_sort.dart';
import '../widgets/product_tile.dart';
import 'yangi_tovar_screen.dart';
import 'mahsulot_detail_screen.dart';
import 'scanner_screen.dart' show showCompactScanner;
import '../utils/product_search.dart' as product_search;
import '../utils/platform_layout.dart';
import '../widgets/add_category_sheet.dart';
import '../widgets/category_image_cover.dart';
import '../widgets/edit_category_sheet.dart';
import '../widgets/ios_style_modals.dart';
import 'desktop/desktop_shell_scope.dart';
import '../services/app_data_sync.dart';

class KatalogScreen extends StatefulWidget {
  const KatalogScreen({super.key});

  @override
  State<KatalogScreen> createState() => _KatalogScreenState();

  /// Backward-compatible wrapper (eski chaqiriqlar uchun).
  static List<Product> filterProductsByQuery(List<Product> products, String query) =>
      product_search.filterProductsByQuery(products, query);

  static String _normalizeBarcodeStatic(String? s) => Product.normalizeBarcode(s);
}

enum _ProductFilter { all, active, inactive }

class _KatalogScreenState extends State<KatalogScreen> with SingleTickerProviderStateMixin, DesktopShellSyncMixin {
  StreamSubscription<List<Product>>? _productsSub;
  StreamSubscription<List<String>>? _categoriesSub;
  final _searchController = TextEditingController();
  String _query = '';
  String? _lockedProductId;
  bool _ignoreNextSearchChange = false;
  _ProductFilter _productFilter = _ProductFilter.all;
  final _products = ProductsProvider.instance;
  final _categories = CategoriesProvider.instance;
  late TabController _tabController;
  bool _syncing = false;
  List<String> _categoryOrderIds = [];

  Future<void> _syncAllData() async {
    if (_syncing || AppDataSync.isRunning) return;
    setState(() => _syncing = true);
    try {
      await AppDataSync.syncAll(force: true);
      if (!mounted) return;
      AppNotify.success(context, 'Ma\'lumotlar sinxronlandi');
      setState(() {});
    } catch (e) {
      if (mounted) AppNotify.error(context, 'Sinxronlash xatosi: $e');
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _productsSub = _products.stream.listen((_) {
      if (mounted) setState(() {});
    });
    _categoriesSub = _categories.stream.listen((_) {
      if (mounted) unawaited(_reloadCategoryOrder());
    });
    unawaited(_bootstrapCatalog());
    unawaited(_reloadCategoryOrder());
  }

  Future<void> _bootstrapCatalog() async {
    await _products.loadFromStorage(refreshInBackground: false);
    await _products.ensureFullCatalogLoaded();
    if (mounted) setState(() {});
  }

  Future<void> _reloadCategoryOrder() async {
    final ids = _categories.rawList
        .map((e) => e['id']?.toString().trim() ?? '')
        .where((e) => e.isNotEmpty)
        .toList();
    _categoryOrderIds = await CategoryOrderStorage.mergeWithCategoryIds(ids);
    final sales = SalesSessionProvider.instance;
    if (sales.categories.isNotEmpty) {
      sales.categories = CategoryOrderSort.apply(sales.categories, _categoryOrderIds);
    }
    if (mounted) setState(() {});
  }

  List<Map<String, dynamic>> get _sortedCategoryRows {
    final raw = _categories.rawList
        .where((e) => e['id'] != null)
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    return CategoryOrderSort.apply(raw, _categoryOrderIds);
  }

  Future<void> _onCategoriesReordered(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;
    final rows = [..._sortedCategoryRows];
    final item = rows.removeAt(oldIndex);
    rows.insert(newIndex, item);
    final ids = rows.map((e) => e['id']!.toString()).toList();
    await CategoryOrderStorage.saveOrderedIds(ids);
    _categoryOrderIds = ids;
    final sales = SalesSessionProvider.instance;
    if (sales.categories.isNotEmpty) {
      sales.categories = CategoryOrderSort.apply(sales.categories, ids);
    }
    if (mounted) setState(() {});
  }

  @override
  Future<void> onDesktopShellSync() async {
    await _products.ensureFullCatalogLoaded(force: true);
    await _categories.loadFromApi();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _productsSub?.cancel();
    _categoriesSub?.cancel();
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<Product> get _productsByFilter {
    final list = _products.items;
    switch (_productFilter) {
      case _ProductFilter.active:
        return list.where((p) => p.initialQuantity > 0).toList();
      case _ProductFilter.inactive:
        return list.where((p) => p.initialQuantity == 0).toList();
      case _ProductFilter.all:
        return list;
    }
  }

  List<Product> get _filteredProducts => _lockedProductId != null
      ? _productsByFilter.where((p) => p.id == _lockedProductId).toList()
      : KatalogScreen.filterProductsByQuery(_productsByFilter, _query);

  int get _allCount => _products.items.length;
  int get _activeCount => _products.items.where((p) => p.initialQuantity > 0).length;
  int get _inactiveCount => _products.items.where((p) => p.initialQuantity == 0).length;

  String _formatCount(int n) {
    if (n < 1000) return '$n';
    final s = n.toString();
    return '${s.substring(0, s.length - 3)} ${s.substring(s.length - 3)}';
  }

  void _maybeClearSearchAfterBarcodeMatch() {
    product_search.scheduleBarcodeAutoAction(
      query: _query,
      filteredProducts: _filteredProducts,
      onSingleBarcodeMatch: (p) {
        if (!mounted) return;
        setState(() => _lockedProductId = p.id);
        _ignoreNextSearchChange = true;
        _searchController.clear();
        setState(() => _query = '');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final products = _filteredProducts;

    return Scaffold(
      appBar: AppBar(
        title: const Text(Strings.navMahsulotlar),
        actions: [
          IconButton(
            tooltip: 'Sinxronlash',
            onPressed: _syncing || AppDataSync.isRunning ? null : _syncAllData,
            icon: _syncing || AppDataSync.isRunning
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                  )
                : const Icon(Icons.sync_rounded),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Mahsulotlar'),
            Tab(text: Strings.kategoriyalar),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildProductsTab(products),
          _buildCategoriesTab(),
        ],
      ),
    );
  }

  Widget _buildProductsTab(List<Product> products) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) {
                    if (_ignoreNextSearchChange) {
                      _ignoreNextSearchChange = false;
                      return;
                    }
                    if (v.trim().isNotEmpty && _lockedProductId != null) {
                      setState(() => _lockedProductId = null);
                    }
                    setState(() => _query = v);
                    _maybeClearSearchAfterBarcodeMatch();
                  },
                  decoration: const InputDecoration(
                    hintText: Strings.mahsulotQidirishHint,
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
              ),
              if (!isDesktopPosLayout) ...[
                const SizedBox(width: 10),
                Material(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: () => _showScanner(context),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      child: const Icon(
                        Icons.qr_code_scanner_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        // Barchasi / Faol / Faol emas
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: _filterChip(
                  label: '${Strings.barchasi} (${_formatCount(_allCount)})',
                  selected: _productFilter == _ProductFilter.all,
                  onTap: () => setState(() => _productFilter = _ProductFilter.all),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _filterChip(
                  label: '${Strings.faol} (${_formatCount(_activeCount)})',
                  selected: _productFilter == _ProductFilter.active,
                  onTap: () => setState(() => _productFilter = _ProductFilter.active),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _filterChip(
                  label: '${Strings.faolEmas} (${_formatCount(_inactiveCount)})',
                  selected: _productFilter == _ProductFilter.inactive,
                  onTap: () => setState(() => _productFilter = _ProductFilter.inactive),
                ),
              ),
            ],
          ),
        ),
        // Yangi mahsulot qo'shish — katta ko'k pill tugma (rasmdagi kabi)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Material(
            color: AppTheme.primary,
            borderRadius: BorderRadius.circular(28),
            elevation: 2,
            shadowColor: AppTheme.primary.withValues(alpha: 0.4),
            child: InkWell(
              onTap: () async {
                final saved = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(builder: (_) => const YangiTovarScreen()),
                );
                if (!mounted) return;
                setState(() {});
                if (saved == true) {
                  AppNotify.success(null, "Tovar muvaffaqiyatli qo'shildi!");
                }
              },
              borderRadius: BorderRadius.circular(28),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_circle_outline_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                    SizedBox(width: 12),
                    Text(
                      "Yangi mahsulot qo'shish",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              await _products.loadFromApi();
              await _categories.loadFromApi();
              if (mounted) setState(() {});
            },
            child: _products.loadError != null
                ? SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                    child: SizedBox(
                      height: MediaQuery.of(context).size.height * 0.6,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.error_outline_rounded, size: 56, color: Theme.of(context).colorScheme.error),
                              const SizedBox(height: 12),
                              Text(
                                _products.loadError!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 15, color: AppTheme.textSecondary),
                              ),
                              const SizedBox(height: 16),
                              TextButton.icon(
                                onPressed: () => _products.loadFromApi(),
                                icon: const Icon(Icons.refresh_rounded),
                                label: const Text("Qayta yuklash"),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                : !_products.isLoaded
                    ? SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                        child: SizedBox(
                          height: MediaQuery.of(context).size.height * 0.6,
                          child: const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(color: AppTheme.primary),
                                SizedBox(height: 12),
                                Text(
                                  "Mahsulotlar yuklanmoqda...",
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    : products.isEmpty
                        ? SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                            child: SizedBox(
                              height: MediaQuery.of(context).size.height * 0.6,
                              child: const Center(
                                child: Text(
                                  "Mahsulot topilmadi",
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          )
                        : ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: products.length,
                            itemBuilder: (context, index) {
                              final p = products[index];
                              final latest = _products.getProductById(p.id) ?? p;
                              return ProductTile(
                                product: p,
                                onTap: () {
                                  _products.prefetchProductForDetail(latest);
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => MahsulotDetailScreen(product: latest),
                                    ),
                                  );
                                },
                                onMenu: () => _showProductMenu(context, p),
                              );
                            },
                          ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoriesTab() {
    final list = _sortedCategoryRows;
    final loadError = _categories.loadError;
    return Column(
      children: [
        if (loadError != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Expanded(child: Text(loadError, style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.error))),
                TextButton(onPressed: () => _categories.loadFromApi(), child: const Text('Qayta yuklash')),
              ],
            ),
          ),
        if (list.isNotEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Icon(Icons.drag_handle_rounded, size: 16, color: AppTheme.textSecondary),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Tartibni o‘zgartirish: chap tomondan ushlab sudrang',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.3),
                  ),
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Material(
            color: AppTheme.primary,
            borderRadius: BorderRadius.circular(28),
            elevation: 2,
            shadowColor: AppTheme.primary.withValues(alpha: 0.4),
            child: InkWell(
              onTap: () => _showAddCategory(context),
              borderRadius: BorderRadius.circular(28),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_circle_outline_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                    SizedBox(width: 12),
                    Text(
                      "Yangi kategoriya qo'shish",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              await _categories.loadFromApi();
              if (mounted) setState(() {});
            },
            child: list.isEmpty
                ? SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                    child: SizedBox(
                      height: MediaQuery.of(context).size.height * 0.6,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.category_rounded, size: 64, color: AppTheme.textSecondary.withValues(alpha: 0.5)),
                            const SizedBox(height: 16),
                            const Text(
                              "Kategoriya yo'q",
                              style: TextStyle(fontSize: 16, color: AppTheme.textSecondary),
                            ),
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: () => _categories.loadFromApi(),
                              icon: const Icon(Icons.refresh_rounded, size: 20),
                              label: const Text('Qayta yuklash'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                : ReorderableListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    buildDefaultDragHandles: false,
                    itemCount: list.length,
                    onReorder: _onCategoriesReordered,
                    itemBuilder: (context, index) {
                      final row = list[index];
                      final id = row['id']?.toString() ?? '$index';
                      final name = (row['name'] as String? ??
                              row['title'] as String? ??
                              row['category_name'] as String? ??
                              '')
                          .trim();
                      if (name.isEmpty) return SizedBox(key: ValueKey('empty-$id'));
                      final imageUrl = _categories.categoryImageUrl(row['id']?.toString());
                      return Card(
                        key: ValueKey('cat-$id'),
                        margin: const EdgeInsets.only(bottom: 12),
                        child: InkWell(
                          onTap: () => EditCategorySheet.show(context, categoryName: name),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                ReorderableDragStartListener(
                                  index: index,
                                  child: const Padding(
                                    padding: EdgeInsets.only(right: 8),
                                    child: Icon(Icons.drag_handle_rounded, color: AppTheme.textSecondary),
                                  ),
                                ),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: CategoryImageCover.build(
                                    imageUrl,
                                    width: 72,
                                    height: 72,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Text(
                                    name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.more_vert_rounded),
                                  onPressed: () => _showCategoryMenu(context, name),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _filterChip({required String label, required bool selected, required VoidCallback onTap}) {
    return Material(
      color: selected ? AppTheme.primaryLight : AppTheme.cardBg,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: selected ? AppTheme.primary : AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showAddCategory(BuildContext context) async {
    final name = await AddCategorySheet.show(context);
    if (name != null && mounted) setState(() {});
  }

  Future<void> _showEditCategory(BuildContext context, String oldName) async {
    await EditCategorySheet.show(context, categoryName: oldName);
    if (mounted) setState(() {});
  }

  void _confirmDeleteCategory(BuildContext context, String name) {
    IosStyleModals.showSheet<void>(
      context: context,
      showGrabber: true,
      child: Builder(
        builder: (ctx) => IosStyleModals.sheetConfirm(
          onCancel: () => Navigator.pop(ctx),
          onConfirm: () async {
            await _categories.removeCategory(name);
            if (ctx.mounted) Navigator.pop(ctx);
            setState(() {});
          },
          cancelLabel: Strings.bekorQilish,
          confirmLabel: "O'chirish",
          confirmBackgroundColor: Colors.red.shade700,
          confirmForegroundColor: Colors.white,
          body: const [
            Text(Strings.kategoriyaniOchirish, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
            SizedBox(height: 8),
            Text(Strings.kategoriyaniOchirishRost, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  void _showCategoryMenu(BuildContext context, String name) {
    IosStyleModals.showSheet(
      context: context,
      showGrabber: true,
      child: Builder(
        builder: (sheetContext) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.primaryLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.edit_rounded, color: AppTheme.primary, size: 22),
              ),
              title: const Text("Tahrirlash"),
              titleTextStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                _showEditCategory(context, name);
              },
            ),
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.delete_outline_rounded, color: Colors.red.shade700, size: 22),
              ),
              title: Text("O'chirish", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.red.shade700)),
              onTap: () {
                Navigator.pop(sheetContext);
                _confirmDeleteCategory(context, name);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showProductMenu(BuildContext context, Product product) {
    IosStyleModals.showSheet(
      context: context,
      showGrabber: true,
      child: Builder(
        builder: (sheetContext) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.primaryLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.edit_rounded, color: AppTheme.primary, size: 22),
              ),
              title: const Text("Tahrirlash"),
              titleTextStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
              onTap: () async {
                Navigator.pop(sheetContext);
                final saved = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => YangiTovarScreen(product: product),
                  ),
                );
                if (!mounted) return;
                setState(() {});
                if (saved == true) {
                  AppNotify.success(null, "Tovar muvaffaqiyatli tahrirlandi!");
                }
              },
            ),
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.delete_outline_rounded, color: Colors.red.shade700, size: 22),
              ),
              title: Text("O'chirish", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.red.shade700)),
              onTap: () {
                Navigator.pop(sheetContext);
                _confirmDelete(context, product);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, Product product) {
    IosStyleModals.showSheet<void>(
      context: context,
      showGrabber: true,
      child: Builder(
        builder: (ctx) => IosStyleModals.sheetConfirm(
          onCancel: () => Navigator.pop(ctx),
          onConfirm: () async {
            await ProductsProvider.instance.removeProduct(product);
            if (ctx.mounted) Navigator.pop(ctx);
            setState(() {});
          },
          cancelLabel: 'Bekor qilish',
          confirmLabel: "O'chirish",
          confirmBackgroundColor: Colors.red.shade700,
          confirmForegroundColor: Colors.white,
          body: [
            const Text("Mahsulotni o'chirish", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
            const SizedBox(height: 8),
            Text("«${product.name}» ni rostdan ham o'chirmoqchimisiz?", textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  void _showScanner(BuildContext context) {
    showCompactScanner(context, onResult: (barcode) {
      if (barcode != null && barcode.isNotEmpty && mounted) {
        _searchController.text = barcode.trim();
        if (_lockedProductId != null) setState(() => _lockedProductId = null);
        setState(() => _query = barcode.trim());
        _maybeClearSearchAfterBarcodeMatch();
      }
    });
  }
}
