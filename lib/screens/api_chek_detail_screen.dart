import 'dart:io';

import 'package:flutter/material.dart';
import '../core/app_notify.dart';
import '../core/product_image_utils.dart';
import '../core/theme.dart';
import '../core/input_formatters.dart';
import '../models/product.dart';
import '../providers/products_provider.dart';
import '../widgets/auth_network_image.dart';
import '../widgets/ios_style_modals.dart';
import '../widgets/product_tile.dart';
import '../utils/platform_layout.dart';
import '../utils/sale_receipt_reprint_print.dart';
import '../utils/sale_return_utils.dart';
import '../utils/sales_return_flow.dart';
import '../utils/invoice_edit_utils.dart';
import '../utils/invoice_edit_flow.dart';

/// API dan kelgan chek batafsil — to'liq chek ko'rinishi (Hisobotlar, Tranzaksiyalar, Mijoz detali).
class ApiChekDetailScreen extends StatefulWidget {
  /// Reports/sales qatoridan: invoice_id, date, created_by, total, discount, customer
  final Map<String, dynamic> sale;
  /// POST invoice-details/{id} javobi: datarows (mahsulotlar), payments, total, sub_total
  final Map<String, dynamic> invoiceDetail;
  /// Batafsil yuklanmagan bo'lsa API xabari (ixtiyoriy)
  final String? invoiceLoadError;

  const ApiChekDetailScreen({
    super.key,
    required this.sale,
    required this.invoiceDetail,
    this.invoiceLoadError,
  });

  @override
  State<ApiChekDetailScreen> createState() => _ApiChekDetailScreenState();

  static String _fmt(int n) => formatThousands(n);

  static int _amount(dynamic v) => parseAmountFromApi(v);

  /// Backend xabari (masalan "sub_total on null") ni foydalanuvchi uchun qisqa qilib ko'rsatish.
  static String _productListErrorText(String? raw) {
    if (raw == null || raw.isEmpty) return "— Batafsil ro'yxat serverdan olinmadi";
    final lower = raw.toLowerCase();
    if (lower.contains('sub_total') && lower.contains('on null')) {
      return "— Serverda xato: chek batafsilida ma'lumot yetishmayapti (sub_total). Backend loglarini tekshiring.";
    }
    if (lower.contains('html') && lower.contains('404')) {
      return "— Batafsil endpoint topilmadi (404). API manzilini tekshiring.";
    }
    return "— $raw";
  }

  /// MOBILE_INVOICE_AND_RECEIPT_API: datarows = mahsulotlar + "Sub total"/"Tax"/"Discount"/"Total" + to'lov turlari.
  /// To'lov qatori "Total"dan oldin ham kelishi mumkin (masalan "Click" 59500).
  static _ParsedInvoiceRows _parseInvoiceDetailRows(List<Map<String, dynamic>> rawRows) {
    final productRows = <Map<String, dynamic>>[];
    final paymentRows = <Map<String, dynamic>>[];
    int subTotal = 0, tax = 0, discount = 0, total = 0;
    const summaryTitles = ['sub total', 'tax', 'total', 'discount', 'chegirma'];
    const notPaymentTitles = ['sub total', 'tax', 'total', 'discount', 'chegirma', 'umumiy summa', 'umumiy', 'soliq'];
    for (final r in rawRows) {
      final title = (r['title'] ?? r['name'] ?? '').toString().trim();
      final titleLower = title.toLowerCase();
      if (titleLower == 'sub total') {
        subTotal = _amount(r['total']);
        continue;
      }
      if (titleLower == 'tax') {
        tax = _amount(r['total']);
        continue;
      }
      if (titleLower == 'discount' || titleLower == 'chegirma') {
        discount = _amount(r['total'] ?? r['discount'] ?? r['amount']);
        continue;
      }
      if (titleLower == 'total') {
        total = _amount(r['total']);
        continue;
      }
      final hasQty = r.containsKey('quantity') || r.containsKey('qty');
      final hasPrice = r.containsKey('price') || r.containsKey('unit_price');
      final hasAmount = r['total'] != null || r['paid'] != null || r['amount'] != null;
      if (hasQty || (hasPrice && title.isNotEmpty && !summaryTitles.contains(titleLower))) {
        productRows.add(r);
        continue;
      }
      if (title.isNotEmpty && hasAmount && !notPaymentTitles.any((t) => titleLower == t || titleLower.startsWith('$t ') || titleLower.startsWith('$t:'))) {
        paymentRows.add(r);
      }
    }
    return _ParsedInvoiceRows(productRows, paymentRows, subTotal, tax, discount, total);
  }
}

