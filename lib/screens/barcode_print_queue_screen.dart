import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_notify.dart';
import '../core/constants.dart';
import '../core/theme.dart';
import '../models/barcode_label_config.dart';
import '../models/barcode_print_queue_item.dart';
import '../models/product.dart';
import '../providers/products_provider.dart';
import '../services/barcode_label_printer.dart';
import '../services/barcode_label_settings.dart';
import '../utils/product_search.dart' as product_search;
import '../widgets/barcode_label_print_dialog.dart';
import '../widgets/product_tile.dart';
import 'scanner_screen.dart' show showCompactScanner;

/// Mobil: shtrix yorliqlarni savatga yig‘ib, oxirida bitta buyruqda chop etish.
class BarcodePrintQueueScreen extends StatefulWidget {
  const BarcodePrintQueueScreen({super.key});

  @override
  State<BarcodePrintQueueScreen> createState() => _BarcodePrintQueueScreenState();
}

class _BarcodePrintQueueScreenState extends State<BarcodePrintQueueScreen> {
  final _searchController = TextEditingController();
  final _queue = <BarcodePrintQueueItem>[];
  final _products = ProductsProvider.instance;
  String _query = '';
  bool _printing = false;
  BarcodeLabelConfig _defaults = BarcodeLabelConfig.defaults;

  @override
  void initState() {
    super.initState();
    _products.addListener(_onCatalog);
    unawaited(_products.warmFromCache());
    unawaited(_products.ensureFullCatalogLoaded());
    unawaited(_loadDefaults());
  }

  Future<void> _loadDefaults() async {
    final cfg = await BarcodeLabelSettings.loadDefaults();
    if (mounted) setState(() => _defaults = cfg);
  }

  void _onCatalog() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _products.removeListener(_onCatalog);
    _searchController.dispose();
    super.dispose();
  }

  List<Product> get _filtered {
    final q = _query.trim();
    if (q.isEmpty) return const [];
    return product_search.filterProductsByQuery(_products.items, q);
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _query = '');
  }

  Future<void> _addProduct(Product product) async {
    if (!product.hasBarcodeForPrint) {
      AppNotify.error(context, 'Mahsulotda shtrix kod yo‘q');
      return;
    }
    final existingIndex = _queue.indexWhere((e) => e.product.id == product.id);
    if (existingIndex >= 0) {
      _clearSearch();
      await _editItem(existingIndex);
      return;
    }
    setState(() {
      _queue.add(
        BarcodePrintQueueItem(
          product: product,
          config: _defaults.copyWith(copies: 1),
        ),
      );
    });
    _clearSearch();
  }

  Future<void> _onBarcode(String raw) async {
    final q = raw.trim();
    if (q.isEmpty) return;
    Product? hit;
    for (final p in _products.items) {
      if (p.matchesBarcode(q) || p.matchesCodeExact(q)) {
        hit = p;
        break;
      }
    }
    if (hit != null) {
      await _addProduct(hit);
      return;
    }
    _searchController.text = q;
    setState(() => _query = q);
  }

  void _openScanner() {
    showCompactScanner(context, onResult: (barcode) async {
      if (barcode == null || barcode.isEmpty || !mounted) return;
      await _onBarcode(barcode);
    });
  }

  Future<void> _editItem(int index) async {
    final item = _queue[index];
    final code = BarcodeLabelPrinter.resolvePrintCode(item.product);
    if (code == null) {
      AppNotify.error(context, 'Mahsulotda shtrix kod yo‘q');
      return;
    }
    final cfg = await showBarcodeLabelPrintDialog(
      context: context,
      product: item.product,
      barcode: code,
      initial: item.config,
      confirmLabel: Strings.saqlash,
    );
    if (cfg == null || !mounted) return;
    await BarcodeLabelSettings.save(cfg);
    setState(() {
      item.config = cfg;
      _defaults = cfg;
    });
  }

  void _removeItem(int index) {
    setState(() => _queue.removeAt(index));
  }

  Future<void> _printAll() async {
    if (_queue.isEmpty || _printing) return;
    setState(() => _printing = true);
    final result = await BarcodeLabelPrinter.printQueue(
      _queue.map((e) => (product: e.product, config: e.config)).toList(),
    );
    if (!mounted) return;
    setState(() => _printing = false);
    if (result.ok) {
      AppNotify.success(context, result.message);
      setState(_queue.clear);
    } else {
      AppNotify.error(context, result.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final showSearch = _query.trim().isNotEmpty;
    final body = Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _query = v),
                  onSubmitted: (q) {
                    final trimmed = q.trim();
                    if (trimmed.isEmpty) return;
                    unawaited(_onBarcode(trimmed));
                  },
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    hintText: Strings.artikulShtrixIsm,
                    prefixIcon: Icon(Icons.search_rounded, color: AppTheme.textSecondary),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  onTap: _openScanner,
                  borderRadius: BorderRadius.circular(10),
                  child: const Padding(
                    padding: EdgeInsets.all(11),
                    child: Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 22),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: showSearch
              ? _buildSearchResults()
              : _queue.isEmpty
                  ? _buildEmpty()
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _queue.length,
                      itemBuilder: (context, index) {
                        final item = _queue[index];
                        return _QueueTile(
                          item: item,
                          onTap: () => _editItem(index),
                          onRemove: () => _removeItem(index),
                        );
                      },
                    ),
        ),
        if (_queue.isNotEmpty && !showSearch)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _printing ? null : _printAll,
                  icon: _printing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.print_rounded),
                  label: Text(_printing ? 'Yuborilmoqda...' : 'Chop etish'),
                ),
              ),
            ),
          ),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text(Strings.barcodeChopEtish),
            if (_queue.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.cardBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_queue.length}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (_queue.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
              tooltip: 'Tozalash',
              onPressed: () => setState(_queue.clear),
            ),
        ],
      ),
      body: body,
    );
  }

  Widget _buildEmpty() {
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        SizedBox(height: MediaQuery.sizeOf(context).height * 0.12),
        Icon(
          Icons.barcode_reader,
          size: 80,
          color: AppTheme.textSecondary.withValues(alpha: 0.4),
        ),
        const SizedBox(height: 20),
        const Text(
          'Yorliq savati bo‘sh',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Mahsulot qidiring yoki shtrix-kodni skanerlang, keyin soni va shablonni tanlang',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: _openScanner,
          icon: const Icon(Icons.qr_code_scanner_rounded),
          label: const Text(Strings.skaner),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchResults() {
    final list = _filtered;
    if (list.isEmpty) {
      return const Center(
        child: Text(
          'Mahsulot topilmadi',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final p = list[index];
        return ProductTile(
          product: p,
          showMenu: false,
          onTap: () => _addProduct(p),
        );
      },
    );
  }
}

class _QueueTile extends StatelessWidget {
  const _QueueTile({
    required this.item,
    required this.onTap,
    required this.onRemove,
  });

  final BarcodePrintQueueItem item;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final code = BarcodeLabelPrinter.resolvePrintCode(item.product) ?? '—';
    final template = item.config.template == BarcodeLabelTemplate.shopName
        ? (item.config.shopName.trim().isEmpty
            ? 'Do‘kon nomi'
            : item.config.shopName.trim())
        : 'Standart';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppTheme.cardBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                clipBehavior: Clip.antiAlias,
                child: ProductTile.buildProductImage(item.product, boxSize: 52),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$code · $template · ${item.config.copies} ta',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: AppTheme.textSecondary),
                onPressed: onRemove,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
