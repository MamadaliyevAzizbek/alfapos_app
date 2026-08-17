import 'package:flutter/material.dart';
import '../core/app_notify.dart';
import '../core/theme.dart';
import '../models/product.dart';
import '../models/receive_supplier.dart';
import '../providers/receive_session_provider.dart';
import '../services/receive_draft_storage.dart';
import '../widgets/throttled_refresh_indicator.dart';

class KirimQoralamalarScreen extends StatefulWidget {
  const KirimQoralamalarScreen({super.key});

  @override
  State<KirimQoralamalarScreen> createState() => _KirimQoralamalarScreenState();
}

class _KirimQoralamalarScreenState extends State<KirimQoralamalarScreen> {
  final _session = ReceiveSessionProvider.instance;
  List<ReceiveDraft> _drafts = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _drafts = await ReceiveDraftStorage.loadDrafts(_session.branchId);
    } catch (e) {
      _drafts = [];
      _error = '$e';
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saqlanganlar'),
      ),
      body: ThrottledRefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 160),
                  Center(child: CircularProgressIndicator()),
                ],
              )
            : _error != null
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(24),
                    children: [
                      const SizedBox(height: 80),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: FilledButton(
                          onPressed: _load,
                          child: const Text('Qayta urinish'),
                        ),
                      ),
                    ],
                  )
                : _drafts.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(24),
                        children: const [
                          SizedBox(height: 80),
                          Text(
                            'Saqlangan qoralamalar yo\'q.\nSavat ichida «Qoralamalarga saqlash» tugmasidan foydalaning.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              height: 1.4,
                            ),
                          ),
                        ],
                      )
                    : ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        itemCount: _drafts.length,
                        itemBuilder: (context, i) {
                          final d = _drafts[i];
                          final title = d.cartItems.isEmpty
                              ? 'Qoralama #${d.id}'
                              : '${d.cartItems.length} mahsulot';
                          final subtitleParts = <String>[
                            if (d.selectedDate.isNotEmpty) d.selectedDate,
                            if (d.savedAt.isNotEmpty) _shortSavedAt(d.savedAt),
                          ];
                          return Card(
                            child: ListTile(
                              title: Text(title),
                              subtitle: Text(subtitleParts.join(' · ')),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    color: Colors.red),
                                onPressed: () => _deleteDraft(d),
                              ),
                              onTap: () => _restoreDraft(d),
                            ),
                          );
                        },
                      ),
      ),
    );
  }

  String _shortSavedAt(String raw) {
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    final local = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
  }

  Future<void> _deleteDraft(ReceiveDraft d) async {
    try {
      await ReceiveDraftStorage.deleteDraft(_session.branchId ?? 1, d.id);
      if (_session.activeDraftId == d.id) {
        _session.activeDraftId = null;
      }
      await _load();
      if (mounted) AppNotify.success(context, 'O\'chirildi');
    } catch (e) {
      if (mounted) AppNotify.error(context, '$e');
    }
  }

  Future<void> _restoreDraft(ReceiveDraft d) async {
    _session.clearCart();
    for (final row in d.cartItems) {
      final id = _productId(row);
      if (id.isEmpty) continue;
      final purchase = _asInt(row['price'] ?? row['purchasePriceUzs']) ?? 0;
      final sell =
          _asInt(row['sellingPrice'] ?? row['sellPriceUzs']) ?? purchase;
      final wholesale =
          _asInt(row['wholesalePrice'] ?? row['wholesalePriceUzs']) ?? 0;
      final currency =
          (row['priceCurrency'] ?? row['purchaseCurrency'] ?? 'uzs')
              .toString()
              .toLowerCase();
      final p = Product(
        id: id,
        name: (row['productTitle'] ?? row['name'] ?? 'Mahsulot').toString(),
        variantId: _asInt(row['variantID'] ?? row['variantId']),
        priceUzs: sell,
        costPriceUzs: purchase,
        wholesalePriceUzs: wholesale,
        purchasePriceCurrency: currency,
        wholesalePriceCurrency: currency,
        sellingPriceCurrency: currency,
      );
      final qty = (row['quantity'] as num?) ?? 1;
      _session.addToCart(p, quantity: qty);
      final last = _session.cart.last;
      last.purchasePriceUzs = purchase;
      last.wholesalePriceUzs = wholesale;
      last.sellPriceUzs = sell;
      last.purchaseCurrency = currency;
      last.wholesaleCurrency = currency;
      last.sellCurrency = currency;
    }
    if (d.selectedSupplierId != null) {
      ReceiveSupplier? sup;
      for (final s in _session.suppliers) {
        if (s.id == d.selectedSupplierId) {
          sup = s;
          break;
        }
      }
      _session.setSupplier(sup);
    }
    if (d.selectedPaymentTypeId != null) {
      Map<String, dynamic>? pay;
      for (final p in _session.paymentTypes) {
        if (_asInt(p['id']) == d.selectedPaymentTypeId) {
          pay = p;
          break;
        }
      }
      if (pay != null) _session.setPaymentType(pay);
    }
    final parsedDate = DateTime.tryParse(d.selectedDate);
    if (parsedDate != null) {
      _session.setDate(parsedDate);
    }
    _session.setComment(d.comment);
    _session.setDeliveryCost(d.receivingDeliveryCost);
    _session.activeDraftId = d.id;
    if (mounted) {
      AppNotify.success(context, 'Qoralama yuklandi');
      Navigator.pop(context);
    }
  }

  static String _productId(Map<String, dynamic> row) {
    final v = row['productID'] ?? row['productId'];
    if (v == null) return '';
    return v.toString();
  }

  static int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.round();
    return int.tryParse(v.toString().split('.').first);
  }
}
