import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/app_navigator.dart';
import '../core/app_notify.dart';
import '../core/constants.dart';
import '../core/theme.dart';
import '../models/cart_item.dart';
import '../models/product.dart';
import '../providers/cart_provider.dart';
import '../providers/clients_provider.dart';
import '../providers/products_provider.dart';
import '../providers/categories_provider.dart';
import '../providers/sales_session_provider.dart';
import '../core/api_client.dart';
import '../services/api_service.dart';
import '../core/seller_preferences.dart';
import '../widgets/product_tile.dart';
import 'tranzaksiya_detail_screen.dart';
import 'scanner_screen.dart' show showCompactScanner;
import '../utils/barcode_product_lookup.dart';
import '../utils/product_catalog_filter.dart';
import '../utils/product_search.dart' as product_search;
import '../utils/platform_layout.dart';
import '../core/input_formatters.dart';
import '../widgets/ios_style_modals.dart';
import 'desktop/cash_register_shift_gate.dart';
import 'desktop/cash_register_shift_dashboard.dart';
import 'desktop/desktop_shell_scope.dart';
import 'desktop/savatcha_desktop_layout.dart';
import '../providers/cash_register_shift_provider.dart';
import 'desktop/sales_filter_dialog.dart';
import 'desktop/sales_nav_filters.dart';
import 'desktop/desktop_payment_screen.dart';
import 'desktop/sales_hold_orders_sheet.dart';
import '../utils/cart_discount_percent.dart';
import '../utils/cart_payment_discount.dart';
import '../utils/customer_group_discount.dart';
import '../utils/sales_filter_cart_price.dart';
import '../utils/catalog_product_price_label.dart';
import '../utils/hold_order_cart.dart';
import '../utils/hold_order_precheck_excel_export.dart';
import '../services/thermal_receipt_printer.dart';
import '../services/desktop_sales_layout_settings.dart';
import '../utils/hold_cart_action.dart';
import '../widgets/pos_editable_focus_scope.dart';
import '../widgets/sales_customer_search.dart';
import 'yangi_mijoz_screen.dart';

/// Savatcha: mahsulotlar API dan (ProductsProvider). Sotuv POST /sales/store orqali, chek ID API javobidan.
/// Savatcha o'zi diska saqlanmaydi (faqat sessiya davomida xotirada).
class SavatchaScreen extends StatefulWidget {
  final VoidCallback? onLogout;
  /// Desktop: sidebar «Tranzaksiyalar» bo‘limiga o‘tish.
  final VoidCallback? onNavigateToTransactions;
  /// Desktop IndexedStack: boshqa tabda bo‘lsa katalog autofokus ishlamasin.
  final bool isTabActive;

  const SavatchaScreen({
    super.key,
    this.onLogout,
    this.onNavigateToTransactions,
    this.isTabActive = true,
  });

  @override
  State<SavatchaScreen> createState() => _SavatchaScreenState();
}

class _SavatchaScreenState extends State<SavatchaScreen> with DesktopShellSyncMixin {
  StreamSubscription<List<CartItem>>? _cartSub;
  StreamSubscription<List<Product>>? _productsSub;
  StreamSubscription<List<String>>? _categoriesSub;
  final _searchController = TextEditingController();
  final _catalogSearchFocus = FocusNode();
  final _discountPercentController = TextEditingController();
  int _catalogSearchRefocusSuspend = 0;
  final _cart = CartProvider.instance;
  final _products = ProductsProvider.instance;
  final _sales = SalesSessionProvider.instance;
  String _query = '';
  Timer? _barcodeSearchDebounce;
  Timer? _catalogSearchDebounce;
  Timer? _catalogSearchRefocusTimer;
  bool _barcodeSearchInFlight = false;
  Client? _selectedClient;
  String _sellerName = '';
  int? _activeHoldOrderId;
  String? _activeHoldInvoiceId;
  int _savedOrdersCount = 0;
  CartItem? _expandedCartLine;
  bool _isReturnMode = false;
  DesktopSalesLayoutMode _desktopSalesLayoutMode = DesktopSalesLayoutMode.standard;
  String? _restaurantCategoryId;

  Future<void> _onRefresh() async {
    if (isDesktopPosLayout) {
      await _products.loadFromApi();
    } else {
      await _products.loadFromStorage(refreshInBackground: true);
      if (_sales.initError == null) {
        await _sales.loadProducts(reset: true, searchValue: '');
        _sales.setSearchQuery('');
      }
    }
    if (mounted) setState(() {});
  }

  /// Mahsulotlar (Katalog) bilan bir xil manba — to'liq mahalliy katalog.
  List<Product> _catalogProductsForSearch() {
    final catalog = ProductsProvider.instance.withCatalogStockAll(_products.items);
    if (catalog.isNotEmpty) return catalog;
    if (_sales.salesProducts.isNotEmpty) {
      return ProductsProvider.instance.withCatalogStockAll(_sales.salesProducts);
    }
    return catalog;
  }

  bool get _salesFiltersActive {
    final toggles = _sales.hideZeroStock ||
        _sales.sellAtWholesalePrice ||
        _sales.sellAtPurchasePrice ||
        _sales.showPurchasePrice ||
        _sales.showUsdEquivalent;
    if (isDesktopPosLayout) {
      return toggles || _sales.categoryId != null || _sales.brandId != null;
    }
    return toggles;
  }

  List<Product> get _mobileCatalogProducts {
    final q = _query.trim();
    if (q.isEmpty) return _catalogProductsForSearch();
    return product_search.filterCatalogProducts(_catalogProductsForSearch(), q);
  }

  @override
  Future<void> onDesktopShellSync() async {
    if (!isDesktopPosLayout) return;
    await _products.refreshFromServer(force: true);
    _sales.applyCatalogStock();
    await _refreshSavedOrdersCount();
    await _reloadDesktopSalesLayoutMode();
    if (mounted) setState(() {});
  }

  Future<void> _reloadDesktopSalesLayoutMode() async {
    if (!isDesktopPosLayout) return;
    final mode = await DesktopSalesLayoutSettings.getMode();
    if (!mounted) return;
    if (mode != _desktopSalesLayoutMode) {
      setState(() {
        _desktopSalesLayoutMode = mode;
        _restaurantCategoryId = null;
      });
    }
  }

  int _restaurantCategoryProductCount(String categoryId) {
    return ProductCatalogFilter.apply(
      _desktopBrowseProducts,
      categoryId: categoryId,
      categories: _sales.categories,
    ).length;
  }

  List<Product> get _restaurantCategoryProducts {
    final catId = _restaurantCategoryId;
    if (catId == null) return [];
    return ProductCatalogFilter.apply(
      _desktopBrowseProducts,
      categoryId: catId,
      categories: _sales.categories,
    );
  }

