import 'package:flutter/material.dart';
import '../core/app_notify.dart';
import '../core/theme.dart';
import '../models/product.dart';
import '../models/receive_supplier.dart';
import '../providers/receive_session_provider.dart';
import '../services/receive_draft_storage.dart';

class KirimQoralamalarScreen extends StatefulWidget {
  const KirimQoralamalarScreen({super.key});

  @override
  State<KirimQoralamalarScreen> createState() => _KirimQoralamalarScreenState();
}

class _KirimQoralamalarScreenState extends State<KirimQoralamalarScreen> {
  final _session = ReceiveSessionProvider.instance;
  List<ReceiveDraft> _drafts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final branch = _session.branchId ?? 1;
    _drafts = await ReceiveDraftStorage.loadDrafts(branch);
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saqlanganlar'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
            tooltip: 'Yangilash',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _drafts.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Saqlangan qoralamalar yo\'q.\nSavat ichida «Qoralamani saqlash» tugmasidan foydalaning.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.textSecondary, height: 1.4),
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _drafts.length,
                  itemBuilder: (context, i) {
                    final d = _drafts[i];
                    return Card(
                      child: ListTile(
                        title: Text('${d.cartItems.length} mahsulot'),
                        subtitle: Text('${d.selectedDate} · ${d.savedAt}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () async {
                            await ReceiveDraftStorage.deleteDraft(_session.branchId ?? 1, d.id);
                            _load();
                          },
                        ),
                        onTap: () => _restoreDraft(d),
                      ),
                    );
                  },
                ),
    );
  }

  Future<void> _restoreDraft(ReceiveDraft d) async {
    _session.clearCart();
    for (final row in d.cartItems) {
      final id = row['productId']?.toString() ?? '';
      if (id.isEmpty) continue;
      final p = Product(
        id: id,
        name: row['name']?.toString() ?? 'Mahsulot',
        variantId: row['variantId'] as int?,
        priceUzs: row['sellPriceUzs'] as int? ?? 0,
        costPriceUzs: row['purchasePriceUzs'] as int?,
      );
      _session.addToCart(p, quantity: (row['quantity'] as num?) ?? 1);
      final last = _session.cart.last;
      last.purchasePriceUzs = row['purchasePriceUzs'] as int? ?? last.purchasePriceUzs;
      last.sellPriceUzs = row['sellPriceUzs'] as int? ?? last.sellPriceUzs;
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
    _session.setComment(d.comment);
    _session.setDeliveryCost(d.receivingDeliveryCost);
    if (mounted) {
      AppNotify.success(context, 'Qoralama yuklandi');
      Navigator.pop(context);
    }
  }
}
