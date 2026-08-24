import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/input_formatters.dart';
import '../../core/theme.dart';
import '../../models/cart_item.dart';
import '../../models/product.dart';
import '../../widgets/pos_editable_focus_scope.dart';
import '../../utils/catalog_product_price_label.dart';
import '../../utils/customer_group_discount.dart';
import '../../widgets/desktop_catalog_product_card.dart';
import '../../widgets/restaurant_category_chips.dart';
import '../../widgets/sales_shortcut_key_badge.dart';
import '../../widgets/sales_pos_search_field.dart';
import '../../services/app_data_sync.dart';
import '../../services/desktop_sales_layout_settings.dart';
import '../../services/product_display_settings.dart';
import '../../services/sales_keyboard_shortcuts_settings.dart';
import '../../services/sales_ui_scale_settings.dart';
import 'sales_nav_filters.dart';
import 'sales_window_tabs.dart';

/// Windows / macOS POS: katalog chapda, savatcha o‘ngda (veb POS ko‘rinishi).
class SavatchaDesktopLayout extends StatelessWidget {
  static const Color _panelBg = Color(0xFFF0F2F5);
  static const Color _totalBar = Color(0xFF3C3F4B);
  static const Color _priceGreen = Color(0xFF16A34A);
  static const Color _paymentBlue = Color(0xFF80A4FF);
  static const Color _paymentBlueActive = Color(0xFF3B6FE8);
  static const Color _chromeBorder = Color(0xFFDDE5F0);
  static const BorderRadius _sharp = BorderRadius.zero;
  static const double _navRadius = 8;
  static const BorderRadius _navCorners = BorderRadius.all(Radius.circular(_navRadius));

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
  final int cartQtyFocusNonce;
  final CartItem? cartQtyFocusItem;
  final void Function(CartItem item) onToggleCartExpand;
  final VoidCallback onCollapseCartExpand;
  final void Function(CartItem item, num quantity) onCartQuantityChanged;
  final void Function(CartItem item, double? unitPriceOverride) onCartUnitPriceChanged;
  final void Function(CartItem item, bool sellByPack) onCartSellByPackChanged;
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
  final bool showSalesList;
  final bool keepSalesListAlive;
  final Widget? salesListPanel;
  final VoidCallback? onOpenShiftDashboard;
  final VoidCallback? onLogout;
  final String cashRegisterLabel;
  final String sellerName;
  final int cartGrandTotal;
  final int cartCatalogTotal;
  final int cartProfitTotal;
  final bool showCartProfit;
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
  final int salesWindowCount;
  final int activeSalesWindowIndex;
  final ValueChanged<int>? onSalesWindowSelected;
  final VoidCallback? onAddSalesWindow;
  final bool canAddSalesWindow;
  final Map<SalesShortcutAction, String> shortcutKeys;

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
    this.cartQtyFocusNonce = 0,
    this.cartQtyFocusItem,
    required this.onToggleCartExpand,
    required this.onCollapseCartExpand,
    required this.onCartQuantityChanged,
    required this.onCartUnitPriceChanged,
    required this.onCartSellByPackChanged,
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
    this.showSalesList = false,
    this.keepSalesListAlive = false,
    this.salesListPanel,
    this.onOpenShiftDashboard,
    this.onLogout,
    required this.cashRegisterLabel,
    required this.sellerName,
    required this.cartGrandTotal,
    this.cartCatalogTotal = 0,
    this.cartProfitTotal = 0,
    this.showCartProfit = false,
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
    this.salesWindowCount = 1,
    this.activeSalesWindowIndex = 0,
    this.onSalesWindowSelected,
    this.onAddSalesWindow,
    this.canAddSalesWindow = false,
    this.shortcutKeys = SalesKeyboardShortcutsSettings.defaults,
  });

  String _shortcutLabel(SalesShortcutAction action) =>
      SalesKeyboardShortcutsSettings.resolveKeyLabel(shortcutKeys, action);

  int get _cartRawTotal => cartItems.fold<int>(0, (s, e) => s + e.total);

  String _cartProfitPercentLabel() {
    if (cartGrandTotal <= 0) return 'F: 0%';
    final pct = cartProfitTotal / cartGrandTotal * 100;
    final abs = pct.abs();
    final value = abs >= 10 ? pct.round().toString() : pct.toStringAsFixed(1);
    return 'F: $value%';
  }

  @override
  Widget build(BuildContext context) {
    return SalesUiScaleSettings.wrapUniformZoom(
      child: ColoredBox(
        color: _panelBg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTopBar(context),
            Expanded(
              child: _buildMainBody(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainBody(BuildContext context) {
    final catalogAndCart = Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(flex: 6, child: _buildCatalogPanel(context)),
        Container(width: 1, color: AppTheme.divider),
        Expanded(flex: 4, child: _buildCartPanel(context)),
      ],
    );
    if (salesListPanel == null || !keepSalesListAlive) {
      return showSalesList && salesListPanel != null ? salesListPanel! : catalogAndCart;
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        Offstage(offstage: showSalesList, child: catalogAndCart),
        Offstage(offstage: !showSalesList, child: salesListPanel),
      ],
    );
  }

  static const Color _navBlue = AppTheme.primary;
  static const Color _navInactive = Color(0xFF64748B);

  /// Qaytarish rejimida butun POS ekrani to‘q sariq urg‘uga o‘tadi (sotuvda — ko‘k).
  Color get _accent => isReturnMode ? AppTheme.returnAccent : _navBlue;

  Color get _cartPanelBg => isReturnMode ? AppTheme.returnPanelBg : Colors.white;

  Color get _totalBarColor => isReturnMode ? AppTheme.returnTotalBar : _totalBar;

  double get _navBtnHeight => SalesUiScaleSettings.navbarControlSize();

  double get _toolGap => SalesUiScaleSettings.navbarGap();

  Widget _buildTopBar(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppTheme.divider)),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: SalesUiScaleSettings.scaled(16.0),
        vertical: SalesUiScaleSettings.scaled(10.0),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 1280;
          final gap = SalesUiScaleSettings.navbarGap();
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildTopBarLeading(compact: compact),
              SizedBox(width: gap),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (!_isRestaurantMode) ...[
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
                      if (onSalesWindowSelected != null && onAddSalesWindow != null)
                        SizedBox(width: gap),
                    ],
                    if (onSalesWindowSelected != null && onAddSalesWindow != null)
                      SalesWindowTabs(
                        windowCount: salesWindowCount,
                        activeIndex: activeSalesWindowIndex,
                        onWindowSelected: onSalesWindowSelected!,
                        onAddWindow: onAddSalesWindow!,
                        canAddWindow: canAddSalesWindow,
                        accentColor: _accent,
                      ),
                  ],
                ),
              ),
              SizedBox(width: gap),
              _buildTopBarActions(compact: compact),
            ],
          );
        },
      ),
    );
  }

  Widget _navSquareIconButton({
    required String tooltip,
    required VoidCallback? onPressed,
    required Widget icon,
  }) {
    return SizedBox(
      width: _navBtnHeight,
      height: _navBtnHeight,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        style: IconButton.styleFrom(
          foregroundColor: _accent,
          shape: const RoundedRectangleBorder(borderRadius: _navCorners),
          side: const BorderSide(color: _chromeBorder),
          backgroundColor: Colors.white,
        ),
        icon: icon,
      ),
    );
  }

  Widget _buildTopBarLeading({required bool compact}) {
    if (onOpenSectionMenu == null) return const SizedBox.shrink();
    return _navSquareIconButton(
      tooltip: 'Bo\'limlar',
      onPressed: onOpenSectionMenu,
      icon: Icon(Icons.menu_rounded, size: SalesUiScaleSettings.navbarIconSize(), color: _accent),
    );
  }

  Widget _buildTopBarActions({required bool compact}) {
    final gap = SalesUiScaleSettings.navbarGap();
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (onReturnModeChanged != null) _buildPosModeNavCards(compact: compact),
        if (onSalesList != null) ...[
          SizedBox(width: gap),
          _navModeCard(
            label: "Sotish ro'yxati",
            icon: Icons.list_alt_rounded,
            selected: showSalesList,
            onTap: onSalesList!,
            compact: compact,
          ),
        ],
        if (onOpenShiftDashboard != null) ...[
          SizedBox(width: gap),
          SizedBox(
            height: _navBtnHeight,
            child: OutlinedButton.icon(
              onPressed: onOpenShiftDashboard,
              style: OutlinedButton.styleFrom(
                foregroundColor: _navInactive,
                backgroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  horizontal: SalesUiScaleSettings.scaled(compact ? 12 : 14),
                ),
                minimumSize: Size(0, _navBtnHeight),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                side: const BorderSide(color: _chromeBorder),
                shape: const RoundedRectangleBorder(borderRadius: _navCorners),
              ),
              icon: Icon(Icons.point_of_sale_outlined, size: SalesUiScaleSettings.navbarIconSize(), color: _navInactive),
              label: Text(
                cashRegisterLabel,
                style: TextStyle(
                  fontSize: SalesUiScaleSettings.scaled(compact ? 14 : 15),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
        if (onGlobalSync != null) ...[
          SizedBox(width: gap),
          ValueListenableBuilder<int>(
            valueListenable: AppDataSync.forceCooldownSeconds,
            builder: (context, left, _) {
              final cooling = left > 0;
              return _navSquareIconButton(
                tooltip: cooling ? 'Sinxronlash ($left s)' : 'Sinxronlash',
                onPressed: (globalSyncing || cooling) ? null : onGlobalSync,
                icon: globalSyncing
                    ? SizedBox(
                        width: SalesUiScaleSettings.navbarIconSize(),
                        height: SalesUiScaleSettings.navbarIconSize(),
                        child: CircularProgressIndicator(strokeWidth: 2, color: _accent),
                      )
                    : Icon(Icons.sync_rounded, size: SalesUiScaleSettings.navbarIconSize(), color: _accent),
              );
            },
          ),
        ],
        if (onLogout != null) ...[
          SizedBox(width: gap),
          SizedBox(
            width: _navBtnHeight,
            height: _navBtnHeight,
            child: PopupMenuButton<String>(
              tooltip: 'Hisob',
              offset: Offset(0, _navBtnHeight + 4),
              color: Colors.white,
              shape: const RoundedRectangleBorder(borderRadius: _navCorners),
              padding: EdgeInsets.zero,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: _navCorners,
                  border: Border.all(color: _chromeBorder),
                ),
                child: Center(
                  child: Icon(
                    Icons.person_outline_rounded,
                    color: _accent,
                    size: SalesUiScaleSettings.navbarIconSize(),
                  ),
                ),
              ),
              onSelected: (value) {
                if (value == 'logout') onLogout?.call();
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
          ),
        ],
      ],
    );
  }

  Widget _buildPosModeNavCards({bool compact = false}) {
    final gap = SalesUiScaleSettings.navbarGap();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _navModeCard(
          label: "Sotuv bo'limi",
          icon: Icons.shopping_cart_outlined,
          selected: !isReturnMode && !showSalesList,
          onTap: () => onReturnModeChanged?.call(false),
          compact: compact,
        ),
        SizedBox(width: gap),
        _navModeCard(
          label: 'Qaytarishlar',
          icon: Icons.replay_rounded,
          selected: isReturnMode && !showSalesList,
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
    final fontSize = SalesUiScaleSettings.scaled(compact ? 14 : 15);
    if (selected) {
      return SizedBox(
        height: _navBtnHeight,
        child: Material(
          elevation: 0,
          borderRadius: _navCorners,
          color: _accent,
          child: InkWell(
            onTap: onTap,
            borderRadius: _navCorners,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: SalesUiScaleSettings.scaled(compact ? 14 : 16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: Colors.white, size: SalesUiScaleSettings.navbarIconSize()),
                  SizedBox(width: SalesUiScaleSettings.scaled(compact ? 6 : 8)),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: _navBtnHeight,
      child: OutlinedButton.icon(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: _navInactive,
          backgroundColor: Colors.white,
          padding: EdgeInsets.symmetric(
            horizontal: SalesUiScaleSettings.scaled(compact ? 12 : 14),
          ),
          minimumSize: Size(0, _navBtnHeight),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          side: const BorderSide(color: _chromeBorder),
          shape: const RoundedRectangleBorder(borderRadius: _navCorners),
        ),
        icon: Icon(icon, size: SalesUiScaleSettings.navbarIconSize(), color: _navInactive),
        label: Text(
          label,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            color: _navInactive,
          ),
        ),
      ),
    );
  }

  bool get _isRestaurantMode => salesLayoutMode == DesktopSalesLayoutMode.restaurant;

  bool get _showRestaurantCategoryChips => _isRestaurantMode && query.trim().isEmpty;

  Widget _buildCatalogPanel(BuildContext context) {
    final initialLoading = productsLoading && catalogProducts.isEmpty;
    final loadingMore = productsLoading && catalogProducts.isNotEmpty;
    final isRestaurant = _isRestaurantMode;
    final crossAxisCount = SalesUiScaleSettings.catalogCrossAxisCount(
      ProductDisplaySettings.catalogGridColumns.value,
    );
    final spacing = SalesUiScaleSettings.scaled(isRestaurant ? 8.0 : 12.0);
    final edgePad = SalesUiScaleSettings.scaled(12.0);
    final gap = _toolGap;
    final h = SalesPosSearchField.height;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(edgePad, edgePad, edgePad, SalesUiScaleSettings.scaled(8.0)),
          child: SizedBox(
            height: h,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: SalesPosSearchField(
                    fieldKey: const ValueKey('desktop-catalog-search'),
                    controller: searchController,
                    focusNode: catalogSearchFocus,
                    hintText: "Mahsulotni qidirish - yoki - Shtrix kod",
                    prefixIcon: Icons.search_rounded,
                    onChanged: onSearchChanged,
                    onSubmitted: onSearchSubmitted,
                    shortcutKeyLabel: _shortcutLabel(SalesShortcutAction.focusProductSearch),
                    accentColor: _accent,
                  ),
                ),
                SizedBox(width: gap),
                _buildCatalogFilterButton(),
              ],
            ),
          ),
        ),
        if (_showRestaurantCategoryChips)
          RestaurantCategoryChips(
            categories: restaurantCategories,
            selectedCategoryId: restaurantCategoryId,
            onCategorySelected: onRestaurantCategorySelected,
            productCount: restaurantCategoryProductCount,
          ),
        Expanded(
          child: initialLoading
              ? Center(child: CircularProgressIndicator(color: _accent))
              : catalogProducts.isEmpty
                  ? Center(
                      child: Text(
                        _showRestaurantCategoryChips && restaurantCategoryId != null
                            ? 'Bu kategoriyada mahsulot yo‘q'
                            : 'Mahsulot topilmadi',
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
                              'catalog-${query.trim()}-${categoryFilterId ?? ''}-${brandFilterId ?? ''}-${restaurantCategoryId ?? ''}-$crossAxisCount',
                            ),
                            padding: EdgeInsets.fromLTRB(
                              edgePad,
                              0,
                              edgePad,
                              loadingMore ? SalesUiScaleSettings.scaled(40.0) : edgePad,
                            ),
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxisCount,
                              mainAxisSpacing: spacing,
                              crossAxisSpacing: spacing,
                              childAspectRatio: isRestaurant ? 0.76 : 0.82,
                            ),
                            itemCount: catalogProducts.length,
                            itemBuilder: (context, i) => DesktopCatalogProductCard(
                              key: ValueKey(catalogProducts[i].id),
                              product: catalogProducts[i],
                              usdRate: usdExchangeRate,
                              catalogSellPriceType: catalogSellPriceType,
                              showPurchasePrice: showPurchasePriceOnCards,
                              showUsdEquivalent: showUsdEquivalentOnCards,
                              showSkuInTitle: showSkuInProductTitle,
                              compact: salesLayoutMode == DesktopSalesLayoutMode.restaurant,
                              onTap: () => onProductTap(catalogProducts[i]),
                            ),
                          ),
                        ),
                        if (loadingMore)
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 8,
                            child: Center(
                              child: SizedBox(
                                width: 28,
                                height: 28,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: _accent,
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

  Widget _buildCatalogFilterButton() {
    return SalesPosToolbarIconButton(
      icon: Icons.tune_rounded,
      iconColor: _accent,
      onTap: onFilterTap,
      tooltip: 'Filtr',
      badge: _isRestaurantMode
          ? null
          : SalesShortcutKeyBadge(
              label: _shortcutLabel(SalesShortcutAction.toggleShowPurchasePrice),
            ),
    );
  }

  Widget _buildCartPanel(BuildContext context) {
    final edgePad = SalesUiScaleSettings.scaled(12.0);
    final gap = _toolGap;
    final h = SalesPosSearchField.height;
    final headerBottom = SalesUiScaleSettings.scaled(8.0);

    Widget cartBody() {
      if (cartItems.isEmpty) {
        return const Center(
          child: Text(
            "Bo'sh Savat",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w500, color: AppTheme.textSecondary),
          ),
        );
      }
      return ListView.builder(
        padding: EdgeInsets.fromLTRB(edgePad, 0, edgePad, edgePad),
        itemCount: cartItems.length,
        itemBuilder: (context, i) {
          final line = cartItems[i];
          return _DesktopCartLine(
            item: line,
            expanded: identical(expandedCartItem, line),
            qtyFocusNonce: cartQtyFocusNonce,
            isQtyFocusTarget: identical(cartQtyFocusItem, line),
            showUsdEquivalent: showUsdEquivalentOnCards,
            usdRate: usdExchangeRate,
            onToggleExpand: () => onToggleCartExpand(line),
            onCollapse: onCollapseCartExpand,
            onIncrement: () => onIncrement(line),
            onDecrement: () => onDecrement(line),
            onRemove: () => onRemoveCartItem(line),
            onQuantityChanged: (q) => onCartQuantityChanged(line, q),
            onUnitPriceChanged: (p) => onCartUnitPriceChanged(line, p),
            onSellByPackChanged: (pack) => onCartSellByPackChanged(line, pack),
            onSuspendCatalogSearchRefocus: onSuspendCatalogSearchRefocus,
            accent: _accent,
          );
        },
      );
    }

    return ColoredBox(
      color: _cartPanelBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Qidiruv card ichida; dropdown ochilganda layoutda joy oladi (bosiladi).
          Padding(
            padding: EdgeInsets.fromLTRB(edgePad, edgePad, edgePad, headerBottom),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: customerSearchSection),
                SizedBox(width: gap),
                SizedBox(
                  height: h,
                  child: SalesPosToolbarIconButton(
                    icon: Icons.delete_outline_rounded,
                    iconColor: Colors.red.shade400,
                    borderColor: Colors.red.shade200,
                    onTap: onClearCart,
                    tooltip: 'Savatni tozalash',
                  ),
                ),
              ],
            ),
          ),
          if (cartItems.isNotEmpty)
            Padding(
              padding: EdgeInsets.fromLTRB(edgePad, 0, edgePad, SalesUiScaleSettings.scaled(2.0)),
              child: Align(
                alignment: Alignment.centerRight,
                child: SalesShortcutKeyBadge(
                  label: _shortcutLabel(SalesShortcutAction.focusLastCartQty),
                ),
              ),
            ),
          Expanded(child: cartBody()),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            color: _totalBarColor,
            child: Row(
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      isReturnMode ? 'Qaytarish summasi' : 'Umumiy',
                      style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600),
                    ),
                    if (!isReturnMode) ...[
                      const SizedBox(width: 6),
                      SalesShortcutKeyBadge(
                        label: _shortcutLabel(SalesShortcutAction.toggleShowCartProfit),
                        onDark: true,
                      ),
                    ],
                  ],
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (cartCatalogTotal > 0 && cartCatalogTotal != cartGrandTotal)
                      CatalogProductPriceLabel.text(
                        CatalogProductPriceLabel.somWithOptionalUsd(
                          cartCatalogTotal,
                          usdRate: usdExchangeRate,
                          showUsdEquivalent: showUsdEquivalentOnCards,
                        ),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 14,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: CatalogProductPriceLabel.text(
                        CatalogProductPriceLabel.somWithOptionalUsd(
                          cartGrandTotal,
                          usdRate: usdExchangeRate,
                          showUsdEquivalent: showUsdEquivalentOnCards,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.visible,
                        style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (showCartProfit && !isReturnMode) ...[
                      const SizedBox(height: 2),
                      Text(
                        _cartProfitPercentLabel(),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.78),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          ColoredBox(
            color: Colors.white,
            child: SizedBox(
              height: 84,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!isReturnMode) ...[
                    _footerSavedOrdersAction(),
                    _footerDivider(),
                    _footerAction(
                      Icons.pause_rounded,
                      "To'xtatish",
                      cartItems.isEmpty || holdCartInFlight ? null : onHoldCart,
                      tooltip: holdCartInFlight ? 'Saqlanmoqda...' : 'Buyurtmani saqlash',
                      loading: holdCartInFlight,
                    ),
                    _footerDivider(),
                  ],
                  // Chegirma qaytarishda ham kerak — qaytarish chegirmali narxda bo‘ladi.
                  _footerAction(
                    Icons.percent_rounded,
                    'Chegirma',
                    onDiscount,
                    iconColor: isReturnMode ? AppTheme.returnAccent : null,
                  ),
                  _footerDivider(),
                  _footerAction(
                    Icons.send_outlined,
                    'Kunlik hisobot',
                    onDailyReport,
                    iconColor: const Color(0xFF26A69A),
                  ),
                  Expanded(
                    flex: 2,
                    child: _footerPaymentButton(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _footerDivider() => const ColoredBox(
        color: Color(0xFFE2E8F0),
        child: SizedBox(width: 1),
      );

  Widget _footerPaymentButton() {
    final enabled = cartItems.isNotEmpty;
    final Color bg;
    if (isReturnMode) {
      bg = enabled ? AppTheme.returnAccent : AppTheme.returnAccentDisabled;
    } else {
      bg = enabled ? _paymentBlueActive : _paymentBlue;
    }
    final fg = enabled ? Colors.white : Colors.white54;

    return Material(
      color: bg,
      child: InkWell(
        onTap: enabled ? onPayment : null,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: fg, width: 2),
              ),
              child: Icon(
                isReturnMode ? Icons.assignment_return_rounded : Icons.keyboard_double_arrow_right_rounded,
                size: 20,
                color: fg,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isReturnMode ? 'Qaytarish qilish' : "To'lov qilish",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: fg,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _footerSavedOrdersAction() {
    return Expanded(
      child: Tooltip(
        message: "Saqlangan buyurtmalar ro'yxati",
        child: Material(
          color: Colors.white,
          child: InkWell(
            onTap: onOpenSavedOrders,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(Icons.recycling_rounded, size: 26, color: AppTheme.primary),
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
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppTheme.textSecondary),
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
    Color? iconColor,
  }) {
    final enabled = onTap != null && !loading;
    final fg = iconColor ?? (enabled ? AppTheme.textSecondary : AppTheme.textSecondary.withValues(alpha: 0.4));
    final textFg = enabled ? AppTheme.textSecondary : AppTheme.textSecondary.withValues(alpha: 0.4);
    final content = Material(
      color: Colors.white,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (loading)
                SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: textFg),
                )
              else
                Icon(icon, size: 26, color: fg),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: textFg),
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

class _DesktopCartLine extends StatefulWidget {
  final CartItem item;
  final bool expanded;
  final int qtyFocusNonce;
  final bool isQtyFocusTarget;
  final bool showUsdEquivalent;
  final double usdRate;
  final VoidCallback onToggleExpand;
  final VoidCallback onCollapse;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onRemove;
  final ValueChanged<num> onQuantityChanged;
  final ValueChanged<double?> onUnitPriceChanged;
  final ValueChanged<bool> onSellByPackChanged;
  final VoidCallback? onSuspendCatalogSearchRefocus;

  /// Sotuvda ko‘k, qaytarishda to‘q sariq.
  final Color accent;

  const _DesktopCartLine({
    required this.item,
    required this.expanded,
    this.qtyFocusNonce = 0,
    this.isQtyFocusTarget = false,
    this.showUsdEquivalent = false,
    this.usdRate = 12600,
    required this.onToggleExpand,
    required this.onCollapse,
    required this.onIncrement,
    required this.onDecrement,
    required this.onRemove,
    required this.onQuantityChanged,
    required this.onUnitPriceChanged,
    required this.onSellByPackChanged,
    this.onSuspendCatalogSearchRefocus,
    this.accent = AppTheme.primary,
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
  bool _inlinePriceEditing = false;
  bool _qtyToPriceFocusTransition = false;

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
    if (_qtyToPriceFocusTransition) return;
    if (_qtyFocusNode.hasFocus || _priceFocusNode.hasFocus) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_qtyToPriceFocusTransition) return;
      if (_qtyFocusNode.hasFocus || _priceFocusNode.hasFocus) return;
      if (_inlineQtyEditing) _closeInlineQtyEdit();
      if (_inlinePriceEditing) _closeInlinePriceEdit();
      if (!widget.expanded) return;
      _commitQuantity();
      _commitPrice();
      widget.onCollapse();
    });
  }

  void _startInlineQtyEdit({bool selectAll = false}) {
    if (_inlinePriceEditing) _closeInlinePriceEdit();
    widget.onSuspendCatalogSearchRefocus?.call();
    _qtyController.text = _qtyText(widget.item.quantity);
    setState(() => _inlineQtyEditing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _qtyFocusNode.requestFocus();
      if (selectAll) {
        _qtyController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _qtyController.text.length,
        );
      }
    });
  }

  void _closeInlineQtyEdit() {
    _commitQuantity();
    if (mounted) setState(() => _inlineQtyEditing = false);
  }

  void _startInlinePriceEdit() {
    if (_inlineQtyEditing) _closeInlineQtyEdit();
    widget.onSuspendCatalogSearchRefocus?.call();
    _priceController.text = formatThousands(widget.item.unitPriceDisplay);
    setState(() => _inlinePriceEditing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _priceFocusNode.requestFocus();
    });
  }

  void _closeInlinePriceEdit() {
    _commitPrice();
    if (mounted) setState(() => _inlinePriceEditing = false);
  }

  @override
  void didUpdateWidget(covariant _DesktopCartLine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isQtyFocusTarget &&
        widget.qtyFocusNonce != oldWidget.qtyFocusNonce &&
        widget.qtyFocusNonce > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _startInlineQtyEdit(selectAll: true);
      });
    }
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
    if (q == widget.item.quantity) return;
    widget.onQuantityChanged(q);
    // Ombor cheklovi miqdorni qisqartirishi mumkin — maydon fokusda bo‘lgani
    // uchun `didUpdateWidget` uni yangilamaydi, shuning uchun o‘zimiz sinxronlaymiz.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final applied = _qtyText(widget.item.quantity);
      if (_qtyController.text == applied) return;
      _qtyController.text = applied;
      _qtyController.selection = TextSelection.collapsed(offset: applied.length);
    });
  }

  void _commitQuantity() => _applyQuantityInput(_qtyController.text, resetIfInvalid: true);

  void _moveFromQuantityToPrice() {
    _qtyToPriceFocusTransition = true;
    _commitQuantity();
    _priceController.text = formatThousands(widget.item.unitPriceDisplay);
    setState(() {
      _inlineQtyEditing = false;
      _inlinePriceEditing = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _priceFocusNode.requestFocus();
      _qtyToPriceFocusTransition = false;
    });
  }

  Widget _buildInlineQuantityControl({bool tight = false}) {
    if (_inlineQtyEditing) {
      return SizedBox(
        width: tight ? 40 : 48,
        child: Focus(
          onKeyEvent: (node, event) {
            if (event is! KeyDownEvent) return KeyEventResult.ignored;
            if (event.logicalKey != LogicalKeyboardKey.tab ||
                HardwareKeyboard.instance.isShiftPressed) {
              return KeyEventResult.ignored;
            }
            _moveFromQuantityToPrice();
            return KeyEventResult.handled;
          },
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
              border: const OutlineInputBorder(
                borderRadius: SavatchaDesktopLayout._sharp,
                borderSide: BorderSide(color: AppTheme.divider),
              ),
              enabledBorder: const OutlineInputBorder(
                borderRadius: SavatchaDesktopLayout._sharp,
                borderSide: BorderSide(color: AppTheme.divider),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: SavatchaDesktopLayout._sharp,
                borderSide: BorderSide(color: widget.accent, width: 1.5),
              ),
            ),
            onChanged: _applyQuantityInput,
            onSubmitted: (_) => _closeInlineQtyEdit(),
            onEditingComplete: _closeInlineQtyEdit,
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: _startInlineQtyEdit,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: tight ? 4 : 6, vertical: 4),
        child: Text(
          _qtyText(widget.item.quantity),
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: tight ? 14 : 15),
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

  void _selectCatalogPriceType(String priceType) {
    final catalogPrice = CustomerGroupDiscount.catalogUnitPriceForItem(widget.item, priceType);
    final def = widget.item.defaultLineUnitPrice.round();
    final v = catalogPrice.round();
    final override = v == def ? null : catalogPrice.toDouble();
    widget.onUnitPriceChanged(override);
    if (!_priceFocusNode.hasFocus) {
      _priceController.text = formatThousands(widget.item.unitPriceDisplay);
    }
  }

  bool _isActiveCatalogPrice(num catalogPrice) {
    return (widget.item.unitPriceDisplay - catalogPrice).abs() < 0.5;
  }

  String? _activeCatalogPriceType() {
    const types = [
      CustomerGroupDiscount.selling,
      CustomerGroupDiscount.wholesale,
    ];
    for (final type in types) {
      final price = CustomerGroupDiscount.catalogUnitPriceForItem(widget.item, type);
      if (_isActiveCatalogPrice(price)) return type;
    }
    return null;
  }

  String _displaySom(num som) => CatalogProductPriceLabel.somWithOptionalUsd(
        som,
        usdRate: widget.usdRate,
        showUsdEquivalent: widget.showUsdEquivalent,
      );

  Widget _oneLineAmount(String text, {double fontSize = 14}) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerRight,
      child: CatalogProductPriceLabel.text(
        text,
        maxLines: 1,
        overflow: TextOverflow.visible,
        softWrap: false,
        textAlign: TextAlign.right,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: fontSize,
          height: 1.1,
          color: AppTheme.textPrimary,
        ),
      ),
    );
  }

  Widget _buildLinePriceAndTotal({required bool tight}) {
    final fontSize = tight ? 13.0 : 14.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildInlinePriceControl(tight: tight),
        SizedBox(width: tight ? 6 : 8),
        _oneLineAmount(_displaySom(widget.item.total), fontSize: fontSize),
      ],
    );
  }

  Widget _buildInlinePriceControl({bool tight = false}) {
    if (_inlinePriceEditing) {
      return SizedBox(
        width: tight ? 84 : 96,
        child: TextField(
          controller: _priceController,
          focusNode: _priceFocusNode,
          keyboardType: TextInputType.number,
          inputFormatters: [ThousandsInputFormatter()],
          textAlign: TextAlign.right,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            filled: true,
            fillColor: Colors.white,
            border: const OutlineInputBorder(
              borderRadius: SavatchaDesktopLayout._sharp,
              borderSide: BorderSide(color: AppTheme.divider),
            ),
            enabledBorder: const OutlineInputBorder(
              borderRadius: SavatchaDesktopLayout._sharp,
              borderSide: BorderSide(color: AppTheme.divider),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: SavatchaDesktopLayout._sharp,
              borderSide: BorderSide(color: widget.accent, width: 1.5),
            ),
          ),
          onChanged: _applyPriceInput,
          onSubmitted: (_) => _closeInlinePriceEdit(),
          onEditingComplete: _closeInlinePriceEdit,
        ),
      );
    }

    return GestureDetector(
      onTap: _startInlinePriceEdit,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: tight ? 2 : 4, vertical: 4),
        child:         _oneLineAmount(
          _displaySom(widget.item.unitPriceDisplay),
          fontSize: tight ? 13 : 14,
        ),
      ),
    );
  }

  CartItem _probeSellByPack(bool sellByPack) {
    return CartItem(product: widget.item.product, sellByPack: sellByPack);
  }

  num _catalogPriceForSellByPack(bool sellByPack) {
    final type = _activeCatalogPriceType() ?? CustomerGroupDiscount.selling;
    return CustomerGroupDiscount.catalogUnitPriceForItem(_probeSellByPack(sellByPack), type);
  }

  Widget _buildSellUnitPicker() {
    final p = widget.item.product;
    if (!p.canSellByPack) return const SizedBox.shrink();

    return Row(
      children: [
        Expanded(
          child: _catalogPriceTypeChip(
            label: 'Dona',
            price: _catalogPriceForSellByPack(false),
            selected: !widget.item.sellByPack,
            onTap: () => widget.onSellByPackChanged(false),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _catalogPriceTypeChip(
            label: 'Pachka (${p.quantityPerPack})',
            price: _catalogPriceForSellByPack(true),
            selected: widget.item.sellByPack,
            onTap: () => widget.onSellByPackChanged(true),
          ),
        ),
      ],
    );
  }

  Widget _buildCatalogPriceTypePicker() {
    const types = <({String type, String label})>[
      (type: CustomerGroupDiscount.selling, label: 'Sotish'),
      (type: CustomerGroupDiscount.wholesale, label: 'Ulgurji'),
    ];
    final activeType = _activeCatalogPriceType();

    return Row(
      children: [
        for (var i = 0; i < types.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: _catalogPriceTypeChip(
              label: types[i].label,
              price: CustomerGroupDiscount.catalogUnitPriceForItem(widget.item, types[i].type),
              selected: types[i].type == activeType,
              onTap: () => _selectCatalogPriceType(types[i].type),
            ),
          ),
        ],
      ],
    );
  }

  Widget _catalogPriceTypeChip({
    required String label,
    required num price,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected ? widget.accent.withValues(alpha: 0.06) : Colors.white,
      borderRadius: SavatchaDesktopLayout._sharp,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            border: Border.all(
              color: selected ? widget.accent : AppTheme.divider,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected ? widget.accent : AppTheme.textSecondary,
                ),
              ),
              const SizedBox(width: 6),
              CatalogProductPriceLabel.text(
                _displaySom(price),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: selected ? widget.accent : AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
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
          border: Border.all(
            color: widget.expanded ? widget.accent.withValues(alpha: 0.35) : AppTheme.divider,
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
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final tight = constraints.maxWidth < 460;
                    final iconBox = tight ? 28.0 : 32.0;
                    return Padding(
                      padding: EdgeInsets.fromLTRB(tight ? 2 : 4, tight ? 5 : 6, tight ? 2 : 4, tight ? 5 : 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: BoxConstraints(minWidth: iconBox, minHeight: iconBox),
                            icon: Icon(
                              widget.expanded ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_right_rounded,
                              size: tight ? 20 : 22,
                              color: AppTheme.textSecondary,
                            ),
                            onPressed: widget.onToggleExpand,
                          ),
                          Expanded(
                            child: Text(
                              p.name,
                              maxLines: 1,
                              softWrap: false,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: tight ? 13 : 14,
                                height: 1.15,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ),
                          SizedBox(width: tight ? 2 : 4),
                          _qtyCircleButton(Icons.remove, widget.onDecrement, compact: tight),
                          _buildInlineQuantityControl(tight: tight),
                          _qtyCircleButton(Icons.add, widget.onIncrement, primary: true, compact: tight),
                          SizedBox(width: tight ? 4 : 6),
                          _buildLinePriceAndTotal(tight: tight),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: BoxConstraints(minWidth: iconBox, minHeight: iconBox),
                            icon: Icon(Icons.delete_outline_rounded, size: tight ? 18 : 20, color: AppTheme.textSecondary),
                            onPressed: widget.onRemove,
                            tooltip: "O'chirish",
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            if (widget.expanded)
              Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  border: Border(top: BorderSide(color: AppTheme.divider)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (p.canSellByPack) ...[
                      _buildSellUnitPicker(),
                      const SizedBox(height: 8),
                    ],
                    _buildCatalogPriceTypePicker(),
                  ],
                ),
              ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _qtyCircleButton(IconData icon, VoidCallback onPressed, {bool primary = false, bool compact = false}) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: Padding(
          padding: EdgeInsets.all(compact ? 3 : 4),
          child: Icon(icon, size: compact ? 18 : 20, color: primary ? widget.accent : AppTheme.textSecondary),
        ),
      ),
    );
  }
}