  List<Map<String, dynamic>> get _restaurantCategoriesWithImages {
    final cats = CategoriesProvider.instance;
    return _sales.categories
        .map((c) {
          final id = c['id']?.toString();
          return {
            ...c,
            'imageUrl': cats.categoryImageUrl(id),
          };
        })
        .toList();
  }

  void _onCashShiftChanged() {
    if (mounted) {
      _sales.syncFromShift();
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    _cartSub = _cart.stream.listen((_) {
      if (mounted) setState(() {});
    });
    _productsSub = _products.stream.listen((_) {
      _sales.applyCatalogStock();
      if (mounted) setState(() {});
    });
    _sales.addListener(_onSalesSessionChanged);
    CashRegisterShiftProvider.instance.addListener(_onCashShiftChanged);
    if (isDesktopPosLayout) {
      FocusManager.instance.addListener(_onDesktopFocusChanged);
      _categoriesSub = CategoriesProvider.instance.stream.listen((_) {
        if (mounted) setState(() {});
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _sellerName = await getSellerName();
      if (!mounted) return;
      if (isDesktopPosLayout) {
        _desktopSalesLayoutMode = await DesktopSalesLayoutSettings.getMode();
        await _products.loadFromStorage(refreshInBackground: true);
        await _sales.init(localFirst: true);
        _sales.applyCatalogStock();
        unawaited(_sales.reloadFilterLists());
        unawaited(CategoriesProvider.instance.loadFromStorage(refreshInBackground: false));
        unawaited(_refreshSavedOrdersCount());
        unawaited(ThermalReceiptPrinter.warmup());
      } else {
        final shift = CashRegisterShiftProvider.instance;
        await shift.ensureCurrentUserId();
        await shift.loadRegisters();
        _sales.syncFromShift();
        await _refreshSavedOrdersCount();
        await _products.loadFromStorage(refreshInBackground: true);
        try {
          await _sales.init(localFirst: true);
          unawaited(_sales.reloadFilterLists());
        } catch (_) {}
        if (shift.isShiftOpen) {
          unawaited(shift.loadShiftDetail());
        }
      }
      if (mounted) {
        setState(() {});
        _refocusCatalogSearch();
      }
    });
  }

  @override
  void didUpdateWidget(covariant SavatchaScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (isDesktopPosLayout && widget.isTabActive && !oldWidget.isTabActive) {
      unawaited(_reloadDesktopSalesLayoutMode());
    }
  }

  /// USB/Bluetooth shtrix skaner klaviatura kabi yozadi — qidiruv inputida fokus bo‘lishi kerak.
  void _refocusCatalogSearch({bool immediate = false}) {
    if (!mounted || !isDesktopPosLayout || !widget.isTabActive || _catalogSearchRefocusSuspend > 0) {
      return;
    }
    _catalogSearchRefocusTimer?.cancel();
    void apply() {
      if (!mounted || !widget.isTabActive || _catalogSearchRefocusSuspend > 0) return;
      if (_catalogSearchFocus.hasFocus) return;
      final primary = FocusManager.instance.primaryFocus;
      if (PosEditableFocusScope.shouldPreserveFocus(primary)) return;
      if (!_catalogSearchFocus.canRequestFocus) return;
      _catalogSearchFocus.requestFocus();
    }
    if (immediate) {
      WidgetsBinding.instance.addPostFrameCallback((_) => apply());
    } else {
      _catalogSearchRefocusTimer = Timer(const Duration(milliseconds: 80), apply);
    }
  }

  void _scheduleCatalogSearchRefocus() => _refocusCatalogSearch();

  /// Miqdor / mijoz / foiz maydoniga o‘tishda qidiruv avtofokusini vaqtincha to‘xtatish.
  void _suspendCatalogSearchRefocusBriefly() {
    _catalogSearchRefocusTimer?.cancel();
    _catalogSearchRefocusSuspend++;
    Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      _catalogSearchRefocusSuspend--;
    });
  }

  void _onDesktopFocusChanged() {
    if (!mounted || !isDesktopPosLayout || !widget.isTabActive || _catalogSearchRefocusSuspend > 0) {
      return;
    }
    if (_catalogSearchFocus.hasFocus) return;
    final primary = FocusManager.instance.primaryFocus;
    if (PosEditableFocusScope.shouldPreserveFocus(primary)) return;
    _scheduleCatalogSearchRefocus();
  }

  Future<T?> _runWithSuspendedCatalogSearchRefocus<T>(Future<T?> Function() action) async {
    _catalogSearchRefocusSuspend++;
    try {
      return await action();
    } finally {
      _catalogSearchRefocusSuspend--;
      _refocusCatalogSearch();
    }
  }

  void _onSalesSessionChanged() {
    _syncDiscountPercentField();
    if (mounted) setState(() {});
    if (_barcodeSearchInFlight) return;
    final pending = _sales.takePendingBarcodeProduct();
    if (pending != null && mounted) {
      _addProductToCart(pending);
      _clearSearchField();
    }
  }

  @override
  void dispose() {
    _cartSub?.cancel();
    _productsSub?.cancel();
    _categoriesSub?.cancel();
    _barcodeSearchDebounce?.cancel();
    _catalogSearchDebounce?.cancel();
    _catalogSearchRefocusTimer?.cancel();
    if (isDesktopPosLayout) {
      FocusManager.instance.removeListener(_onDesktopFocusChanged);
    }
    _sales.removeListener(_onSalesSessionChanged);
    CashRegisterShiftProvider.instance.removeListener(_onCashShiftChanged);
    _catalogSearchFocus.dispose();
    _searchController.dispose();
    _discountPercentController.dispose();
    super.dispose();
  }

  void _syncDiscountPercentField() {
    if (!isDesktopPosLayout) return;
    final p = _sales.cartDiscountPercent;
    final text = p != 0 ? '$p' : '';
    if (_discountPercentController.text != text) {
      _discountPercentController.text = text;
    }
  }

  void _setCartDiscountPercent(int percent) {
    final old = _sales.cartDiscountPercent;
    _sales.setCartDiscountPercent(percent);
    for (final item in _cart.items) {
      var base = item.unitPriceBaseForCartPercent;
      if (base == null) {
        final line = item.unitPriceForLine;
        base = old != 0 ? line / ((100 + old) / 100) : line;
        item.unitPriceBaseForCartPercent = base;
      }
      CartDiscountPercent.applyToItem(item, percent);
    }
    _syncDiscountPercentField();
    setState(() {});
  }

  void _setCartLineUnitPrice(CartItem item, double? override) {
    CartDiscountPercent.onManualUnitPrice(
      item,
      override,
      _sales.cartDiscountPercent,
    );
    _cart.updateSalePriceOverride(item, item.salePriceOverride);
  }

  void _clearSearchField() {
    _searchController.clear();
    if (mounted) setState(() => _query = '');
    _refocusCatalogSearch();
  }

