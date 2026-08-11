import 'package:flutter/material.dart';
import '../core/input_formatters.dart';
import '../services/reports_repository.dart';
import '../widgets/throttled_refresh_indicator.dart';

class KirimTarixScreen extends StatefulWidget {
  const KirimTarixScreen({super.key});

  @override
  State<KirimTarixScreen> createState() => _KirimTarixScreenState();
}

class _KirimTarixScreenState extends State<KirimTarixScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _rows = [];
  late DateTime _from;
  late DateTime _to;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _to = now;
    _from = now.subtract(const Duration(days: 30));
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final from = '${_from.year}-${_from.month.toString().padLeft(2, '0')}-${_from.day.toString().padLeft(2, '0')}';
      final to = '${_to.year}-${_to.month.toString().padLeft(2, '0')}-${_to.day.toString().padLeft(2, '0')}';
      final res = await ReportsRepository.instance.getReceivingReport(
        body: ReportsRepository.receivingListBody(from: from, to: to, rowLimit: 100),
      );
      _rows = ReportsRepository.extractRows(res);
    } catch (e) {
      _error = e.toString();
      _rows = [];
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kirim tarixi')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: _from,
                        firstDate: DateTime(2020),
                        lastDate: _to,
                      );
                      if (d != null) {
                        setState(() => _from = d);
                        _load();
                      }
                    },
                    child: Text('Dan: ${_from.day}.${_from.month}.${_from.year}'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: _to,
                        firstDate: _from,
                        lastDate: DateTime.now(),
                      );
                      if (d != null) {
                        setState(() => _to = d);
                        _load();
                      }
                    },
                    child: Text('Gacha: ${_to.day}.${_to.month}.${_to.year}'),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!, textAlign: TextAlign.center))
                    : _rows.isEmpty
                        ? const Center(child: Text('Kirimlar topilmadi'))
                        : ThrottledRefreshIndicator(
                            onRefresh: _load,
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: _rows.length,
                              itemBuilder: (context, i) {
                                final r = _rows[i];
                                final inv = (r['invoice_id'] ?? r['invoiceId'] ?? r['id'] ?? '').toString();
                                final total = parseAmountFromApi(r['total'] ?? r['grand_total'] ?? 0);
                                final date = (r['date'] ?? r['created_at'] ?? '').toString();
                                final supplier = (r['supplier'] ?? r['customer'] ?? r['supplier_name'] ?? '').toString();
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: ListTile(
                                    title: Text(inv.isNotEmpty ? inv : 'Kirim'),
                                    subtitle: Text([if (date.isNotEmpty) date, if (supplier.isNotEmpty) supplier].join(' · ')),
                                    trailing: Text(
                                      formatThousands(total),
                                      style: const TextStyle(fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}
