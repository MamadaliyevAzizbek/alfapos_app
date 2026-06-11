import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/input_formatters.dart';
import '../../core/theme.dart';
import '../../models/cart_item.dart';
import '../../models/product.dart';
import '../../widgets/pos_editable_focus_scope.dart';
import '../../utils/catalog_product_price_label.dart';
import '../../widgets/product_tile.dart';
import '../../widgets/reorderable_category_grid.dart';
import '../../services/desktop_sales_layout_settings.dart';
import 'sales_nav_filters.dart';

/// Windows / macOS POS: katalog chapda, savatcha o‘ngda (veb POS ko‘rinishi).
class SavatchaDesktopLayout extends StatelessWidget {
  static const Color _panelBg = Color(0xFFF0F2F5);
  static const Color _totalBar = Color(0xFF2D3446);
  static const Color _priceGreen = Color(0xFF16A34A);

  final TextEditingController searchController;
  final FocusNode? catalogSearchFocus;
  final VoidCallback? onCatalogSearchRefocus;
  final VoidCallback? onSuspendCatalogSearchRefocus;
  final VoidCallback? onPointerDownAnywhere;
  final String query;
  final List<Product> catalogProducts;
  final List<CartItem> cartItems;
  final bool productsLoading;
  final String? selectedCustomerName;
  final ValueChanged<String> onSearchChanged;
  final Future<void> Function(String) onSearchSubmitted;
  final VoidCallback onFilterTap;
  final String? categoryFilterId;
  final String? brandFilterId;
  final List<Map<String, dynamic>> filterCategories;
  final List<Map<String, dynamic>> filterBrands;
  final ValueChanged<String?> onCategoryFilterChanged;
  final ValueChanged<String?> onBrandFilterChanged;
  final Widget customerSearchSection;
  final VoidCallback onOpenSavedOrders;
  final int savedOrdersCount;
  final VoidCallback? onLoadMoreProducts;
  final List<Map<String, dynamic>> cashRegisters;
  final int? selectedCashRegisterId;
  final ValueChanged<Map<String, dynamic>>? onCashRegisterSelected;
  final bool showPurchasePriceOnCards;
  final bool showUsdEquivalentOnCards;
  final bool showSkuInProductTitle;
  /// `purchase` | `wholesale` — katalog kartochkasidagi asosiy narx.
  final String? catalogSellPriceType;
  final VoidCallback onClearCart;
  final void Function(Product product) onProductTap;
  final CartItem? expandedCartItem;
  final void Function(CartItem item) onToggleCartExpand;
  final VoidCallback onCollapseCartExpand;
  final void Function(CartItem item, num quantity) onCartQuantityChanged;
  final void Function(CartItem item, double? unitPriceOverride) onCartUnitPriceChanged;
  final void Function(CartItem item) onRemoveCartItem;
  final void Function(CartItem item) onIncrement;
  final void Function(CartItem item) onDecrement;
  final VoidCallback onPayment;
  final VoidCallback onDailyReport;
  final VoidCallback onDiscount;
  final TextEditingController discountPercentController;
  final ValueChanged<int> onDiscountPercentChanged;
  final VoidCallback onHoldCart;
  final bool holdCartInFlight;
  final VoidCallback? onSalesList;
  final VoidCallback? onOpenShiftDashboard;
  final VoidCallback? onLogout;
  final String cashRegisterLabel;
  final String sellerName;
  final int cartGrandTotal;
  final int cartCatalogTotal;
  final int cartDiscountPercent;
  final double usdExchangeRate;
  final bool isReturnMode;
  final ValueChanged<bool>? onReturnModeChanged;
  final DesktopSalesLayoutMode salesLayoutMode;
  final List<Map<String, dynamic>> restaurantCategories;
  final String? restaurantCategoryId;
  final ValueChanged<String?> onRestaurantCategorySelected;
  final VoidCallback onRestaurantCategoryBack;
  final int Function(String categoryId)? restaurantCategoryProductCount;
  final Future<void> Function(List<Map<String, dynamic>> reordered)? onRestaurantCategoriesReordered;
  final VoidCallback? onOpenSectionMenu;
  final VoidCallback? onGlobalSync;
  final bool globalSyncing;

