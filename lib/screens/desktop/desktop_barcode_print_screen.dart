import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_notify.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/barcode_label_config.dart';
import '../../models/barcode_print_queue_item.dart';
import '../../models/product.dart';
import '../../providers/products_provider.dart';
import '../../services/barcode_label_printer.dart';
import '../../services/barcode_label_settings.dart';
import '../../utils/product_search.dart' as product_search;
import '../../widgets/barcode_label_print_dialog.dart';
import '../../widgets/product_tile.dart';

/// Desktop: shtrix kod chop etish — 0 dan desktop UI.
class DesktopBarcodePrintScreen extends StatefulWidget {
  const DesktopBarcodePrintScreen({super.key});

  @override
  State<DesktopBarcodePrintScreen> createState() => _DesktopBarcodePrintScreenState();
}

class _DesktopBarcodePrintScreenState extends State<DesktopBarcodePrintScreen> {
  final _searchController = TextEditingController();
  final _queue = <BarcodePrintQueueItem>[];
  final _products = ProductsProvider.instance;
  String _query = '';
  bool _printing = false;
  BarcodeLabelConfig _defaults = BarcodeLabelConfig.defaults;

  static const _thStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    color: AppTheme.textSecondary,
    letterSpacing: 0.3,
  );

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

  List<Product> get _searchResults {
    final q = _query.trim();
    if (q.isEmpty) return const [];
    return product_search
        .filterProductsByQuery(_products.items, q)
        .where((p) => p.hasBarcodeForPrint)
        .toList();
  }

  int get _totalCopies =>
      _queue.fold(0, (sum, e) => sum + e.config.copies);

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

  String _templateLabel(BarcodeLabelConfig cfg) {
    if (cfg.template == BarcodeLabelTemplate.shopName) {
      final name = cfg.shopName.trim();
      return name.isEmpty ? 'Do‘kon nomi bilan' : name;
    }
    return 'Narx bilan';
  }

  @override
  Widget build(BuildContext context) {
    final searching = _query.trim().isNotEmpty;
    final results = _searchResults;

    return ColoredBox(
      color: const Color(0xFFF8FAFC),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Column(
          children: [
            _header(),
            const SizedBox(height: 14),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 5,
                    child: _panel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _searchField(),
                          const SizedBox(height: 12),
                          Expanded(
                            child: searching
                                ? _buildSearchPane(results)
                                : _buildQueueTable(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  SizedBox(
                    width: 280,
                    child: _panel(child: _sideSummary()),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8EDF5)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppTheme.primaryLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.barcode_reader, color: AppTheme.primary),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    Strings.barcodeChopEtish,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Mahsulotlarni qidirib yig‘ing, sozlang va bitta buyruqda chop eting',
                    style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
            if (_queue.isNotEmpty) ...[
              OutlinedButton.icon(
                onPressed: _printing ? null : () => setState(_queue.clear),
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: const Text('Tozalash'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.textPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                  side: const BorderSide(color: AppTheme.divider),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(width: 10),
            ],
            FilledButton.icon(
              onPressed: (_queue.isEmpty || _printing) ? null : _printAll,
              icon: _printing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.print_rounded, size: 20),
              label: Text(
                _printing ? 'Yuborilmoqda...' : 'Chop etish',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppTheme.primary.withValues(alpha: 0.45),
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _panel({required Widget child}) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8EDF5)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: child,
      ),
    );
  }

  Widget _searchField() {
    return TextField(
      controller: _searchController,
      onChanged: (v) => setState(() => _query = v),
      style: const TextStyle(fontSize: 15),
      decoration: InputDecoration(
        hintText: 'Nom yoki shtrix kod bo‘yicha qidirish',
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textSecondary),
        suffixIcon: _query.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close_rounded, color: AppTheme.textSecondary),
                onPressed: _clearSearch,
              ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.primary, width: 1.4),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  Widget _sideSummary() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Yig‘indi',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        _summaryRow('Mahsulotlar', '${_queue.length}'),
        const SizedBox(height: 10),
        _summaryRow('Jami yorliqlar', '$_totalCopies'),
        const Spacer(),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.divider),
          ),
          child: const Text(
            'Qidiruvdan mahsulotni tanlang. Qatordan ustiga bosib soni va shablonni sozlang. Oxirida «Chop etish»ni bosing.',
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: AppTheme.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _summaryRow(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchPane(List<Product> results) {
    if (results.isEmpty) {
      return const Center(
        child: Text(
          'Shtrix kodli mahsulot topilmadi',
          style: TextStyle(fontSize: 15, color: AppTheme.textSecondary),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Qidiruv natijalari (${results.length})',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: ListView.separated(
            itemCount: results.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final p = results[index];
              final code = BarcodeLabelPrinter.resolvePrintCode(p) ?? '—';
              return InkWell(
                onTap: () => _addProduct(p),
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: SizedBox(
                          width: 56,
                          height: 56,
                          child: ProductTile.buildProductImageCover(
                            p,
                            width: 56,
                            height: 56,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              code,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.add_circle_outline_rounded, color: AppTheme.primary),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildQueueTable() {
    if (_queue.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.qr_code_2_rounded,
              size: 72,
              color: AppTheme.textSecondary.withValues(alpha: 0.35),
            ),
            const SizedBox(height: 16),
            const Text(
              'Yorliqlar ro‘yxati bo‘sh',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Yuqoridagi qidiruvdan mahsulot qo‘shing',
              style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: const BoxDecoration(
            color: Color(0xFFF8FAFC),
            borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            border: Border(bottom: BorderSide(color: AppTheme.divider)),
          ),
          child: const Row(
            children: [
              SizedBox(width: 72, child: Text('RASM', style: _thStyle)),
              Expanded(flex: 4, child: Text('MAHSULOT', style: _thStyle)),
              Expanded(flex: 3, child: Text('SHTRIX KOD', style: _thStyle)),
              Expanded(flex: 3, child: Text('SHABLON', style: _thStyle)),
              Expanded(
                flex: 2,
                child: Text('SONI', style: _thStyle, textAlign: TextAlign.center),
              ),
              SizedBox(
                width: 56,
                child: Text('AMAL', style: _thStyle, textAlign: TextAlign.center),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _queue.length,
            itemBuilder: (context, index) {
              final item = _queue[index];
              final code = BarcodeLabelPrinter.resolvePrintCode(item.product) ?? '—';
              final bg = index.isEven ? Colors.white : const Color(0xFFFAFBFC);
              return Material(
                color: bg,
                child: InkWell(
                  onTap: () => _editItem(index),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: AppTheme.divider)),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 72,
                          height: 56,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: SizedBox(
                                width: 56,
                                height: 56,
                                child: ProductTile.buildProductImageCover(
                                  item.product,
                                  width: 56,
                                  height: 56,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 4,
                          child: Text(
                            item.product.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(
                            code,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(
                            _templateLabel(item.config),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            '${item.config.copies}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 56,
                          child: PopupMenuButton<String>(
                            tooltip: 'Amallar',
                            color: Colors.white,
                            elevation: 8,
                            surfaceTintColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(color: AppTheme.divider),
                            ),
                            onSelected: (value) {
                              if (value == 'edit') _editItem(index);
                              if (value == 'remove') _removeItem(index);
                            },
                            itemBuilder: (context) => const [
                              PopupMenuItem(value: 'edit', child: Text('Sozlash')),
                              PopupMenuItem(value: 'remove', child: Text('Olib tashlash')),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
