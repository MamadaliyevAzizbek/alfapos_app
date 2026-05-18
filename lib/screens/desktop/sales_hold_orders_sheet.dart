import 'package:flutter/material.dart';
import '../../core/app_notify.dart';
import '../../core/input_formatters.dart';
import '../../core/theme.dart';
import '../../providers/products_provider.dart';
import '../../providers/sales_session_provider.dart';
import '../../utils/hold_order_cart.dart';
import '../../utils/hold_orders_response.dart';
import '../../utils/platform_layout.dart';

/// Saqlangan (pauza) buyurtmalar — «Buyurtmani saqlash ro'yxati».
class SalesHoldOrdersSheet extends StatefulWidget {
  final Future<void> Function(HoldOrderResume resume) onResume;
  final VoidCallback? onListChanged;

  const SalesHoldOrdersSheet({
    super.key,
    required this.onResume,
    this.onListChanged,
  });

  static Future<void> show(
    BuildContext context, {
    required Future<void> Function(HoldOrderResume resume) onResume,
    VoidCallback? onListChanged,
  }) {
    final sheet = SalesHoldOrdersSheet(
      onResume: onResume,
      onListChanged: onListChanged,
    );
    if (isDesktopPosLayout) {
      return showDialog<void>(
        context: context,
        barrierColor: Colors.black38,
        builder: (_) => sheet,
      );
    }
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => sheet,
      ),
    );
  }

  @override
  State<SalesHoldOrdersSheet> createState() => _SalesHoldOrdersSheetState();
}

