import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

class ReceiveCartEditValues {
  final num quantity;
  final int purchasePriceUzs;
  final int wholesalePriceUzs;
  final int sellPriceUzs;
  final String purchaseCurrency;
  final String wholesaleCurrency;
  final String sellCurrency;
  final num? purchasePriceApi;
  final num? wholesalePriceApi;
  final num? sellPriceApi;

  const ReceiveCartEditValues({
    required this.quantity,
    required this.purchasePriceUzs,
    required this.wholesalePriceUzs,
    required this.sellPriceUzs,
    required this.purchaseCurrency,
    required this.wholesaleCurrency,
    required this.sellCurrency,
    this.purchasePriceApi,
    this.wholesalePriceApi,
    this.sellPriceApi,
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

  String _priceLabel(ReceiveCartItem item, {required String kind}) {
    switch (kind) {
      case 'purchase':
        if (item.purchaseCurrency == 'usd') {
          final v = item.purchasePriceApi ?? item.purchasePriceUzs;
          return 'Kelish: ${_formatUsd(v)} USD';
        }
        return 'Kelish: ${formatThousands(item.purchasePriceUzs)}';
      case 'wholesale':
        if (item.wholesaleCurrency == 'usd') {
          final v = item.wholesalePriceApi ?? item.wholesalePriceUzs;
          return 'Ulgurji: ${_formatUsd(v)} USD';
        }
        return 'Ulgurji: ${formatThousands(item.wholesalePriceUzs)}';
      default:
        if (item.sellCurrency == 'usd') {
          final v = item.sellPriceApi ?? item.sellPriceUzs;
          return 'Sotish: ${_formatUsd(v)} USD';
        }
        return 'Sotish: ${formatThousands(item.sellPriceUzs)}';
    }
  }

  static String _formatUsd(num n) {
    final d = n.toDouble();
    if (d == d.roundToDouble()) return '${d.round()}';
    var s = d.toStringAsFixed(4);
    s = s.replaceFirst(RegExp(r'0+$'), '');
    s = s.replaceFirst(RegExp(r'\.$'), '');
    return s;
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
          ? const Center(
              child: Text(
                'Savat bo\'sh',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              itemCount: cart.length,
              itemBuilder: (context, i) {
                final item = cart[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    title: Text(
                      item.product.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      'Miqdor: ${item.quantity} · ${_priceLabel(item, kind: 'purchase')} · '
                      '${_priceLabel(item, kind: 'wholesale')} · '
                      '${_priceLabel(item, kind: 'sell')} · '
                      'Jami: ${formatThousands(item.lineTotalInUzs(usdRate: _session.usdExchangeRate))}',
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
                        const Text(
                          'Jami:',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          '${formatThousands(total)} so\'m',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                            color: AppTheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _saveDraft,
                        icon: const Icon(Icons.bookmark_outline_rounded),
                        label: const Text('Qoralamalarga saqlash'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
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
                            MaterialPageRoute(
                              builder: (_) => const KirimYakunlashScreen(),
                            ),
                          );
                          if (mounted) setState(() {});
                        },
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
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
    final isUpdate = _session.activeDraftId != null;
    try {
      await ReceiveDraftStorage.saveFromSession(_session);
      _session.resetAfterDraftSaved();
      if (!mounted) return;
      AppNotify.success(
        context,
        isUpdate ? 'Qoralama yangilandi' : 'Qoralamalarga saqlandi',
      );
      Navigator.pop(context);
    } catch (e) {
      if (mounted) AppNotify.error(context, '$e');
    }
  }

  Future<void> _editItem(ReceiveCartItem item) async {
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
      _applyEditValues(productId, values!);
      _session.resumeNotify();
      setState(() {});
    });
  }

  void _applyEditValues(String productId, ReceiveCartEditValues values) {
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
  }
}

class ReceiveCartItemEditSheet extends StatefulWidget {
  const ReceiveCartItemEditSheet({super.key, required this.item});

  final ReceiveCartItem item;

  @override
  State<ReceiveCartItemEditSheet> createState() =>
      _ReceiveCartItemEditSheetState();
}

class _ReceiveCartItemEditSheetState extends State<ReceiveCartItemEditSheet> {
  late final TextEditingController _qtyCtrl;
  late final TextEditingController _purchaseCtrl;
  late final TextEditingController _wholesaleCtrl;
  late final TextEditingController _sellCtrl;
  late String _purchaseCurrency;
  late String _wholesaleCurrency;
  late String _sellCurrency;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _purchaseCurrency = item.purchaseCurrency.toLowerCase();
    _wholesaleCurrency = item.wholesaleCurrency.toLowerCase();
    _sellCurrency = item.sellCurrency.toLowerCase();
    _qtyCtrl = TextEditingController(text: item.quantity.toString());
    _purchaseCtrl = TextEditingController(
      text: _priceFieldInitial(
        currency: _purchaseCurrency,
        api: item.purchasePriceApi,
        uzsInt: item.purchasePriceUzs,
      ),
    );
    _wholesaleCtrl = TextEditingController(
      text: _priceFieldInitial(
        currency: _wholesaleCurrency,
        api: item.wholesalePriceApi,
        uzsInt: item.wholesalePriceUzs,
      ),
    );
    _sellCtrl = TextEditingController(
      text: _priceFieldInitial(
        currency: _sellCurrency,
        api: item.sellPriceApi,
        uzsInt: item.sellPriceUzs,
      ),
    );
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _purchaseCtrl.dispose();
    _wholesaleCtrl.dispose();
    _sellCtrl.dispose();
    super.dispose();
  }

  static String _formatUsdForField(num n) {
    final d = n.toDouble();
    if (d == d.roundToDouble()) return '${d.round()}';
    var s = d.toStringAsFixed(4);
    s = s.replaceFirst(RegExp(r'0+$'), '');
    s = s.replaceFirst(RegExp(r'\.$'), '');
    return s;
  }

  static String _priceFieldInitial({
    required String currency,
    required num? api,
    required int uzsInt,
  }) {
    if (currency == 'usd' && api != null) return _formatUsdForField(api);
    if (currency == 'usd') {
      return uzsInt > 0 ? _formatUsdForField(uzsInt) : '';
    }
    return uzsInt > 0 ? formatThousands(uzsInt) : '';
  }

  static double? _parseUsd(String? s) {
    if (s == null || s.trim().isEmpty) return null;
    var t = s
        .replaceAll(RegExp(r'[\s\u00a0]'), '')
        .replaceAll(RegExp(r'\$|usd', caseSensitive: false), '');
    t = t.replaceAll(',', '.');
    if (t.split('.').length > 2) return null;
    return double.tryParse(t);
  }

  InputDecoration _qtyDecoration(String label) {
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
      floatingLabelStyle: const TextStyle(
        color: AppTheme.primary,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  void _save() {
    final qty = num.tryParse(_qtyCtrl.text.replaceAll(',', '.').trim());
    if (qty == null || qty <= 0) {
      AppNotify.info(context, 'Miqdorni kiriting');
      return;
    }

    late final int purchaseDisplay;
    late final num? purchaseApi;
    if (_purchaseCurrency == 'usd') {
      final d = _parseUsd(_purchaseCtrl.text);
      if (d == null || d < 0) {
        AppNotify.info(context, "Kelish narxi noto'g'ri (USD)");
        return;
      }
      purchaseApi = d;
      purchaseDisplay = d.round();
    } else {
      final purchase = parseFormattedSum(_purchaseCtrl.text);
      if (purchase == null || purchase < 0) {
        AppNotify.info(context, 'Kelish narxini kiriting');
        return;
      }
      purchaseApi = null;
      purchaseDisplay = purchase;
    }

    late final int sellDisplay;
    late final num? sellApi;
    if (_sellCurrency == 'usd') {
      final d = _parseUsd(_sellCtrl.text);
      if (d == null || d <= 0) {
        AppNotify.info(context, 'Sotish narxini kiriting (USD)');
        return;
      }
      sellApi = d;
      sellDisplay = d.round();
    } else {
      final sell = parseFormattedSum(_sellCtrl.text);
      if (sell == null || sell < 0) {
        AppNotify.info(context, 'Sotish narxini kiriting');
        return;
      }
      sellApi = null;
      sellDisplay = sell;
    }

    late final int wholesaleDisplay;
    late final num? wholesaleApi;
    final wholesaleText = _wholesaleCtrl.text.trim();
    if (wholesaleText.isEmpty) {
      wholesaleApi = null;
      wholesaleDisplay = 0;
    } else if (_wholesaleCurrency == 'usd') {
      final d = _parseUsd(_wholesaleCtrl.text);
      if (d == null || d < 0) {
        AppNotify.info(context, "Ulgurji narxi noto'g'ri (USD)");
        return;
      }
      wholesaleApi = d;
      wholesaleDisplay = d.round();
    } else {
      final wholesale = parseFormattedSum(_wholesaleCtrl.text);
      if (wholesale == null || wholesale < 0) {
        AppNotify.info(context, 'Ulgurji narxini kiriting');
        return;
      }
      wholesaleApi = null;
      wholesaleDisplay = wholesale;
    }

    Navigator.pop(
      context,
      ReceiveCartEditValues(
        quantity: qty,
        purchasePriceUzs: purchaseDisplay,
        wholesalePriceUzs: wholesaleDisplay,
        sellPriceUzs: sellDisplay,
        purchaseCurrency: _purchaseCurrency,
        wholesaleCurrency: _wholesaleCurrency,
        sellCurrency: _sellCurrency,
        purchasePriceApi: purchaseApi,
        wholesalePriceApi: wholesaleApi,
        sellPriceApi: sellApi,
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
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _qtyCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: _qtyDecoration('Miqdor'),
        ),
        const SizedBox(height: 12),
        _priceFieldWithCurrency(
          label: Strings.kelishNarxi,
          controller: _purchaseCtrl,
          currency: _purchaseCurrency,
          onCurrency: (v) => setState(() => _purchaseCurrency = v),
        ),
        const SizedBox(height: 12),
        _priceFieldWithCurrency(
          label: Strings.sotuvNarxi,
          controller: _sellCtrl,
          currency: _sellCurrency,
          onCurrency: (v) => setState(() => _sellCurrency = v),
        ),
        const SizedBox(height: 12),
        _priceFieldWithCurrency(
          label: Strings.ulgurjiNarxi,
          controller: _wholesaleCtrl,
          currency: _wholesaleCurrency,
          onCurrency: (v) => setState(() => _wholesaleCurrency = v),
        ),
      ],
    );
  }

  /// Yangi mahsulot ekrani bilan bir xil: narx + UZS/USD.
  Widget _priceFieldWithCurrency({
    required String label,
    required TextEditingController controller,
    required String currency,
    required ValueChanged<String> onCurrency,
  }) {
    final isUsd = currency.toLowerCase() == 'usd';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        DecoratedBox(
          decoration: BoxDecoration(
            color: AppTheme.cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.divider),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: isUsd
                      ? const TextInputType.numberWithOptions(decimal: true)
                      : TextInputType.number,
                  inputFormatters:
                      isUsd ? <TextInputFormatter>[] : [ThousandsInputFormatter()],
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    hintText: isUsd ? 'Masalan: 1.25' : null,
                    suffixText: isUsd ? 'USD' : Strings.som,
                    suffixStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 16,
                    ),
                  ),
                ),
              ),
              Container(
                width: 1,
                height: 36,
                color: AppTheme.divider,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _currencyChip(
                      label: 'UZS',
                      selected: !isUsd,
                      onTap: () => onCurrency('uzs'),
                    ),
                    const SizedBox(width: 4),
                    _currencyChip(
                      label: 'USD',
                      selected: isUsd,
                      onTap: () => onCurrency('usd'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _currencyChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppTheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? AppTheme.primary : AppTheme.divider,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : AppTheme.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
