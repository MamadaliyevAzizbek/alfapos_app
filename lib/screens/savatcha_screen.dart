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
import '../models/sales_window_snapshot.dart';
import '../providers/cart_provider.dart';
import '../providers/clients_provider.dart';
import '../providers/products_provider.dart';
import '../providers/categories_provider.dart';
import '../providers/sales_session_provider.dart';
import '../core/api_client.dart';
import '../services/api_service.dart';
import '../core/seller_preferences.dart';
import '../widgets/app_dropdown.dart';
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
import '../services/sales_keyboard_shortcuts_settings.dart';
import '../services/sales_stock_limit_settings.dart';
import '../services/sales_ui_scale_settings.dart';
import '../services/sales_cart_profit_display_settings.dart';
import '../utils/cart_stock_limit.dart';
import '../utils/cash_register_utils.dart';
import '../utils/sales_store_body.dart';
import '../services/category_order_storage.dart';
import '../services/desktop_sales_layout_settings.dart';
import '../services/product_catalog_sort_settings.dart';
import '../services/product_display_settings.dart';
import '../utils/category_order_sort.dart';
import '../utils/product_catalog_sort.dart';
import '../utils/hold_cart_action.dart';
import '../utils/invoice_edit_utils.dart';
import '../utils/pos_navigation.dart';
import 'tranzaksiyalar_screen.dart';
import '../widgets/pos_editable_focus_scope.dart';
import '../widgets/sales_customer_search.dart';
import '../models/chergirma_result.dart';
import 'chergirma_screen.dart';
import 'yangi_mijoz_screen.dart';
import '../widgets/throttled_refresh_indicator.dart';

/// Savatcha: mahsulotlar API dan (ProductsProvider). Sotuv POST /sales/store orqali, chek ID API javobidan.
/// Savatcha o'zi diska saqlanmaydi (faqat sessiya davomida xotirada).
class SavatchaScreen extends StatefulWidget {
  final VoidCallback? onLogout;
  /// Desktop IndexedStack: boshqa tabda bo‘lsa katalog autofokus ishlamasin.
  final bool isTabActive;
  final VoidCallback? onOpenSectionMenu;
  final VoidCallback? onGlobalSync;

