import 'dart:async';

import 'package:flutter/material.dart';
import '../core/app_notify.dart';
import '../core/constants.dart';
import '../core/theme.dart';
import '../core/user_permissions.dart';
import '../models/product.dart';
import '../providers/products_provider.dart';
import '../providers/categories_provider.dart';
import '../providers/sales_session_provider.dart';
import '../services/category_order_storage.dart';
import '../utils/category_order_sort.dart';
import '../widgets/desktop_catalog_product_table.dart';
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
import 'desktop/desktop_barcode_print_screen.dart';
import 'desktop/desktop_shell_scope.dart';
import '../widgets/throttled_refresh_indicator.dart';

class KatalogScreen extends StatefulWidget {
  const KatalogScreen({super.key});

  @override
  State<KatalogScreen> createState() => _KatalogScreenState();

  /// Backward-compatible wrapper (eski chaqiriqlar uchun).
  static List<Product> filterProductsByQuery(List<Product> products, String query) =>
      product_search.filterProductsByQuery(products, query);
}

class _KatalogScreenState extends State<KatalogScreen> with SingleTickerProviderStateMixin, DesktopShellSyncMixin {
  StreamSubscription<List<Product>>? _productsSub;
  StreamSubscription<List<String>>? _categoriesSub;
  final _searchController = TextEditingController();
  String _query = '';
  String? _lockedProductId;
  bool _ignoreNextSearchChange = false;
  final _products = ProductsProvider.instance;
  final _categories = CategoriesProvider.instance;
  late TabController _tabController;
  List<String> _categoryOrderIds = [];
  String? _desktopCategoryId;