class _ApiChekDetailScreenState extends State<ApiChekDetailScreen> {
  bool _catalogReady = false;
  bool _printing = false;

  @override
  void initState() {
    super.initState();
    _catalogReady = ProductsProvider.instance.isLoaded;
    _prepareCatalog();
  }

  Future<void> _prepareCatalog() async {
    try {
      await ProductsProvider.instance.loadFromApi();
    } catch (_) {}
    if (mounted) setState(() => _catalogReady = true);
  }

  Future<void> _printReceipt() async {
    if (_printing) return;
    setState(() => _printing = true);
    try {
      final result = await SaleReceiptReprintPrint.print(
        sale: widget.sale,
        invoiceDetail: widget.invoiceDetail,
      );
      if (!mounted) return;
      if (result.ok) {
        AppNotify.success(context, result.message);
      } else {
        AppNotify.warning(context, result.message);
      }
    } catch (e) {
      if (mounted) AppNotify.error(context, 'Chop etish xatosi: $e');
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_catalogReady && !ProductsProvider.instance.isLoaded) {
      final invoiceId = widget.sale['invoice_id'] ?? widget.sale['order_id'] ?? widget.sale['id'];
      final idStr = invoiceId?.toString() ?? '—';
      final posTitle = idStr.startsWith('POS') ? idStr : 'POS$idStr';
      return Scaffold(
        appBar: AppBar(title: Text("Chek #$posTitle")),
        body: const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
      );
    }

    final invoiceId = widget.sale['invoice_id'] ?? widget.sale['order_id'] ?? widget.sale['id'];
    final idStr = invoiceId?.toString() ?? '—';
    final posTitle = idStr.startsWith('POS') ? idStr : 'POS$idStr';

    final dateRaw = widget.sale['date'] ?? widget.sale['created_at'] ?? widget.invoiceDetail['date'] ?? '';
    DateTime? dt;
    if (dateRaw != null && dateRaw.toString().isNotEmpty) {
      dt = DateTime.tryParse(dateRaw.toString().replaceFirst(' ', 'T'));
    }
    dt ??= DateTime.now();
    final dateStr = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    final timeStr = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';

    final sellerName = (widget.sale['created_by'] ?? widget.invoiceDetail['created_by'] ?? 'Sotuvchi').toString();
    final customer = widget.sale['customer'] ?? widget.invoiceDetail['customer'];
    final clientName = customer is String ? customer : (customer is Map ? (customer['name'] ?? '').toString() : '');

    // invoiceDetail — MOBILE_INVOICE_AND_RECEIPT_API: datarows = mahsulotlar + Sub total/Tax/Total + to'lov turlari
    final inv = widget.invoiceDetail;
    List<dynamic> datarows = inv['datarows'] as List<dynamic>? ??
        inv['data'] as List<dynamic>? ??
        inv['items'] as List<dynamic>? ??
        inv['products'] as List<dynamic>? ??
        inv['invoice_items'] as List<dynamic>? ??
        inv['rows'] as List<dynamic>? ??
        [];
    if (datarows is! List && inv['data'] is Map) {
      final d = inv['data'] as Map;
      datarows = d['datarows'] as List<dynamic>? ?? d['items'] as List<dynamic>? ?? [];
    }
    if (datarows is! List) datarows = [];
    final rawRows = datarows.where((e) => e is Map).map((e) => Map<String, dynamic>.from(e as Map)).toList();

    final parsed = ApiChekDetailScreen._parseInvoiceDetailRows(rawRows);
    final rows = parsed.productRows;
    List<Map<String, dynamic>> payments = parsed.paymentRows;
    if (payments.isEmpty) {
      final paymentsRaw = inv['payments'] as List<dynamic>? ?? inv['payment_types'] as List<dynamic>? ?? [];
      if (paymentsRaw is List && paymentsRaw.isNotEmpty) {
        payments = paymentsRaw.where((e) => e is Map).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    }
    final subTotalUzs = parsed.subTotal;
    final taxUzs = parsed.tax;
    final totalFromDetail = parsed.total;
    final discountFromRows = parsed.discount;

    final totalUzs = totalFromDetail > 0 ? totalFromDetail : ApiChekDetailScreen._amount(widget.sale['total'] ?? inv['total'] ?? inv['grand_total']);
    int effectiveSubTotal = subTotalUzs;
    if (effectiveSubTotal == 0 && rows.isNotEmpty) {
      for (final r in rows) {
        effectiveSubTotal += ApiChekDetailScreen._amount(r['total'] ?? r['calculatedPrice'] ?? r['sum']);
      }
    }
    int discountUzs = discountFromRows > 0 ? discountFromRows : ApiChekDetailScreen._amount(widget.sale['discount'] ?? inv['discount'] ?? 0);
    if (discountUzs == 0 && effectiveSubTotal > 0 && totalUzs > 0 && effectiveSubTotal > totalUzs) {
      discountUzs = effectiveSubTotal - totalUzs;
    }

    final alreadyReturned = isSaleAlreadyReturned(widget.sale, invoiceDetail: inv);
    final showReturnButton = canShowReturnSaleButton(widget.sale, invoiceDetail: inv);
    final showEditButton = canShowInvoiceEditButton(widget.sale, invoiceDetail: inv);
    final showDateEditButton = canShowInvoiceDateEditButton(widget.sale, invoiceDetail: inv);
    final isEdited = widget.sale['is_invoice_edited'] == 1 ||
        widget.sale['is_invoice_edited'] == true ||
        widget.sale['is_invoice_edited'] == '1';
    final editSource = (widget.sale['invoice_edit_source_invoice_id'] ?? '').toString().trim();

    return Scaffold(
      appBar: AppBar(
        title: Text("Chek #$posTitle"),
        actions: [
          if (showEditButton)
            IconButton(
              tooltip: 'Tahrirlash',
              icon: const Icon(Icons.edit_rounded),
              onPressed: () async {
                await InvoiceEditFlow.startFullEdit(
                  context,
                  widget.sale,
                  invoiceDetail: inv,
                  popCurrentRoute: true,
                );
              },
            ),
          if (showDateEditButton)
            IconButton(
              tooltip: 'Sanani tahrirlash',
              icon: const Icon(Icons.calendar_month_rounded),
              onPressed: () async {
                final ok = await InvoiceEditFlow.editSaleDate(
                  context,
                  widget.sale,
                  invoiceDetail: inv,
                  popCurrentRoute: true,
                );
                if (ok && mounted) setState(() {});
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$dateStr - $timeStr',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 6),
            Text('Chek raqami: $posTitle', style: const TextStyle(fontSize: 14)),
            Text('Sotuvchi: $sellerName', style: const TextStyle(fontSize: 14)),
            if (clientName.toString().trim().isNotEmpty)
              Text('Mijoz: ${clientName.toString().trim()}', style: const TextStyle(fontSize: 14)),
            if (isEdited) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade100),
                ),
                child: Text(
                  editSource.isNotEmpty
                      ? 'Tahrirlangan chek (avvalgi: $editSource)'
                      : 'Tahrirlangan chek',
                  style: TextStyle(fontSize: 13, color: Colors.blue.shade900, fontWeight: FontWeight.w600),
                ),
              ),
            ],
            if (alreadyReturned) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: Colors.orange.shade800, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Bu chek allaqachon qaytarilgan. Qayta qaytarish mumkin emas.',
                        style: TextStyle(fontSize: 13, color: Colors.orange.shade900, height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),

            _CollapsibleSectionCard(
              title: "Savatcha",
              initiallyExpanded: true,
              child: rows.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        ApiChekDetailScreen._productListErrorText(widget.invoiceLoadError),
                        style: TextStyle(fontSize: 14, color: widget.invoiceLoadError != null ? Colors.red.shade700 : Colors.grey.shade700),
                      ),
                    )
                  : Column(
                      children: [
                        for (final r in rows) _CartItemRow(row: r),
                      ],
                    ),
            ),

            const SizedBox(height: 14),

            _StaticSectionCard(
              title: "To'lov",
              child: payments.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text('— To\'lov ma\'lumoti yo\'q', style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
                    )
                  : Column(
                      children: [
                        for (final p in payments)
                          _PaymentRow(
                            methodName: (p['payment_name'] ??
                                    p['name'] ??
                                    p['payment_method'] ??
                                    p['payment_type'] ??
                                    p['title'] ??
                                    p['method'] ??
                                    p['type'] ??
                                    '—')
                                .toString(),
                            amount: ApiChekDetailScreen._amount(p['total'] ?? p['paid'] ?? p['amount'] ?? 0),
                          ),
                      ],
                    ),
            ),

            const SizedBox(height: 14),

            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  if (effectiveSubTotal > 0)
                    _kv("Umumiy summa", '${ApiChekDetailScreen._fmt(effectiveSubTotal)} UZS'),
                  if (taxUzs > 0) ...[
                    const SizedBox(height: 6),
                    _kv("Soliq", '${ApiChekDetailScreen._fmt(taxUzs)} UZS'),
                  ],
                  const SizedBox(height: 6),
                  _kv("Chegirma", '${ApiChekDetailScreen._fmt(discountUzs)} UZS', valueColor: discountUzs > 0 ? Colors.green.shade700 : null),
                  const Divider(height: 18),
                  _kv("Jami", '${ApiChekDetailScreen._fmt(totalUzs)} UZS', isTotal: true),
                ],
              ),
            ),

            if (isDesktopPosLayout) ...[
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _printing ? null : _printReceipt,
                  icon: _printing
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: AppTheme.primary),
                        )
                      : const Icon(Icons.print_rounded, size: 22, color: AppTheme.primary),
                  label: Text(
                    _printing ? 'Chop etilmoqda...' : 'Chekni chop etish',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.primary),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: AppTheme.primary, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],

            if (showEditButton) ...[
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => InvoiceEditFlow.startFullEdit(
                    context,
                    widget.sale,
                    invoiceDetail: inv,
                    popCurrentRoute: true,
                  ),
                  icon: const Icon(Icons.edit_rounded, size: 22),
                  label: const Text('Chekni tahrirlash'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
            if (showDateEditButton) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final ok = await InvoiceEditFlow.editSaleDate(
                      context,
                      widget.sale,
                      invoiceDetail: inv,
                      popCurrentRoute: true,
                    );
                    if (ok && mounted) setState(() {});
                  },
                  icon: const Icon(Icons.calendar_month_rounded, size: 22),
                  label: const Text('Sanani tahrirlash'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],

            if (showReturnButton) ...[
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final orderId = getOrderIdFromSale(widget.sale);
                  if (orderId == null) {
                    if (context.mounted) {
                      AppNotify.error(context, "Chek ID aniqlanmadi");
                    }
                    return;
                  }
                  if (!canShowReturnSaleButton(widget.sale, invoiceDetail: inv)) {
                    if (context.mounted) {
                      AppNotify.info(context, "Bu chek allaqachon qaytarilgan");
                    }
                    return;
                  }
                  final due = SalesReturnFlow.saleDueAmount(widget.sale, invoiceDetail: inv);
                  final confirm = await IosStyleModals.showSheet<bool>(
                    context: context,
                    showGrabber: true,
                    child: Builder(
                      builder: (ctx) => Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text("Chekni qaytarish", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                            const SizedBox(height: 10),
                            Text(
                              due > 0
                                  ? "Qarzli chek to'lovsiz yo'l bilan qaytariladi (web bilan bir xil: yangi «… qaytarilgan» chek). Davom etasizmi?"
                                  : "Ushbu sotuv API orqali bekor qilinadi (serverda ham qaytariladi). Davom etasizmi?",
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 14),
                            IosStyleModals.sheetPillCancelSaveRow(
                              cancelLabel: "Bekor qilish",
                              saveLabel: "Qaytarish",
                              onCancel: () => Navigator.pop(ctx, false),
                              onSave: () => Navigator.pop(ctx, true),
                              saveBackgroundColor: Colors.red.shade700,
                              saveForegroundColor: Colors.white,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                  if (confirm != true || !context.mounted) return;
                  try {
                    // SALES_RETURNS_API: qarzli → store+tolovsiz; to'langan → return-full-order.
                    await SalesReturnFlow.returnFullReceipt(
                      sale: widget.sale,
                      invoiceDetail: inv,
                    );
                    SaleReturnGuard.markReturned(orderId);
                    widget.sale['status'] = 'returned';
                    widget.sale['is_returned'] = true;
                    if (!context.mounted) return;
                    Navigator.pop(context, true);
                    AppNotify.success(null, "Chek muvaffaqiyatli qaytarildi");
                  } catch (e) {
                    if (!context.mounted) return;
                    AppNotify.error(
                      context,
                      "Qaytarish xatosi: ${e.toString().replaceFirst('Exception: ', '')}",
                    );
                  }
                },
                icon: const Icon(Icons.undo_rounded, size: 22),
                label: const Text("Chekni qaytarish"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Chek ekrani: ochiq kartа (To'lov va h.k.).
class _StaticSectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _StaticSectionCard({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = Colors.grey.shade200;
    return Material(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

/// Faqat Savatcha: ochiladi-yopiladi (qora fon flash oldini olish bilan).
class _CollapsibleSectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final bool initiallyExpanded;

  const _CollapsibleSectionCard({
    required this.title,
    required this.child,
    this.initiallyExpanded = true,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = Colors.grey.shade200;
    return Material(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          hoverColor: Colors.transparent,
          splashFactory: NoSplash.splashFactory,
          listTileTheme: const ListTileThemeData(
            tileColor: Colors.transparent,
            selectedTileColor: Colors.transparent,
          ),
        ),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          maintainState: true,
          backgroundColor: Colors.white,
          collapsedBackgroundColor: Colors.white,
          shape: const Border(),
          collapsedShape: const Border(),
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          title: Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          children: [child],
        ),
      ),
    );
  }
}

class _PaymentRow extends StatelessWidget {
  final String methodName;
  final int amount;
  const _PaymentRow({required this.methodName, required this.amount});

  @override
  Widget build(BuildContext context) {
    final name = methodName.trim().isEmpty ? '—' : methodName.trim();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              name,
              style: const TextStyle(fontSize: 16, color: AppTheme.textPrimary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '${formatThousands(amount)} UZS',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
          ),
        ],
      ),
    );
  }
}

class _CartItemRow extends StatelessWidget {
  final Map<String, dynamic> row;
  const _CartItemRow({required this.row});

  static int _amount(dynamic v) => parseAmountFromApi(v);

  static bool _isKgUnit(String u) {
    final s = u.trim().toLowerCase();
    return s == 'kg' || s == 'кг' || s.contains('kilo') || s.contains('кил');
  }

  static bool _isPieceUnit(String u) {
    final s = u.trim().toLowerCase();
    return s.contains('dona') || s.contains('sht') || s.contains('шт') || s.contains('piece') || s.contains('ta');
  }

  static String _fmtQtyByUnit(String rawQty, String rawUnit) {
    final q = num.tryParse(rawQty.replaceAll(',', '.').trim());
    if (q == null) return rawQty.trim();
    final unit = rawUnit.trim();
    if (unit.isEmpty) {
      // API ba'zan birlikni yubormaydi; bunday holatda:
      // - agar ".000" bo'lsa (butun) => dona kabi ko'rsatamiz
      // - aks holda (1.500) => kg kabi kasrni saqlaymiz
      if (q == q.roundToDouble()) return q.toInt().toString();
      return rawQty.replaceAll(',', '.').trim();
    }
    if (_isKgUnit(unit)) {
      // kg uchun .000 lar ko‘rinsin
      return q.toStringAsFixed(3);
    }
    if (_isPieceUnit(unit)) {
      // dona/sht uchun .000 lar bo‘lmasin
      return q.round().toString();
    }
    // boshqa birliklar: butun bo‘lsa butun, bo‘lmasa asl ko‘rinish
    if (q == q.roundToDouble()) return q.toInt().toString();
    return rawQty.trim();
  }

  static Map<String, dynamic>? _mapOrNull(dynamic v) => v is Map ? Map<String, dynamic>.from(v as Map) : null;

  static String _barcodeLike(Map<String, dynamic> r) {
    // 1) to'g'ridan-to'g'ri row ichida
    dynamic bc = r['bar_code'] ??
        r['barcode'] ??
        r['barCode'] ??
        r['newBarcode'] ??
        r['barcode_number'] ??
        r['barcodeNumber'] ??
        r['product_barcode'] ??
        r['item_barcode'] ??
        r['line_barcode'] ??
        r['variant_barcode'] ??
        r['variant_bar_code'] ??
        r['plu'] ??
        r['PLU'] ??
        r['code'] ??
        r['ean'] ??
        r['upc'];

    // 2) ichki product/variant strukturalari bo'lsa
    final product = _mapOrNull(r['product']);
    bc ??= product?['bar_code'] ?? product?['barcode'] ?? product?['newBarcode'] ?? product?['code'];

    final variant = _mapOrNull(r['variant']);
    bc ??= variant?['bar_code'] ?? variant?['barcode'] ?? variant?['newBarcode'] ?? variant?['code'];

    final variants = r['variants'];
    if (bc == null && variants is List && variants.isNotEmpty) {
      final v0 = _mapOrNull(variants.first);
      bc = v0?['bar_code'] ?? v0?['barcode'] ?? v0?['newBarcode'] ?? v0?['code'];
    }

    var s = (bc ?? '').toString().trim();
    if (s.isNotEmpty) return s;

    // 3) Ba'zi API lar barcode ni ichki obyektda yuboradi
    for (final nestKey in ['item', 'cart_item', 'cartItem', 'line', 'product_info', 'productInfo']) {
      final nest = _mapOrNull(r[nestKey]);
      if (nest == null) continue;
      s = _barcodeLike(nest);
      if (s.isNotEmpty) return s;
    }
    return '';
  }

  static String _skuLike(Map<String, dynamic> r) {
    dynamic sku = r['sku'] ?? r['sku_code'] ?? r['artikul'] ?? r['article'] ?? r['SKU'];
    final product = _mapOrNull(r['product']);
    sku ??= product?['sku'] ?? product?['sku_code'] ?? product?['artikul'];
    return (sku ?? '').toString().trim();
  }

  /// Invoice qatorida productID / variantID bo'lsa — mahsulotlar ro'yxatidan topish.
  static Product? _productFromInvoiceRow(Map<String, dynamic> r) {
    final prov = ProductsProvider.instance;
    if (!prov.isLoaded || prov.items.isEmpty) return null;

    for (final key in ['productID', 'product_id', 'productId', 'pid', 'item_product_id', 'catalog_id']) {
      final raw = r[key];
      if (raw == null) continue;
      final idStr = raw.toString().trim();
      if (idStr.isEmpty || idStr == '0') continue;
      final p = prov.getProductById(idStr);
      if (p != null) return p;
    }

    final productMap = _mapOrNull(r['product']);
    if (productMap != null) {
      for (final key in ['id', 'productID', 'product_id', 'productId']) {
        final raw = productMap[key];
        if (raw == null) continue;
        final idStr = raw.toString().trim();
        if (idStr.isEmpty || idStr == '0') continue;
        final p = prov.getProductById(idStr);
        if (p != null) return p;
      }
    }

    final vidRaw = r['variantID'] ?? r['variant_id'] ?? r['variantId'];
    final vid = vidRaw is int ? vidRaw : int.tryParse(vidRaw?.toString().trim() ?? '');
    if (vid != null && vid != 0) {
      for (final p in prov.items) {
        if (p.variantId == vid) return p;
      }
    }
    return null;
  }

  /// Chek `title` dan mahsulot nomini ajratib, katalog bilan solishtirish.
  static String _titleMatchBase(Map<String, dynamic> r) {
    final title = (r['title'] ?? r['product_title'] ?? r['productTitle'] ?? r['name'] ?? '').toString().trim();
    if (title.isEmpty) return '';
    var base = title.replaceAll(RegExp(r'\s+'), ' ');
    final paren = base.indexOf('(');
    if (paren > 0) base = base.substring(0, paren).trim();
    final dashIdx = base.indexOf(' - ');
    if (dashIdx > 0) base = base.substring(0, dashIdx).trim();
    return base.trim();
  }

  /// Invoice qatorida ID bo'lmasa — `title` dan katalogga moslash.
  static Product? _productByTitleFallback(Map<String, dynamic> r) {
    final base = _titleMatchBase(r);
    if (base.isEmpty) return null;
    final prov = ProductsProvider.instance;
    if (!prov.isLoaded || prov.items.isEmpty) return null;
    final lb = base.toLowerCase();
    for (final cand in prov.items) {
      if (cand.name.trim().toLowerCase() == lb) return cand;
    }
    for (final cand in prov.items) {
      final n = cand.name.trim().toLowerCase();
      if (n.length >= 2 && (lb == n || lb.startsWith(n) || n.startsWith(lb) || lb.contains(n) || n.contains(lb))) {
        return cand;
      }
    }
    return null;
  }

  static Product? _resolvedProduct(Map<String, dynamic> r) {
    final byId = _productFromInvoiceRow(r);
    if (byId != null) return byId;
    return _productByTitleFallback(r);
  }

  static String? _imagePathFromDynamic(dynamic v) {
    if (v == null) return null;
    if (v is String) {
      final s = v.trim();
      if (s.isEmpty || s == 'null') return null;
      return s;
    }
    if (v is Map) {
      final m = Map<String, dynamic>.from(v as Map);
      for (final k in ['url', 'path', 'src', 'full_url']) {
        final u = m[k];
        if (u is String && u.trim().isNotEmpty) return u.trim();
      }
    }
    return null;
  }

  static String? _rowImageRaw(Map<String, dynamic> r) {
    const keys = ['productImage', 'imageURL', 'imageUrl', 'image_url', 'photo', 'thumbnail', 'thumb', 'product_image', 'variant_image', 'image_path'];
    for (final k in keys) {
      final p = _imagePathFromDynamic(r[k]);
      if (p != null) return p;
    }
    final top = _imagePathFromDynamic(r['image']);
    if (top != null) return top;
    final pm = _mapOrNull(r['product']);
    if (pm != null) {
      for (final k in keys) {
        final p = _imagePathFromDynamic(pm[k]);
        if (p != null) return p;
      }
      return _imagePathFromDynamic(pm['image']);
    }
    return null;
  }

  static Widget _lineThumbnail(Map<String, dynamic> row) {
    const box = 56.0;
    final placeholder = Container(
      width: box,
      height: box,
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: Alignment.center,
      child: const Icon(Icons.inventory_2_outlined, color: AppTheme.textSecondary),
    );
    final p = _resolvedProduct(row);
    if (p != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: box,
          height: box,
          child: ProductTile.buildProductImage(p, boxSize: box),
        ),
      );
    }
    final raw = _rowImageRaw(row);
    if (raw == null || raw.isEmpty) return placeholder;
    final file = File(raw);
    if (file.existsSync()) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.file(
          file,
          width: box,
          height: box,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => placeholder,
        ),
      );
    }
    final url = ProductImageUtils.resolveToUrl(raw);
    if (url.isEmpty) return placeholder;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AuthNetworkImage(
        url: url,
        width: box,
        height: box,
        fit: BoxFit.cover,
        placeholder: placeholder,
      ),
    );
  }

  /// API qatorda barcode bo'lmasa — katalogdan; oxirida qator SKU.
  static String _displayCodeLine(Map<String, dynamic> r) {
    final fromApi = _barcodeLike(r);
    if (fromApi.isNotEmpty) return fromApi;

    final p = _resolvedProduct(r);
    if (p != null) {
      final main = (p.barcode ?? '').trim();
      if (main.isNotEmpty) return main;
      final adds = p.additionalBarcodes;
      if (adds != null) {
        for (final a in adds) {
          final t = a.trim();
          if (t.isNotEmpty) return t;
        }
      }
      final skuP = (p.sku ?? '').trim();
      if (skuP.isNotEmpty) return skuP;
    }
    return _skuLike(r);
  }

  @override
  Widget build(BuildContext context) {
    final title = (row['title'] ?? row['product_title'] ?? row['productTitle'] ?? row['name'] ?? '—').toString();
    final qty = row['quantity'] ?? row['qty'] ?? '';
    final qtyStrRaw = qty.toString().trim();
    final unitRaw = (row['unit_name'] ?? row['unit'] ?? row['unitName'] ?? row['measure'] ?? '').toString().trim();

    String qtyStr = '—';
    if (qtyStrRaw.isNotEmpty) {
      // Agar API allaqachon birlik bilan yuborsa: "6.000 шт" / "1.250 kg"
      final parts = qtyStrRaw.split(RegExp(r'\s+'));
      if (parts.length >= 2) {
        final qPart = parts.first;
        final uPart = parts.sublist(1).join(' ');
        final qFmt = _fmtQtyByUnit(qPart, uPart);
        qtyStr = '$qFmt $uPart'.trim();
      } else if (unitRaw.isNotEmpty) {
        final qFmt = _fmtQtyByUnit(qtyStrRaw, unitRaw);
        qtyStr = '$qFmt $unitRaw'.trim();
      } else {
        // birlik topilmasa ham: 1.000 -> 1 (dona), 1.500 -> 1.500 (kg kabi)
        qtyStr = _fmtQtyByUnit(qtyStrRaw, '');
      }
    }

    final price = _amount(row['price'] ?? row['unit_price'] ?? 0);
    final sum = _amount(row['total'] ?? row['calculatedPrice'] ?? row['sum'] ?? (price * (int.tryParse(qtyStrRaw) ?? 1)));

    final codeLine = _displayCodeLine(row);
    final barcodeShown = codeLine.isNotEmpty ? codeLine : '—';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          _lineThumbnail(row),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  barcodeShown,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                  ),
                ),
                if (sum > 0) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${formatThousands(sum)} UZS',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                      height: 1.25,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          _QtyChip(text: qtyStr),
        ],
      ),
    );
  }
}

class _QtyChip extends StatelessWidget {
  final String text;
  const _QtyChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300, width: 2),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textSecondary),
      ),
    );
  }
}

Widget _kv(String k, String v, {Color? valueColor, bool isTotal = false}) {
  final keyStyle = TextStyle(fontSize: isTotal ? 16 : 14, fontWeight: isTotal ? FontWeight.w800 : FontWeight.w500);
  final valueStyle = TextStyle(
    fontSize: isTotal ? 18 : 14,
    fontWeight: isTotal ? FontWeight.w800 : FontWeight.w700,
    color: valueColor ?? (isTotal ? AppTheme.primary : AppTheme.textPrimary),
  );
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(k, style: keyStyle),
      Text(v, style: valueStyle),
    ],
  );
}

class _ParsedInvoiceRows {
  final List<Map<String, dynamic>> productRows;
  final List<Map<String, dynamic>> paymentRows;
  final int subTotal;
  final int tax;
  final int discount;
  final int total;
  _ParsedInvoiceRows(this.productRows, this.paymentRows, this.subTotal, this.tax, this.discount, this.total);
}
