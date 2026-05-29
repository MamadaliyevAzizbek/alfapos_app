import 'package:flutter/material.dart';
import '../../core/input_formatters.dart';
import '../../core/theme.dart';
import '../../models/cart_item.dart';
import '../../models/product.dart';
import '../../providers/clients_provider.dart';
import '../tranzaksiya_detail_screen.dart';
import '../../widgets/mixed_payment_inline_card.dart';

/// Desktop POS: to'liq ekran to'lov oynasi (web POS ko'rinishi).
class DesktopPaymentScreen extends StatelessWidget {
  final List<CartItem> items;
  final int? initialDiscountPercent;
  final Client? initialClient;
  final int? initialOrderId;
  final String? initialInvoiceId;
  final bool isReturnCheckout;

  const DesktopPaymentScreen({
    super.key,
    required this.items,
    this.initialDiscountPercent,
    this.initialClient,
    this.initialOrderId,
    this.initialInvoiceId,
    this.isReturnCheckout = false,
  });

  static Future<String?> show(
    BuildContext context, {
    required List<CartItem> items,
    int? initialDiscountPercent,
    Client? initialClient,
    int? initialOrderId,
    String? initialInvoiceId,
    bool isReturnCheckout = false,
  }) {
    return Navigator.of(context).push<String>(
      PageRouteBuilder(
        opaque: true,
        fullscreenDialog: true,
        pageBuilder: (_, __, ___) => DesktopPaymentScreen(
          items: items,
          initialDiscountPercent: initialDiscountPercent,
          initialClient: initialClient,
          initialOrderId: initialOrderId,
          initialInvoiceId: initialInvoiceId,
          isReturnCheckout: isReturnCheckout,
        ),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return TranzaksiyaDetailScreen(
      items: items,
      initialDiscountPercent: initialDiscountPercent,
      initialClient: initialClient,
      initialOrderId: initialOrderId,
      initialInvoiceId: initialInvoiceId,
      useDesktopFullscreenLayout: true,
      isReturnCheckout: isReturnCheckout,
    );
  }
}

/// Desktop to'lov UI — TranzaksiyaDetailScreen ichida ishlatiladi.
class DesktopPaymentLayout extends StatefulWidget {
  final List<CartItem> items;
  final Client? client;
  final int totalRaw;
  final int totalAfterDiscount;
  final String sellerName;
  final String storeName;
  final String description;
  final ValueChanged<String> onDescriptionChanged;
  final bool paymentTypesLoading;
  final List<MapEntry<String, String>> paymentList;
  final Map<String, int> paymentAmounts;
  final bool mixedPayment;
  final ValueChanged<bool> onMixedPaymentChanged;
  final String? selectedPaymentKey;
  final ValueChanged<String> onPaymentKeySelected;
  final void Function(String key, String title) onPaymentMethodTap;
  final void Function(String key, String raw) onMixedPaymentAmountChanged;
  final ValueChanged<String> onClearPayment;
  final TextEditingController amountController;
  final ValueChanged<String> onAmountChanged;
  final int remainingToPay;
  final int changeAmount;
  final int clientBalanceUzs;
  final bool canComplete;
  final bool submitting;
  final bool paymentComplete;
  final bool printing;
  final bool printingPrecheck;
  final VoidCallback onComplete;
  final VoidCallback onClose;
  final VoidCallback onPrint;
  final VoidCallback onPrintPrecheck;
  final int debtAmount;
  final List<MapEntry<String, int>> allocatedPayments;
  final bool isReturnCheckout;
  final int returnRefundDue;
  final bool returnCreditUsesGeneralDebt;

  const DesktopPaymentLayout({
    super.key,
    required this.items,
    required this.client,
    required this.totalRaw,
    required this.totalAfterDiscount,
    required this.sellerName,
    required this.storeName,
    required this.description,
    required this.onDescriptionChanged,
    required this.paymentTypesLoading,
    required this.paymentList,
    required this.paymentAmounts,
    required this.mixedPayment,
    required this.onMixedPaymentChanged,
    required this.selectedPaymentKey,
    required this.onPaymentKeySelected,
    required this.onPaymentMethodTap,
    required this.onMixedPaymentAmountChanged,
    required this.onClearPayment,
    required this.amountController,
    required this.onAmountChanged,
    this.remainingToPay = 0,
    this.changeAmount = 0,
    this.clientBalanceUzs = 0,
    required this.canComplete,
    required this.submitting,
    this.paymentComplete = false,
    this.printing = false,
    this.printingPrecheck = false,
    required this.onComplete,
    required this.onClose,
    required this.onPrint,
    required this.onPrintPrecheck,
    this.debtAmount = 0,
    this.allocatedPayments = const [],
    this.isReturnCheckout = false,
    this.returnRefundDue = 0,
    this.returnCreditUsesGeneralDebt = false,
  });

  @override
  State<DesktopPaymentLayout> createState() => _DesktopPaymentLayoutState();
}

class _DesktopPaymentLayoutState extends State<DesktopPaymentLayout> {
  late final TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController(text: widget.description);
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  String get _dateStr {
    final d = DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  static const double _footerButtonHeight = 64;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _buildReceiptSide()),
                  const VerticalDivider(width: 1, color: AppTheme.divider),
                  Expanded(child: _buildPaymentSide()),
                ],
              ),
            ),
            if (!widget.paymentComplete) _buildCheckoutFooter(),
            if (widget.paymentComplete) _buildPaymentCompleteFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildReceiptSide() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(24, 20, 24, 8),
          child: Text(
            "Sotuv bo'limi Tafsilotlar",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.storeName, style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
              Text(_dateStr, style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
              const Text(
                "Sotuv bo'limi Chek",
                style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
              ),
              Text(
                'Sotuvchi: ${widget.sellerName}',
                style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
              ),
              Text(
                'Mijoz: ${widget.client?.name ?? 'Mijoz'}',
                style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
              ),
              if (widget.clientBalanceUzs > 0) ...[
                const SizedBox(height: 4),
                Text(
                  'Mijoz balansi: ${formatThousands(widget.clientBalanceUzs)} UZS',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2E7D32),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _itemsTable(),
          ),
        ),
      ],
    );
  }

  List<MapEntry<String, int>> get _paymentFooterRows {
    if (widget.allocatedPayments.isNotEmpty) return widget.allocatedPayments;
    final rows = <MapEntry<String, int>>[];
    for (final e in widget.paymentList) {
      final amt = widget.paymentAmounts[e.key] ?? 0;
      if (amt > 0) rows.add(MapEntry(e.value, amt));
    }
    return rows;
  }

  Widget _itemsTable() {
    final paymentRows = _paymentFooterRows;
    return Table(
      columnWidths: const {
        0: FlexColumnWidth(2.2),
        1: FlexColumnWidth(1),
        2: FlexColumnWidth(1),
        3: FlexColumnWidth(1),
      },
      border: TableBorder(
        horizontalInside: BorderSide(color: AppTheme.divider.withValues(alpha: 0.6)),
      ),
      children: [
        TableRow(
          decoration: BoxDecoration(color: Colors.grey.shade50),
          children: _headerCells(['Mahsulot nomi', 'Miqdori', 'Narxi', 'Umumiy']),
        ),
        ...widget.items.map((item) {
          final p = item.product;
          final unit = item.sellByPack ? 'pachka' : Product.unitDisplayShort(p.unit);
          return TableRow(
            children: [
              _cell(item.product.name),
              _cell('${item.quantity} $unit'),
              _cell(formatThousands(item.unitPriceDisplay)),
              _cell(formatThousands(item.total)),
            ],
          );
        }),
        for (final pay in paymentRows)
          TableRow(children: [_cell(''), _cell(''), _cell(pay.key), _cell(formatThousands(pay.value))]),
        TableRow(
          children: [
            _cell(''),
            _cell(''),
            _cell('Umumiy', bold: true),
            _cell(formatThousands(widget.totalAfterDiscount), bold: true),
          ],
        ),
      ],
    );
  }

  List<Widget> _headerCells(List<String> labels) {
    return labels
        .map(
          (t) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            child: Text(
              t,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textPrimary),
            ),
          ),
        )
        .toList();
  }

  Widget _cell(String text, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
          color: AppTheme.textPrimary,
        ),
      ),
    );
  }

  Widget _buildPaymentSide() {
    if (widget.paymentComplete) {
      return _buildPaymentCompleteSide();
    }

    String? selectedName;
    for (final e in widget.paymentList) {
      if (e.key == widget.selectedPaymentKey) {
        selectedName = e.value;
        break;
      }
    }

    final headerTitle = widget.isReturnCheckout
        ? 'Qaytarish ${formatThousands(widget.returnRefundDue)}'
        : 'Umumiy ${formatThousands(widget.totalAfterDiscount)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildPaymentHeader(title: headerTitle),
        Expanded(
          child: widget.paymentTypesLoading
              ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (widget.isReturnCheckout) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF3E0),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFFFB74D)),
                          ),
                          child: const Text(
                            'Ichki qaytarish: to\'lov summalari mijozga qaytariladi. Mijoz balansi bu rejimda ishlatilmaydi.',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                        ),
                        if (widget.returnCreditUsesGeneralDebt) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFF81C784)),
                            ),
                            child: const Text(
                              'Qarz to\'lovi: mijozning umumiy qarzidan avtomatik ayiriladi (chek tanlash shart emas). '
                              'Qancha kamaygani mijoz sotuvlari ro\'yxatida due_amount yangilanadi.',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                      ],
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Text(
                                "Aralash to'lov",
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                              ),
                            ),
                            Switch(
                              value: widget.mixedPayment,
                              activeTrackColor: AppTheme.primary.withValues(alpha: 0.45),
                              activeThumbColor: AppTheme.primary,
                              onChanged: widget.submitting ? null : widget.onMixedPaymentChanged,
                            ),
                          ],
                        ),
                      ),
                      if (widget.mixedPayment || widget.remainingToPay > 0 || widget.changeAmount > 0) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            if (widget.remainingToPay > 0)
                              Text(
                                "Qolgan: ${formatThousands(widget.remainingToPay)}",
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFE53935),
                                ),
                              ),
                            if (widget.changeAmount > 0) ...[
                              const SizedBox(width: 16),
                              Text(
                                "Qaytim: ${formatThousands(widget.changeAmount)}",
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF2E7D32),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                      const SizedBox(height: 16),
                      if (!widget.mixedPayment && selectedName != null)
                        _buildSinglePaymentMethodBanner(selectedName),
                      if (widget.mixedPayment) ...[
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 2.35,
                          ),
                          itemCount: widget.paymentList.length,
                          itemBuilder: (context, i) {
                            final e = widget.paymentList[i];
                            final amount = widget.paymentAmounts[e.key] ?? 0;
                            final isBalance = _isBalanceName(e.value);
                            return MixedPaymentInlineCard(
                              desktopLarge: true,
                              title: e.value,
                              icon: iconForPaymentName(e.value),
                              amount: amount,
                              balanceUzs: isBalance ? widget.clientBalanceUzs : null,
                              onAmountChanged: (raw) => widget.onMixedPaymentAmountChanged(e.key, raw),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                      ],
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Icon(Icons.description_outlined, size: 18, color: Colors.grey.shade600),
                          const SizedBox(width: 6),
                          Text('Izoh:', style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _noteController,
                        minLines: 4,
                        maxLines: 6,
                        decoration: InputDecoration(
                          hintText: 'Izoh',
                          filled: true,
                          fillColor: const Color(0xFFF5F5F5),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                        onChanged: widget.onDescriptionChanged,
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  /// Pastki qator: chapda oldindan chek, o‘ngda to‘lov — bir xil balandlik va chiziq.
  Widget _buildCheckoutFooter() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 1, color: AppTheme.divider),
        if (!widget.mixedPayment && widget.paymentList.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
            child: Row(
              children: [
                const Expanded(child: SizedBox()),
                Expanded(child: _buildPaymentTypeRowContent()),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: _buildPrecheckPrintButton()),
              const SizedBox(width: 16),
              Expanded(child: _buildCompletePaymentButton()),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentCompleteFooter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Row(
        children: [
          Expanded(child: _buildLargePrintButton()),
          const Expanded(child: SizedBox()),
        ],
      ),
    );
  }

  Widget _buildCompletePaymentButton() {
    return SizedBox(
      height: _footerButtonHeight,
      width: double.infinity,
      child: FilledButton(
        onPressed: widget.canComplete && !widget.submitting ? widget.onComplete : null,
        style: FilledButton.styleFrom(
          backgroundColor: widget.canComplete ? AppTheme.primary : const Color(0xFFBDBDBD),
          disabledBackgroundColor: const Color(0xFFE0E0E0),
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, _footerButtonHeight),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: widget.submitting
            ? const SizedBox(
                height: 28,
                width: 28,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
              )
            : const Text(
                "To'lov amalga oshirildi",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: 0.2),
              ),
      ),
    );
  }

  Widget _buildPaymentCompleteSide() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildPaymentHeader(title: "To'lov qabul qilindi"),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_rounded, size: 72, color: Colors.green.shade600),
                const SizedBox(height: 20),
                Text(
                  'Umumiy ${formatThousands(widget.totalAfterDiscount)} UZS',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 28),
                _buildLargePrintButton(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentHeader({required String title}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            onPressed: (widget.submitting || widget.printing || widget.printingPrecheck) ? null : widget.onClose,
            style: IconButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              shape: const CircleBorder(),
            ),
            icon: const Icon(Icons.close_rounded, size: 22),
          ),
        ],
      ),
    );
  }

  Widget _buildPrecheckPrintButton() {
    final busy = widget.printingPrecheck || widget.printing || widget.submitting;
    return SizedBox(
      height: _footerButtonHeight,
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: busy || widget.items.isEmpty ? null : widget.onPrintPrecheck,
        icon: widget.printingPrecheck
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: AppTheme.primary),
              )
            : const Icon(Icons.print_rounded, size: 22, color: AppTheme.primary),
        label: Text(
          widget.printingPrecheck ? 'Chop etilmoqda...' : 'Chop etish (oldindan chek)',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.primary),
        ),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, _footerButtonHeight),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          side: const BorderSide(color: AppTheme.primary, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  Widget _buildLargePrintButton() {
    return SizedBox(
      height: _footerButtonHeight,
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: widget.printing ? null : widget.onPrint,
        icon: widget.printing
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: AppTheme.primary),
              )
            : const Icon(Icons.print_rounded, size: 24, color: AppTheme.primary),
        label: Text(
          widget.printing ? 'Chop etilmoqda...' : 'Qabulni chop etish',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.primary),
        ),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, _footerButtonHeight),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          side: const BorderSide(color: AppTheme.primary, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  /// Bitta to'lov: summa avtomatik — pastdagi tugmadan tur tanlanadi (input yo'q).
  Widget _buildSinglePaymentMethodBanner(String selectedName) {
    final key = widget.selectedPaymentKey;
    final amount = key != null
        ? (widget.paymentAmounts[key] ?? widget.totalAfterDiscount)
        : widget.totalAfterDiscount;
    final isBalance = _isBalanceName(selectedName);
    final insufficient = isBalance && amount < widget.totalAfterDiscount;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.35), width: 1.5),
      ),
      child: Row(
        children: [
          Icon(Icons.payments_outlined, color: AppTheme.primary, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  selectedName,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  insufficient
                      ? "Mijoz balansidan: ${formatThousands(amount)} UZS — qolgan ${formatThousands(widget.totalAfterDiscount - amount)} UZS to'lanmadi"
                      : "To'liq summa: ${formatThousands(amount)} UZS",
                  style: TextStyle(
                    fontSize: 14,
                    color: insufficient ? const Color(0xFFE53935) : AppTheme.textSecondary,
                    fontWeight: insufficient ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  "Aralash to'lovni yoqsangiz, har bir tur uchun summani alohida kiritasiz.",
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Pastki qator: Naqd / Click / Terminal — teng kenglikda, katta tugmalar.
  Widget _buildPaymentTypeRowContent() {
    return Row(
      children: [
        for (var i = 0; i < widget.paymentList.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: _buildPaymentTypeButton(widget.paymentList[i]),
          ),
        ],
      ],
    );
  }

  Widget _buildPaymentTypeButton(MapEntry<String, String> entry) {
    final selected = entry.key == widget.selectedPaymentKey;
    return Material(
      color: selected ? AppTheme.primary : const Color(0xFFBDBDBD),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: widget.submitting ? null : () => widget.onPaymentKeySelected(entry.key),
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          height: 52,
          child: Center(
            child: Text(
              entry.value,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

bool _isBalanceName(String name) {
  final n = name.toLowerCase();
  return n.contains('balans') || n.contains('balance');
}
