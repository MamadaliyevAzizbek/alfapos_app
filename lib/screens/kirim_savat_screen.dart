import 'package:flutter/material.dart';
import '../core/app_notify.dart';
import '../core/constants.dart';
import '../core/input_formatters.dart';
import '../core/theme.dart';
import '../models/receive_cart_item.dart';
import '../providers/receive_session_provider.dart';
import '../services/receive_draft_storage.dart';
import '../widgets/ios_style_modals.dart';
import 'kirim_yakunlash_screen.dart';

class KirimSavatScreen extends StatefulWidget {
  const KirimSavatScreen({super.key});

  @override
  State<KirimSavatScreen> createState() => _KirimSavatScreenState();
}

class _EditCartValues {
  final num quantity;
  final int purchasePriceUzs;
  final int sellPriceUzs;

  const _EditCartValues({
    required this.quantity,
    required this.purchasePriceUzs,
    required this.sellPriceUzs,
  });
}

class _KirimSavatScreenState extends State<KirimSavatScreen> {
  final _session = ReceiveSessionProvider.instance;

  @override
  void initState() {
    super.initState();
    _session.addListener(_onSession);
  }

  @override
  void dispose() {
    _session.removeListener(_onSession);
    super.dispose();
  }

  void _onSession() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final cart = _session.cart;
    final total = _session.cartTotalUzs;
    return Scaffold(
      appBar: AppBar(
        title: Text('Savat (${cart.length})'),
      ),
      body: cart.isEmpty
          ? const Center(child: Text('Savat bo\'sh', style: TextStyle(color: AppTheme.textSecondary)))
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              itemCount: cart.length,
              itemBuilder: (context, i) {
                final item = cart[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    title: Text(item.product.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      'Miqdor: ${item.quantity} · Kelish: ${formatThousands(item.purchasePriceUzs)} · '
                      'Sotish: ${formatThousands(item.sellPriceUzs)} · Jami: ${formatThousands(item.lineTotalUzs)}',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => _session.removeFromCart(item),
                    ),
                    onTap: () => _editItem(item),
                  ),
                );
              },
            ),
      bottomNavigationBar: cart.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Jami:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                        Text(
                          '${formatThousands(total)} so\'m',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: AppTheme.primary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _saveDraft,
                        icon: const Icon(Icons.bookmark_outline_rounded),
                        label: const Text('Qoralamani saqlash'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () async {
                          await Navigator.push<void>(
                            context,
                            MaterialPageRoute(builder: (_) => const KirimYakunlashScreen()),
                          );
                          if (mounted) setState(() {});
                        },
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('Kirimni yakunlash'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Future<void> _saveDraft() async {
    if (_session.cart.isEmpty) {
      AppNotify.info(context, 'Savat bo\'sh');
      return;
    }
    try {
      await ReceiveDraftStorage.saveFromSession(_session);
      if (mounted) AppNotify.success(context, 'Qoralama saqlandi');
    } catch (e) {
      if (mounted) AppNotify.error(context, '$e');
    }
  }

  Future<void> _editItem(ReceiveCartItem item) async {
    final productId = item.product.id;
    _session.pauseNotify();
    _EditCartValues? values;
    try {
      values = await IosStyleModals.showSheet<_EditCartValues?>(
        context: context,
        isScrollControlled: true,
        showGrabber: true,
        child: _ReceiveCartItemEditSheet(item: item),
      );
    } catch (e) {
      _session.resumeNotify();
      rethrow;
    }

    if (!mounted || values == null) {
      _session.resumeNotify();
      if (mounted) setState(() {});
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        _session.resumeNotify();
        return;
      }
      _session.updateCartItemByProductId(
        productId,
        quantity: values!.quantity,
        purchasePriceUzs: values.purchasePriceUzs,
        sellPriceUzs: values.sellPriceUzs,
      );
      _session.resumeNotify();
      setState(() {});
    });
  }
}

class _ReceiveCartItemEditSheet extends StatefulWidget {
  const _ReceiveCartItemEditSheet({required this.item});

  final ReceiveCartItem item;

  @override
  State<_ReceiveCartItemEditSheet> createState() => _ReceiveCartItemEditSheetState();
}

class _ReceiveCartItemEditSheetState extends State<_ReceiveCartItemEditSheet> {
  late final TextEditingController _qtyCtrl;
  late final TextEditingController _purchaseCtrl;
  late final TextEditingController _sellCtrl;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _qtyCtrl = TextEditingController(text: item.quantity.toString());
    _purchaseCtrl = TextEditingController(text: formatThousands(item.purchasePriceUzs));
    _sellCtrl = TextEditingController(text: formatThousands(item.sellPriceUzs));
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _purchaseCtrl.dispose();
    _sellCtrl.dispose();
    super.dispose();
  }

  InputDecoration _fieldDecoration(String label) {
    return InputDecoration(
      labelText: label,
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
    final qty = num.tryParse(_qtyCtrl.text.replaceAll(',', '.').trim());
    if (qty == null || qty <= 0) {
      AppNotify.info(context, 'Miqdorni kiriting');
      return;
    }
    final purchase = parseFormattedSum(_purchaseCtrl.text);
    final sell = parseFormattedSum(_sellCtrl.text);
    if (purchase == null || purchase < 0) {
      AppNotify.info(context, 'Kelish narxini kiriting');
      return;
    }
    if (sell == null || sell < 0) {
      AppNotify.info(context, 'Sotish narxini kiriting');
      return;
    }
    Navigator.pop(
      context,
      _EditCartValues(
        quantity: qty,
        purchasePriceUzs: purchase,
        sellPriceUzs: sell,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return IosStyleModals.sheetKeyboardForm(
      context: context,
      onCancel: () => Navigator.pop(context, null),
      onSave: _save,
      cancelLabel: Strings.bekorQilish,
      saveLabel: Strings.saqlash,
      body: [
        Text(
          widget.item.product.name,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: AppTheme.textPrimary),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _qtyCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: _fieldDecoration('Miqdor'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _purchaseCtrl,
          keyboardType: TextInputType.number,
          inputFormatters: [ThousandsInputFormatter()],
          decoration: _fieldDecoration('Kelish narxi (so\'m)'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _sellCtrl,
          keyboardType: TextInputType.number,
          inputFormatters: [ThousandsInputFormatter()],
          decoration: _fieldDecoration('Sotish narxi (so\'m)'),
        ),
      ],
    );
  }
}
