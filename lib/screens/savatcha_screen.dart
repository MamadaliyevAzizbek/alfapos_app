import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../core/app_notify.dart';
import '../core/constants.dart';
import '../core/theme.dart';
import '../models/cart_item.dart';
import '../models/product.dart';
import '../providers/cart_provider.dart';
import '../providers/products_provider.dart';
import '../widgets/product_tile.dart';
import 'tranzaksiya_detail_screen.dart';
import 'scanner_screen.dart' show showCompactScanner;
import '../utils/product_search.dart' as product_search;
import '../core/input_formatters.dart';
import '../widgets/ios_style_modals.dart';

/// Savatcha: mahsulotlar API dan (ProductsProvider). Sotuv POST /sales/store orqali, chek ID API javobidan.
/// Savatcha o'zi diska saqlanmaydi (faqat sessiya davomida xotirada).
class SavatchaScreen extends StatefulWidget {
  const SavatchaScreen({super.key});

  @override
  State<SavatchaScreen> createState() => _SavatchaScreenState();
}

class _SavatchaScreenState extends State<SavatchaScreen> {
  final _searchController = TextEditingController();
  final _cart = CartProvider.instance;
  final _products = ProductsProvider.instance;
  String _query = '';

  Future<void> _onRefresh() async {
    await _products.loadFromApi();
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _cart.stream.listen((_) => setState(() {}));
    _products.stream.listen((_) => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) => _products.loadFromApi());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Product> get _filteredProducts =>
      product_search.filterProductsByQuery(_products.items, _query);