  /// Ekranni tortib yangilash — foydalanuvchi ataylab so‘ragan sinxronizatsiya.
  ///
  /// `force: true` bo‘lmasa 15 daqiqalik throttle va fingerprint tekshiruvi
  /// tarmoqqa umuman chiqmasligi mumkin: webda qo‘shilgan mahsulot ko‘rinmay
  /// qoladi. Ketma-ket tortish `PullRefreshGuard` bilan cheklangani uchun
  /// bu yerda force xavfsiz.
  Future<void> _pullRefreshCatalog() async {
    await _products.refreshFromServer(force: true);
    await _categories.refreshFromServer(force: true);
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    final tabCount = isDesktopPosLayout ? 3 : 2;
    _tabController = TabController(length: tabCount, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _productsSub = _products.stream.listen((_) {
      if (mounted) setState(() {});
    });
    _categoriesSub = _categories.stream.listen((_) {
      if (mounted) unawaited(_reloadCategoryOrder());
    });
    UserPermissionsStore.instance.addListener(_onPermissionsChanged);
    unawaited(_bootstrapCatalog());
    unawaited(_reloadCategoryOrder());
  }

  void _onPermissionsChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _bootstrapCatalog() async {
    await _products.warmFromCache();
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
    UserPermissionsStore.instance.removeListener(_onPermissionsChanged);
    _productsSub?.cancel();
    _categoriesSub?.cancel();
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<Product> get _filteredProducts {
    final base = _lockedProductId != null
        ? _products.items.where((p) => p.id == _lockedProductId).toList()
        : KatalogScreen.filterProductsByQuery(_products.items, _query);
    final cat = _desktopCategoryId?.trim();
    if (cat == null || cat.isEmpty) return base;
    return base.where((p) {
      final id = p.categoryId?.trim();
      final raw = p.category?.trim();
      return id == cat || raw == cat;
    }).toList();
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
        toolbarHeight: 0,
        bottom: TabBar(
          controller: _tabController,
          labelPadding: EdgeInsets.zero,
          labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          unselectedLabelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          tabs: [
            const Tab(height: 40, text: 'Mahsulotlar'),
            const Tab(height: 40, text: Strings.kategoriyalar),
            if (isDesktopPosLayout)
              const Tab(height: 40, text: Strings.barcodeChopEtish),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildProductsTab(products),
          _buildCategoriesTab(),
          if (isDesktopPosLayout) const DesktopBarcodePrintScreen(),
        ],
      ),
    );
  }

  Widget _buildProductsTab(List<Product> products) {
    if (isDesktopPosLayout) {
      return _buildDesktopProductsTab(products);
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
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
                  style: TextStyle(fontSize: isDesktopPosLayout ? 14 : 13),
                  decoration: InputDecoration(
                    isDense: !isDesktopPosLayout,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: isDesktopPosLayout ? 14 : 12,
                    ),
                    hintText: Strings.mahsulotQidirishHint,
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
              ),
              if (!isDesktopPosLayout) ...[
                const SizedBox(width: 8),
                _squareActionButton(
                  icon: Icons.qr_code_scanner_rounded,
                  onTap: () => _showScanner(context),
                ),
                const SizedBox(width: 8),
                _squareActionButton(
                  icon: Icons.add_rounded,
                  onTap: _openNewProduct,
                ),
              ],
            ],
          ),
        ),
        if (isDesktopPosLayout)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: SizedBox(
              width: double.infinity,
              height: 36,
              child: FilledButton.icon(
                onPressed: _openNewProduct,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text(
                  "Yangi mahsulot qo'shish",
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ),
        Expanded(
          child: ThrottledRefreshIndicator(
            onRefresh: _pullRefreshCatalog,
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

  Widget _buildDesktopProductsTab(List<Product> products) {
    final totalCount = _products.items.length;
    final shownCount = products.length;
    final categories = _categories.idNameOptions;
    final selectedCategoryName = () {
      if ((_desktopCategoryId ?? '').isEmpty) return 'Barcha Mahsulotlar';
      for (final row in categories) {
        if (row['id'] == _desktopCategoryId) {
          return (row['name'] as String?) ?? 'Barcha Mahsulotlar';
        }
      }
      return 'Barcha Mahsulotlar';
    }();

    Widget actionButton({
      required IconData icon,
      required String label,
      required VoidCallback onTap,
      bool primary = false,
    }) {
      final style = primary
          ? FilledButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            )
          : OutlinedButton.styleFrom(
              foregroundColor: AppTheme.textPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              side: const BorderSide(color: AppTheme.divider),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            );

      final child = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
        ],
      );

      return primary
          ? FilledButton(onPressed: onTap, style: style, child: child)
          : OutlinedButton(onPressed: onTap, style: style, child: child);
    }

    return ColoredBox(
      color: const Color(0xFFF8FAFC),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE8EDF5)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0A0F172A),
                    blurRadius: 18,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.inventory_2_outlined,
                            color: AppTheme.primary,
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Mahsulotlar',
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Mahsulotlarni boshqarish va kuzatish',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            actionButton(
                              icon: Icons.add_rounded,
                              label: Strings.qoShish,
                              onTap: _openNewProduct,
                              primary: true,
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _desktopFilterCard(
                            title: 'KATEGORIYALAR (${shownCount.toString()} / ${totalCount.toString()})',
                            child: Builder(
                              builder: (fieldContext) => InkWell(
                                onTap: () => _openDesktopCategoryDropdown(fieldContext, categories),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 15,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppTheme.divider),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          selectedCategoryName,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: AppTheme.textPrimary,
                                          ),
                                        ),
                                      ),
                                      const Icon(
                                        Icons.keyboard_arrow_down_rounded,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _desktopFilterCard(
                            title: 'QIDIRISH',
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
                              style: const TextStyle(fontSize: 14),
                              decoration: const InputDecoration(
                                hintText: 'Qidirish',
                                filled: false,
                                prefixIcon: Icon(
                                  Icons.search_rounded,
                                  color: AppTheme.textSecondary,
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 14,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: ThrottledRefreshIndicator(
              onRefresh: _pullRefreshCatalog,
              child: _products.loadError != null
                  ? SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      child: SizedBox(
                        height: MediaQuery.of(context).size.height * 0.6,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.error_outline_rounded,
                                  size: 56,
                                  color: Theme.of(context).colorScheme.error,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _products.loadError!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                TextButton.icon(
                                  onPressed: () => _products.loadFromApi(),
                                  icon: const Icon(Icons.refresh_rounded),
                                  label: const Text('Qayta yuklash'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    )
                  : !_products.isLoaded
                      ? SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          child: SizedBox(
                            height: MediaQuery.of(context).size.height * 0.6,
                            child: const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircularProgressIndicator(color: AppTheme.primary),
                                  SizedBox(height: 12),
                                  Text(
                                    'Mahsulotlar yuklanmoqda...',
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
                              physics: const AlwaysScrollableScrollPhysics(
                                parent: BouncingScrollPhysics(),
                              ),
                              child: SizedBox(
                                height: MediaQuery.of(context).size.height * 0.6,
                                child: const Center(
                                  child: Text(
                                    'Mahsulot topilmadi',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ),
                              ),
                            )
                          : DesktopCatalogProductTable(
                              products: products,
                              usdRate: SalesSessionProvider.instance.usdRate > 0
                                  ? SalesSessionProvider.instance.usdRate
                                  : 12600,
                              onProductTap: (p) {
                                final latest = _products.getProductById(p.id) ?? p;
                                _products.prefetchProductForDetail(latest);
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => MahsulotDetailScreen(product: latest),
                                  ),
                                );
                              },
                              onEdit: (p) async {
                                final saved = await Navigator.of(context).push<bool>(
                                  MaterialPageRoute(
                                    builder: (_) => YangiTovarScreen(product: p),
                                  ),
                                );
                                if (!mounted) return;
                                setState(() {});
                                if (saved == true) {
                                  AppNotify.success(null, "Tovar muvaffaqiyatli tahrirlandi!");
                                }
                              },
                              onDelete: (p) => _confirmDelete(context, p),
                              canDeleteProducts: UserPermissionsStore.instance.canDeleteProducts,
                            ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _desktopFilterCard({
    required String title,
    required Widget child,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.textSecondary,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }

  Future<void> _openDesktopCategoryDropdown(
    BuildContext anchorContext,
    List<Map<String, dynamic>> categories,
  ) async {
    final box = anchorContext.findRenderObject() as RenderBox?;
    if (box == null) return;
    final overlay = Overlay.of(anchorContext).context.findRenderObject() as RenderBox?;
    if (overlay == null) return;

    final topLeft = box.localToGlobal(Offset.zero, ancestor: overlay);
    final bottomRight = box.localToGlobal(box.size.bottomRight(Offset.zero), ancestor: overlay);
    final picked = await showMenu<String>(
      context: anchorContext,
      color: Colors.white,
      elevation: 8,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppTheme.divider),
      ),
      position: RelativeRect.fromRect(
        Rect.fromPoints(topLeft, bottomRight),
        Offset.zero & overlay.size,
      ),
      items: [
        PopupMenuItem<String>(
          value: '',
          child: Text(
            'Barcha Mahsulotlar',
            style: TextStyle(
              fontWeight: (_desktopCategoryId ?? '').isEmpty ? FontWeight.w700 : FontWeight.w500,
              color: (_desktopCategoryId ?? '').isEmpty ? AppTheme.primary : AppTheme.textPrimary,
            ),
          ),
        ),
        ...categories.map(
          (row) {
            final id = row['id'] as String;
            final selected = _desktopCategoryId == id;
            return PopupMenuItem<String>(
              value: id,
              child: Text(
                row['name'] as String,
                style: TextStyle(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? AppTheme.primary : AppTheme.textPrimary,
                ),
              ),
            );
          },
        ),
      ],
    );
    if (picked == null || !mounted) return;
    setState(() => _desktopCategoryId = picked.isEmpty ? null : picked);
  }

  Widget _buildCategoriesTab() {
    final list = _sortedCategoryRows;
    final loadError = _categories.loadError;
    if (isDesktopPosLayout) {
      return ColoredBox(
        color: const Color(0xFFF8FAFC),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE8EDF5)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0A0F172A),
                  blurRadius: 18,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              Strings.kategoriyalar,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Kategoriyalarni tartiblash va boshqarish',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: () => _showAddCategory(context),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text(
                          "Qo'shish",
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (loadError != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            loadError,
                            style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.error),
                          ),
                        ),
                        TextButton(
                          onPressed: () => _categories.loadFromApi(),
                          child: const Text('Qayta yuklash'),
                        ),
                      ],
                    ),
                  ),
                if (list.isNotEmpty)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(18, 8, 18, 0),
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
                Expanded(
                  child: ThrottledRefreshIndicator(
                    onRefresh: _pullRefreshCatalog,
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
                                  ],
                                ),
                              ),
                            ),
                          )
                        : ReorderableListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                            padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
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
                                    padding: const EdgeInsets.all(14),
                                    child: Row(
                                      children: [
                                        ReorderableDragStartListener(
                                          index: index,
                                          child: const Padding(
                                            padding: EdgeInsets.only(right: 10),
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
                                        PopupMenuButton<String>(
                                          tooltip: 'Amallar',
                                          color: Colors.white,
                                          elevation: 8,
                                          surfaceTintColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                            side: const BorderSide(color: AppTheme.divider),
                                          ),
                                          onSelected: (value) {
                                            if (value == 'edit') _showEditCategory(context, name);
                                            if (value == 'delete') _confirmDeleteCategory(context, name);
                                          },
                                          itemBuilder: (context) => const [
                                            PopupMenuItem<String>(
                                              value: 'edit',
                                              child: Text('Tahrirlash'),
                                            ),
                                            PopupMenuItem<String>(
                                              value: 'delete',
                                              child: Text("O'chirish"),
                                            ),
                                          ],
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
            ),
          ),
        ),
      );
    }

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
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
          child: SizedBox(
            width: double.infinity,
            height: 36,
            child: FilledButton.icon(
              onPressed: () => _showAddCategory(context),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text(
                "Yangi kategoriya qo'shish",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: ThrottledRefreshIndicator(
            onRefresh: _pullRefreshCatalog,
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
            if (UserPermissionsStore.instance.canDeleteProducts)
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
    if (!UserPermissionsStore.instance.canDeleteProducts) return;
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

  Widget _squareActionButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppTheme.primary,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(11),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }

  Future<void> _openNewProduct() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const YangiTovarScreen()),
    );
    if (!mounted) return;
    setState(() {});
    if (saved == true) {
      AppNotify.success(null, "Tovar muvaffaqiyatli qo'shildi!");
    }
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