  const SavatchaDesktopLayout({
    super.key,
    required this.searchController,
    this.catalogSearchFocus,
    this.onCatalogSearchRefocus,
    this.onSuspendCatalogSearchRefocus,
    this.onPointerDownAnywhere,
    required this.query,
    required this.catalogProducts,
    required this.cartItems,
    required this.productsLoading,
    this.selectedCustomerName,
    required this.onSearchChanged,
    required this.onSearchSubmitted,
    required this.onFilterTap,
    this.categoryFilterId,
    this.brandFilterId,
    this.filterCategories = const [],
    this.filterBrands = const [],
    required this.onCategoryFilterChanged,
    required this.onBrandFilterChanged,
    required this.customerSearchSection,
    required this.onOpenSavedOrders,
    this.savedOrdersCount = 0,
    this.onLoadMoreProducts,
    this.cashRegisters = const [],
    this.selectedCashRegisterId,
    this.onCashRegisterSelected,
    this.showPurchasePriceOnCards = false,
    this.showUsdEquivalentOnCards = false,
    this.showSkuInProductTitle = false,
    this.catalogSellPriceType,
    required this.onClearCart,
    required this.onProductTap,
    this.expandedCartItem,
    required this.onToggleCartExpand,
    required this.onCollapseCartExpand,
    required this.onCartQuantityChanged,
    required this.onCartUnitPriceChanged,
    required this.onRemoveCartItem,
    required this.onIncrement,
    required this.onDecrement,
    required this.onPayment,
    required this.onDailyReport,
    required this.onDiscount,
    required this.discountPercentController,
    required this.onDiscountPercentChanged,
    required this.onHoldCart,
    this.holdCartInFlight = false,
    this.onSalesList,
    this.onOpenShiftDashboard,
    this.onLogout,
    required this.cashRegisterLabel,
    required this.sellerName,
    required this.cartGrandTotal,
    this.cartCatalogTotal = 0,
    this.cartDiscountPercent = 0,
    this.usdExchangeRate = 12600,
    this.isReturnMode = false,
    this.onReturnModeChanged,
    this.salesLayoutMode = DesktopSalesLayoutMode.standard,
    this.restaurantCategories = const [],
    this.restaurantCategoryId,
    required this.onRestaurantCategorySelected,
    required this.onRestaurantCategoryBack,
    this.restaurantCategoryProductCount,
    this.onRestaurantCategoriesReordered,
    this.onOpenSectionMenu,
    this.onGlobalSync,
    this.globalSyncing = false,
  });

  int get _cartRawTotal => cartItems.fold<int>(0, (s, e) => s + e.total);

