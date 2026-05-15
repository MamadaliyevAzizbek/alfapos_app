import 'package:flutter/material.dart';
import '../core/app_notify.dart';
import '../core/constants.dart';
import '../core/theme.dart';
import '../core/input_formatters.dart';
import '../providers/clients_provider.dart';
import '../services/api_service.dart';
import 'api_chek_detail_screen.dart';
import '../widgets/ios_style_modals.dart';

/// Mijoz detali: ma'lumotlar, cheklar ro'yxati, qarz to'lash
class MijozDetailScreen extends StatefulWidget {
  final Client client;

  const MijozDetailScreen({super.key, required this.client});

  @override
  State<MijozDetailScreen> createState() => _MijozDetailScreenState();
}

class _MijozDetailScreenState extends State<MijozDetailScreen> {
  static const int _ordersPageSize = 20;
  late Client _client;
  num _totalDebt = 0;
  num _balance = 0;
  List<Map<String, dynamic>> _apiOrders = [];
  List<Map<String, dynamic>> _paymentTypes = [];
  bool _loading = true;
  bool _ordersLoadingMore = false;
  bool _ordersHasMore = true;
  int _ordersOffset = 0;

  @override
  void initState() {
    super.initState();
    _client = widget.client;
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    final idNum = int.tryParse(_client.id);
    if (idNum == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    // Avval hozirgi ma'lumotni darhol ko'rsatamiz
    _totalDebt = _client.dueAmount ?? 0;
    _balance = _client.balance ?? 0;

    final customerFuture = ContactsApi.getCustomer(idNum);
    final paymentTypesFuture = SalesApi.getPaymentTypes();

    try {
      final results = await Future.wait<dynamic>([
        customerFuture,
        paymentTypesFuture,
      ], eagerError: false);

      final customerRes = results[0] as Map<String, dynamic>;
      final ptRes = results[1] as Map<String, dynamic>;

      final customer = customerRes['customer'] as Map<String, dynamic>? ?? customerRes;
      final one = Client.fromApiJson(Map<String, dynamic>.from(customer));
      _client = one;
      _totalDebt = one.dueAmount ?? _totalDebt;
      _balance = one.balance ?? _balance;

      await _loadOrdersPage(reset: true);

      final data = ptRes['data'] ?? ptRes['payment_types'];
      if (data is List) {
        _paymentTypes = data
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .where((e) => (e['id'] ?? '').toString().isNotEmpty)
            .toList();
      }
    } catch (_) {
      // qisman xato bo'lsa ham ekran qolgan ma'lumot bilan ishlaydi
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadOrdersPage({required bool reset}) async {
    final idNum = int.tryParse(_client.id);
    if (idNum == null) return;
    if (!reset && (_ordersLoadingMore || !_ordersHasMore)) return;

    if (reset) {
      _ordersOffset = 0;
      _ordersHasMore = true;
      _apiOrders = [];
    } else {
      if (mounted) setState(() => _ordersLoadingMore = true);
    }
    try {
      final res = await ContactsApi.getCustomerOrders(idNum, body: {
        'rowLimit': _ordersPageSize,
        'rowOffset': _ordersOffset,
        'columnKey': 'id',
        'columnSortedBy': 'desc',
      });

      if (_ordersOffset == 0) {
        final apiTotalDebt = res['totalDebt'] ?? res['total_debt'] ?? res['due_amount'];
        if (apiTotalDebt != null) {
          final n = parseAmountFromApi(apiTotalDebt);
          if (n >= 0) _totalDebt = n;
        }
      }

      final raw = _extractOrdersList(res);
      final list = raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e as Map))
          .where((o) => !_isSummaryRow(o))
          .toList();
      final merged = _deduplicateOrdersById([..._apiOrders, ...list]);
      _apiOrders = merged;

      final fetchedCount = list.length;
      _ordersOffset += fetchedCount;
      _ordersHasMore = fetchedCount >= _ordersPageSize;

      if (_totalDebt == 0 && _apiOrders.isNotEmpty) {
        _totalDebt = _apiOrders.fold<num>(0, (s, o) => s + parseAmountFromApi(o['due_amount'] ?? 0));
      }
    } catch (_) {
      if (reset) _apiOrders = [];
    } finally {
      if (!reset && mounted) setState(() => _ordersLoadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _client;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FF),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(c.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            onPressed: () => _showEditDialog(context),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0D6EFD), Color(0xFF4DA3FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0D6EFD).withValues(alpha: 0.28),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Mijoz dashboard",
                      style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      c.name,
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
                    if (c.phone != null && c.phone!.isNotEmpty)
                      Row(
                        children: [
                          const Icon(Icons.phone_rounded, color: Colors.white, size: 16),
                          const SizedBox(width: 6),
                          Text(c.phone!, style: const TextStyle(color: Colors.white, fontSize: 13)),
                        ],
                      ),
                    if (c.address != null && c.address!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.location_on_rounded, color: Colors.white, size: 16),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(c.address!, style: const TextStyle(color: Colors.white, fontSize: 13)),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _metricCard(
                      title: "Jami qarz",
                      value: _formatAmount(_totalDebt),
                      valueColor: _totalDebt > 0 ? Colors.red.shade700 : const Color(0xFF2D5B9A),
                      icon: Icons.receipt_long_rounded,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _metricCard(
                      title: "Balans",
                      value: _formatAmount(_balance),
                      valueColor: _balance > 0
                          ? Colors.green.shade700
                          : (_balance < 0 ? Colors.red.shade700 : const Color(0xFF2D5B9A)),
                      icon: Icons.account_balance_wallet_rounded,
                    ),
                  ),
                ],
              ),
              if (_totalDebt > 0) ...[
                const SizedBox(height: 12),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF0D6EFD), Color(0xFF4DA3FF)]),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _showPayDebtDialog(context),
                      icon: const Icon(Icons.payment_rounded, size: 22),
                      label: const Text(Strings.qarzTolash),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              const Text("Cheklar", style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF1B3A66))),
              const SizedBox(height: 10),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
                )
              else if (_apiOrders.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: Text("Bu mijoz uchun chek topilmadi", style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
                  ),
                )
              else
                ...[
                  ..._apiOrders.map(
                    (o) {
                      final invoiceId = (o['invoice_id'] ?? o['invoiceId'] ?? '').toString();
                      final totalInt = parseAmountFromApi(o['total'] ?? o['grand_total'] ?? o['total_amount'] ?? 0);
                      final total = formatThousands(totalInt);
                      final due = parseAmountFromApi(o['due_amount'] ?? 0);
                      final dateStr = (o['date'] ?? o['created_at'] ?? '').toString();
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFFE6F1FF),
                            child: Icon(Icons.receipt_long_rounded, color: Color(0xFF0D6EFD)),
                          ),
                          title: Text(
                            invoiceId.isNotEmpty ? "Chek #$invoiceId" : "Chek",
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            [if (dateStr.isNotEmpty) dateStr, total].join(" — "),
                          ),
                          trailing: due > 0
                              ? Text(
                                  "Qoldiq: ${formatThousands(due)}",
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.red),
                                )
                              : const Icon(Icons.chevron_right_rounded, color: Color(0xFF5C8DFF)),
                          onTap: () => _openApiChek(context, o),
                        ),
                      );
                    },
                  ),
                  if (_ordersHasMore)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 8),
                      child: Center(
                        child: OutlinedButton.icon(
                          onPressed: _ordersLoadingMore ? null : () => _loadOrdersPage(reset: false).then((_) {
                            if (mounted) setState(() {});
                          }),
                          icon: _ordersLoadingMore
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.expand_more_rounded),
                          label: Text(_ordersLoadingMore ? "Yuklanmoqda..." : "Yana yuklash"),
                        ),
                      ),
                    ),
                ],
            ],
          ),
        ),
      ),
    );
  }

  /// API chek (mijoz orders) ustiga bosilganda: invoice-details yuklab, ApiChekDetailScreen ochish.
  Future<void> _openApiChek(BuildContext context, Map<String, dynamic> order) async {
    final orderId = getOrderIdFromSale(order);
    if (orderId == null) {
      if (context.mounted) {
        AppNotify.warning(context, "Chek ID aniqlanmadi");
      }
      return;
    }
    Map<String, dynamic>? detail;
    String? loadError;
    try {
      detail = await ReportsApi.getInvoiceDetails(orderId);
    } catch (e) {
      loadError = e.toString();
      try {
        final now = DateTime.now();
        final to = now.toIso8601String().substring(0, 10);
        final from = now.subtract(const Duration(days: 30)).toIso8601String().substring(0, 10);
        final invoice = (order['invoice_id'] ?? order['order_id'] ?? order['id'] ?? '').toString();
        detail = await ReportsApi.getSalesAllDetails(
          body: ReportsApi.salesAllDetailsBody(
            from: from,
            to: to,
            rowLimit: 200,
            rowOffset: 0,
            searchValue: invoice,
          ),
        );
      } catch (_) {}
    }
    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ApiChekDetailScreen(
          sale: order,
          invoiceDetail: detail ?? {},
          invoiceLoadError: loadError,
        ),
      ),
    ).then((_) => _load());
  }

  /// API javobidan buyurtmalar ro'yxati — datarows, data.datarows, orders va h.k.
  static List<dynamic> _extractOrdersList(Map<String, dynamic> res) {
    dynamic raw = res['datarows'] ?? res['orders'] ?? res['data'];
    if (raw is List<dynamic>) return raw;
    if (raw is Map<String, dynamic>) {
      final inner = raw['datarows'] ?? raw['orders'] ?? raw['data'] ?? raw['items'];
      if (inner is List<dynamic>) return inner;
    }
    return [];
  }

  /// Jadval oxiridagi umumiy qarz qatori — chek emas, ko'rsatilmasin (API dagi "Umumiy" / "Jami" qatori)
  static bool _isSummaryRow(Map<String, dynamic> o) {
    final title = (o['title'] ?? o['name'] ?? o['label'] ?? o['type'] ?? '').toString().trim().toLowerCase();
    if (title.isNotEmpty) {
      if (title == 'umumiy' || title == 'total' || title == 'jami' || title == 'general total' || title == 'overall') return true;
      if (title.contains('umumiy') || title.contains('jami') || title == 'grand total') return true;
    }
    if (o['is_total'] == true || o['is_summary'] == true || o['row_type'] == 'total') return true;
    final invoiceId = (o['invoice_id'] ?? o['invoiceId'] ?? '').toString().trim();
    final id = o['id'];
    if (invoiceId.isEmpty && (id == null || id == 0 || id == '0')) return true;
    // Chek raqami (POS...) bo'lmagan qator — odatda jadval oxiridagi umumiy qarz qatori
    if (invoiceId.isEmpty) return true;
    return false;
  }

  /// Bir xil chek (id yoki invoice_id) ikki marta kelmasin — API dublikat qaytarsa bitta ko'rsatamiz
  static List<Map<String, dynamic>> _deduplicateOrdersById(List<Map<String, dynamic>> list) {
    final seen = <String>{};
    return list.where((o) {
      final id = (o['id'] ?? o['order_id'] ?? o['invoice_id'] ?? '').toString();
      final key = id.isEmpty ? null : id;
      if (key == null || seen.contains(key)) return false;
      seen.add(key);
      return true;
    }).toList();
  }

  /// API dagi ko'rinishida: butun "4 000.00", kasr "2 000.50" (dastur hech narsa qo'shmasin — faqat raqam)
  static String _formatAmount(num n) {
    if (n == n.round()) return '${formatThousands(n.round())}.00';
    return n.toString();
  }

  Widget _metricCard({
    required String title,
    required String value,
    required Color valueColor,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD6E8FF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 17, color: const Color(0xFF0D6EFD)),
              const SizedBox(width: 6),
              Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: valueColor),
          ),
        ],
      ),
    );
  }

  Future<void> _showPayDebtDialog(BuildContext context) async {
    final controller = TextEditingController();
    int? selectedPaymentTypeId;
    if (_paymentTypes.isNotEmpty) {
      final raw = _paymentTypes.first['id'];
      selectedPaymentTypeId = raw is int ? raw : int.tryParse(raw.toString());
    }
    final result = await IosStyleModals.showSheet<Map<String, int>>(
      context: context,
      isScrollControlled: true,
      showGrabber: true,
      child: Builder(
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDialogState) => SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + MediaQuery.viewInsetsOf(ctx).bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(Strings.qarzTolash, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                const SizedBox(height: 10),
                Text("Jami qarz: ${_formatAmount(_totalDebt)}", style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  inputFormatters: [ThousandsInputFormatter()],
                  decoration: InputDecoration(
                    labelText: "To'lov summasi",
                    suffixText: 'UZS',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                if (_paymentTypes.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: selectedPaymentTypeId,
                    decoration: InputDecoration(
                      labelText: "To'lov turi",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: _paymentTypes.map((e) {
                      final raw = e['id'];
                      final id = raw is int ? raw : int.tryParse(raw.toString());
                      if (id == null) return null;
                      final name = (e['name'] ?? e['title'] ?? 'Payment $id').toString();
                      return DropdownMenuItem<int>(value: id, child: Text(name));
                    }).whereType<DropdownMenuItem<int>>().toList(),
                    onChanged: (v) => setDialogState(() => selectedPaymentTypeId = v),
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text(Strings.bekorQilish),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          final amount = parseFormattedSum(controller.text) ?? 0;
                          if (amount > 0 && amount <= _totalDebt.round()) {
                            Navigator.pop(ctx, {
                              'amount': amount,
                              if (selectedPaymentTypeId != null) 'paymentTypeId': selectedPaymentTypeId!,
                            });
                          }
                        },
                        child: const Text("To'lash"),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final amount = result?['amount'] ?? 0;
    final paymentTypeId = result?['paymentTypeId'];
    if (amount <= 0 || !mounted) return;
    try {
      await ClientsProvider.instance.addDebt(
        _client.id,
        -amount,
        'tolov_${DateTime.now().millisecondsSinceEpoch}',
        paymentTypeId: paymentTypeId,
      );
      if (!mounted) return;
      await _load();
      if (mounted) AppNotify.success(context, "${formatThousands(amount)} qarz to'landi");
    } catch (e) {
      if (mounted) AppNotify.error(context, "Xatolik: $e");
    }
  }

  Future<void> _showEditDialog(BuildContext context) async {
    final c = _client;
    final nameController = TextEditingController(text: c.name);
    final phoneController = TextEditingController(text: c.phone ?? '');
    final addressController = TextEditingController(text: c.address ?? '');
    final result = await IosStyleModals.showPopupPanel<bool>(
      context: context,
      child: Builder(
        builder: (ctx) => ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.75),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                child: Text(
                  Strings.mijozMalumotlari,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(labelText: "Ism", border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: phoneController,
                        decoration: const InputDecoration(labelText: "Telefon", border: OutlineInputBorder()),
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: addressController,
                        decoration: const InputDecoration(labelText: Strings.yashashJoyi, border: OutlineInputBorder()),
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text(Strings.bekorQilish),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          final name = nameController.text.trim();
                          if (name.isEmpty) return;
                          final updated = Client(
                            id: c.id,
                            name: name,
                            email: c.email,
                            phone: phoneController.text.trim().isEmpty ? null : phoneController.text.trim(),
                            address: addressController.text.trim().isEmpty ? null : addressController.text.trim(),
                          );
                          ClientsProvider.instance.updateClient(updated);
                          _client = updated;
                          Navigator.pop(ctx, true);
                        },
                        child: const Text(Strings.saqlash),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (result == true && mounted) setState(() {});
  }
}