class _SalesHoldOrdersSheetState extends State<SalesHoldOrdersSheet> {
  List<Map<String, dynamic>> _holds = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await SalesSessionProvider.instance.fetchHoldOrders(force: true);
    if (mounted) {
      setState(() {
        _holds = list;
        _loading = false;
      });
      widget.onListChanged?.call();
    }
  }

  String _customerName(Map<String, dynamic> h, int index) {
    final c = h['customer'];
    if (c is Map) {
      final first = c['first_name'] ?? '';
      final last = c['last_name'] ?? '';
      final n = '$first $last'.trim();
      if (n.isNotEmpty) return '$index. $n';
      final name = (c['name'] ?? c['full_name'] ?? '').toString().trim();
      if (name.isNotEmpty) return '$index. $name';
    }
    return '$index. Mijoz';
  }

  String _customerTypeLabel(Map<String, dynamic> h) {
    final c = h['customer'];
    if (c is Map) {
      final t = (c['customer_type'] ?? c['type'] ?? c['customer_group'] ?? '').toString();
      if (t.isNotEmpty) return t;
    }
    return 'Customer';
  }

  int _total(Map<String, dynamic> h) => HoldOrdersResponse.displayTotal(h);

  String? _cashRegisterLabel(Map<String, dynamic> h) {
    return HoldOrdersResponse.resolveCashRegisterLabel(
      h,
      registers: SalesSessionProvider.instance.cashRegisters,
    );
  }

  Widget _cashRegisterBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFE8EAF6),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color(0xFF3949AB),
        ),
      ),
    );
  }

  String? _orderLabel(Map<String, dynamic> h) {
    final id = HoldOrdersResponse.resolveOrderId(h);
    if (id == null || id <= 0) return null;
    final inv = HoldOrdersResponse.resolveInvoiceId(h);
    if (inv != null && inv.isNotEmpty) return inv.startsWith('POS') ? inv : 'POS$inv';
    return '#$id';
  }

  String _dateTime(Map<String, dynamic> h) {
    final raw = h['created_at'] ?? h['date'] ?? h['time'] ?? h['updated_at'];
    if (raw == null) return '';
    final s = raw.toString();
    if (s.length >= 16) return s.substring(0, 16).replaceFirst('T', ' ');
    return s;
  }

  String _dateTimeCompact(Map<String, dynamic> h) {
    final full = _dateTime(h);
    if (full.isEmpty) return '';
    final parts = full.split(' ');
    if (parts.length == 2) {
      final d = parts[0];
      final dayMonth = d.length >= 10 ? '${d.substring(8, 10)}.${d.substring(5, 7)}' : d;
      return '$dayMonth ${parts[1].substring(0, 5)}';
    }
    return full.length > 11 ? full.substring(0, 11) : full;
  }

  Widget _buildHoldOrderTile(Map<String, dynamic> h, int idx) {
    if (isDesktopPosLayout) return _buildHoldOrderTileDesktop(h, idx);
    return _buildHoldOrderTileMobile(h, idx);
  }

  String _mobileRowTitle(Map<String, dynamic> h, int idx) {
    final name = _customerName(h, idx);
    final order = _orderLabel(h);
    final kassa = _cashRegisterLabel(h);
    final parts = <String>[name];
    if (order != null && order.isNotEmpty) parts.add(order);
    if (kassa != null && kassa.isNotEmpty) parts.add(kassa);
    return parts.join(' · ');
  }

  Widget _buildHoldOrderTileMobile(Map<String, dynamic> h, int idx) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppTheme.divider),
      ),
      child: InkWell(
        onTap: () => _resume(h),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _mobileRowTitle(h, idx),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                formatThousands(_total(h)),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2E7D32),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                _dateTimeCompact(h),
                style: const TextStyle(fontSize: 10, color: Color(0xFF78909C)),
              ),
              IconButton(
                tooltip: 'O\'chirish',
                onPressed: () => _delete(h),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFE53935),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHoldOrderTileDesktop(Map<String, dynamic> h, int idx) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppTheme.divider),
      ),
      child: InkWell(
        onTap: () => _resume(h),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        _customerName(h, idx),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0F2F1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _customerTypeLabel(h),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF00897B),
                        ),
                      ),
                    ),
                    if (_orderLabel(h) != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        _orderLabel(h)!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF78909C),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    if (_cashRegisterLabel(h) != null) ...[
                      const SizedBox(width: 8),
                      _cashRegisterBadge(_cashRegisterLabel(h)!),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  formatThousands(_total(h)),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2E7D32),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                tooltip: 'Chop etish',
                onPressed: () => AppNotify.info(context, 'Chop etish tez orada'),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFE3F2FD),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                icon: const Icon(Icons.print_rounded, color: Color(0xFF1565C0), size: 22),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFCE4EC),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _dateTime(h),
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF546E7A),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      tooltip: 'O\'chirish',
                      onPressed: () => _delete(h),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFFE53935),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      ),
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 18),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _delete(Map<String, dynamic> h) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('O\'chirish'),
        content: const Text('Ushbu saqlangan buyurtmani o\'chirasizmi?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Yo\'q')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Ha'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await SalesSessionProvider.instance.cancelHoldOrder(h);
      if (mounted) {
        AppNotify.success(context, 'O\'chirildi');
        await _load();
      }
    } catch (e) {
      if (mounted) AppNotify.error(context, '$e');
    }
  }

  Future<void> _resume(Map<String, dynamic> h) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: AppTheme.primary),
                SizedBox(height: 16),
                Text('Savat yuklanmoqda...'),
              ],
            ),
          ),
        ),
      ),
    );
    HoldOrderResume? resume;
    Object? loadError;
    try {
      if (!ProductsProvider.instance.isLoaded) {
        await ProductsProvider.instance.loadFromApi();
      }
      resume = await HoldOrderCart.fetchResume(h);
    } catch (e) {
      loadError = e;
    }
    if (!mounted) return;
    Navigator.pop(context);
    if (resume == null || resume.items.isEmpty) {
      final oid = h['orderID'] ?? h['order_id'] ?? h['id'];
      final detail = loadError != null ? ' ($loadError)' : '';
      AppNotify.info(context, 'Savat o\'qilmadi${oid != null ? ' (buyurtma $oid)' : ''}$detail');
      return;
    }
    Navigator.pop(context);
    await widget.onResume(resume);
  }

  Widget _buildListBody() {
    return _loading
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                  : _holds.isEmpty
                      ? const Center(
                          child: Text(
                            'Saqlangan buyurtma yo\'q',
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 15),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _holds.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, i) => _buildHoldOrderTile(_holds[i], i + 1),
                        );
  }

  @override
  Widget build(BuildContext context) {
    if (isDesktopPosLayout) {
      return Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: SizedBox(
          width: 720,
          height: 420,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        "Buyurtmani saqlash ro'yxati",
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(child: _buildListBody()),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Saqlangan buyurtmalar"),
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _buildListBody(),
    );
  }
}