  Map<String, dynamic>? _selectedRegister() {
    if (cashRegisters.isEmpty) return null;
    if (selectedCashRegisterId == null) return cashRegisters.first;
    for (final r in cashRegisters) {
      final id = r['id'] ?? r['cash_register_id'];
      final n = id is int ? id : int.tryParse(id?.toString() ?? '');
      if (n == selectedCashRegisterId) return r;
    }
    return cashRegisters.first;
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _panelBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTopBar(context),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 6, child: _buildCatalogPanel(context)),
                Container(width: 1, color: AppTheme.divider),
                Expanded(flex: 4, child: _buildCartPanel(context)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static const Color _navBlue = AppTheme.primary;
  static const Color _navInactive = Color(0xFF64748B);

  ButtonStyle get _navLinkStyle => TextButton.styleFrom(
        foregroundColor: _navInactive,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      );

  Widget _buildTopBar(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppTheme.divider)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 1280;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildTopBarLeading(compact: compact),
              const SizedBox(width: 12),
              Expanded(
                child: SalesNavCategoryBrandFilters(
                  categoryId: categoryFilterId,
                  brandId: brandFilterId,
                  categories: filterCategories,
                  brands: filterBrands,
                  onCategoryChanged: onCategoryFilterChanged,
                  onBrandChanged: onBrandFilterChanged,
                  expand: true,
                ),
              ),
              const SizedBox(width: 12),
              _buildTopBarActions(compact: compact),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTopBarLeading({required bool compact}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onOpenSectionMenu != null) ...[
          IconButton(
            tooltip: 'Bo\'limlar',
            onPressed: onOpenSectionMenu,
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.menu_rounded, size: compact ? 24 : 26, color: AppTheme.textPrimary),
          ),
          SizedBox(width: compact ? 4 : 8),
        ],
        Text(
          "Sotuv bo'limi",
          style: TextStyle(
            fontSize: compact ? 16 : 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        SizedBox(width: compact ? 12 : 16),
        Icon(Icons.point_of_sale_rounded, color: _navBlue, size: compact ? 20 : 22),
        const SizedBox(width: 6),
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: compact ? 110 : 140),
          child: Text(
            cashRegisterLabel,
            style: TextStyle(
              fontSize: compact ? 14 : 15,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildTopBarActions({required bool compact}) {
    final linkStyle = compact
        ? _navLinkStyle.copyWith(
            padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 10, vertical: 10)),
            textStyle: WidgetStateProperty.all(const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          )
        : _navLinkStyle;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onReturnModeChanged != null) _buildPosModeNavCards(compact: compact),
        if (onOpenShiftDashboard != null)
          TextButton.icon(
            onPressed: onOpenShiftDashboard,
            style: linkStyle,
            icon: Icon(Icons.account_balance_wallet_outlined, size: compact ? 20 : 22, color: _navInactive),
            label: const Text('Kassa smenasi'),
          ),
        if (onSalesList != null)
          TextButton.icon(
            onPressed: onSalesList,
            style: linkStyle,
            icon: Icon(Icons.list_alt_rounded, size: compact ? 20 : 22, color: _navInactive),
            label: const Text("Sotish ro'yxati"),
          ),
        if (onGlobalSync != null)
          IconButton(
            tooltip: 'Sinxronlash',
            onPressed: globalSyncing ? null : onGlobalSync,
            icon: globalSyncing
                ? SizedBox(
                    width: compact ? 20 : 22,
                    height: compact ? 20 : 22,
                    child: const CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2563EB)),
                  )
                : Icon(Icons.sync_rounded, size: compact ? 22 : 24, color: const Color(0xFF2563EB)),
          ),
        if (onLogout != null)
          PopupMenuButton<String>(
            tooltip: 'Hisob',
            offset: const Offset(0, 48),
            color: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            icon: Icon(Icons.person_outline_rounded, color: _navBlue, size: compact ? 24 : 26),
            onSelected: (value) {
              if (value == 'logout') onLogout!();
            },
            itemBuilder: (context) => [
              const PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout_rounded, size: 20, color: AppTheme.textPrimary),
                    SizedBox(width: 10),
                    Text('Chiqish', style: TextStyle(fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildPosModeNavCards({bool compact = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _navModeCard(
          label: "Sotuv bo'limi",
          icon: Icons.shopping_cart_outlined,
          selected: !isReturnMode,
          onTap: () => onReturnModeChanged?.call(false),
          compact: compact,
        ),
        SizedBox(width: compact ? 8 : 12),
        _navModeCard(
          label: 'Qaytarishlar',
          icon: Icons.replay_rounded,
          selected: isReturnMode,
          onTap: () => onReturnModeChanged?.call(true),
          compact: compact,
        ),
      ],
    );
  }

  Widget _navModeCard({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
    bool compact = false,
  }) {
    if (selected) {
      return Material(
        elevation: 3,
        shadowColor: _navBlue.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(10),
        color: _navBlue,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: compact ? 14 : 16, vertical: compact ? 9 : 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white, size: compact ? 18 : 20),
                SizedBox(width: compact ? 6 : 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: compact ? 14 : 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return TextButton.icon(
      onPressed: onTap,
      style: compact
          ? _navLinkStyle.copyWith(
              padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 10, vertical: 10)),
            )
          : _navLinkStyle,
      icon: Icon(icon, size: compact ? 20 : 22, color: _navInactive),
      label: Text(label, style: TextStyle(fontSize: compact ? 14 : 15)),
    );
  }

  bool get _isRestaurantBrowse =>
      salesLayoutMode == DesktopSalesLayoutMode.restaurant &&
      query.trim().isEmpty &&
      restaurantCategoryId == null;

  bool get _isRestaurantCategoryView =>
      salesLayoutMode == DesktopSalesLayoutMode.restaurant &&
      query.trim().isEmpty &&
      restaurantCategoryId != null;

  String? _restaurantCategoryName() {
    final id = restaurantCategoryId;
    if (id == null) return null;
    for (final c in restaurantCategories) {
      if (c['id']?.toString() == id) {
        final name = c['name']?.toString().trim();
        if (name != null && name.isNotEmpty) return name;
      }
    }
    return null;
  }

  Widget _buildCatalogPanel(BuildContext context) {
    final initialLoading = productsLoading && catalogProducts.isEmpty && !_isRestaurantBrowse;
    final loadingMore = productsLoading && catalogProducts.isNotEmpty;
    final showCategoryGrid = _isRestaurantBrowse;
    final showProductGrid = !showCategoryGrid;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                flex: 5,
                child: TextField(
                  controller: searchController,
                  focusNode: catalogSearchFocus,
                  autofocus: catalogSearchFocus != null,
                  onChanged: onSearchChanged,
                  onSubmitted: onSearchSubmitted,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: "Mahsulotni qidirish - yoki - Shtrix kod",
                    filled: true,
                    fillColor: Colors.white,
                    prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textSecondary),
                    suffixIcon: query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded, size: 20),
                            onPressed: () {
                              searchController.clear();
                              onSearchChanged('');
                            },
                          )
                        : null,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppTheme.divider),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppTheme.primary, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _buildCatalogRegisterSelector(),
              const SizedBox(width: 8),
              _buildCatalogFilterButton(),
            ],
          ),
        ),
        if (_isRestaurantCategoryView)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                onTap: onRestaurantCategoryBack,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  child: Row(
                    children: [
                      const Icon(Icons.arrow_back_rounded, size: 22, color: AppTheme.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _restaurantCategoryName() ?? 'Kategoriya',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      TextButton(
                        onPressed: onRestaurantCategoryBack,
                        child: const Text('Orqaga'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        Expanded(
          child: showCategoryGrid
              ? _buildRestaurantCategoryGrid(context)
              : initialLoading
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                  : showProductGrid && catalogProducts.isEmpty
                      ? Center(
                          child: Text(
                            _isRestaurantCategoryView ? 'Bu kategoriyada mahsulot yo‘q' : 'Mahsulot topilmadi',
                            style: const TextStyle(fontSize: 16, color: AppTheme.textSecondary),
                          ),
                        )
                      : Stack(
                          children: [
                            NotificationListener<ScrollNotification>(
                              onNotification: (n) {
                                if (loadingMore || onLoadMoreProducts == null) return false;
                                if (n is ScrollEndNotification &&
                                    n.metrics.pixels >= n.metrics.maxScrollExtent - 120) {
                                  onLoadMoreProducts!();
                                }
                                return false;
                              },
                              child: GridView.builder(
                                key: ValueKey(
                                  'catalog-${query.trim()}-${categoryFilterId ?? ''}-${brandFilterId ?? ''}-${restaurantCategoryId ?? ''}',
                                ),
                                padding: EdgeInsets.fromLTRB(12, 0, 12, loadingMore ? 40 : 12),
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 4,
                                  mainAxisSpacing: 12,
                                  crossAxisSpacing: 12,
                                  childAspectRatio: 0.82,
                                ),
                                itemCount: catalogProducts.length,
                                itemBuilder: (context, i) => _DesktopProductCard(
                                  key: ValueKey(catalogProducts[i].id),
                                  product: catalogProducts[i],
                                  usdRate: usdExchangeRate,
                                  catalogSellPriceType: catalogSellPriceType,
                                  showPurchasePrice: showPurchasePriceOnCards,
                                  showUsdEquivalent: showUsdEquivalentOnCards,
                                  showSkuInTitle: showSkuInProductTitle,
                                  onTap: () => onProductTap(catalogProducts[i]),
                                ),
                              ),
                            ),
                            if (loadingMore)
                              const Positioned(
                                left: 0,
                                right: 0,
                                bottom: 8,
                                child: Center(
                                  child: SizedBox(
                                    width: 28,
                                    height: 28,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: AppTheme.primary,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
        ),
      ],
    );
  }

  Widget _buildCatalogRegisterSelector() {
    final register = _selectedRegister();
    final label = register != null
        ? (register['name'] ?? register['title'] ?? cashRegisterLabel).toString()
        : cashRegisterLabel;

    if (cashRegisters.length > 1 && onCashRegisterSelected != null) {
      return ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 140, maxWidth: 200),
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.divider),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<Map<String, dynamic>>(
              isExpanded: true,
              value: register,
              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.textSecondary),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
              items: cashRegisters
                  .map(
                    (r) => DropdownMenuItem(
                      value: r,
                      child: Text(
                        (r['name'] ?? r['title'] ?? 'Kassa').toString(),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (r) {
                if (r != null) onCashRegisterSelected!(r);
              },
            ),
          ),
        ),
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 140, maxWidth: 200),
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.divider),
        ),
        alignment: Alignment.centerLeft,
        child: Text(
          label,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildCatalogFilterButton() {
    return Material(
      color: const Color(0xFFEAF2FF),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onFilterTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF93C5FD), width: 1.3),
          ),
          child: const Icon(
            Icons.tune_rounded,
            size: 22,
            color: Color(0xFF1D4ED8),
          ),
        ),
      ),
    );
  }

  Widget _buildRestaurantCategoryGrid(BuildContext context) {
    final visible = restaurantCategories.where((c) {
      final id = c['id']?.toString();
      if (id == null || id.isEmpty) return false;
      final count = restaurantCategoryProductCount?.call(id);
      return count == null || count > 0;
    }).toList();

    return ReorderableCategoryGrid(
      categories: visible,
      productCount: restaurantCategoryProductCount,
      onCategorySelected: onRestaurantCategorySelected,
      onOrderChanged: (reordered) async {
        if (onRestaurantCategoriesReordered != null) {
          await onRestaurantCategoriesReordered!(reordered);
        }
      },
    );
  }

  Widget _buildCartPanel(BuildContext context) {
    return ColoredBox(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: customerSearchSection),
                    const SizedBox(width: 8),
                    Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        onTap: onClearCart,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 48,
                          height: 48,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Icon(Icons.delete_outline_rounded, size: 22, color: Colors.red.shade400),
                        ),
                      ),
                    ),
                  ],
                ),
                if (isReturnMode) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFFCC80)),
                    ),
                    child: const Text(
                      'Mahsulot tanlang va qaytarish qiling. Mijoz tanlab «Qarz» to\'lovi bilan qaytarilsa, qarzi kamayadi.',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF6D4C41)),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: cartItems.isEmpty
                ? const Center(
                    child: Text(
                      "Bo'sh Savat",
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w500, color: AppTheme.textSecondary),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: cartItems.length,
                    itemBuilder: (context, i) {
                      final line = cartItems[i];
                      return _DesktopCartLine(
                        item: line,
                        expanded: identical(expandedCartItem, line),
                        onToggleExpand: () => onToggleCartExpand(line),
                        onCollapse: onCollapseCartExpand,
                        onIncrement: () => onIncrement(line),
                        onDecrement: () => onDecrement(line),
                        onRemove: () => onRemoveCartItem(line),
                        onQuantityChanged: (q) => onCartQuantityChanged(line, q),
                        onUnitPriceChanged: (p) => onCartUnitPriceChanged(line, p),
                        onSuspendCatalogSearchRefocus: onSuspendCatalogSearchRefocus,
                      );
                    },
                  ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              color: _totalBar,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Text(
                  isReturnMode ? 'Qaytarish summasi' : 'Umumiy',
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (cartCatalogTotal > 0 && cartCatalogTotal != cartGrandTotal)
                      Text(
                        formatThousands(cartCatalogTotal),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 14,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    Text(
                      formatThousands(cartGrandTotal),
                      style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 14),
            child: SizedBox(
              height: 88,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!isReturnMode) _footerSavedOrdersAction(),
                  if (!isReturnMode)
                    _footerAction(
                      Icons.pause_circle_outline_rounded,
                      "To'xtatish",
                      cartItems.isEmpty || holdCartInFlight ? null : onHoldCart,
                      tooltip: holdCartInFlight ? 'Saqlanmoqda...' : 'Buyurtmani saqlash',
                      loading: holdCartInFlight,
                    ),
                  if (!isReturnMode) _footerAction(Icons.percent_rounded, 'Chegirma', onDiscount),
                  _footerAction(Icons.send_rounded, 'Kunlik hisobot', onDailyReport),
                  Expanded(
                    flex: 2,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Material(
                        color: isReturnMode ? const Color(0xFFE65100) : AppTheme.primary,
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          onTap: cartItems.isEmpty ? null : onPayment,
                          borderRadius: BorderRadius.circular(10),
                          child: Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  isReturnMode ? 'Qaytarish qilish' : "To'lov qilish",
                                  style: TextStyle(
                                    color: cartItems.isEmpty ? Colors.white54 : Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 17,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  isReturnMode
                                      ? Icons.assignment_return_rounded
                                      : Icons.keyboard_double_arrow_right_rounded,
                                  size: 26,
                                  color: cartItems.isEmpty ? Colors.white54 : Colors.white,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _footerSavedOrdersAction() {
    return Expanded(
      child: Tooltip(
        message: "Saqlangan buyurtmalar ro'yxati",
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onOpenSavedOrders,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(Icons.recycling_rounded, size: 28, color: AppTheme.textSecondary),
                      if (savedOrdersCount > 0)
                        Positioned(
                          right: -8,
                          top: -6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                            decoration: const BoxDecoration(
                              color: Color(0xFFE53935),
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              savedOrdersCount > 9 ? '9+' : '$savedOrdersCount',
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Savatcha',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _footerAction(
    IconData icon,
    String label,
    VoidCallback? onTap, {
    String? tooltip,
    bool loading = false,
  }) {
    final enabled = onTap != null && !loading;
    final fg = enabled ? AppTheme.textSecondary : AppTheme.textSecondary.withValues(alpha: 0.4);
    final content = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (loading)
                SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: fg),
                )
              else
                Icon(icon, size: 28, color: fg),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: fg),
              ),
            ],
          ),
        ),
      ),
    );
    return Expanded(
      child: tooltip != null ? Tooltip(message: tooltip, child: content) : content,
    );
  }
}