  @override
  Widget build(BuildContext context) {
    final items = _cart.items;
    final showSearchResults = _query.trim().isNotEmpty;
    final products = _filteredProducts;

    return Scaffold(
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
          if (items.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
              onPressed: () {
                _cart.clear();
                setState(() {});
              },
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
                    onChanged: (v) => setState(() => _query = v),
                    onSubmitted: (q) async {
                      await _searchAndAdd(q);
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
                  ? _products.isLoaded == false
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
                                return ProductTile(
                                  product: p,
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
            child: Row(
              children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _openScanner(context),
                      icon: const Icon(Icons.qr_code_scanner_rounded, size: 22),
                      label: const Text(Strings.skaner),
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
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => TranzaksiyaDetailScreen(
                              items: List.from(items),
                            ),
                          ),
                        );
                      },
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

  Future<void> _searchAndAdd(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;

    // Muhim: barcode skanerdan keyin darrov qidirilganda mahsulotlar hali yuklanmagan bo‘lishi mumkin.
    if (_products.items.isEmpty || _products.isLoaded == false) {
      try {
        await _products.loadFromApi();
      } catch (_) {}
    }

    final list = product_search.filterProductsByQuery(_products.items, q);
    if (list.isEmpty) {
      assert(() {
        final total = _products.items.length;
        final withBarcode = _products.items.where((p) => (p.barcode ?? '').trim().isNotEmpty).length;
        final withPack = _products.items.where((p) => p.quantityInPack && p.quantityPerPack > 1).length;
        final withPackNoBarcode = _products.items
            .where((p) => p.quantityInPack && p.quantityPerPack > 1 && (p.barcode == null || p.barcode!.trim().isEmpty))
            .length;
        final qNorm = Product.normalizeBarcode(q);
        final samplePack = _products.items
            .where((p) => p.quantityInPack && p.quantityPerPack > 1)
            .take(3)
            .map((p) => 'id=${p.id} bc=${p.barcode} units=${p.quantityPerPack} packPrice=${p.sellPricePerPack}')
            .join(' | ');
        // ignore: avoid_print
        print('[Savatcha search] NOT FOUND q="$q" qNorm="$qNorm" items=$total withBarcode=$withBarcode withPack=$withPack withPackNoBarcode=$withPackNoBarcode samplePack=($samplePack)');
        return true;
      }());
      if (!mounted) return;
      AppNotify.info(context, "Bu shtrix kod bo'yicha mahsulot topilmadi. Ro'yxatni yangilab ko'ring.");
      return;
    }

    if (list.length == 1) {
      _addProductToCart(list.single);
      _searchController.clear();
      if (mounted) setState(() => _query = '');
    } else {
      _searchController.text = q;
      if (mounted) setState(() => _query = q);
    }
  }

  void _addProductToCart(Product product) {
    final hasPack = product.quantityPerPack > 1 &&
        product.sellPricePerPack != null &&
        product.sellPricePerPack! > 0;
    if (hasPack) {
      final packPrice = product.sellPricePerPack ?? 0;
      final pieceLabel = product.sellingPriceCurrency.toLowerCase() == 'usd'
          ? product.priceFormatted
          : '${formatThousands(product.priceUzs)} so\'m';
      final packQty = product.quantityPerPack;
      showCupertinoModalPopup<void>(
        context: context,
        builder: (ctx) => CupertinoActionSheet(
          title: Text(product.name),
          message: const Text('Sotish turini tanlang'),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(ctx);
                _cart.add(CartItem(product: product, quantity: 1, sellByPack: true));
                setState(() {});
              },
              child: Text('Pachka — ${formatThousands(packPrice)} ($packQty dona)'),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(ctx);
                _cart.add(CartItem(product: product, quantity: 1, sellByPack: false));
                setState(() {});
              },
              child: Text('Dona — $pieceLabel'),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx),
            child: const Text(Strings.bekorQilish),
          ),
        ),
      );
    } else {
      _cart.add(CartItem(product: product, quantity: 1, sellByPack: false));
      setState(() {});
    }
  }

  void _showCartLinePriceDialog(BuildContext context, CartItem item) {
    final p = item.product;
    final unitHint = item.sellByPack ? '1 pachka' : '1 dona';
    final controller = TextEditingController(text: formatThousands(item.unitPriceDisplay));
    IosStyleModals.showSheet<void>(
      context: context,
      isScrollControlled: true,
      showGrabber: true,
      child: Builder(
        builder: (ctx) => SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + MediaQuery.viewInsetsOf(ctx).bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text("Narxni o'zgartirish", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
              const SizedBox(height: 8),
              Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                autofocus: true,
                inputFormatters: [ThousandsInputFormatter()],
                decoration: InputDecoration(
                  labelText: '$unitHint narxi',
                  suffixText: Strings.som,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.primary, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        _cart.updateSalePriceOverride(item, null);
                        Navigator.pop(ctx);
                        setState(() {});
                      },
                      child: const Text('Standart narx'),
                    ),
                  ),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text(Strings.bekorQilish),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        final v = parseFormattedSum(controller.text);
                        if (v == null || v < 0) {
                          AppNotify.info(context, "To'g'ri narx kiriting");
                          return;
                        }
                        final def = item.defaultLineUnitPrice;
                        _cart.updateSalePriceOverride(item, v == def ? null : v.toDouble());
                        Navigator.pop(ctx);
                        setState(() {});
                      },
                      child: const Text(Strings.saqlash),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openScanner(BuildContext context) {
    showCompactScanner(context, onResult: (barcode) async {
      if (barcode == null || barcode.isEmpty || !mounted) return;
      // Katalog bilan bir xil: skaner qaytgan qiymatni trim qilib _query ga qo‘yamiz
      final q = barcode.trim();
      _searchController.text = q;
      setState(() => _query = q);
      // Mahsulotlar bo‘sh bo‘lsa avval yuklash (Katalogda allaqachon yuklangan bo‘lishi mumkin)
      if (_products.items.isEmpty || !_products.isLoaded) {
        try {
          await _products.loadFromApi();
        } catch (_) {}
        if (!mounted) return;
      }
      // Katalogdagidek aynan _filteredProducts (bir xil ro‘yxat va qidiruv) dan foydalanamiz
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final list = product_search.filterProductsByQuery(_products.items, _query);
        if (list.isEmpty) {
          AppNotify.info(context, "Bu shtrix kod bo'yicha mahsulot topilmadi. Ro'yxatni yangilab ko'ring.");
          return;
        }
        if (list.length == 1) {
          _addProductToCart(list.single);
          _searchController.clear();
          setState(() => _query = '');
        }
        // 2+ natija bo‘lsa qidiruv natijalari allaqachon _query tufayli ko‘rinadi
      });
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