  void _onSearchFieldChanged(String v) {
    if (_query != v) {
      _query = v;
      if (mounted) setState(() {});
    }
    _barcodeSearchDebounce?.cancel();
    final q = v.trim();

    // Mobil: Mahsulotlar (Katalog) kabi — mahalliy filtr; API har harfda emas.
    if (!isDesktopPosLayout) {
      if (q.isEmpty && _sales.lastSearch.isNotEmpty) {
        _sales.setSearchQuery('');
      }
      if (product_search.looksLikeBarcodeInput(q)) {
        _barcodeSearchDebounce = Timer(const Duration(milliseconds: 500), () {
          if (!mounted) return;
          if (_searchController.text.trim() != q) return;
          unawaited(_searchAndAdd(q));
        });
      }
      return;
    }

    // Mahsulotlar (Katalog) kabi: nom — faqat mahalliy filtr; API har harfda emas.
    if (q.isEmpty) {
      if (_sales.lastSearch.isNotEmpty) {
        _sales.setSearchQuery('');
        unawaited(_sales.loadProducts(reset: true, searchValue: ''));
      }
      return;
    }

    if (product_search.looksLikeBarcodeInput(q)) {
      _barcodeSearchDebounce = Timer(const Duration(milliseconds: 400), () {
        if (!mounted) return;
        if (_searchController.text.trim() != q) return;
        unawaited(_desktopBarcodeSearchAndAdd(q));
      });
      return;
    }

    _catalogSearchDebounce?.cancel();
    _catalogSearchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      if (_searchController.text.trim() != q) return;
      unawaited(_desktopSearchProducts(q));
    });
  }

  List<Product> get _filteredProducts =>
      product_search.filterProductsByQuery(_products.items, _query);

  /// Desktop: filtrsiz ko‘rish — to‘liq mahalliy katalog (Mahsulotlar bo‘limi).
  List<Product> get _desktopBrowseProducts {
    final hasCatBrand = _sales.categoryId != null || _sales.brandId != null;
    if (hasCatBrand) {
      final seen = <String>{};
      final merged = <Product>[];
      for (final p in [
        ..._sales.salesProducts,
        ...ProductsProvider.instance.withCatalogStockAll(_products.items),
      ]) {
        if (p.id.isEmpty || !seen.add(p.id)) continue;
        merged.add(p);
      }
      var list = ProductCatalogFilter.apply(
        merged,
        categoryId: _sales.categoryId,
        brandId: _sales.brandId,
        categories: _sales.categories,
        brands: _sales.brands,
      );
      if (_sales.hideZeroStock) {
        list = list.where((p) => p.hasStock).toList();
      }
      return list;
    }
    if (_products.items.isNotEmpty) {
      var list = ProductsProvider.instance.withCatalogStockAll(_products.items);
      if (_sales.hideZeroStock) {
        list = list.where((p) => p.hasStock).toList();
      }
      return list;
    }
    return _sales.catalogProductsVisible;
  }

  List<Product> get _desktopCatalogProducts {
    final q = _query.trim();
    if (q.isNotEmpty) {
      return product_search.filterCatalogProducts(_catalogProductsForSearch(), q);
    }
    if (_desktopSalesLayoutMode == DesktopSalesLayoutMode.restaurant) {
      if (_restaurantCategoryId != null) return _restaurantCategoryProducts;
      return const [];
    }
    return _desktopBrowseProducts;
  }

  /// Desktop: nom bo'yicha mahalliy qidiruv (Katalog kabi); shtrix — alohida.
  Future<void> _desktopSearchProducts(String query) async {
    final q = query.trim();
    if (q.isEmpty) {
      if (_sales.lastSearch.isNotEmpty) {
        _sales.setSearchQuery('');
        await _sales.loadProducts(reset: true, searchValue: '');
      }
      if (mounted) setState(() {});
      return;
    }
    if (product_search.looksLikeBarcodeInput(q)) {
      await _desktopBarcodeSearchAndAdd(q);
    }
  }

  int get _cartRawTotal => _cart.items.fold<int>(0, (s, e) => s + e.total);

  int get _cartCatalogTotal => CartDiscountPercent.catalogLinesTotal(_cart.items);

  int get _cartGrandTotal => _cartRawTotal;

  @override
  Widget build(BuildContext context) {
    if (isDesktopPosLayout) {
      return _buildDesktopPos(context);
    }

    final items = _cart.items;
    final showSearchResults = _query.trim().isNotEmpty;
    final products = showSearchResults ? _mobileCatalogProducts : _filteredProducts;
    final hasLocalCatalog = _catalogProductsForSearch().isNotEmpty;
    final catalogLoading = showSearchResults &&
        !hasLocalCatalog &&
        !_products.isLoaded &&
        _sales.productsLoading;
    final shift = CashRegisterShiftProvider.instance;
    final showShiftDashboard = shift.requiresCashRegister && shift.isShiftOpen;

    return CashRegisterShiftGate(
      child: Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text(Strings.savatcha),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.cardBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${items.length}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: Strings.saqlanganBuyurtmalar,
            onPressed: () => _openHoldOrders(context),
            icon: Badge(
              isLabelVisible: _savedOrdersCount > 0,
              label: Text(
                _savedOrdersCount > 9 ? '9+' : '$_savedOrdersCount',
                style: const TextStyle(fontSize: 10),
              ),
              child: const Icon(Icons.list_alt_rounded),
            ),
          ),
          if (showShiftDashboard)
            IconButton(
              tooltip: 'Kassa smenasi',
              icon: const Icon(Icons.point_of_sale_rounded),
              onPressed: () => openCashRegisterShiftDashboard(context),
            ),
          if (items.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
              onPressed: _clearCart,
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: Strings.artikulShtrixIsm,
                      prefixIcon: Icon(Icons.search_rounded, color: AppTheme.textSecondary),
                    ),
                    onChanged: _onSearchFieldChanged,
                    onSubmitted: (q) async {
                      _barcodeSearchDebounce?.cancel();
                      _catalogSearchDebounce?.cancel();
                      final trimmed = q.trim();
                      if (trimmed.isEmpty) return;
                      if (product_search.looksLikeBarcodeInput(trimmed)) {
                        await _searchAndAdd(trimmed);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Material(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: () => _openScanner(context),
                    borderRadius: BorderRadius.circular(12),
                    child: const Padding(
                      padding: EdgeInsets.all(14),
                      child: Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 26),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                FocusScope.of(context).unfocus();
                FocusManager.instance.primaryFocus?.unfocus();
              },
              behavior: HitTestBehavior.translucent,
              child: RefreshIndicator(
                onRefresh: _onRefresh,
                child: showSearchResults
                  ? catalogLoading
                      ? const Center(
                          child: CircularProgressIndicator(color: AppTheme.primary),
                        )
                      : products.isEmpty
                          ? SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                              child: SizedBox(
                                height: MediaQuery.of(context).size.height * 0.5,
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
                                final usd = _sales.usdRate > 0 ? _sales.usdRate : 12600.0;
                                final sellType = _sales.activeSellPriceType;
                                return ProductTile(
                                  product: p,
                                  showSkuInTitle: true,
                                  primaryPriceLabel: CatalogProductPriceLabel.primary(
                                    p,
                                    sellType: sellType,
                                    usdRate: usd,
                                    showUsdEquivalent: _sales.showUsdEquivalent,
                                  ),
                                  secondaryPriceLabel: _sales.showPurchasePrice
                                      ? CatalogProductPriceLabel.purchaseLine(p)
                                      : null,
                                  onTap: () {
                                    _addProductToCart(p);
                                    _searchController.clear();
                                    setState(() => _query = '');
                                  },
                                  showBarcode: false,
                                  showMenu: false,
                                );
                              },
                            )
                  : items.isEmpty
                      ? SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                          child: SizedBox(
                            height: MediaQuery.of(context).size.height * 0.7,
                            child: _EmptyCart(
                              onScanner: () => _openScanner(context),
                            ),
                          ),
                        )
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final item = items[index];
                            return _CartItemTile(
                              item: item,
                              onLineTap: () => _showCartLinePriceDialog(context, item),
                              onIncrement: () {
                                _cart.updateQuantity(item, item.quantity + 1);
                                setState(() {});
                              },
                              onDecrement: () {
                                if (item.quantity > 1) {
                                  _cart.updateQuantity(item, item.quantity - 1);
                                } else {
                                  _cart.remove(item);
                                }
                                setState(() {});
                              },
                              onQuantityChanged: (newQty) {
                                _cart.updateQuantity(item, newQty);
                                setState(() {});
                              },
                            );
                          },
                        ),
              ),
            ),
          ),
        if (items.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _sales.holdCartInFlight ? null : () => _holdCart(context),
                        icon: _sales.holdCartInFlight
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                              )
                            : const Icon(Icons.pause_circle_outline_rounded, size: 22),
                        label: Text(_sales.holdCartInFlight ? 'Saqlanmoqda...' : Strings.toxtatish),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showDesktopFilterSheet(context),
                        icon: Icon(
                          Icons.tune_rounded,
                          size: 22,
                          color: _salesFiltersActive ? AppTheme.primary : null,
                        ),
                        label: Text(
                          _salesFiltersActive ? 'Filtr •' : 'Filtr',
                          style: TextStyle(
                            color: _salesFiltersActive ? AppTheme.primary : null,
                            fontWeight: _salesFiltersActive ? FontWeight.w600 : null,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () => _openPayment(context),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(Strings.keyingisi),
                            SizedBox(width: 4),
                            Icon(Icons.arrow_forward_rounded, size: 18),
                          ],
                        ),
                      ),
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

  Future<void> _searchAndAdd(String query) async {
    final q = query.trim();
    if (q.isEmpty || _barcodeSearchInFlight) return;
    _barcodeSearchInFlight = true;
    try {
      final found = await BarcodeProductLookup.resolve(
        query: q,
        salesScreenProducts: _sales.salesProducts,
        branchId: _sales.branchId ?? 1,
      );
      if (found != null) {
        _addProductToCart(found);
        _clearSearchField();
        return;
      }

      final localHits = [
        ...product_search.filterProductsByBarcodeQuery(_products.items, q),
        ...product_search.filterProductsByBarcodeQuery(_sales.salesProducts, q),
      ];
      if (localHits.length > 1) {
        if (mounted) {
          AppNotify.info(context, 'Bir nechta mahsulot topildi — ro‘yxatdan tanlang');
        }
        return;
      }

      if (!mounted) return;
      AppNotify.info(context, "Bu shtrix kod bo'yicha mahsulot topilmadi. Ro'yxatni yangilab ko'ring.");
    } finally {
      _barcodeSearchInFlight = false;
    }
  }

  String _packChoiceLabel(Product product) {
    final qty = product.quantityPerPack;
    final sellType = _sales.activeSellPriceType;
    if (sellType == 'purchase') {
      final pack = product.purchasePackUnitPriceNum;
      if (pack != null && pack > 0) {
        return 'Pachka — ${formatThousands(pack.round())} kelish ($qty dona)';
      }
    } else if (sellType == 'wholesale') {
      final pack = product.wholesalePackUnitPriceNum;
      if (pack != null && pack > 0) {
        return 'Pachka — ${formatThousands(pack.round())} ulgurji ($qty dona)';
      }
    }
    final packPrice = product.packSellUnitPriceNum!;
    return 'Pachka — ${formatThousands(packPrice.round())} ($qty dona)';
  }

  String _pieceChoiceLabel(Product product) {
    final sellType = _sales.activeSellPriceType;
    if (sellType == 'purchase') {
      final cost = product.costPriceUzs;
      if (cost != null && cost > 0) {
        return 'Dona — ${formatThousands(cost)} kelish';
      }
    } else if (sellType == 'wholesale') {
      return 'Dona — ${formatThousands(product.wholesalePiecePriceNum.round())} ulgurji';
    }
    if (product.sellingPriceCurrency.toLowerCase() == 'usd') {
      return 'Dona — ${product.priceFormatted}';
    }
    return 'Dona — ${formatThousands(product.pieceSellPriceNum.round())} so\'m';
  }

  void _addProductToCart(Product product) {
    void afterAdd(CartItem line) {
      _applyCustomerPricingToNewItem(line);
      _expandedCartLine = null;
      setState(() {});
    }

    if (product.canSellByPack) {
      showCupertinoModalPopup<void>(
        context: context,
        builder: (ctx) => CupertinoActionSheet(
          title: Text(product.name),
          message: const Text('Sotish turini tanlang'),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(ctx);
                afterAdd(_cart.add(CartItem(product: product, quantity: 1, sellByPack: true)));
              },
              child: Text(_packChoiceLabel(product)),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(ctx);
                afterAdd(_cart.add(CartItem(product: product, quantity: 1, sellByPack: false)));
              },
              child: Text(_pieceChoiceLabel(product)),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx),
            child: const Text(Strings.bekorQilish),
          ),
        ),
      ).whenComplete(_refocusCatalogSearch);
    } else {
      afterAdd(_cart.add(CartItem(product: product, quantity: 1, sellByPack: false)));
      _refocusCatalogSearch();
    }
  }

  Future<void> _showCartLinePriceDialog(BuildContext context, CartItem item) async {
    final result = await IosStyleModals.showSheet<_CartLinePriceResult>(
      context: context,
      isScrollControlled: true,
      showGrabber: true,
      child: _CartLinePriceEditSheet(item: item),
    );
    if (!mounted || result == null) return;
    if (result.useStandard) {
      _setCartLineUnitPrice(item, null);
    } else {
      final def = item.defaultLineUnitPrice;
      final price = result.price;
      _setCartLineUnitPrice(item, price != null && price == def ? null : price);
    }
    setState(() {});
  }

  void _openScanner(BuildContext context) {
    showCompactScanner(context, onResult: (barcode) async {
      if (barcode == null || barcode.isEmpty || !mounted) return;
      final q = barcode.trim();
      _barcodeSearchDebounce?.cancel();
      _searchController.text = q;
      setState(() => _query = q);
      await _searchAndAdd(q);
    });
  }

  Widget _buildDesktopPos(BuildContext context) {
    if (_sales.initLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
      );
    }
    if (_sales.initError != null && _sales.salesProducts.isEmpty) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_sales.initError!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => _sales.init(localFirst: true),
                child: const Text('Qayta yuklash'),
              ),
            ],
          ),
        ),
      );
    }

    final items = _cart.items;
    return Scaffold(
      body: CashRegisterShiftGate(
        child: SavatchaDesktopLayout(
        searchController: _searchController,
        catalogSearchFocus: _catalogSearchFocus,
        onCatalogSearchRefocus: _refocusCatalogSearch,
        onSuspendCatalogSearchRefocus: _suspendCatalogSearchRefocusBriefly,
        query: _query,
        catalogProducts: _desktopCatalogProducts,
        cartItems: items,
        productsLoading: _sales.productsLoading,
        selectedCustomerName: _selectedClient?.name,
        cashRegisterLabel: _sales.cashRegisterName,
        cashRegisters: _sales.cashRegisters,
        selectedCashRegisterId: _sales.cashRegisterId,
        onCashRegisterSelected: (r) {
          _sales.selectCashRegister(r);
          unawaited(_refreshSavedOrdersCount());
          setState(() {});
        },
        showPurchasePriceOnCards: _sales.showPurchasePrice,
        showUsdEquivalentOnCards: _sales.showUsdEquivalent,
        catalogSellPriceType: _sales.activeSellPriceType,
        sellerName: _sellerName.isNotEmpty ? _sellerName : 'Sotuvchi',
        cartGrandTotal: _cartGrandTotal,
        cartCatalogTotal: _cartCatalogTotal,
        cartDiscountPercent: _sales.cartDiscountPercent,
        usdExchangeRate: _sales.usdRate > 0 ? _sales.usdRate : 12600,
        onSearchChanged: _onSearchFieldChanged,
        onSearchSubmitted: _desktopSearchSubmit,
        categoryFilterId: _sales.categoryId,
        brandFilterId: _sales.brandId,
        filterCategories: _sales.categories,
        filterBrands: _sales.brands,
        onCategoryFilterChanged: (v) {
          _sales.setCategoryFilter(v);
          setState(() {});
        },
        onBrandFilterChanged: (v) {
          _sales.setBrandFilter(v);
          setState(() {});
        },
        onFilterTap: () => _runWithSuspendedCatalogSearchRefocus(
          () => _showDesktopFilterSheet(context),
        ),
        customerSearchSection: PosEditableFocusScope(
          child: SalesCustomerSearch(
            selected: _selectedClient,
            onSelected: _onCustomerSelected,
            onAddNew: () => _addCustomer(context),
            iconOnlyAddButton: true,
          ),
        ),
        onOpenSavedOrders: () => _runWithSuspendedCatalogSearchRefocus(
          () => SalesHoldOrdersSheet.show(
            context,
            onResume: _resumeHoldOrder,
            onExportExcel: _exportHoldOrderExcel,
            onListChanged: () => unawaited(_refreshSavedOrdersCount()),
          ),
        ),
        savedOrdersCount: _savedOrdersCount,
        onLoadMoreProducts: _query.trim().isEmpty &&
                _sales.hasMoreProducts &&
                !_sales.productsLoading
            ? () => _sales.loadMoreProducts()
            : null,
        onClearCart: _clearCart,
        onSalesList: widget.onNavigateToTransactions,
        onProductTap: (p) => _addProductToCart(p),
        expandedCartItem: _expandedCartLine,
        onToggleCartExpand: (item) {
          setState(() {
            _expandedCartLine = identical(_expandedCartLine, item) ? null : item;
          });
        },
        onCollapseCartExpand: () {
          setState(() => _expandedCartLine = null);
        },
        onCartQuantityChanged: (item, qty) {
          if (qty <= 0) {
            _cart.remove(item);
            if (identical(_expandedCartLine, item)) _expandedCartLine = null;
          } else {
            _cart.updateQuantity(item, qty);
          }
          setState(() {});
        },
        onCartUnitPriceChanged: (item, override) {
          _setCartLineUnitPrice(item, override);
          setState(() {});
        },
        onRemoveCartItem: (item) {
          _cart.remove(item);
          if (identical(_expandedCartLine, item)) _expandedCartLine = null;
          setState(() {});
        },
        onIncrement: (item) {
          _cart.updateQuantity(item, item.quantity + 1);
          setState(() {});
        },
        onDecrement: (item) {
          if (item.quantity > 1) {
            _cart.updateQuantity(item, item.quantity - 1);
          } else {
            _cart.remove(item);
            if (identical(_expandedCartLine, item)) _expandedCartLine = null;
          }
          setState(() {});
        },
        onPayment: () => _openPayment(context),
        onDailyReport: () => _sendDailyReport(context),
        discountPercentController: _discountPercentController,
        onDiscountPercentChanged: _setCartDiscountPercent,
        onDiscount: () => _runWithSuspendedCatalogSearchRefocus(
          () => _showDiscountDialog(context),
        ),
        holdCartInFlight: _sales.holdCartInFlight,
        onHoldCart: () => _holdCart(context),
        onOpenShiftDashboard: _openShiftDashboard,
        onLogout: widget.onLogout == null
            ? null
            : () async {
                await AuthApi.logout();
                widget.onLogout?.call();
              },
        isReturnMode: _isReturnMode,
        onReturnModeChanged: _setReturnMode,
        salesLayoutMode: _desktopSalesLayoutMode,
        restaurantCategories: _restaurantCategoriesWithImages,
        restaurantCategoryId: _restaurantCategoryId,
        onRestaurantCategorySelected: (id) {
          setState(() => _restaurantCategoryId = id);
        },
        onRestaurantCategoryBack: () {
          setState(() => _restaurantCategoryId = null);
        },
        restaurantCategoryProductCount: _restaurantCategoryProductCount,
        ),
      ),
    );
  }

  Future<void> _openShiftDashboard() async {
    if (!mounted) return;
    await _runWithSuspendedCatalogSearchRefocus(
      () => openCashRegisterShiftDashboard(context),
    );
  }

  /// Savat, foiz, mijoz va pauza holatini tozalash.
  void _clearCart() {
    _cart.clear();
    _expandedCartLine = null;
    _activeHoldOrderId = null;
    _activeHoldInvoiceId = null;
    _selectedClient = null;
    _setCartDiscountPercent(0);
  }

  void _setReturnMode(bool returnMode) {
    if (_isReturnMode == returnMode) return;
    if (_cart.items.isNotEmpty) _clearCart();
    setState(() => _isReturnMode = returnMode);
  }

  Future<void> _onCustomerSelected(Client? client) async {
    if (client == null) {
      setState(() {
        _selectedClient = null;
        CustomerGroupDiscount.applyCustomerPricingToCart(_cart.items, null);
        CartDiscountPercent.afterCustomerPricing(_cart.items, _sales.cartDiscountPercent);
      });
      return;
    }

    Client? effective = client;
    try {
      effective = await ClientsProvider.instance.resolveClientForSales(client);
    } on ApiException catch (e) {
      if (mounted) AppNotify.warning(context, e.message);
      effective = client;
    }

    if (!mounted) return;
    final groups = await ClientsProvider.instance.fetchCustomerGroups();
    if (!mounted) return;
    setState(() {
      _selectedClient = effective;
      _reapplyCustomerGroupPricingToCart(groups: groups);
    });
  }

  /// Mijoz tanlanganida — barcha savat qatorlariga guruh foizi (har yangi mahsulotda ham).
  void _reapplyCustomerGroupPricingToCart({List<Map<String, dynamic>>? groups}) {
    final client = _selectedClient;
    if (client == null) return;
    CustomerGroupDiscount.applyCustomerPricingToCart(
      _cart.items,
      client,
      groups: groups ?? ClientsProvider.instance.cachedCustomerGroups,
    );
    CartDiscountPercent.afterCustomerPricing(_cart.items, _sales.cartDiscountPercent);
  }

  void _applyCustomerPricingToNewItem(CartItem item) {
    if (_selectedClient != null) {
      _reapplyCustomerGroupPricingToCart();
      return;
    }
    if (_sales.activeSellPriceType != null) {
      SalesFilterCartPrice.applySessionPriceToItem(item, _sales);
      CartDiscountPercent.applyToItem(item, _sales.cartDiscountPercent);
      return;
    }
    CartDiscountPercent.initNewItem(item);
    CartDiscountPercent.syncBaseFromCurrent(item);
    CartDiscountPercent.applyToItem(item, _sales.cartDiscountPercent);
  }

  void _reapplySalesFilterPricingToCart() {
    if (_selectedClient != null) {
      _reapplyCustomerGroupPricingToCart();
      return;
    }
    if (_sales.activeSellPriceType != null) {
      SalesFilterCartPrice.applySessionPriceToCart(_cart.items, _sales);
    } else {
      for (final item in _cart.items) {
        item.salePriceOverride = null;
        item.unitPriceBaseForCartPercent = item.defaultLineUnitPrice.toDouble();
      }
    }
    CartDiscountPercent.afterCustomerPricing(_cart.items, _sales.cartDiscountPercent);
  }

  Future<void> _refreshSavedOrdersCount({bool force = false}) async {
    final list = await _sales.fetchHoldOrders(force: force);
    if (mounted) setState(() => _savedOrdersCount = list.length);
  }

  Future<void> _resumeHoldOrder(HoldOrderResume resume) async {
    _cart.clear();
    for (final item in resume.items) {
      _cart.add(CartItem(
        product: item.product,
        quantity: item.quantity,
        sellByPack: item.sellByPack,
        salePriceOverride: item.salePriceOverride,
      ));
    }
    _activeHoldOrderId = resume.orderId;
    _activeHoldInvoiceId = resume.invoiceId;
    _selectedClient = resume.customer;
    if (_activeHoldOrderId != null) {
      try {
        await SalesApi.continueSale(_activeHoldOrderId!);
      } catch (_) {}
    }
    unawaited(ClientsProvider.instance.fetchCustomerGroups().then((groups) {
      if (!mounted) return;
      CustomerGroupDiscount.applyCustomerPricingToCart(
        _cart.items,
        resume.customer,
        groups: groups,
      );
      CartDiscountPercent.afterCustomerPricing(_cart.items, _sales.cartDiscountPercent);
      setState(() {});
    }));
    final pct = resume.discountPercent ?? 0;
    _sales.setCartDiscountPercent(pct);
    for (final item in _cart.items) {
      CartDiscountPercent.syncBaseFromCurrent(item);
      if (pct != 0 && item.hasSalePriceOverride) {
        item.unitPriceBaseForCartPercent =
            item.unitPriceForLine / ((100 + pct) / 100);
      }
      CartDiscountPercent.applyToItem(item, pct);
    }
    _syncDiscountPercentField();
    if (mounted) {
      setState(() {});
      await _refreshSavedOrdersCount();
      AppNotify.success(
        context,
        'Buyurtma qayta ochildi — qayta pauza qilsangiz shu buyurtma yangilanadi',
      );
      _refocusCatalogSearch();
    }
  }

  Future<void> _desktopBarcodeSearchAndAdd(String q) async {
    if (_barcodeSearchInFlight) return;
    _barcodeSearchInFlight = true;
    try {
      final found = await BarcodeProductLookup.resolve(
        query: q,
        salesScreenProducts: _sales.salesProducts,
        branchId: _sales.branchId ?? 1,
      );
      if (found != null) {
        _addProductToCart(found);
        _clearSearchField();
        return;
      }

      final localHits = [
        ...product_search.filterProductsByBarcodeQuery(_products.items, q),
        ...product_search.filterProductsByBarcodeQuery(_sales.salesProducts, q),
      ];
      if (localHits.length > 1) {
        if (mounted) {
          AppNotify.info(context, 'Bir nechta mahsulot topildi — ro‘yxatdan tanlang');
        }
        return;
      }

      if (mounted) {
        AppNotify.info(context, "Bu shtrix kod bo'yicha mahsulot topilmadi");
      }
    } finally {
      _barcodeSearchInFlight = false;
    }
  }

  Future<void> _desktopSearchSubmit(String q) async {
    _barcodeSearchDebounce?.cancel();
    _catalogSearchDebounce?.cancel();
    await _desktopSearchProducts(q);
  }

  Future<void> _holdCart(BuildContext context) async {
    final items = _cart.items;
    final ok = await HoldCartAction.savePausedCart(
      context: context,
      cartItems: items,
      subTotal: _cartCatalogTotal,
      grandTotal: _cartGrandTotal,
      customerId: _selectedClient != null ? int.tryParse(_selectedClient!.id) : null,
      orderId: _activeHoldOrderId,
      invoiceId: _activeHoldInvoiceId,
      discountPercent: _sales.cartDiscountPercent,
    );
    if (!ok || !mounted) return;
    _activeHoldOrderId = null;
    _activeHoldInvoiceId = null;
    _selectedClient = null;
    _setCartDiscountPercent(0);
    await _refreshSavedOrdersCount();
    setState(() {});
    _refocusCatalogSearch();
  }

  void _openHoldOrders(BuildContext context) {
    SalesHoldOrdersSheet.show(
      context,
      onResume: _resumeHoldOrder,
      onExportExcel: _exportHoldOrderExcel,
      onListChanged: () => unawaited(_refreshSavedOrdersCount()),
    );
  }

  Future<void> _exportHoldOrderExcel(Map<String, dynamic> hold) async {
    await _runWithSuspendedCatalogSearchRefocus(() async {
      final ctx = appNavigatorKey.currentContext;
      if (ctx == null || !ctx.mounted) return null;

      var loadingVisible = false;
      try {
        loadingVisible = true;
        showDialog<void>(
          context: ctx,
          barrierDismissible: false,
          builder: (_) => const PopScope(
            canPop: false,
            child: Center(
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: AppTheme.primary),
                      SizedBox(height: 16),
                      Text(
                        'Excel fayl tayyorlanmoqda...',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );

        final result = await HoldOrderPrecheckExcelExport.exportHoldOrderFromApp(
          hold,
          onPrepared: () async {
            if (!ctx.mounted || !loadingVisible) return;
            Navigator.of(ctx, rootNavigator: true).pop();
            loadingVisible = false;
          },
        );

        if (!ctx.mounted) return null;
        if (result.cancelled) return null;
        if (result.ok) {
          AppNotify.success(ctx, result.message);
        } else {
          AppNotify.warning(ctx, result.message);
        }
      } catch (e) {
        if (ctx.mounted) {
          AppNotify.error(ctx, 'Yuklab olish xatosi: $e');
        }
      } finally {
        if (ctx.mounted && loadingVisible) {
          Navigator.of(ctx, rootNavigator: true).pop();
        }
      }
      return null;
    });
  }

  Future<void> _sendDailyReport(BuildContext context) async {
    try {
      await _sales.sendDailySummary();
      if (mounted) AppNotify.success(context, 'Kunlik hisobot yuborildi');
    } catch (e) {
      if (mounted) AppNotify.error(context, 'Yuborilmadi: $e');
    }
  }

  Future<void> _showDiscountDialog(BuildContext context) {
    if (isDesktopPosLayout) {
      return _showDesktopPaymentDiscountDialog(context);
    }
    return _showPercentDiscountDialog(context);
  }

  Future<void> _showPercentDiscountDialog(BuildContext context) {
    final c = TextEditingController(
      text: _sales.cartDiscountPercent != 0 ? '${_sales.cartDiscountPercent}' : '',
    );
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Foiz (%)'),
        content: TextField(
          controller: c,
          keyboardType: const TextInputType.numberWithOptions(signed: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^-?\d{0,3}$')),
          ],
          decoration: const InputDecoration(
            labelText: 'Foiz',
            suffixText: '%',
            helperText: '+20 qo‘shadi, -20 ayiradi',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text(Strings.bekorQilish)),
          FilledButton(
            onPressed: () {
              final p = int.tryParse(c.text.trim()) ?? 0;
              _setCartDiscountPercent(p.clamp(-100, 100));
              Navigator.pop(ctx);
            },
            child: const Text(Strings.saqlash),
          ),
        ],
      ),
    );
  }

  Future<void> _showDesktopPaymentDiscountDialog(BuildContext context) async {
    final cartTotal = _cartGrandTotal;
    if (cartTotal <= 0) {
      AppNotify.info(context, 'Savat bo\'sh');
      return;
    }

    final payController = TextEditingController(
      text: formatThousands(cartTotal),
    );

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final paid = parseFormattedSum(payController.text) ?? cartTotal;
            final clampedPaid = paid.clamp(0, cartTotal);
            final discount = cartTotal - clampedPaid;

            return AlertDialog(
              title: const Text('To\'lov summasi'),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Jami', style: TextStyle(color: AppTheme.textSecondary)),
                        Text(
                          '${formatThousands(cartTotal)} so\'m',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: payController,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      inputFormatters: [ThousandsInputFormatter()],
                      onChanged: (_) => setDialogState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Mijoz to\'laydi',
                        suffixText: 'so\'m',
                        helperText: 'Farq avtomatik chegirma bo\'lib qatorlarga taqsimlanadi',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Chegirma'),
                          Text(
                            '${formatThousands(discount)} so\'m',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primary,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(Strings.bekorQilish),
                ),
                FilledButton(
                  onPressed: () {
                    final amount = parseFormattedSum(payController.text);
                    if (amount == null) return;
                    if (amount < 0 || amount > cartTotal) {
                      AppNotify.error(ctx, '0 dan $cartTotal gacha summa kiriting');
                      return;
                    }
                    Navigator.pop(ctx);
                    _applyPaymentDiscount(amount);
                  },
                  child: const Text(Strings.saqlash),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _applyPaymentDiscount(int amountPaidUzs) {
    _sales.setCartDiscountPercent(0);
    _syncDiscountPercentField();
    CartPaymentDiscount.applyCustomerPayment(_cart.items, amountPaidUzs);
    for (final item in _cart.items) {
      _cart.updateSalePriceOverride(item, item.salePriceOverride);
    }
    setState(() {});
  }

  Future<void> _showDesktopFilterSheet(BuildContext context) async {
    final applied = await SalesFilterDialog.show(context);
    if (!mounted) return;
    if (applied == true) {
      _reapplySalesFilterPricingToCart();
      setState(() {});
      unawaited(_sales.loadProducts(reset: true));
    } else {
      setState(() {});
    }
  }

  Future<void> _addCustomer(BuildContext context) async {
    final created = await _runWithSuspendedCatalogSearchRefocus(() async {
      if (isDesktopPosLayout) {
        return showYangiMijozDialog(context);
      }
      return Navigator.of(context).push<Client>(
        MaterialPageRoute(builder: (_) => const YangiMijozScreen()),
      );
    });
    if (created != null && mounted) await _onCustomerSelected(created);
  }

  void _openPayment(BuildContext context) {
    final items = _cart.items;
    if (items.isEmpty) return;
    if (isDesktopPosLayout) {
      unawaited(SalesSessionProvider.instance.ensurePaymentTypesLoaded());
    }
    final orderId = _activeHoldOrderId;
    final invoiceId = _activeHoldInvoiceId;
    final client = _selectedClient;

    void afterPayment() {
      if (!mounted) return;
      _cart.clear();
      _expandedCartLine = null;
      _activeHoldOrderId = null;
      _activeHoldInvoiceId = null;
      _selectedClient = null;
      _setCartDiscountPercent(0);
      _isReturnMode = false;
      setState(() {});
      unawaited(_refreshSavedOrdersCount(force: true));
      _refocusCatalogSearch();
    }

    if (isDesktopPosLayout) {
      _catalogSearchRefocusSuspend++;
      DesktopPaymentScreen.show(
        context,
        items: List.from(items),
        initialClient: client,
        initialOrderId: orderId,
        initialInvoiceId: invoiceId,
        isReturnCheckout: _isReturnMode,
      ).then((result) {
        _catalogSearchRefocusSuspend--;
        if (result is String && result.isNotEmpty) {
          final wasReturn = _isReturnMode;
          afterPayment();
          if (mounted) {
            final label = result.startsWith('POS') ? result : 'POS$result';
            final msg = wasReturn
                ? 'Qaytarish #$label muvaffaqiyatli!'
                : 'Tranzaksiya #$label muvaffaqiyatli!';
            AppNotify.success(context, msg);
          }
        } else if (mounted) {
          _refocusCatalogSearch();
        }
      });
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TranzaksiyaDetailScreen(
          items: List.from(items),
          initialClient: client,
          initialOrderId: orderId,
          initialInvoiceId: invoiceId,
          onCustomerChanged: _onCustomerSelected,
        ),
      ),
    ).then((result) {
      if (result == 'held') {
        afterPayment();
      } else if (result is String && result.isNotEmpty) {
        afterPayment();
        if (mounted) {
          final label = result.startsWith('POS') ? result : 'POS$result';
          AppNotify.success(context, 'Tranzaksiya #$label muvaffaqiyatli!');
        }
      }
    });
  }

}

class _EmptyCart extends StatelessWidget {
  final VoidCallback onScanner;

  const _EmptyCart({required this.onScanner});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: MediaQuery.of(context).size.height - 200,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.qr_code_2_rounded,
              size: 80,
              color: AppTheme.textSecondary.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 20),
            const Text(
              Strings.savatchadaHechNarsa,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              Strings.savatchaQoShish,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary.withValues(alpha: 0.9),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onScanner,
                icon: const Icon(Icons.qr_code_scanner_rounded),
                label: const Text(Strings.skaner),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CartItemTile extends StatefulWidget {
  final CartItem item;
  final VoidCallback onLineTap;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final ValueChanged<num>? onQuantityChanged;

  const _CartItemTile({
    required this.item,
    required this.onLineTap,
    required this.onIncrement,
    required this.onDecrement,
    this.onQuantityChanged,
  });

  @override
  State<_CartItemTile> createState() => _CartItemTileState();
}

class _CartItemTileState extends State<_CartItemTile> {
  bool _editing = false;
  late TextEditingController _controller;
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus && _editing) _applyAndClose();
  }

  void _applyAndClose() {
    final s = _controller.text.trim().replaceAll(',', '.');
    final q = num.tryParse(s);
    if (q != null && q > 0 && widget.onQuantityChanged != null) {
      widget.onQuantityChanged!(q);
    }
    if (mounted) setState(() => _editing = false);
  }

  static String _formatQuantity(num q) {
    if (q == q.roundToDouble()) return q.toInt().toString();
    return q.toString();
  }

  static String _formatUzs(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
      buf.write(s[i]);
    }
    return '$buf UZS';
  }

  static String _formatLineTotal(CartItem item) {
    final p = item.product;
    if (p.sellingPriceCurrency.toLowerCase() == 'usd') {
      final t = item.lineSubtotal;
      final dec = t == t.roundToDouble() ? 0 : 2;
      return '${t.toStringAsFixed(dec)} USD';
    }
    return _formatUzs(item.total);
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final p = item.product;
    final unitLabel = item.sellByPack ? "pachka" : "dona";
    final canEdit = widget.onQuantityChanged != null;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: widget.onLineTap,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: AppTheme.cardBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: ProductTile.buildProductImage(p, boxSize: 56),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                            if (item.hasSalePriceOverride) ...[
                              const SizedBox(height: 2),
                              Text(
                                'Vaqtinchalik narx (shu sotuv)',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.orange.shade800,
                                ),
                              ),
                            ],
                            const SizedBox(height: 4),
                            Text(
                              _formatLineTotal(item),
                              style: const TextStyle(
                                color: AppTheme.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${_formatQuantity(item.quantity)} $unitLabel',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: AppTheme.cardBg,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_rounded, size: 20),
                    onPressed: widget.onDecrement,
                  ),
                  if (_editing)
                    SizedBox(
                      width: 56,
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                          border: InputBorder.none,
                        ),
                        onSubmitted: (_) => _applyAndClose(),
                      ),
                    )
                  else
                    GestureDetector(
                      onTap: canEdit
                          ? () {
                              _controller.text = _formatQuantity(item.quantity);
                              setState(() => _editing = true);
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                FocusScope.of(context).requestFocus(_focusNode);
                              });
                            }
                          : null,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Text(
                          _formatQuantity(item.quantity),
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  IconButton(
                    icon: const Icon(Icons.add_rounded, size: 20),
                    onPressed: widget.onIncrement,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CartLinePriceResult {
  const _CartLinePriceResult.standard() : useStandard = true, price = null;
  const _CartLinePriceResult.saved(this.price) : useStandard = false;

  final bool useStandard;
  final double? price;
}

class _CartLinePriceEditSheet extends StatefulWidget {
  const _CartLinePriceEditSheet({required this.item});

  final CartItem item;

  @override
  State<_CartLinePriceEditSheet> createState() => _CartLinePriceEditSheetState();
}

class _CartLinePriceEditSheetState extends State<_CartLinePriceEditSheet> {
  late final TextEditingController _priceCtrl;

  @override
  void initState() {
    super.initState();
    _priceCtrl = TextEditingController(text: formatThousands(widget.item.unitPriceDisplay));
  }

  @override
  void dispose() {
    _priceCtrl.dispose();
    super.dispose();
  }

  InputDecoration _fieldDecoration(String label, {String? suffix}) {
    return InputDecoration(
      labelText: label,
      suffixText: suffix,
      filled: true,
      fillColor: AppTheme.cardBg,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.primary, width: 2),
      ),
      floatingLabelStyle: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600),
    );
  }

  void _save() {
    final v = parseFormattedSum(_priceCtrl.text);
    if (v == null || v < 0) {
      AppNotify.info(context, "To'g'ri narx kiriting");
      return;
    }
    Navigator.pop(context, _CartLinePriceResult.saved(v.toDouble()));
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final unitHint = item.sellByPack ? '1 pachka narxi' : '1 dona narxi';
    final catalog = item.defaultLineUnitPrice.round();

    return IosStyleModals.sheetKeyboardForm(
      context: context,
      onCancel: () => Navigator.pop(context),
      onSave: _save,
      cancelLabel: Strings.bekorQilish,
      saveLabel: Strings.saqlash,
      middle: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: TextButton(
          onPressed: () => Navigator.pop(context, const _CartLinePriceResult.standard()),
          style: TextButton.styleFrom(
            foregroundColor: AppTheme.primary,
            padding: const EdgeInsets.symmetric(vertical: 8),
          ),
          child: const Text(
            'Standart narx',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
        ),
      ),
      body: [
        const Text(
          "Narxni o'zgartirish",
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: AppTheme.textPrimary),
        ),
        const SizedBox(height: 6),
        Text(
          item.product.name,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _priceCtrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          inputFormatters: [ThousandsInputFormatter()],
          decoration: _fieldDecoration(unitHint, suffix: Strings.som),
        ),
        const SizedBox(height: 8),
        Text(
          'Katalog narxi: ${formatThousands(catalog)} ${Strings.som}',
          style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
        ),
      ],
    );
  }
}