class _DesktopProductCard extends StatelessWidget {
  final Product product;
  final double usdRate;
  final String? catalogSellPriceType;
  final bool showPurchasePrice;
  final bool showUsdEquivalent;
  final bool showSkuInTitle;
  final VoidCallback onTap;

  const _DesktopProductCard({
    super.key,
    required this.product,
    required this.usdRate,
    this.catalogSellPriceType,
    this.showPurchasePrice = false,
    this.showUsdEquivalent = false,
    this.showSkuInTitle = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final qty = product.initialQuantity;
    final primary = CatalogProductPriceLabel.primary(
      product,
      sellType: catalogSellPriceType,
      usdRate: usdRate,
      showUsdEquivalent: showUsdEquivalent,
    );
    final purchase = showPurchasePrice ? _purchaseLabel(product) : null;

    return Material(
      color: Colors.white,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppTheme.divider),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return ProductTile.buildProductImageCover(
                    product,
                    width: constraints.maxWidth,
                    height: constraints.maxHeight,
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.inventory_2_outlined, size: 14, color: AppTheme.textSecondary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          showSkuInTitle ? product.nameWithSku : product.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              primary,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: SavatchaDesktopLayout._priceGreen,
                              ),
                            ),
                            if (purchase != null)
                              Text(
                                purchase,
                                style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                              ),
                          ],
                        ),
                      ),
                      Text(
                        '$qty',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String? _purchaseLabel(Product p) {
    final c = p.costPriceUzs;
    if (c == null || c <= 0) return null;
    return 'Kelish: ${formatThousands(c)}';
  }
}

