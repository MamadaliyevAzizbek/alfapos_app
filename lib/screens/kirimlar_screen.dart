import 'package:flutter/material.dart';
import '../core/app_notify.dart';
import '../core/constants.dart';
import '../core/theme.dart';
import '../models/product.dart';
import '../providers/products_provider.dart';
import '../services/api_service.dart';
import '../widgets/product_tile.dart';
import '../widgets/ios_style_modals.dart';
import 'katalog_screen.dart';
import 'scanner_screen.dart' show showCompactScanner;

/// Menu → Kirimlar: mahsulotlar API dan (POST /receives/products), kirim faqat API ga (POST /receives/store).
class KirimlarScreen extends StatefulWidget {
  const KirimlarScreen({super.key});

  @override
  State<KirimlarScreen> createState() => _KirimlarScreenState();
}

class _KirimlarScreenState extends State<KirimlarScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  List<Product> _products = [];
  bool _loading = true;
  String? _error;
  /// API dan GET /receives/payment-types — birinchi to'lov turi id (kirim store da payments uchun)
  int _paymentTypeId = 1;

  /// API: products[] va variants[] — har bir product ga product_id bo'yicha variant ni birlashtiradi
  static List<Map<String, dynamic>> _mergeProductsWithVariants(Map<String, dynamic> res) {
    final productsRaw = res['products'] ?? res['data'];
    List<dynamic> productsList = [];
    if (productsRaw is List<dynamic>) productsList = productsRaw;
    if (productsList.isEmpty) return [];

    final variantsRaw = res['variants'] ?? [];
    final List<Map<String, dynamic>> variants = variantsRaw is List<dynamic>
        ? variantsRaw.map((e) => e is Map ? Map<String, dynamic>.from(e as Map) : <String, dynamic>{}).where((m) => m.isNotEmpty).toList()
        : [];

    final List<Map<String, dynamic>> result = [];
    for (final p in productsList) {
      if (p is! Map) continue;
      final product = Map<String, dynamic>.from(p as Map);
      final productId = product['productID'] ?? product['id'];
      if (productId == null) continue;
      final productIdInt = productId is int ? productId : int.tryParse(productId.toString());
      Map<String, dynamic>? variant;
      for (final v in variants) {
        final vid = v['product_id'];
        if (vid == null) continue;
        final vInt = vid is int ? vid : int.tryParse(vid.toString());
        if (vInt == productIdInt) {
          variant = v;
          break;
        }
      }
      final merged = Map<String, dynamic>.from(product);
      if (variant != null && variant.isNotEmpty) {
        merged.addAll(variant);
        merged['quantity'] = variant['availableQuantity'];
        merged['variants'] = [variant];
      }
      result.add(merged);
    }
    return result;
  }

  Future<void> _loadPaymentTypes() async {
    try {
      final res = await ReceivesApi.getPaymentTypes();
      final list = res['payment_types'] as List<dynamic>? ??
          res['data'] as List<dynamic>? ??
          res['paymentTypes'] as List<dynamic>? ??
          [];
      if (list.isNotEmpty && list.first is Map) {
        final first = list.first as Map;
        final id = first['id'] ?? first['payment_type_id'];
        if (id != null) {
          final n = id is int ? id : int.tryParse(id.toString());
          if (n != null && mounted) setState(() => _paymentTypeId = n);
        }
      }
    } catch (_) {}
  }

  Future<void> _loadFromApi() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    _loadPaymentTypes();
    try {
      final res = await ReceivesApi.getReceivesProducts(body: {
        'rowLimit': 500,
        'orderType': 'receiving',
      });
      final rows = _mergeProductsWithVariants(res);
      final list = rows
          .map((e) {
            try {
              return Product.fromApiJson(
                e,
                unitIdToName: null,
                unitIdToShortName: null,
              );
            } catch (_) {
              return null;
            }
          })
          .whereType<Product>()
          .where((p) => p.id.isNotEmpty)
          .toList();
      if (mounted) {
        setState(() {
          _products = list;
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _products = [];
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _loadFromApi();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Product> get _filtered =>
      KatalogScreen.filterProductsByQuery(_products, _query);

  void _openScanner() {
    showCompactScanner(context, onResult: (barcode) {
      if (barcode == null || barcode.isEmpty || !mounted) return;
      final q = barcode.trim();
      _searchController.text = q;
      setState(() => _query = q);
    });
  }

  Future<void> _addKirim(Product p) async {
    final controller = TextEditingController();
    final result = await IosStyleModals.showSheet<bool>(
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
              Text(
                p.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "Ombordagi miqdor: ${p.initialQuantity} ${p.unit ?? 'dona'}",
                style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary, height: 1.3),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: Strings.kirimMiqdori,
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
                ),
              ),
              const SizedBox(height: 18),
              IosStyleModals.sheetPillCancelSaveRow(
                cancelLabel: Strings.bekorQilish,
                saveLabel: Strings.saqlash,
                onCancel: () => Navigator.pop(ctx, false),
                onSave: () {
                  final v = int.tryParse(controller.text.trim());
                  if (v != null && v > 0) {
                    Navigator.pop(ctx, true);
                  } else {
                    AppNotify.info(ctx, "Kirim miqdorini kiriting (1 yoki undan katta)");
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
    if (result != true || !mounted) return;
    final add = int.tryParse(controller.text.trim()) ?? 0;
    if (add <= 0) return;
    final costPrice = p.costPriceUzs ?? 0;
    final totalReceive = costPrice * add;
    final productId = int.tryParse(p.id);
    if (productId == null) {
      if (mounted) {
        AppNotify.warning(context, "Mahsulot ID aniqlanmadi");
      }
      return;
    }
    // API doc: orderType receiving, salesOrReceivingType supplier, cart, payments, supplier (null yoki { id })
    final receiveBody = {
      'orderType': 'receiving',
      'salesOrReceivingType': 'supplier',
      'status': 'done',
      'subTotal': totalReceive,
      'tax': 0,
      'discount': 0,
      'grandTotal': totalReceive,
      'dueAmount': 0,
      'profit': 0,
      'cart': [
        {
          'productID': productId,
          'variantID': p.variantId ?? 1,
          'quantity': add,
          'price': costPrice,
          'productTitle': p.name,
          'variantTitle': 'default_variant',
          'orderType': 'receiving',
          'discount': 0,
          'taxID': null,
          'calculatedPrice': totalReceive,
          'cartItemNote': '',
        },
      ],
      'payments': [
        {'paymentID': _paymentTypeId, 'paid': totalReceive},
      ],
      'supplier': null,
    };
    try {
      await ReceivesApi.storeReceive(receiveBody);
      if (!mounted) return;
      await _loadFromApi();
      await ProductsProvider.instance.loadFromApi();
      if (mounted) {
        AppNotify.success(context, "${p.name}: +$add qo'shildi. Kirim API ga yozildi.");
      }
    } catch (e) {
      if (mounted) {
        AppNotify.error(context, "Kirim saqlanmadi: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(Strings.kirimlar),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loading ? null : _loadFromApi,
            tooltip: "Qayta yuklash",
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
                    onChanged: (v) => setState(() => _query = v),
                    decoration: const InputDecoration(
                      hintText: "Mahsulot qidirish",
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Material(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: _openScanner,
                    borderRadius: BorderRadius.circular(12),
                    child: const Padding(
                      padding: EdgeInsets.all(14),
                      child: Icon(
                        Icons.qr_code_scanner_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _error!,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.red.shade700,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: _loadFromApi,
                                icon: const Icon(Icons.refresh_rounded, size: 20),
                                label: const Text("Qayta yuklash"),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _filtered.isEmpty
                        ? Center(
                            child: Text(
                              "Mahsulot topilmadi",
                              style: TextStyle(
                                fontSize: 16,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _filtered.length,
                            itemBuilder: (context, index) {
                              final p = _filtered[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 10),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  leading: Container(
                                    width: 56,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      color: AppTheme.cardBg,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: ProductTile.buildProductImage(
                                      p,
                                      boxSize: 56,
                                    ),
                                  ),
                                  title: Text(
                                    p.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: Text(
                                    "Omborda: ${p.initialQuantity} ${p.unit ?? 'dona'}",
                                  ),
                                  trailing: const Icon(
                                    Icons.add_circle_outline_rounded,
                                    color: AppTheme.primary,
                                  ),
                                  onTap: () => _addKirim(p),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
