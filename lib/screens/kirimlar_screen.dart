import 'dart:async';

import 'package:flutter/material.dart';
import '../core/app_notify.dart';
import '../core/api_client.dart';
import '../core/constants.dart';
import '../core/input_formatters.dart';
import '../core/theme.dart';
import '../models/product.dart';
import '../providers/products_provider.dart';
import '../providers/receive_session_provider.dart';
import '../utils/product_search.dart' as product_search;
import '../widgets/ios_style_modals.dart';
import '../widgets/product_tile.dart';
import 'kirim_qoralamalar_screen.dart';
import 'kirim_savat_screen.dart'
    show ReceiveCartEditValues, ReceiveCartItemEditSheet;
import 'kirim_tarix_screen.dart';
import 'kirim_yakunlash_screen.dart';
import 'yangi_tovar_screen.dart';
import '../models/receive_cart_item.dart';
import '../services/receive_draft_storage.dart';
import 'scanner_screen.dart' show showCompactScanner;
import '../utils/platform_layout.dart';
import 'desktop/desktop_shell_scope.dart';
import '../widgets/throttled_refresh_indicator.dart';

/// Kirim — web /receives bilan bir xil: taminotchi, savat, barcode, store.
class KirimlarScreen extends StatefulWidget {
  const KirimlarScreen({super.key});

  @override
  State<KirimlarScreen> createState() => _KirimlarScreenState();
}