class _DesktopCartLine extends StatefulWidget {
  final CartItem item;
  final bool expanded;
  final VoidCallback onToggleExpand;
  final VoidCallback onCollapse;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onRemove;
  final ValueChanged<num> onQuantityChanged;
  final ValueChanged<double?> onUnitPriceChanged;
  final VoidCallback? onSuspendCatalogSearchRefocus;

  const _DesktopCartLine({
    required this.item,
    required this.expanded,
    required this.onToggleExpand,
    required this.onCollapse,
    required this.onIncrement,
    required this.onDecrement,
    required this.onRemove,
    required this.onQuantityChanged,
    required this.onUnitPriceChanged,
    this.onSuspendCatalogSearchRefocus,
  });

  @override
  State<_DesktopCartLine> createState() => _DesktopCartLineState();
}

class _DesktopCartLineState extends State<_DesktopCartLine> {
  late final TextEditingController _qtyController;
  late final TextEditingController _priceController;
  late final FocusNode _qtyFocusNode;
  late final FocusNode _priceFocusNode;
  bool _inlineQtyEditing = false;

  @override
  void initState() {
    super.initState();
    _qtyController = TextEditingController(text: _qtyText(widget.item.quantity));
    _priceController = TextEditingController(text: formatThousands(widget.item.unitPriceDisplay));
    _qtyFocusNode = FocusNode();
    _priceFocusNode = FocusNode();
    _qtyFocusNode.addListener(_onEditFocusChange);
    _priceFocusNode.addListener(_onEditFocusChange);
  }