  const SavatchaScreen({
    super.key,
    this.onLogout,
    this.isTabActive = true,
    this.onOpenSectionMenu,
    this.onGlobalSync,
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
  final _customerSearchFocus = FocusNode();
  final _discountPercentController = TextEditingController();
  Map<SalesShortcutAction, String> _shortcutKeys = Map.of(SalesKeyboardShortcutsSettings.defaults);
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
  int? _activeHoldQueueNumber;
  int? _invoiceEditOrderId;
  String? _invoiceEditReason;
  String? _invoiceEditSourceInvoiceId;
  int _savedOrdersCount = 0;
  CartItem? _expandedCartLine;
  CartItem? _cartQtyFocusItem;
  int _cartQtyFocusNonce = 0;
  bool _isReturnMode = false;
  bool _showDesktopSalesList = false;
  bool _desktopSalesListMounted = false;
  DesktopSalesLayoutMode _desktopSalesLayoutMode = DesktopSalesLayoutMode.standard;
  String? _restaurantCategoryId;
  List<String> _categoryOrderIds = [];
  static const int _maxSalesWindows = 12;
  final List<SalesWindowSnapshot> _salesWindows = [SalesWindowSnapshot.empty()];
  int _activeSalesWindowIndex = 0;
  bool _applyingSalesWindow = false;

  bool get _isInvoiceEditMode => _invoiceEditOrderId != null;

  /// Ekranni tortib yangilash — katalogni serverdan to‘liq o‘qiydi.
  ///
  /// Avval faqat diskdan o‘qib, API yangilanishini fonga qo‘yardik; u esa
  /// 15 daqiqalik throttle ichida hech narsa qilmasdi — spinner tugasa ham
  /// webda qo‘shilgan mahsulot ko‘rinmasdi. Ketma-ket tortish
  /// `PullRefreshGuard` bilan cheklangani uchun force xavfsiz.
  Future<void> _onRefresh() async {
    await _products.refreshFromServer(force: true);
    if (_sales.initError == null) {
      // Qidiruv matni ekranda qolgani uchun uni tozalamaymiz — aks holda
      // server natijalari yo‘qolib, eski lokal ro‘yxat ko‘rinib qolardi.
      final q = _query.trim();
      await _sales.loadProducts(reset: true, searchValue: q);
      _sales.setSearchQuery(q);
    }
    if (mounted) setState(() {});
  }

  /// Yagona katalog — ProductsProvider.
  List<Product> _catalogProductsForSearch() {
    return _sortCatalogProducts(
      ProductsProvider.instance.withCatalogStockAll(_products.items),
    );
  }

  List<Product> get _mobileCatalogProducts {
    final q = _query.trim();
    if (q.isEmpty) return _catalogProductsForSearch();
    // Desktop bilan bir xil: mahalliy filtr + server natijalarini birlashtirish.
    final local = product_search.filterCatalogProducts(_catalogProductsForSearch(), q);
    return _mergeSearchResults(q, local);
  }

  @override
  Future<void> onDesktopShellSync() async {
    if (!isDesktopPosLayout) return;
    await _products.ensureFullCatalogLoaded(force: true);
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
    return _sortCatalogProducts(
      ProductCatalogFilter.apply(
        _desktopBrowseProducts,
        categoryId: catId,
        categories: _sales.categories,
      ),
    );
  }

  List<Map<String, dynamic>> get _restaurantCategoriesWithImages {
    final cats = CategoriesProvider.instance;
    final base = _sales.categories
        .map((c) {
          final id = c['id']?.toString();
          return {
            ...c,
            'imageUrl': cats.categoryImageUrl(id),
          };
        })
        .toList();
    return CategoryOrderSort.apply(base, _categoryOrderIds);
  }

  Future<void> _reloadCategoryOrder() async {
    final ids = _sales.categories
        .map((c) => c['id']?.toString().trim() ?? '')
        .where((e) => e.isNotEmpty)
        .toList();
    _categoryOrderIds = await CategoryOrderStorage.mergeWithCategoryIds(ids);
    _sales.categories = CategoryOrderSort.apply(_sales.categories, _categoryOrderIds);
    if (mounted) setState(() {});
  }

  Future<void> _onRestaurantCategoriesReordered(List<Map<String, dynamic>> reordered) async {
    final ids = reordered
        .map((c) => c['id']?.toString().trim() ?? '')
        .where((e) => e.isNotEmpty)
        .toList();
    await CategoryOrderStorage.saveOrderedIds(ids);
    _categoryOrderIds = ids;
    _sales.categories = CategoryOrderSort.apply(_sales.categories, ids);
    if (mounted) setState(() {});
  }

  void _onCashShiftChanged() {
    if (mounted) {
      _sales.syncFromShift();
      setState(() {});
    }
  }

  void _onProductDisplayChanged() {
    if (mounted) setState(() {});
  }

  void _onProductCatalogSortChanged() {
    if (mounted) setState(() {});
  }

  List<Product> _sortCatalogProducts(List<Product> list) {
    return ProductCatalogSort.apply(
      list,
      mode: ProductCatalogSortSettings.sortMode.value,
      usdRate: _sales.usdRate > 0 ? _sales.usdRate : 12600,
    );
  }

  @override
  void initState() {
    super.initState();
    ProductDisplaySettings.showSkuInTitle.addListener(_onProductDisplayChanged);
    ProductCatalogSortSettings.sortMode.addListener(_onProductCatalogSortChanged);
    unawaited(ProductDisplaySettings.load());
    unawaited(ProductCatalogSortSettings.load());
    _cartSub = _cart.stream.listen((_) {
      if (mounted) setState(() {});
    });
    _productsSub = _products.stream.listen((_) {
      _sales.applyCatalogStock();
      if (mounted) setState(() {});
    });
    _sales.addListener(_onSalesSessionChanged);
    CashRegisterShiftProvider.instance.addListener(_onCashShiftChanged);
    SalesKeyboardShortcutsSettings.revision.addListener(_onShortcutSettingsChanged);
    SalesStockLimitSettings.allowNegative.addListener(_onStockLimitSettingsChanged);
    SalesCartProfitDisplaySettings.visible.addListener(_onCartProfitDisplayChanged);
    unawaited(_loadShortcutKeys());
    unawaited(SalesStockLimitSettings.load());
    unawaited(SalesCartProfitDisplaySettings.load());
    unawaited(SalesUiScaleSettings.load());
    if (isDesktopPosLayout) {
      FocusManager.instance.addListener(_onDesktopFocusChanged);
      _categoriesSub = CategoriesProvider.instance.stream.listen((_) {
        if (mounted) {
          unawaited(_reloadCategoryOrder());
        }
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _sellerName = await getSellerName();
      if (!mounted) return;
      if (isDesktopPosLayout) {
        _desktopSalesLayoutMode = await DesktopSalesLayoutSettings.getMode();
        await _products.warmFromCache();
        await _sales.init(localFirst: true);
        _sales.applyCatalogStock();
        await _sales.reloadFilterLists();
        unawaited(_products.ensureFullCatalogLoaded().then((_) {
          _sales.applyCatalogStock();
          if (mounted) setState(() {});
        }));
        unawaited(CategoriesProvider.instance.warmFromCache());
        unawaited(_refreshSavedOrdersCount());
        unawaited(ThermalReceiptPrinter.warmup());
        unawaited(_reloadCategoryOrder());
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
        unawaited(_applyPendingInvoiceEditIfAny());
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
    unawaited(_reloadCategoryOrder());
    if (_sales.hasPendingInvoiceEdit) {
      unawaited(_applyPendingInvoiceEditIfAny());
    }
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
    ProductDisplaySettings.showSkuInTitle.removeListener(_onProductDisplayChanged);
    ProductCatalogSortSettings.sortMode.removeListener(_onProductCatalogSortChanged);
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
    SalesKeyboardShortcutsSettings.revision.removeListener(_onShortcutSettingsChanged);
    SalesStockLimitSettings.allowNegative.removeListener(_onStockLimitSettingsChanged);
    SalesCartProfitDisplaySettings.visible.removeListener(_onCartProfitDisplayChanged);
    _catalogSearchFocus.dispose();
    _customerSearchFocus.dispose();
    _searchController.dispose();
    _discountPercentController.dispose();
    super.dispose();
  }

  void _syncDiscountPercentField() {
    if (!isDesktopPosLayout) return;
    final p = CartDiscountPercent.discountPercentToUi(_sales.cartDiscountPercent);
    final text = p != 0 ? '$p' : '';
    if (_discountPercentController.text != text) {
      _discountPercentController.text = text;
    }
  }

  void _captureActiveSalesWindow() {
    if (!isDesktopPosLayout || _applyingSalesWindow) return;
    _salesWindows[_activeSalesWindowIndex] = SalesWindowSnapshot(
      cartItems: _cart.items.map((e) => e.copy()).toList(),
      client: _selectedClient,
      discountPercent: _sales.cartDiscountPercent,
      isReturnMode: _isReturnMode,
      holdOrderId: _activeHoldOrderId,
      holdInvoiceId: _activeHoldInvoiceId,
      holdQueueNumber: _activeHoldQueueNumber,
      invoiceEditOrderId: _invoiceEditOrderId,
      invoiceEditReason: _invoiceEditReason,
      invoiceEditSourceInvoiceId: _invoiceEditSourceInvoiceId,
    );
  }

  Future<void> _applySalesWindow(SalesWindowSnapshot window) async {
    if (!isDesktopPosLayout) return;
    _applyingSalesWindow = true;
    try {
      _cart.replaceAll(window.cartItems.map((e) => e.copy()));
      _selectedClient = window.client;
      _activeHoldOrderId = window.holdOrderId;
      _activeHoldInvoiceId = window.holdInvoiceId;
      _activeHoldQueueNumber = window.holdQueueNumber;
      _invoiceEditOrderId = window.invoiceEditOrderId;
      _invoiceEditReason = window.invoiceEditReason;
      _invoiceEditSourceInvoiceId = window.invoiceEditSourceInvoiceId;
      _expandedCartLine = null;
      _cartQtyFocusItem = null;

      _sales.setCartDiscountPercent(window.discountPercent);
      for (final item in _cart.items) {
        CartDiscountPercent.syncBaseFromCurrent(item);
        CartDiscountPercent.applyToItem(item, window.discountPercent);
      }
      _syncDiscountPercentField();

      if (_isReturnMode != window.isReturnMode) {
        _isReturnMode = window.isReturnMode;
        if (window.isReturnMode) {
          unawaited(() async {
            try {
              await SalesApi.setReturnsType();
            } catch (_) {}
          }());
        }
      }
    } finally {
      _applyingSalesWindow = false;
    }
    if (mounted) setState(() {});
  }

  void _switchSalesWindow(int index) {
    if (!isDesktopPosLayout || index == _activeSalesWindowIndex) return;
    if (index < 0 || index >= _salesWindows.length) return;
    _captureActiveSalesWindow();
    _activeSalesWindowIndex = index;
    unawaited(_applySalesWindow(_salesWindows[index]));
    _refocusCatalogSearch();
  }

  void _addSalesWindow() {
    if (!isDesktopPosLayout) return;
    if (_cart.items.isEmpty) {
      AppNotify.info(context, 'Yangi oyna uchun avval savatga mahsulot qo\'shing');
      return;
    }
    if (_salesWindows.length >= _maxSalesWindows) {
      AppNotify.warning(context, 'Maksimum $_maxSalesWindows ta sotuv oynasi');
      return;
    }
    _captureActiveSalesWindow();
    _salesWindows.add(SalesWindowSnapshot.empty());
    _activeSalesWindowIndex = _salesWindows.length - 1;
    unawaited(_applySalesWindow(_salesWindows[_activeSalesWindowIndex]));
    _refocusCatalogSearch();
  }

  /// To‘lov yakunlangach joriy oynani yopish (bitta oyna qolsa — tozalash).
  Future<void> _closeActiveSalesWindowAfterPayment() async {
    if (!isDesktopPosLayout) return;

    if (_salesWindows.length <= 1) {
      _salesWindows[0] = SalesWindowSnapshot.empty();
      _activeSalesWindowIndex = 0;
      return;
    }

    _salesWindows.removeAt(_activeSalesWindowIndex);
    if (_activeSalesWindowIndex >= _salesWindows.length) {
      _activeSalesWindowIndex = _salesWindows.length - 1;
    }
    await _applySalesWindow(_salesWindows[_activeSalesWindowIndex]);
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

  void _focusLastAddedCartQuantity() {
    final items = _cart.items;
    if (items.isEmpty) return;
    _suspendCatalogSearchRefocusBriefly();
    setState(() {
      _cartQtyFocusItem = items.first;
      _cartQtyFocusNonce++;
    });
  }

  void _focusCatalogSearchInput() {
    if (!mounted || !isDesktopPosLayout || !widget.isTabActive) return;
    _catalogSearchRefocusTimer?.cancel();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.isTabActive) return;
      if (!_catalogSearchFocus.canRequestFocus) return;
      _catalogSearchFocus.requestFocus();
      final text = _searchController.text;
      if (text.isNotEmpty) {
        _searchController.selection = TextSelection(baseOffset: 0, extentOffset: text.length);
      }
    });
  }

  Future<void> _loadShortcutKeys() async {
    final keys = await SalesKeyboardShortcutsSettings.loadAll();
    if (!mounted) return;
    setState(() => _shortcutKeys = keys);
  }

  void _onShortcutSettingsChanged() {
    unawaited(_loadShortcutKeys());
  }

  void _onStockLimitSettingsChanged() {
    if (mounted) setState(() {});
  }

  void _onCartProfitDisplayChanged() {
    if (mounted) setState(() {});
  }

  bool get _allowNegativeStockSales => SalesStockLimitSettings.allowNegative.value;

  /// Ombor tekshiruvi uchun barcha savat qatorlari.
  ///
  /// Desktopda bir nechta sotuv oynasi bitta omborni bo‘lishadi. Joriy oyna
  /// snapshot’i `CartItem.copy()` nusxalarini saqlagani uchun uni emas, jonli
  /// `_cart.items` ni qo‘shamiz — aks holda o‘zgartirilayotgan qator ikki marta
  /// hisoblanib, qoldiq yetarli bo‘lsa ham cheklov chiqadi.
  List<CartItem> _allCartItemsForStockCheck() {
    if (!isDesktopPosLayout) return _cart.items;
    final items = <CartItem>[];
    for (var i = 0; i < _salesWindows.length; i++) {
      if (i == _activeSalesWindowIndex) continue;
      items.addAll(_salesWindows[i].cartItems);
    }
    items.addAll(_cart.items);
    return items;
  }

  void _notifyStockInsufficient() {
    AppNotify.warning(context, CartStockLimit.message);
  }

  bool _canAddProductToCart(
    Product product, {
    num quantity = 1,
    bool sellByPack = false,
  }) {
    if (_allowNegativeStockSales || _isReturnMode || _isInvoiceEditMode) return true;
    final aligned = ProductsProvider.instance.withBestKnownStock(product);
    final ok = CartStockLimit.allowsAdd(
      product: aligned,
      allItems: _allCartItemsForStockCheck(),
      addQuantity: quantity,
      sellByPack: sellByPack,
    );
    if (!ok) _notifyStockInsufficient();
    return ok;
  }

  bool _canSetCartLineQuantity(
    CartItem item,
    num newQuantity, {
    bool? sellByPack,
    bool notify = true,
  }) {
    if (_allowNegativeStockSales || _isReturnMode || _isInvoiceEditMode) return true;
    if (newQuantity <= 0) return true;
    final aligned = ProductsProvider.instance.withBestKnownStock(item.product);
    final ok = CartStockLimit.allowsLineQuantity(
      product: aligned,
      allItems: _allCartItemsForStockCheck(),
      line: item,
      newQuantity: newQuantity,
      sellByPack: sellByPack,
    );
    if (!ok && notify) _notifyStockInsufficient();
    return ok;
  }

  /// Ombor cheklovi yoniq bo‘lsa, so‘ralgan miqdorni qoldiqqacha qisqartiradi.
  ///
  /// `null` — o‘zgarish qo‘llanmaydi (qoldiq umuman yo‘q yoki allaqachon to‘lgan).
  num? _cartLineQuantityWithinStock(CartItem item, num quantity) {
    if (_canSetCartLineQuantity(item, quantity, notify: false)) return quantity;
    final aligned = ProductsProvider.instance.withBestKnownStock(item.product);
    final maxQty = CartStockLimit.maxLineQuantity(
      product: aligned,
      allItems: _allCartItemsForStockCheck(),
      line: item,
    );
    if (maxQty <= 0 || maxQty >= quantity || maxQty == item.quantity) {
      _notifyStockInsufficient();
      return null;
    }
    final label = maxQty == maxQty.roundToDouble() ? '${maxQty.round()}' : '$maxQty';
    AppNotify.warning(
      context,
      'Omborda $label ta qoldi — miqdor shunga moslashtirildi',
    );
    return maxQty;
  }

  void _updateCartQuantity(CartItem item, num quantity) {
    final within = _cartLineQuantityWithinStock(item, quantity);
    if (within == null) return;
    quantity = within;
    if (quantity <= 0) {
      _cart.remove(item);
      if (identical(_expandedCartLine, item)) _expandedCartLine = null;
    } else {
      _cart.updateQuantity(item, quantity);
    }
    setState(() {});
  }

  void _incrementCartLine(CartItem item) {
    _updateCartQuantity(item, item.quantity + 1);
  }

  void _focusCustomerSearchInput() {
    if (!mounted || !isDesktopPosLayout || !widget.isTabActive) return;
    _suspendCatalogSearchRefocusBriefly();
    if (_selectedClient != null) {
      setState(() {
        _selectedClient = null;
        CustomerGroupDiscount.applyCustomerPricingToCart(_cart.items, null);
        CartDiscountPercent.afterCustomerPricing(_cart.items, _sales.cartDiscountPercent);
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.isTabActive) return;
      if (!_customerSearchFocus.canRequestFocus) return;
      _customerSearchFocus.requestFocus();
    });
  }

  Map<ShortcutActivator, Intent> _salesShortcutIntents() {
    final activators = SalesKeyboardShortcutsSettings.buildActivators(_shortcutKeys);
    return {
      for (final entry in activators.entries)
        entry.key: switch (entry.value) {
          SalesShortcutAction.focusCustomerSearch => const _FocusCustomerSearchIntent(),
          SalesShortcutAction.focusProductSearch => const _FocusCatalogSearchIntent(),
          SalesShortcutAction.focusLastCartQty => const _FocusLastCartQtyIntent(),
          SalesShortcutAction.toggleShowPurchasePrice => const _ToggleShowPurchasePriceIntent(),
          SalesShortcutAction.toggleShowCartProfit => const _ToggleShowCartProfitIntent(),
        },
    };
  }

  Future<void> _toggleCartProfitDisplay() async {
    if (!isDesktopPosLayout) return;
    await SalesCartProfitDisplaySettings.toggle();
    if (mounted) setState(() {});
  }

  void _toggleShowPurchasePriceOnCards() {
    if (!isDesktopPosLayout || _desktopSalesLayoutMode != DesktopSalesLayoutMode.standard) {
      return;
    }
    _sales.setShowPurchasePrice(!_sales.showPurchasePrice);
    setState(() {});
  }

  void _setCartLineSellByPack(CartItem item, bool sellByPack) {
    if (item.sellByPack == sellByPack) return;
    if (sellByPack && !item.product.canSellByPack) return;
    if (!_canSetCartLineQuantity(item, item.quantity, sellByPack: sellByPack)) return;
    item.sellByPack = sellByPack;
    item.salePriceOverride = null;
    item.unitPriceBaseForCartPercent = null;
    _applyCustomerPricingToNewItem(item);
    _cart.updateSalePriceOverride(item, item.salePriceOverride);
  }

  void _clearSearchField() {
    _searchController.clear();
    _query = '';
    if (mounted && !isDesktopPosLayout) setState(() {});
    _refocusCatalogSearch();
  }

  void _onSearchFieldChanged(String v) {
    if (_query != v) {
      _query = v;
      // Desktop: qidiruv matni ValueListenableBuilder orqali yangilanadi —
      // setState TextField fokusini buzmasligi uchun shu yerda chaqirilmaydi.
      if (mounted && !isDesktopPosLayout) setState(() {});
    }
    _barcodeSearchDebounce?.cancel();
    _catalogSearchDebounce?.cancel();
    final q = v.trim();

    // Nom — mahalliy filtr + debounce bilan server; shtrix — avtomatik qo‘shish.
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
        unawaited(
          isDesktopPosLayout ? _desktopBarcodeSearchAndAdd(q) : _searchAndAdd(q),
        );
      });
      return;
    }

    _catalogSearchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      if (_searchController.text.trim() != q) return;
      unawaited(_searchProductsByQuery(q));
    });
  }

  List<Product> _mergeSearchResults(String query, List<Product> local) {
    final q = query.trim();
    if (q.isEmpty) return local;
    if (_sales.lastSearch != q || _sales.salesProducts.isEmpty) return local;

    final seen = local.map((p) => p.id).toSet();
    final merged = [...local];
    for (final p in _sales.salesProducts) {
      if (!product_search.productMatchesSearchQuery(p, q)) continue;
      if (seen.add(p.id)) merged.add(p);
    }
    return product_search.sortProductsBySearchRelevance(merged, q);
  }

  /// Desktop: kategoriya/brend tanlanganida filtr, aks holda to'liq katalog.
  List<Product> get _desktopBrowseProducts {
    final hasCatBrand = _sales.categoryId != null || _sales.brandId != null;
    var list = List<Product>.from(_catalogProductsForSearch());

    if (hasCatBrand) {
      if (!_sales.productsLoading && _sales.salesProducts.isNotEmpty) {
        list = ProductsProvider.instance.withCatalogStockAll(_sales.salesProducts);
      } else {
        list = ProductCatalogFilter.apply(
          list,
          categoryId: _sales.categoryId,
          brandId: _sales.brandId,
          categories: _sales.categories,
          brands: _sales.brands,
        );
      }
    } else if (list.isEmpty) {
      list = _sales.catalogProductsVisible;
    }

    if (_sales.hideZeroStock) {
      list = list.where((p) => p.hasStock).toList();
    }
    return _sortCatalogProducts(list);
  }

  List<Product> _desktopCatalogProductsFor(String searchQuery) {
    final q = searchQuery.trim();
    if (q.isNotEmpty) {
      final local = product_search.filterCatalogProducts(_catalogProductsForSearch(), q);
      return _mergeSearchResults(q, local);
    }
    if (_desktopSalesLayoutMode == DesktopSalesLayoutMode.restaurant) {
      if (_restaurantCategoryId != null) return _restaurantCategoryProducts;
      return _desktopBrowseProducts;
    }
    return _desktopBrowseProducts;
  }

  /// Nom/SKU — mahalliy + server qidiruv; shtrix/PLU/tarozi — alohida.
  Future<void> _searchProductsByQuery(String query) async {
    final q = query.trim();
    if (q.isEmpty) {
      if (_sales.lastSearch.isNotEmpty) {
        _sales.setSearchQuery('');
        await _sales.loadProducts(reset: true, searchValue: '');
      }
      if (mounted) setState(() {});
      return;
    }
    if (product_search.looksLikeBarcodeOrPluInput(q)) {
      if (isDesktopPosLayout) {
        await _desktopBarcodeSearchAndAdd(q);
      } else {
        await _searchAndAdd(q);
      }
      return;
    }

    _sales.setSearchQuery(q);
    await _sales.loadProducts(reset: true, searchValue: q);
    if (mounted) setState(() {});
  }

  int get _cartRawTotal => _cart.items.fold<int>(0, (s, e) => s + e.total);

  int get _cartCatalogTotal => CartDiscountPercent.catalogLinesTotal(_cart.items);

  int get _cartGrandTotal => _cartRawTotal;

  int get _cartProfitTotal =>
      _cartGrandTotal - SalesStoreBody.estimateCostUzs(_cart.items);

  Widget _mobileCashRegisterBar() {
    final registers = _sales.cashRegisters;
    if (registers.length <= 1) return const SizedBox.shrink();

    Map<String, dynamic> selected = registers.first;
    final selectedId = _sales.cashRegisterId;
    for (final r in registers) {
      if (cashRegisterParseId(r['id']) == selectedId) {
        selected = r;
        break;
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: AppDropdownField<Map<String, dynamic>>(
        label: 'Kassa',
        value: selected,
        items: registers
            .map(
              (r) => appDropdownItem(
                value: r,
                label: cashRegisterDisplayTitle(r),
              ),
            )
            .toList(),
        onChanged: (r) {
          if (r == null) return;
          _sales.selectCashRegister(r);
          unawaited(_refreshSavedOrdersCount());
          setState(() {});
        },
      ),
    );
  }

  /// Mobil: «Sotuv bo'limi» / «Qaytarishlar» — desktopdagi yuqori kartochkalar muqobili.
  Widget _mobileModeSwitch(bool returnMode) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Expanded(
              child: _mobileModeTab(
                label: "Sotuv bo'limi",
                icon: Icons.shopping_cart_rounded,
                selected: !returnMode,
                color: AppTheme.primary,
                onTap: () => _setReturnMode(false),
              ),
            ),
            Expanded(
              child: _mobileModeTab(
                label: 'Qaytarishlar',
                icon: Icons.replay_rounded,
                selected: returnMode,
                color: AppTheme.returnAccent,
                onTap: () => _setReturnMode(true),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mobileModeTab({
    required String label,
    required IconData icon,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
  }) {
    final fg = selected ? Colors.white : AppTheme.textSecondary;
    return Material(
      color: selected ? color : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: selected ? null : onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: fg),
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
    if (isDesktopPosLayout) {
      return _buildDesktopPos(context);
    }

    final items = _cart.items;
    final showSearchResults = _query.trim().isNotEmpty;
    final products = showSearchResults ? _mobileCatalogProducts : const <Product>[];
    final catalogLoading = showSearchResults &&
        products.isEmpty &&
        (_sales.productsLoading || !_products.isLoaded);
    final shift = CashRegisterShiftProvider.instance;
    final showShiftDashboard = shift.requiresCashRegister && shift.isShiftOpen;
    final returnMode = _isReturnMode;
    final accent = returnMode ? AppTheme.returnAccent : AppTheme.primary;

    return CashRegisterShiftGate(
      child: Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(returnMode ? 'Qaytarishlar' : Strings.savatcha),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: returnMode ? AppTheme.returnSurface : AppTheme.cardBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${items.length}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: returnMode ? AppTheme.returnText : AppTheme.textPrimary,
                ),
              ),
            ),
          ],
        ),
        actions: [
          if (!returnMode)
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
          _mobileModeSwitch(returnMode),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      hintText: Strings.artikulShtrixIsm,
                      prefixIcon: Icon(Icons.search_rounded, color: AppTheme.textSecondary),
                    ),
                    onChanged: _onSearchFieldChanged,
                    onSubmitted: (q) async {
                      _barcodeSearchDebounce?.cancel();
                      _catalogSearchDebounce?.cancel();
                      final trimmed = q.trim();
                      if (trimmed.isEmpty) return;
                      await _searchProductsByQuery(trimmed);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: accent,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    onTap: () => _openScanner(context),
                    borderRadius: BorderRadius.circular(10),
                    child: const Padding(
                      padding: EdgeInsets.all(11),
                      child: Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 22),
                    ),
                  ),
                ),
              ],
            ),
          ),
          _mobileCashRegisterBar(),
          Expanded(
            child: GestureDetector(
              onTap: () {
                FocusScope.of(context).unfocus();
                FocusManager.instance.primaryFocus?.unfocus();
              },
              // deferToChild: miqdor TextField birinchi bosishda fokus oladi;
              // translucent ota onTap fokusni darhol yopib yuborardi.
              behavior: HitTestBehavior.deferToChild,
              child: ThrottledRefreshIndicator(
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
                                  showSkuInTitle: ProductDisplaySettings.showSkuInTitle.value,
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
                              accent: accent,
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
                              onIncrement: () => _incrementCartLine(item),
                              onDecrement: () {
                                if (item.quantity > 1) {
                                  _updateCartQuantity(item, item.quantity - 1);
                                } else {
                                  _cart.remove(item);
                                  setState(() {});
                                }
                              },
                              onQuantityChanged: (newQty) => _updateCartQuantity(item, newQty),
                            );
                          },
                        ),
              ),
            ),
          ),
        if (items.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    // Qaytarishda saqlangan buyurtma bo‘lmaydi (desktop bilan bir xil).
                    if (!returnMode) ...[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _sales.holdCartInFlight ? null : () => _holdCart(context),
                          icon: _sales.holdCartInFlight
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                                )
                              : const Icon(Icons.pause_circle_outline_rounded, size: 20),
                          label: Text(_sales.holdCartInFlight ? 'Saqlanmoqda...' : Strings.toxtatish),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            visualDensity: VisualDensity.compact,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showDiscountDialog(context),
                        icon: Icon(
                          Icons.percent_rounded,
                          size: 20,
                          color: _sales.cartDiscountPercent != 0 ? accent : null,
                        ),
                        label: Text(
                          _sales.cartDiscountPercent != 0
                              ? 'Chegirma ${CartDiscountPercent.discountPercentToUi(_sales.cartDiscountPercent)}%'
                              : 'Chegirma',
                          style: TextStyle(
                            color: _sales.cartDiscountPercent != 0 ? accent : null,
                            fontWeight: _sales.cartDiscountPercent != 0 ? FontWeight.w600 : null,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: () => _openPayment(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: returnMode ? AppTheme.returnAccent : null,
                      foregroundColor: returnMode ? Colors.white : null,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(returnMode ? 'Qaytarish qilish' : Strings.keyingisi),
                        const SizedBox(width: 4),
                        Icon(
                          returnMode
                              ? Icons.assignment_return_rounded
                              : Icons.arrow_forward_rounded,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
    );
  }

  String _barcodeNotFoundMessage(String? message) {
    final m = (message ?? '').trim();
    if (m.isEmpty) return "Bu shtrix kod bo'yicha mahsulot topilmadi";
    final lower = m.toLowerCase();
    if (lower.contains('https scanning') ||
        lower.contains('proksi') ||
        lower.contains('json o‘rniga') ||
        lower.contains("json o'rniga") ||
        lower.contains('<html') ||
        lower == 'topilmadi') {
      return "Bu shtrix kod bo'yicha mahsulot topilmadi";
    }
    return m;
  }

  Future<void> _searchAndAdd(String query) async {
    final q = query.trim();
    if (q.isEmpty || _barcodeSearchInFlight) return;
    _barcodeSearchInFlight = true;
    try {
      final result = await BarcodeProductLookup.resolveDetailed(
        query: q,
        salesScreenProducts: _sales.salesProducts,
        branchId: _sales.branchId ?? 1,
      );
      if (result.found) {
        _addProductToCart(result.product!, quantity: result.quantity);
        _clearSearchField();
        return;
      }
      if (result.scalePluNotFound) {
        if (mounted) {
          AppNotify.info(context, _barcodeNotFoundMessage(result.message));
        }
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
    } catch (_) {
      if (mounted) {
        AppNotify.info(context, "Bu shtrix kod bo'yicha mahsulot topilmadi");
      }
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

  void _addProductToCart(Product product, {num quantity = 1}) {
    final qty = quantity > 0 ? quantity : 1;
    void afterAdd(CartItem line) {
      _applyCustomerPricingToNewItem(line);
      _expandedCartLine = null;
      setState(() {});
    }

    void addLine({required bool sellByPack}) {
      if (!_canAddProductToCart(product, quantity: qty, sellByPack: sellByPack)) {
        return;
      }
      afterAdd(_cart.add(CartItem(product: product, quantity: qty, sellByPack: sellByPack)));
    }

    // Taroz (kg) — pachka tanlash oynasi kerak emas.
    if (qty != 1) {
      addLine(sellByPack: false);
      _refocusCatalogSearch();
      return;
    }

    if (product.canSellByPack && !isDesktopPosLayout) {
      showCupertinoModalPopup<void>(
        context: context,
        builder: (ctx) => CupertinoActionSheet(
          title: Text(product.name),
          message: const Text('Sotish turini tanlang'),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(ctx);
                addLine(sellByPack: true);
              },
              child: Text(_packChoiceLabel(product)),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(ctx);
                addLine(sellByPack: false);
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
      addLine(sellByPack: false);
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
    if (result.sellByPack != null) {
      _setCartLineSellByPack(item, result.sellByPack!);
    }
    final def = item.defaultLineUnitPrice;
    final price = result.price;
    _setCartLineUnitPrice(item, price != null && price == def ? null : price);
    setState(() {});
  }

  void _openSalesListForCurrentRegister() {
    if (!isDesktopPosLayout) {
      PosNavigation.openTransactionsSection?.call();
      return;
    }
    setState(() {
      _showDesktopSalesList = true;
      _desktopSalesListMounted = true;
    });
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
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _searchController,
      builder: (context, searchValue, _) =>
          _buildDesktopPosScaffold(context, items, searchValue.text),
    );
  }

  Widget _buildDesktopPosScaffold(
    BuildContext context,
    List<CartItem> items,
    String searchQuery,
  ) {
    return Scaffold(
      body: Shortcuts(
        shortcuts: _salesShortcutIntents(),
        child: Actions(
          actions: <Type, Action<Intent>>{
            _FocusLastCartQtyIntent: CallbackAction<_FocusLastCartQtyIntent>(
              onInvoke: (_) {
                _focusLastAddedCartQuantity();
                return null;
              },
            ),
            _FocusCatalogSearchIntent: CallbackAction<_FocusCatalogSearchIntent>(
              onInvoke: (_) {
                _focusCatalogSearchInput();
                return null;
              },
            ),
            _FocusCustomerSearchIntent: CallbackAction<_FocusCustomerSearchIntent>(
              onInvoke: (_) {
                _focusCustomerSearchInput();
                return null;
              },
            ),
            _ToggleShowPurchasePriceIntent: CallbackAction<_ToggleShowPurchasePriceIntent>(
              onInvoke: (_) {
                _toggleShowPurchasePriceOnCards();
                return null;
              },
            ),
            _ToggleShowCartProfitIntent: CallbackAction<_ToggleShowCartProfitIntent>(
              onInvoke: (_) {
                unawaited(_toggleCartProfitDisplay());
                return null;
              },
            ),
          },
          child: CashRegisterShiftGate(
            child: SavatchaDesktopLayout(
        searchController: _searchController,
        catalogSearchFocus: _catalogSearchFocus,
        onCatalogSearchRefocus: _refocusCatalogSearch,
        onSuspendCatalogSearchRefocus: _suspendCatalogSearchRefocusBriefly,
        query: searchQuery,
        catalogProducts: _desktopCatalogProductsFor(searchQuery),
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
        showSkuInProductTitle: ProductDisplaySettings.showSkuInTitle.value,
        catalogSellPriceType: _sales.activeSellPriceType,
        sellerName: _sellerName.isNotEmpty ? _sellerName : 'Sotuvchi',
        cartGrandTotal: _cartGrandTotal,
        cartCatalogTotal: _cartCatalogTotal,
        cartProfitTotal: _cartProfitTotal,
        showCartProfit: SalesCartProfitDisplaySettings.visible.value,
        cartDiscountPercent: _sales.cartDiscountPercent,
        usdExchangeRate: _sales.usdRate > 0 ? _sales.usdRate : 12600,
        onSearchChanged: _onSearchFieldChanged,
        onSearchSubmitted: _desktopSearchSubmit,
        categoryFilterId: _sales.categoryId,
        brandFilterId: _sales.brandId,
        filterCategories: _sales.categories,
        filterBrands: _sales.brands,
        onCategoryFilterChanged: (v) async {
          if (_sales.categories.isEmpty) {
            await _sales.reloadFilterLists();
          }
          await _sales.setCategoryFilter(v);
          if (mounted) setState(() {});
        },
        onBrandFilterChanged: (v) async {
          if (_sales.brands.isEmpty) {
            await _sales.reloadFilterLists();
          }
          await _sales.setBrandFilter(v);
          if (mounted) setState(() {});
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
            sharpCorners: false,
            searchFocusNode: _customerSearchFocus,
            shortcutKeyLabel: SalesKeyboardShortcutsSettings.resolveKeyLabel(
              _shortcutKeys,
              SalesShortcutAction.focusCustomerSearch,
            ),
            accentColor: _isReturnMode ? AppTheme.returnAccent : AppTheme.primary,
          ),
        ),
        shortcutKeys: _shortcutKeys,
        onOpenSavedOrders: () => _runWithSuspendedCatalogSearchRefocus(
          () => SalesHoldOrdersSheet.show(
            context,
            onResume: _resumeHoldOrder,
            onExportExcel: _exportHoldOrderExcel,
            onListChanged: () => unawaited(_refreshSavedOrdersCount()),
          ),
        ),
        savedOrdersCount: _savedOrdersCount,
        onLoadMoreProducts: searchQuery.trim().isEmpty &&
                _sales.hasMoreProducts &&
                !_sales.productsLoading
            ? () => _sales.loadMoreProducts()
            : null,
        onClearCart: _clearCart,
        onSalesList: _openSalesListForCurrentRegister,
        showSalesList: _showDesktopSalesList,
        keepSalesListAlive: _desktopSalesListMounted,
        salesListPanel: TranzaksiyalarScreen(
          filterByCurrentEmployee: true,
          tabIndex: 1,
          currentIndex: _showDesktopSalesList ? 1 : 0,
        ),
        onProductTap: (p) => _addProductToCart(p),
        cartQtyFocusNonce: _cartQtyFocusNonce,
        cartQtyFocusItem: _cartQtyFocusItem,
        expandedCartItem: _expandedCartLine,
        onToggleCartExpand: (item) {
          setState(() {
            _expandedCartLine = identical(_expandedCartLine, item) ? null : item;
          });
        },
        onCollapseCartExpand: () {
          setState(() => _expandedCartLine = null);
        },
        onCartQuantityChanged: (item, qty) => _updateCartQuantity(item, qty),
        onCartUnitPriceChanged: (item, override) {
          _setCartLineUnitPrice(item, override);
          setState(() {});
        },
        onCartSellByPackChanged: (item, sellByPack) {
          _setCartLineSellByPack(item, sellByPack);
          setState(() {});
        },
        onRemoveCartItem: (item) {
          _cart.remove(item);
          if (identical(_expandedCartLine, item)) _expandedCartLine = null;
          setState(() {});
        },
        onIncrement: _incrementCartLine,
        onDecrement: (item) {
          if (item.quantity > 1) {
            _updateCartQuantity(item, item.quantity - 1);
          } else {
            _cart.remove(item);
            if (identical(_expandedCartLine, item)) _expandedCartLine = null;
            setState(() {});
          }
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
        onRestaurantCategoriesReordered: _onRestaurantCategoriesReordered,
        onOpenSectionMenu: widget.onOpenSectionMenu,
        onGlobalSync: widget.onGlobalSync,
        globalSyncing: DesktopShellScope.maybeOf(context)?.syncing ?? false,
        salesWindowCount: _salesWindows.length,
        activeSalesWindowIndex: _activeSalesWindowIndex,
        onSalesWindowSelected: _switchSalesWindow,
        onAddSalesWindow: _addSalesWindow,
        canAddSalesWindow: items.isNotEmpty,
            ),
          ),
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
    _activeHoldQueueNumber = null;
    _selectedClient = null;
    _setCartDiscountPercent(0);
    _captureActiveSalesWindow();
  }

  void _setReturnMode(bool returnMode) {
    if (_showDesktopSalesList) {
      setState(() => _showDesktopSalesList = false);
    }
    if (_isReturnMode == returnMode) return;
    if (_cart.items.isNotEmpty) _clearCart();
    setState(() => _isReturnMode = returnMode);
    _captureActiveSalesWindow();
    if (returnMode) {
      unawaited(() async {
        try {
          await SalesApi.setReturnsType();
        } catch (_) {}
      }());
    }
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
    _activeHoldQueueNumber = resume.queueNumber;
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
      _captureActiveSalesWindow();
      await _refreshSavedOrdersCount();
      AppNotify.success(
        context,
        'Buyurtma qayta ochildi — qayta pauza qilsangiz shu buyurtma yangilanadi',
      );
      _refocusCatalogSearch();
    }
  }

  void _clearInvoiceEditState() {
    _invoiceEditOrderId = null;
    _invoiceEditReason = null;
    _invoiceEditSourceInvoiceId = null;
  }

  Future<void> _applyPendingInvoiceEditIfAny() async {
    final pending = _sales.consumePendingInvoiceEdit();
    if (pending == null) return;
    await _resumeInvoiceEdit(pending.resume, pending.hold);
  }

  Future<void> _resumeInvoiceEdit(InvoiceEditResume resume, HoldOrderResume hold) async {
    _cart.clear();
    _activeHoldOrderId = null;
    _activeHoldInvoiceId = null;
    _activeHoldQueueNumber = null;
    _isReturnMode = false;
    for (final item in hold.items) {
      _cart.add(CartItem(
        product: item.product,
        quantity: item.quantity,
        sellByPack: item.sellByPack,
        salePriceOverride: item.salePriceOverride,
      ));
    }
    _invoiceEditOrderId = resume.editOrderId;
    _invoiceEditReason = resume.editReason;
    _invoiceEditSourceInvoiceId = resume.sourceInvoiceId;
    _selectedClient = hold.customer;
    unawaited(ClientsProvider.instance.fetchCustomerGroups().then((groups) {
      if (!mounted) return;
      CustomerGroupDiscount.applyCustomerPricingToCart(
        _cart.items,
        hold.customer,
        groups: groups,
      );
      CartDiscountPercent.afterCustomerPricing(_cart.items, _sales.cartDiscountPercent);
      setState(() {});
    }));
    final pct = hold.discountPercent ?? resume.discountPercent ?? 0;
    _sales.setCartDiscountPercent(pct);
    for (final item in _cart.items) {
      CartDiscountPercent.syncBaseFromCurrent(item);
      if (pct != 0 && item.hasSalePriceOverride) {
        item.unitPriceBaseForCartPercent = item.unitPriceForLine / ((100 + pct) / 100);
      }
      CartDiscountPercent.applyToItem(item, pct);
    }
    _syncDiscountPercentField();
    if (mounted) {
      setState(() {});
      _captureActiveSalesWindow();
      final src = resume.sourceInvoiceId;
      final label = src != null && src.isNotEmpty
          ? (src.toUpperCase().startsWith('POS') ? src : 'POS$src')
          : '#${resume.editOrderId}';
      AppNotify.info(
        context,
        'Chek tahrirlash: $label — o‘zgartirishlarni kiritib to‘lang',
      );
      _refocusCatalogSearch();
    }
  }

  Future<void> _desktopBarcodeSearchAndAdd(String q) async {
    if (_barcodeSearchInFlight) return;
    _barcodeSearchInFlight = true;
    try {
      final result = await BarcodeProductLookup.resolveDetailed(
        query: q,
        salesScreenProducts: _sales.salesProducts,
        branchId: _sales.branchId ?? 1,
      );
      if (result.found) {
        _addProductToCart(result.product!, quantity: result.quantity);
        _clearSearchField();
        return;
      }
      if (result.scalePluNotFound) {
        if (mounted) {
          AppNotify.info(context, _barcodeNotFoundMessage(result.message));
        }
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

      // barcode-search topmadi — kod SKU yoki nom ichida bo‘lishi mumkin,
      // shuning uchun web kabi umumiy qidiruvga tushamiz.
      _sales.setSearchQuery(q);
      await _sales.loadProducts(reset: true, searchValue: q);
      if (!mounted) return;
      setState(() {});

      final pending = _sales.takePendingBarcodeProduct();
      if (pending != null) {
        _addProductToCart(pending);
        _clearSearchField();
        return;
      }
      if (_desktopCatalogProductsFor(q).isNotEmpty) return;

      AppNotify.info(context, "Bu shtrix kod bo'yicha mahsulot topilmadi");
    } catch (_) {
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
    await _searchProductsByQuery(q);
  }

  Future<void> _holdCart(BuildContext context) async {
    if (_isInvoiceEditMode) {
      AppNotify.warning(context, 'Chek tahrirlash rejimida pauza qilib bo‘lmaydi');
      return;
    }
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
    _activeHoldQueueNumber = null;
    _selectedClient = null;
    _setCartDiscountPercent(0);
    await _refreshSavedOrdersCount();
    _captureActiveSalesWindow();
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
      return _showDesktopDiscountDialog(context);
    }
    return _openChergirmaScreen(context);
  }

  Future<void> _openChergirmaScreen(BuildContext context) async {
    final cartTotal = _cartGrandTotal;
    if (cartTotal <= 0) {
      AppNotify.info(context, 'Savat bo\'sh');
      return;
    }

    final r = await Navigator.push<ChergirmaResult>(
      context,
      MaterialPageRoute(
        builder: (_) => ChergirmaScreen(
          totalUzs: cartTotal,
          distributeToCartLines: true,
        ),
      ),
    );
    if (r != null && mounted) {
      _applyChergirmaResult(r);
    }
  }

  void _applyChergirmaResult(ChergirmaResult r) {
    switch (r.mode) {
      case ChergirmaMode.clear:
        _clearCartDiscount();
        break;
      case ChergirmaMode.percent:
        _setCartDiscountPercent(r.value.clamp(-100, 100));
        break;
      case ChergirmaMode.discountUzs:
        _applyPaymentDiscount(_cartGrandTotal - r.value);
        break;
      case ChergirmaMode.customerPays:
        _applyPaymentDiscount(r.value);
        break;
    }
  }

  void _clearCartDiscount() {
    _sales.setCartDiscountPercent(0);
    for (final item in _cart.items) {
      CartDiscountPercent.applyToItem(item, 0);
      _cart.updateSalePriceOverride(item, item.salePriceOverride);
    }
    _syncDiscountPercentField();
    setState(() {});
  }

  Future<void> _showDesktopDiscountDialog(BuildContext context) async {
    final cartTotal = _cartGrandTotal;
    if (cartTotal <= 0) {
      AppNotify.info(context, 'Savat bo\'sh');
      return;
    }

    var byPercent = _sales.cartDiscountPercent != 0;
    final valueController = TextEditingController(
      text: byPercent
          ? '${CartDiscountPercent.discountPercentToUi(_sales.cartDiscountPercent)}'
          : formatThousands(cartTotal),
    );

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            int? percentValue() {
              final t = valueController.text.trim();
              if (t.isEmpty) return null;
              return int.tryParse(t);
            }

            int? sumValue() => parseFormattedSum(valueController.text);

            final paid = (sumValue() ?? cartTotal).clamp(0, cartTotal);
            final sumDiscount = cartTotal - paid;

            final pct = percentValue() ?? 0;
            final percentDiscount = CartDiscountPercent.previewDiscountUzs(cartTotal, pct);

            final previewDiscount = byPercent ? percentDiscount : sumDiscount;

            bool canSave() {
              if (byPercent) {
                final v = percentValue();
                return v != null && v >= 0 && v <= 100;
              }
              final v = sumValue();
              return v != null && v >= 0 && v <= cartTotal;
            }

            void setUnit(bool percent) {
              setDialogState(() {
                byPercent = percent;
                valueController.text = percent
                    ? (_sales.cartDiscountPercent != 0
                        ? '${CartDiscountPercent.discountPercentToUi(_sales.cartDiscountPercent)}'
                        : '')
                    : formatThousands(cartTotal);
              });
            }

            Widget unitToggle() {
              return DecoratedBox(
                decoration: BoxDecoration(
                  color: AppTheme.cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.divider),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _discountUnitSegment('%', byPercent, () => setUnit(true)),
                    _discountUnitSegment("so'm", !byPercent, () => setUnit(false)),
                  ],
                ),
              );
            }

            return AlertDialog(
              title: Text(byPercent ? 'Chegirma (foiz)' : 'Chegirma (summa)'),
              content: SizedBox(
                width: 420,
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
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: valueController,
                            autofocus: true,
                            keyboardType: TextInputType.number,
                            inputFormatters: byPercent
                                ? [FilteringTextInputFormatter.allow(RegExp(r'^\d{0,3}'))]
                                : [ThousandsInputFormatter()],
                            onChanged: (_) => setDialogState(() {}),
                            decoration: InputDecoration(
                              labelText: byPercent ? 'Chegirma foizi' : 'Mijoz to\'laydi',
                              suffixText: byPercent ? '%' : 'so\'m',
                              helperText: byPercent
                                  ? 'Masalan: 10 — 10% chegirma'
                                  : 'Farq avtomatik chegirma bo\'lib qatorlarga taqsimlanadi',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        unitToggle(),
                      ],
                    ),
                    if (previewDiscount > 0) ...[
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
                              '${formatThousands(previewDiscount)} so\'m',
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
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _clearCartDiscount();
                  },
                  child: const Text('Tozalash'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(Strings.bekorQilish),
                ),
                FilledButton(
                  onPressed: canSave()
                      ? () {
                          if (byPercent) {
                            final p = percentValue();
                            if (p == null) return;
                            Navigator.pop(ctx);
                            _setCartDiscountPercent(
                              CartDiscountPercent.discountPercentFromUi(p),
                            );
                            return;
                          }
                          final amount = sumValue();
                          if (amount == null) return;
                          if (amount < 0 || amount > cartTotal) {
                            AppNotify.error(ctx, '0 dan $cartTotal gacha summa kiriting');
                            return;
                          }
                          Navigator.pop(ctx);
                          _applyPaymentDiscount(amount);
                        }
                      : null,
                  child: const Text(Strings.saqlash),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _discountUnitSegment(String label, bool selected, VoidCallback onTap) {
    return Material(
      color: selected ? AppTheme.primary : Colors.transparent,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: Container(
          width: 52,
          height: 56,
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: selected ? Colors.white : AppTheme.textSecondary,
            ),
          ),
        ),
      ),
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
    final orderId = _isInvoiceEditMode ? null : _activeHoldOrderId;
    final invoiceId = _isInvoiceEditMode ? null : _activeHoldInvoiceId;
    final queueNumber = _isInvoiceEditMode ? null : _activeHoldQueueNumber;
    final editOrderId = _invoiceEditOrderId;
    final editReason = _invoiceEditReason;
    final client = _selectedClient;

    void afterPayment() {
      if (!mounted) return;
      _cart.clear();
      _expandedCartLine = null;
      _activeHoldOrderId = null;
      _activeHoldInvoiceId = null;
      _activeHoldQueueNumber = null;
      _clearInvoiceEditState();
      _selectedClient = null;
      _setCartDiscountPercent(0);
      _isReturnMode = false;
      if (isDesktopPosLayout) {
        unawaited(_closeActiveSalesWindowAfterPayment().then((_) {
          if (!mounted) return;
          setState(() {});
          unawaited(_refreshSavedOrdersCount(force: true));
          _refocusCatalogSearch();
        }));
      } else {
        setState(() {});
        unawaited(_refreshSavedOrdersCount(force: true));
        _refocusCatalogSearch();
      }
    }

    if (isDesktopPosLayout) {
      _catalogSearchRefocusSuspend++;
      DesktopPaymentScreen.show(
        context,
        items: List.from(items),
        initialClient: client,
        initialOrderId: orderId,
        initialInvoiceId: invoiceId,
        initialQueueNumber: queueNumber,
        editOrderId: editOrderId,
        editReason: editReason,
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
          initialQueueNumber: queueNumber,
          editOrderId: editOrderId,
          editReason: editReason,
          isReturnCheckout: _isReturnMode,
          onCustomerChanged: _onCustomerSelected,
        ),
      ),
    ).then((result) {
      if (result == 'held') {
        afterPayment();
      } else if (result is String && result.isNotEmpty) {
        final wasReturn = _isReturnMode;
        afterPayment();
        if (mounted) {
          final label = result.startsWith('POS') ? result : 'POS$result';
          AppNotify.success(
            context,
            wasReturn
                ? 'Qaytarish #$label muvaffaqiyatli!'
                : 'Tranzaksiya #$label muvaffaqiyatli!',
          );
        }
      }
    });
  }

}

class _EmptyCart extends StatelessWidget {
  final VoidCallback onScanner;
  final Color accent;

  const _EmptyCart({required this.onScanner, this.accent = AppTheme.primary});

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
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
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
    _controller = TextEditingController(text: _formatQuantity(widget.item.quantity));
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(covariant _CartItemTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_editing && !_focusNode.hasFocus) {
      final t = _formatQuantity(widget.item.quantity);
      if (_controller.text != t) _controller.text = t;
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus && _editing) {
      // setState paytida vaqtinchalik focus yo'qolishi mumkin — keyingi frameda tekshiramiz.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _focusNode.hasFocus || !_editing) return;
        _applyAndClose();
      });
    }
  }

  void _startEditing() {
    if (widget.onQuantityChanged == null) return;
    _controller.text = _formatQuantity(widget.item.quantity);
    setState(() => _editing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_editing) return;
      _focusNode.requestFocus();
      _controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _controller.text.length,
      );
    });
  }

  void _applyAndClose() {
    final s = _controller.text.trim().replaceAll(',', '.').replaceAll(' ', '');
    final q = num.tryParse(s);
    if (q != null && q > 0 && widget.onQuantityChanged != null) {
      widget.onQuantityChanged!(q);
    } else {
      _controller.text = _formatQuantity(widget.item.quantity);
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
    final unitLabel = item.sellByPack ? 'pachka' : 'dona';
    final canEdit = widget.onQuantityChanged != null;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: InkWell(
                onTap: widget.onLineTap,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
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
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              p.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                height: 1.15,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _formatLineTotal(item),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppTheme.primary,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              item.hasSalePriceOverride
                                  ? 'Vaqtinchalik · ${_formatQuantity(item.quantity)} $unitLabel'
                                  : '${_formatQuantity(item.quantity)} $unitLabel',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: item.hasSalePriceOverride
                                    ? FontWeight.w500
                                    : FontWeight.w400,
                                color: item.hasSalePriceOverride
                                    ? Colors.orange.shade800
                                    : AppTheme.textSecondary,
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
            const SizedBox(width: 8),
            Container(
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.cardBg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.remove_rounded, size: 20),
                    onPressed: () {
                      if (_editing) _applyAndClose();
                      widget.onDecrement();
                    },
                  ),
                  SizedBox(
                    width: 48,
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      readOnly: !_editing,
                      showCursor: _editing,
                      enableInteractiveSelection: _editing,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                        border: InputBorder.none,
                      ),
                      onTap: canEdit
                          ? () {
                              if (!_editing) {
                                _startEditing();
                              } else {
                                _controller.selection = TextSelection(
                                  baseOffset: 0,
                                  extentOffset: _controller.text.length,
                                );
                              }
                            }
                          : null,
                      onSubmitted: (_) => _applyAndClose(),
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.add_rounded, size: 20),
                    onPressed: () {
                      if (_editing) _applyAndClose();
                      widget.onIncrement();
                    },
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
  const _CartLinePriceResult.saved(this.price, {this.sellByPack});

  final double? price;
  final bool? sellByPack;
}

class _CartLinePriceEditSheet extends StatefulWidget {
  const _CartLinePriceEditSheet({required this.item});

  final CartItem item;

  @override
  State<_CartLinePriceEditSheet> createState() => _CartLinePriceEditSheetState();
}

class _CartLinePriceEditSheetState extends State<_CartLinePriceEditSheet> {
  late final TextEditingController _priceCtrl;
  late bool _sellByPack;
  String? _activePriceType;

  @override
  void initState() {
    super.initState();
    _sellByPack = widget.item.sellByPack;
    _priceCtrl = TextEditingController(text: formatThousands(widget.item.unitPriceDisplay));
    _activePriceType = _detectActivePriceType();
  }

  @override
  void dispose() {
    _priceCtrl.dispose();
    super.dispose();
  }

  CartItem get _probe => CartItem(
        product: widget.item.product,
        quantity: widget.item.quantity,
        sellByPack: _sellByPack,
      );

  bool get _sellByPackChanged => _sellByPack != widget.item.sellByPack;

  bool? get _sellByPackResult => _sellByPackChanged ? _sellByPack : null;

  String? _detectActivePriceType() {
    final current = parseFormattedSum(_priceCtrl.text)?.toDouble() ??
        widget.item.unitPriceDisplay.toDouble();
    const types = [
      CustomerGroupDiscount.selling,
      CustomerGroupDiscount.wholesale,
    ];
    for (final type in types) {
      final price = CustomerGroupDiscount.catalogUnitPriceForItem(_probe, type);
      if ((current - price).abs() < 0.5) return type;
    }
    return null;
  }

  void _syncActiveFromField() {
    final next = _detectActivePriceType();
    if (next != _activePriceType) {
      setState(() => _activePriceType = next);
    }
  }

  void _selectCatalogPriceType(String priceType) {
    final price = CustomerGroupDiscount.catalogUnitPriceForItem(_probe, priceType);
    setState(() {
      _activePriceType = priceType;
      _priceCtrl.text = formatThousands(price.round());
    });
  }

  void _setSellByPack(bool sellByPack) {
    if (_sellByPack == sellByPack) return;
    setState(() => _sellByPack = sellByPack);
    final type = _activePriceType ?? CustomerGroupDiscount.selling;
    final price = CustomerGroupDiscount.catalogUnitPriceForItem(_probe, type);
    _priceCtrl.text = formatThousands(price.round());
    setState(() => _activePriceType = type);
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
    Navigator.pop(
      context,
      _CartLinePriceResult.saved(v.toDouble(), sellByPack: _sellByPackResult),
    );
  }

  Widget _priceTypeChip({
    required String label,
    required num price,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected ? AppTheme.primary.withValues(alpha: 0.08) : Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? AppTheme.primary : AppTheme.divider,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected ? AppTheme.primary : AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                formatThousands(price.round()),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: selected ? AppTheme.primary : AppTheme.textPrimary,
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
    final item = widget.item;
    final product = item.product;
    final unitHint = _sellByPack ? '1 pachka narxi' : '1 dona narxi';
    final sellingPrice = CustomerGroupDiscount.catalogUnitPriceForItem(
      _probe,
      CustomerGroupDiscount.selling,
    );
    final wholesalePrice = CustomerGroupDiscount.catalogUnitPriceForItem(
      _probe,
      CustomerGroupDiscount.wholesale,
    );

    return IosStyleModals.sheetKeyboardForm(
      context: context,
      onCancel: () => Navigator.pop(context),
      onSave: _save,
      cancelLabel: Strings.bekorQilish,
      saveLabel: Strings.saqlash,
      body: [
        const Text(
          "Narxni o'zgartirish",
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: AppTheme.textPrimary),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _priceCtrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          inputFormatters: [ThousandsInputFormatter()],
          onChanged: (_) => _syncActiveFromField(),
          decoration: _fieldDecoration(unitHint, suffix: Strings.som),
        ),
        const SizedBox(height: 14),
        const Text(
          'Sotish turi',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _priceTypeChip(
                label: 'Sotish',
                price: sellingPrice,
                selected: _activePriceType == CustomerGroupDiscount.selling,
                onTap: () => _selectCatalogPriceType(CustomerGroupDiscount.selling),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _priceTypeChip(
                label: 'Ulgurji',
                price: wholesalePrice,
                selected: _activePriceType == CustomerGroupDiscount.wholesale,
                onTap: () => _selectCatalogPriceType(CustomerGroupDiscount.wholesale),
              ),
            ),
          ],
        ),
        if (product.canSellByPack) ...[
          const SizedBox(height: 12),
          const Text(
            "O'lchov",
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _priceTypeChip(
                  label: 'Dona',
                  price: CustomerGroupDiscount.catalogUnitPriceForItem(
                    CartItem(product: product, sellByPack: false),
                    _activePriceType ?? CustomerGroupDiscount.selling,
                  ),
                  selected: !_sellByPack,
                  onTap: () => _setSellByPack(false),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _priceTypeChip(
                  label: 'Pachka (${product.quantityPerPack})',
                  price: CustomerGroupDiscount.catalogUnitPriceForItem(
                    CartItem(product: product, sellByPack: true),
                    _activePriceType ?? CustomerGroupDiscount.selling,
                  ),
                  selected: _sellByPack,
                  onTap: () => _setSellByPack(true),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _FocusLastCartQtyIntent extends Intent {
  const _FocusLastCartQtyIntent();
}

class _FocusCatalogSearchIntent extends Intent {
  const _FocusCatalogSearchIntent();
}

class _FocusCustomerSearchIntent extends Intent {
  const _FocusCustomerSearchIntent();
}

class _ToggleShowPurchasePriceIntent extends Intent {
  const _ToggleShowPurchasePriceIntent();
}

class _ToggleShowCartProfitIntent extends Intent {
  const _ToggleShowCartProfitIntent();
}