class _KirimlarScreenState extends State<KirimlarScreen>
    with DesktopShellSyncMixin {
  final _searchController = TextEditingController();
  final _session = ReceiveSessionProvider.instance;
  String _query = '';
  List<Product> _products = [];
  bool _loadingProducts = false;
  String? _productsError;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _session.addListener(_onSession);
    ProductsProvider.instance.addListener(_onCatalogUpdated);
    _init();
  }

  Future<void> _init({bool force = false}) async {
    // Sotuv/Mahsulotlar kabi: UI darhol, kesh + fon sync.
    unawaited(
        ProductsProvider.instance.loadFromStorage(refreshInBackground: true));
    if (force) {
      await _session.loadInit(force: true);
    } else {
      unawaited(_session.loadInit());
    }
    if (mounted) setState(() {});
  }

  void _onCatalogUpdated() {
    if (mounted) setState(() {});
  }

  @override
  Future<void> onDesktopShellSync() => _init();

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _session.removeListener(_onSession);
    ProductsProvider.instance.removeListener(_onCatalogUpdated);
    super.dispose();
  }

  void _onSession() {
    if (mounted) setState(() {});
  }

  List<Product> get _localCatalog => ProductsProvider.instance
      .withCatalogStockAll(ProductsProvider.instance.items);

  List<Product> _mergeSearchResults(String query, List<Product> local) {
    final q = query.trim();
    if (q.isEmpty || _products.isEmpty) return local;
    final seen = local.map((p) => p.id).toSet();
    final merged = [...local];
    for (final p in _products) {
      if (!product_search.productMatchesSearchQuery(p, q)) continue;
      if (seen.add(p.id)) merged.add(p);
    }
    return product_search.sortProductsBySearchRelevance(merged, q);
  }

  Future<void> _searchProducts(String q) async {
    final query = q.trim();
    if (!mounted) return;
    if (query.isEmpty) {
      setState(() {
        _products = [];
        _loadingProducts = false;
        _productsError = null;
      });
      return;
    }
    final hasLocal =
        product_search.filterProductsByQuery(_localCatalog, query).isNotEmpty;
    if (!hasLocal) {
      setState(() {
        _loadingProducts = true;
        _productsError = null;
      });
    }
    try {
      final list = ProductsProvider.instance.withCatalogStockAll(
        await _session.searchProducts(query),
      );
      if (!mounted || _query.trim() != query) return;
      setState(() {
        _products = list;
        _loadingProducts = false;
      });
    } catch (e) {
      if (!mounted || _query.trim() != query) return;
      setState(() {
        _loadingProducts = false;
        if (!hasLocal) {
          _products = [];
          _productsError = e.toString();
        }
      });
    }
  }

  void _onSearchChanged(String v) {
    setState(() => _query = v);
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (_searchController.text.trim() == v.trim()) {
        _searchProducts(v.trim());
      }
    });
  }

  Future<void> _onBarcode(String barcode) async {
    final q = barcode.trim();
    if (q.isEmpty) return;
    _searchController.text = q;
    setState(() => _query = q);
    try {
      final hit = await _session.findByBarcodeDetailed(q);
      if (hit != null) {
        _session.addToCart(
          ProductsProvider.instance.withCatalogStock(hit.product),
          quantity: hit.quantity,
        );
        _searchController.clear();
        setState(() => _query = '');
        if (mounted) {
          final qtyLabel = hit.isScaleItem ? ' (${hit.quantity} kg)' : '';
          AppNotify.success(
              context, '${hit.product.name}$qtyLabel savatga qo\'shildi');
        }
        return;
      }
    } on ApiException catch (e) {
      if (mounted) AppNotify.error(context, e.message);
      return;
    }
    await _searchProducts(q);
    if (!mounted) return;
    final list = product_search.filterProductsByBarcodeQuery(_products, q);
    if (list.length == 1) {
      _session
          .addToCart(ProductsProvider.instance.withCatalogStock(list.single));
      _searchController.clear();
      setState(() => _query = '');
      AppNotify.success(context, '${list.single.name} savatga qo\'shildi');
    }
  }

  void _openScanner() {
    showCompactScanner(context, onResult: (barcode) async {
      if (barcode == null || barcode.isEmpty || !mounted) return;
      await _onBarcode(barcode);
    });
  }

  Future<void> _openNewProduct() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const YangiTovarScreen()),
    );
    if (!mounted) return;

    // Yangi mahsulot ProductsProvider ga saqlangan bo‘ladi. Kirim oynasida
    // qolamiz va keyingi qidiruv yangi katalog bilan bajariladi.
    _searchDebounce?.cancel();
    _searchController.clear();
    setState(() {
      _query = '';
      _products = [];
      _productsError = null;
    });
    if (saved == true) {
      await ProductsProvider.instance.warmFromCache();
      if (mounted) setState(() {});
    }
  }

  void _addProduct(Product p, {num quantity = 1}) {
    final aligned = ProductsProvider.instance.withCatalogStock(p);
    _session.addToCart(aligned, quantity: quantity);
    _searchController.clear();
    setState(() => _query = '');
  }

  Future<void> _saveDraft() async {
    if (_session.cart.isEmpty) {
      AppNotify.info(context, 'Savat bo\'sh');
      return;
    }
    final isUpdate = _session.activeDraftId != null;
    try {
      await ReceiveDraftStorage.saveFromSession(_session);
      _session.resetAfterDraftSaved();
      if (!mounted) return;
      setState(() => _query = '');
      _searchController.clear();
      AppNotify.success(
        context,
        isUpdate ? 'Qoralama yangilandi' : 'Qoralamalarga saqlandi',
      );
    } catch (e) {
      if (mounted) AppNotify.error(context, '$e');
    }
  }

  Future<void> _editCartItem(ReceiveCartItem item) async {
    final productId = item.product.id;
    _session.pauseNotify();
    ReceiveCartEditValues? values;
    try {
      values = await IosStyleModals.showSheet<ReceiveCartEditValues?>(
        context: context,
        isScrollControlled: true,
        showGrabber: true,
        child: ReceiveCartItemEditSheet(item: item),
      );
    } catch (_) {
      _session.resumeNotify();
      rethrow;
    }
    if (!mounted || values == null) {
      _session.resumeNotify();
      if (mounted) setState(() {});
      return;
    }
    _session.updateCartItemByProductId(
      productId,
      quantity: values.quantity,
      purchasePriceUzs: values.purchasePriceUzs,
      wholesalePriceUzs: values.wholesalePriceUzs,
      sellPriceUzs: values.sellPriceUzs,
      purchaseCurrency: values.purchaseCurrency,
      wholesaleCurrency: values.wholesaleCurrency,
      sellCurrency: values.sellCurrency,
      purchasePriceApi: values.purchasePriceApi,
      wholesalePriceApi: values.wholesalePriceApi,
      sellPriceApi: values.sellPriceApi,
      clearPurchasePriceApi: values.purchaseCurrency != 'usd',
      clearWholesalePriceApi: values.wholesaleCurrency != 'usd',
      clearSellPriceApi: values.sellCurrency != 'usd',
    );
    _session.resumeNotify();
    setState(() {});
  }

  void _clearCart() {
    if (_session.cart.isEmpty) return;
    _session.clearCart();
  }

  Product _displayProduct(Product p) =>
      ProductsProvider.instance.withCatalogStock(p);

  List<Product> get _filtered {
    final q = _query.trim();
    if (q.isEmpty) return const [];
    final local = product_search.filterProductsByQuery(_localCatalog, q);
    return _mergeSearchResults(q, local);
  }

  @override
  Widget build(BuildContext context) {
    final items = _session.cart;
    final showSearchResults = _query.trim().isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            const Text(Strings.kirimlar),
            if (items.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.cardBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${items.length}',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'Tarix',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const KirimTarixScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.bookmark_outline_rounded),
            tooltip: 'Saqlanganlar',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const KirimQoralamalarScreen()),
            ),
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
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    onSubmitted: (q) async {
                      final trimmed = q.trim();
                      if (trimmed.isEmpty) return;
                      await _searchProducts(trimmed);
                    },
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      hintText: Strings.artikulShtrixIsm,
                      prefixIcon: Icon(Icons.search_rounded,
                          color: AppTheme.textSecondary),
                    ),
                  ),
                ),
                if (!isDesktopPosLayout) ...[
                  const SizedBox(width: 8),
                  Material(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      onTap: _openScanner,
                      borderRadius: BorderRadius.circular(10),
                      child: const Padding(
                        padding: EdgeInsets.all(11),
                        child: Icon(Icons.qr_code_scanner_rounded,
                            color: Colors.white, size: 22),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      onTap: _openNewProduct,
                      borderRadius: BorderRadius.circular(10),
                      child: const Padding(
                        padding: EdgeInsets.all(11),
                        child: Icon(Icons.add_rounded,
                            color: Colors.white, size: 22),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: ThrottledRefreshIndicator(
              onRefresh: () => _init(force: true),
              child: showSearchResults
                  ? _buildSearchResults()
                  : items.isEmpty
                      ? _buildEmptyCart()
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final item = items[index];
                            return _ReceiveLineTile(
                              item: item,
                              onTap: () => _editCartItem(item),
                              onIncrement: () => _session.updateCartItem(
                                item,
                                quantity: item.quantity + 1,
                              ),
                              onDecrement: () {
                                if (item.quantity > 1) {
                                  _session.updateCartItem(item,
                                      quantity: item.quantity - 1);
                                } else {
                                  _session.removeFromCart(item);
                                }
                              },
                              onQuantityChanged: (q) =>
                                  _session.updateCartItem(item, quantity: q),
                            );
                          },
                        ),
            ),
          ),
          if (items.isNotEmpty && !showSearchResults)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _saveDraft,
                      icon:
                          const Icon(Icons.bookmark_outline_rounded, size: 20),
                      label: const Text('Qoralamalarga saqlash'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton(
                      onPressed: () async {
                        await Navigator.push<void>(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const KirimYakunlashScreen()),
                        );
                        if (mounted) setState(() {});
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
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
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyCart() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(32),
      children: [
        SizedBox(height: MediaQuery.sizeOf(context).height * 0.12),
        Icon(
          Icons.qr_code_2_rounded,
          size: 80,
          color: AppTheme.textSecondary.withValues(alpha: 0.4),
        ),
        const SizedBox(height: 20),
        const Text(
          'Kirim savati bo\'sh',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary),
        ),
        const SizedBox(height: 8),
        const Text(
          'Mahsulot qidiring yoki shtrix-kodni skanerlang',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
        ),
        if (!isDesktopPosLayout) ...[
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _openScanner,
            icon: const Icon(Icons.qr_code_scanner_rounded),
            label: const Text(Strings.skaner),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSearchResults() {
    final list = _filtered;
    if (list.isEmpty && _loadingProducts) {
      return const Center(
          child: CircularProgressIndicator(color: AppTheme.primary));
    }
    if (list.isEmpty && _productsError != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 80),
          Text(_productsError!, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          const Text(
            'Pastga tortib yangilang',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSecondary),
          ),
        ],
      );
    }
    if (list.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 120),
          Center(
            child: Text('Mahsulot topilmadi',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
        ],
      );
    }
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final p = _displayProduct(list[index]);
        return ProductTile(
          product: p,
          primaryPriceLabel:
              'Kelish: ${formatThousands(p.costPriceUzs ?? 0)} so\'m',
          secondaryPriceLabel: 'Sotish: ${p.priceFormatted}',
          showBarcode: true,
          showMenu: false,
          onTap: () => _addProduct(p),
        );
      },
    );
  }
}