  void _onEditFocusChange() {
    if (_qtyFocusNode.hasFocus || _priceFocusNode.hasFocus) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_qtyFocusNode.hasFocus || _priceFocusNode.hasFocus) return;
      if (_inlineQtyEditing) _closeInlineQtyEdit();
      if (!widget.expanded) return;
      _commitQuantity();
      _commitPrice();
      widget.onCollapse();
    });
  }

  void _startInlineQtyEdit() {
    widget.onSuspendCatalogSearchRefocus?.call();
    _qtyController.text = _qtyText(widget.item.quantity);
    setState(() => _inlineQtyEditing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _qtyFocusNode.requestFocus();
    });
  }

  void _closeInlineQtyEdit() {
    _commitQuantity();
    if (mounted) setState(() => _inlineQtyEditing = false);
  }

  void _submitQuantityAndCollapse() {
    _commitQuantity();
    if (widget.expanded) widget.onCollapse();
  }

  void _submitPriceAndCollapse() {
    _commitPrice();
    if (widget.expanded) widget.onCollapse();
  }

  @override
  void didUpdateWidget(covariant _DesktopCartLine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_qtyFocusNode.hasFocus) {
      final q = _qtyText(widget.item.quantity);
      if (_qtyController.text != q) _qtyController.text = q;
    }
    if (!_priceFocusNode.hasFocus) {
      final p = formatThousands(widget.item.unitPriceDisplay);
      if (_priceController.text != p) _priceController.text = p;
    }
  }

  @override
  void dispose() {
    _qtyFocusNode.removeListener(_onEditFocusChange);
    _priceFocusNode.removeListener(_onEditFocusChange);
    _qtyController.dispose();
    _priceController.dispose();
    _qtyFocusNode.dispose();
    _priceFocusNode.dispose();
    super.dispose();
  }

  static String _qtyText(num q) {
    if (q == q.roundToDouble()) return '${q.round()}';
    return q.toString();
  }

  static num? _parseQty(String raw) {
    final t = raw.trim().replaceAll(' ', '').replaceAll(',', '.');
    if (t.isEmpty) return null;
    return num.tryParse(t);
  }

  void _applyQuantityInput(String raw, {bool resetIfInvalid = false}) {
    final q = _parseQty(raw);
    if (q == null || q <= 0) {
      if (resetIfInvalid) _qtyController.text = _qtyText(widget.item.quantity);
      return;
    }
    if (q != widget.item.quantity) widget.onQuantityChanged(q);
  }

  void _commitQuantity() => _applyQuantityInput(_qtyController.text, resetIfInvalid: true);

  Widget _buildInlineQuantityControl() {
    if (_inlineQtyEditing) {
      return SizedBox(
        width: 52,
        child: TextField(
          controller: _qtyController,
          focusNode: _qtyFocusNode,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
          ],
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: AppTheme.divider),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: AppTheme.divider),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
            ),
          ),
          onChanged: _applyQuantityInput,
          onSubmitted: (_) => _closeInlineQtyEdit(),
          onEditingComplete: _closeInlineQtyEdit,
        ),
      );
    }

    return GestureDetector(
      onTap: _startInlineQtyEdit,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Text(
          _qtyText(widget.item.quantity),
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
    );
  }

  void _applyPriceInput(String raw, {bool resetIfInvalid = false}) {
    final v = parseFormattedSum(raw);
    if (v == null || v < 0) {
      if (resetIfInvalid) _priceController.text = formatThousands(widget.item.unitPriceDisplay);
      return;
    }
    final def = widget.item.defaultLineUnitPrice.round();
    final override = v == def ? null : v.toDouble();
    final current = widget.item.salePriceOverride?.round();
    final next = override?.round();
    if (current != next) widget.onUnitPriceChanged(override);
  }

  void _commitPrice() => _applyPriceInput(_priceController.text, resetIfInvalid: true);

  InputDecoration get _inputDecoration => InputDecoration(
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppTheme.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppTheme.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
        ),
      );

  Widget _labeledField(String label, Widget field) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        field,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.item.product;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: PosEditableFocusScope(
        child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: widget.expanded ? AppTheme.primary.withValues(alpha: 0.35) : AppTheme.divider,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onToggleExpand,
                splashFactory: NoSplash.splashFactory,
                highlightColor: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.vertical(
                  top: const Radius.circular(8),
                  bottom: Radius.circular(widget.expanded ? 0 : 8),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 8, 8),
                  child: Row(
                    children: [
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                        icon: Icon(
                          widget.expanded ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_right_rounded,
                          color: AppTheme.textSecondary,
                        ),
                        onPressed: widget.onToggleExpand,
                      ),
                      Expanded(
                        child: Text(
                          p.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppTheme.textPrimary),
                        ),
                      ),
                      _qtyCircleButton(Icons.remove, widget.onDecrement),
                      _buildInlineQuantityControl(),
                      _qtyCircleButton(Icons.add, widget.onIncrement, primary: true),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 72,
                        child: Text(
                          formatThousands(widget.item.total),
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppTheme.textPrimary),
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppTheme.textSecondary),
                        onPressed: widget.onRemove,
                        tooltip: "O'chirish",
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (widget.expanded)
              Container(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(7)),
                  border: Border(top: BorderSide(color: AppTheme.divider)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _labeledField(
                        'Miqdori',
                        TextField(
                          controller: _qtyController,
                          focusNode: _qtyFocusNode,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
                          ],
                          decoration: _inputDecoration,
                          onChanged: _applyQuantityInput,
                          onSubmitted: (_) => _submitQuantityAndCollapse(),
                          onEditingComplete: _submitQuantityAndCollapse,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _labeledField(
                        'Chegirmali narx',
                        TextField(
                          controller: _priceController,
                          focusNode: _priceFocusNode,
                          keyboardType: TextInputType.number,
                          inputFormatters: [ThousandsInputFormatter()],
                          decoration: _inputDecoration,
                          onChanged: _applyPriceInput,
                          onSubmitted: (_) => _submitPriceAndCollapse(),
                          onEditingComplete: _submitPriceAndCollapse,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _qtyCircleButton(IconData icon, VoidCallback onPressed, {bool primary = false}) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 20, color: primary ? AppTheme.primary : AppTheme.textSecondary),
        ),
      ),
    );
  }
}
