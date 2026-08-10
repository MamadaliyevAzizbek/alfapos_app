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
import '../services/api_service.dart';
import '../utils/product_search.dart' as product_search;
import '../utils/receive_products.dart';
import '../widgets/product_tile.dart';
import 'kirim_qoralamalar_screen.dart';
import 'kirim_savat_screen.dart';
import 'kirim_tarix_screen.dart';
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

class _KirimlarScreenState extends State<KirimlarScreen> with DesktopShellSyncMixin {
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

  Future<void> _init() async {
    await ProductsProvider.instance.loadFromStorage();
    await _session.loadInit();
    if (mounted) await _searchProducts('');
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

  Future<void> _searchProducts(String q) async {
    if (!mounted) return;
    setState(() {
      _loadingProducts = true;
      _productsError = null;
    });
    try {
      List<Product> list;
      if (q.trim().isEmpty) {
        final res = await ReceivesApi.getReceivesProducts(body: {
          'orderType': 'receiving',
          'rowLimit': 200,
          'offset': 0,
          if (_session.branchId != null) 'currentBranch': _session.branchId,
        });
        list = ReceiveProducts.productsFromApiResponse(res);
      } else {
        list = await _session.searchProducts(q);
      }
      list = ProductsProvider.instance.withCatalogStockAll(list);
      if (mounted) {
        setState(() {
          _products = list;
          _loadingProducts = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _products = [];
          _loadingProducts = false;
          _productsError = e.toString();
        });
      }
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
          AppNotify.success(context, '${hit.product.name}$qtyLabel savatga qo\'shildi');
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
      _session.addToCart(ProductsProvider.instance.withCatalogStock(list.single));
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

  void _addProduct(Product p) {
    final aligned = ProductsProvider.instance.withCatalogStock(p);
    _session.addToCart(aligned);
    AppNotify.success(context, '${aligned.name} savatga qo\'shildi');
  }

  Product _displayProduct(Product p) => ProductsProvider.instance.withCatalogStock(p);

  List<Product> get _filtered {
    final q = _query.trim();
    if (q.isEmpty) return _products;
    return product_search.filterProductsByQuery(_products, q);
  }

  @override
  Widget build(BuildContext context) {
    final supplier = _session.selectedSupplier;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(Strings.kirimlar),
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
        ],
      ),
      body: _session.initLoading
          ? const Center(child: CircularProgressIndicator())
          : _session.initError != null
              ? ThrottledRefreshIndicator(
                  onRefresh: _init,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(24),
                    children: [
                      const SizedBox(height: 80),
                      Text(_session.initError!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      const Text(
                        'Pastga tortib yangilang',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: InkWell(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const KirimSavatScreen()),
                        ).then((_) {
                          if (mounted) _searchProducts(_query);
                        }),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFD6E8FF)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.local_shipping_outlined, color: AppTheme.primary),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  supplier?.name ?? 'Yetkazib beruvchi (yakunlashda tanlanadi)',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: supplier != null ? AppTheme.textPrimary : AppTheme.textSecondary,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryLight,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'Savat: ${_session.cartCount}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.primary,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              onChanged: _onSearchChanged,
                              onSubmitted: _searchProducts,
                              decoration: const InputDecoration(
                                hintText: 'Mahsulot yoki shtrix kod',
                                prefixIcon: Icon(Icons.search_rounded, color: AppTheme.textSecondary),
                              ),
                            ),
                          ),
                          if (!isDesktopPosLayout) ...[
                            const SizedBox(width: 10),
                            Material(
                              color: AppTheme.primary,
                              borderRadius: BorderRadius.circular(12),
                              child: InkWell(
                                onTap: _openScanner,
                                borderRadius: BorderRadius.circular(12),
                                child: const Padding(
                                  padding: EdgeInsets.all(14),
                                  child: Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 26),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Expanded(
                      child: ThrottledRefreshIndicator(
                        onRefresh: _init,
                        child: _buildProductList(),
                      ),
                    ),
                  ],
                ),
      bottomNavigationBar: _session.cartCount > 0 ? _buildCartBottomBar() : null,
    );
  }

  Widget _buildCartBottomBar() {
    final count = _session.cartCount;
    final total = _session.cartTotalUzs;
    return Material(
      elevation: 8,
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Savat: $count ta mahsulot',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  Text(
                    '${formatThousands(total)} so\'m',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: AppTheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const KirimSavatScreen()),
                  ).then((_) {
                    if (mounted) _searchProducts(_query);
                  }),
                  icon: const Icon(Icons.shopping_cart_rounded),
                  label: Text('Savat ($count)'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductList() {
    if (_loadingProducts) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 120),
          Center(child: CircularProgressIndicator()),
        ],
      );
    }
    if (_productsError != null) {
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
    final list = _filtered;
    if (list.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 120),
          Center(
            child: Text('Mahsulot topilmadi', style: TextStyle(color: AppTheme.textSecondary)),
          ),
        ],
      );
    }
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(16, 0, 16, _session.cartCount > 0 ? 8 : 16),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final p = _displayProduct(list[index]);
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: SizedBox(
              width: 56,
              height: 56,
              child: ProductTile.buildProductImage(p, boxSize: 56),
            ),
            title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(
              'Omborda: ${p.stockDisplayText} · Kelish: ${p.costPriceUzs ?? 0}',
            ),
            trailing: const Icon(Icons.add_circle_outline_rounded, color: AppTheme.primary),
            onTap: () => _addProduct(p),
          ),
        );
      },
    );
  }
}