class _ReceiveLineTile extends StatefulWidget {
  final ReceiveCartItem item;
  final VoidCallback onTap;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final ValueChanged<num> onQuantityChanged;

  const _ReceiveLineTile({
    required this.item,
    required this.onTap,
    required this.onIncrement,
    required this.onDecrement,
    required this.onQuantityChanged,
  });

  @override
  State<_ReceiveLineTile> createState() => _ReceiveLineTileState();
}

class _ReceiveLineTileState extends State<_ReceiveLineTile> {
  bool _editing = false;
  late TextEditingController _controller;
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _qty(widget.item.quantity));
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(covariant _ReceiveLineTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_editing && !_focusNode.hasFocus) {
      final t = _qty(widget.item.quantity);
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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _focusNode.hasFocus || !_editing) return;
        _applyAndClose();
      });
    }
  }

  void _startEditing() {
    _controller.text = _qty(widget.item.quantity);
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
    if (q != null && q > 0) {
      widget.onQuantityChanged(q);
    } else {
      _controller.text = _qty(widget.item.quantity);
    }
    if (mounted) setState(() => _editing = false);
  }

  static String _qty(num q) {
    if (q == q.roundToDouble()) return q.toInt().toString();
    return q.toString();
  }

  static String _formatUsd(num n) {
    final d = n.toDouble();
    if (d == d.roundToDouble()) return '${d.round()}';
    var s = d.toStringAsFixed(4);
    s = s.replaceFirst(RegExp(r'0+$'), '');
    s = s.replaceFirst(RegExp(r'\.$'), '');
    return s;
  }

  static String _kelishLine(ReceiveCartItem item) {
    if (item.purchaseCurrency == 'usd') {
      final v = item.purchasePriceApi ?? item.purchasePriceUzs;
      return 'Kelish ${_qty(item.quantity)} × ${_formatUsd(v)} USD';
    }
    return 'Kelish ${_qty(item.quantity)} × ${formatThousands(item.purchasePriceUzs)}';
  }

  static String _pricesLine(ReceiveCartItem item) {
    final wholesale = item.wholesaleCurrency == 'usd'
        ? '${_formatUsd(item.wholesalePriceApi ?? item.wholesalePriceUzs)} USD'
        : formatThousands(item.wholesalePriceUzs);
    final sell = item.sellCurrency == 'usd'
        ? '${_formatUsd(item.sellPriceApi ?? item.sellPriceUzs)} USD'
        : formatThousands(item.sellPriceUzs);
    return 'Ulgurji $wholesale · Sotish $sell';
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final p = item.product;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: widget.onTap,
                borderRadius: BorderRadius.circular(10),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppTheme.cardBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: ProductTile.buildProductImage(p, boxSize: 56),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${formatThousands(item.lineTotalInUzs(usdRate: ReceiveSessionProvider.instance.usdExchangeRate))} so\'m',
                            style: const TextStyle(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            _kelishLine(item),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          Text(
                            _pricesLine(item),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
            const SizedBox(width: 6),
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
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                        border: InputBorder.none,
                      ),
                      onTap: () {
                        if (!_editing) {
                          _startEditing();
                        } else {
                          _controller.selection = TextSelection(
                            baseOffset: 0,
                            extentOffset: _controller.text.length,
                          );
                        }
                      },
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
