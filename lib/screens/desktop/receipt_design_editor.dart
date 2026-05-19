import 'dart:io';

import 'package:flutter/material.dart';
import '../../core/app_notify.dart';
import '../../core/theme.dart';
import '../../models/receipt_design_config.dart';
import '../../services/printer_settings.dart';
import '../../services/receipt_design_storage.dart';
import '../../services/thermal_receipt_printer.dart';
import '../../utils/receipt_sample_data.dart';
import '../../utils/thermal_receipt_capture.dart';
import '../../widgets/receipt_widget.dart';

/// Sozlamalar: chek dizayni (2 ta shablon + custom).
class ReceiptDesignEditor extends StatefulWidget {
  const ReceiptDesignEditor({super.key});

  @override
  State<ReceiptDesignEditor> createState() => _ReceiptDesignEditorState();
}

class _ReceiptDesignEditorState extends State<ReceiptDesignEditor> {
  ReceiptDesignConfig _config = ReceiptDesignConfig.presetTableColumns();
  final _storeController = TextEditingController();
  final _footerTextController = TextEditingController();
  final _headerExtraController = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  bool _previewPrinting = false;
  bool _pickingImage = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _storeController.dispose();
    _footerTextController.dispose();
    _headerExtraController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final c = await ReceiptDesignStorage.load();
    if (!mounted) return;
    setState(() {
      _config = c;
      _storeController.text = c.storeName;
      _footerTextController.text = c.footerText;
      _headerExtraController.text = c.headerExtraText;
      _loading = false;
    });
  }

  Future<void> _applyTemplate(ReceiptTemplateKind kind, String label) async {
    setState(() {
      switch (kind) {
        case ReceiptTemplateKind.numberedList:
          _config = ReceiptDesignConfig.presetNumberedList().copyWith(
            storeName: _storeController.text,
            footerText: _footerTextController.text,
            headerExtraText: _headerExtraController.text,
            logoPath: _config.logoPath,
            footerImagePath: _config.footerImagePath,
            showSellerPhone: _config.showSellerPhone,
            showClient: _config.showClient,
            showDescription: _config.showDescription,
            showBarcode: _config.showBarcode,
            fontScale: _config.fontScale,
          );
          break;
        case ReceiptTemplateKind.tableColumns:
          _config = ReceiptDesignConfig.presetTableColumns().copyWith(
            storeName: _storeController.text,
            footerText: _footerTextController.text,
            headerExtraText: _headerExtraController.text,
            logoPath: _config.logoPath,
            footerImagePath: _config.footerImagePath,
            showSellerPhone: _config.showSellerPhone,
            showClient: _config.showClient,
            showDescription: _config.showDescription,
            showBarcode: _config.showBarcode,
            fontScale: _config.fontScale,
          );
          break;
        case ReceiptTemplateKind.custom:
          _config = _mergedConfig().copyWith(template: ReceiptTemplateKind.custom);
          break;
      }
    });
    await ReceiptDesignStorage.save(_mergedConfig());
    if (!mounted) return;
    AppNotify.success(context, 'Shablon: $label');
  }

  Future<void> _persistSilently() async {
    await ReceiptDesignStorage.save(_mergedConfig());
  }

  ReceiptDesignConfig _mergedConfig() {
    return _config.copyWith(
      storeName: _storeController.text.trim(),
      footerText: _footerTextController.text,
      headerExtraText: _headerExtraController.text,
    );
  }

  String _previewStoreName() {
    return _mergedConfig().resolveStoreName(
      branchName: 'Alfa market',
      cashRegisterName: '',
    );
  }

  ReceiptWidget _previewWidget() {
    final cfg = _mergedConfig();
    return ReceiptWidget(
      design: cfg,
      storeName: _previewStoreName(),
      dateTime: DateTime(2026, 5, 19, 19, 59, 38),
      receiptNumber: ReceiptSampleData.receiptNumber,
      sellerName: ReceiptSampleData.sellerName,
      sellerPhone: ReceiptSampleData.sellerPhone,
      productRows: ReceiptSampleData.products,
      paymentRows: ReceiptSampleData.payments,
      discount: ReceiptSampleData.discount,
      totalSum: ReceiptSampleData.total,
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await ReceiptDesignStorage.save(_mergedConfig());
    if (!mounted) return;
    setState(() => _saving = false);
    AppNotify.success(context, 'Chek dizayni saqlandi');
  }

  Future<void> _pickLogo() async {
    if (_pickingImage) return;
    setState(() => _pickingImage = true);
    final result = await ReceiptDesignStorage.pickAndSaveLogo();
    if (!mounted) return;
    setState(() => _pickingImage = false);
    if (result.cancelled) return;
    if (!result.ok) {
      AppNotify.error(context, result.error ?? 'Logo tanlanmadi');
      return;
    }
    setState(() => _config = _mergedConfig().copyWith(logoPath: result.path));
    await _persistSilently();
    if (!mounted) return;
    AppNotify.success(context, 'Logo qo\'shildi — pastdagi ko\'rinishni tekshiring');
  }

  Future<void> _pickFooterImage() async {
    if (_pickingImage) return;
    setState(() => _pickingImage = true);
    final result = await ReceiptDesignStorage.pickAndSaveFooterImage();
    if (!mounted) return;
    setState(() => _pickingImage = false);
    if (result.cancelled) return;
    if (!result.ok) {
      AppNotify.error(context, result.error ?? 'Rasm tanlanmadi');
      return;
    }
    setState(() => _config = _mergedConfig().copyWith(footerImagePath: result.path));
    await _persistSilently();
    if (!mounted) return;
    AppNotify.success(context, 'Pastki rasm qo\'shildi');
  }

  Future<void> _printPreview() async {
    setState(() => _previewPrinting = true);
    try {
      await ReceiptDesignStorage.save(_mergedConfig());
      if (!mounted) return;
      final pngBytes = await captureReceiptForThermal(_previewWidget(), context: context);
      final directOnly = await PrinterSettings.isPrinterReady();
      final result = await ThermalReceiptPrinter.printPngBytes(
        pngBytes,
        directOnly: directOnly,
      );
      if (!mounted) return;
      if (result.ok) {
        AppNotify.success(context, result.message);
      } else {
        AppNotify.warning(context, result.message);
      }
    } catch (e) {
      if (mounted) AppNotify.error(context, 'Chop etish: $e');
    } finally {
      if (mounted) setState(() => _previewPrinting = false);
    }
  }

  void _showPreviewDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380, maxHeight: 720),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 8, 0),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Chek ko‘rinishi',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(color: AppTheme.divider),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      child: _previewWidget(),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _previewPrinting ? null : _printPreview,
                      icon: const Icon(Icons.print_rounded),
                      label: Text(_previewPrinting ? 'Chop etilmoqda...' : 'Test chop'),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Yopish'),
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(color: AppTheme.primary),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Chek dizayni (80mm termal, mahalliy)',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        const Text(
          'API emas — o‘zingiz logo, do‘kon nomi va pastki matn/rasm qo‘yasiz. '
          '2 ta tayyor shablon yoki maxsus dizayn.',
          style: TextStyle(color: AppTheme.textSecondary, height: 1.4),
        ),
        const SizedBox(height: 20),
        const Text('Shablon', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _templateCard(
              title: 'Ro\'yxat',
              subtitle: 'Alfapos.pdf — raqamlangan qatorlar',
              kind: ReceiptTemplateKind.numberedList,
              icon: Icons.format_list_numbered_rounded,
            ),
            _templateCard(
              title: 'Jadval',
              subtitle: 'Alfapos chek.pdf — ustunlar',
              kind: ReceiptTemplateKind.tableColumns,
              icon: Icons.table_rows_rounded,
            ),
            _templateCard(
              title: 'Maxsus',
              subtitle: 'Logo, rasm, matnlar',
              kind: ReceiptTemplateKind.custom,
              icon: Icons.tune_rounded,
            ),
          ],
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _storeController,
          decoration: InputDecoration(
            labelText: 'Do\'kon nomi',
            hintText: 'Bo\'sh qoldirsangiz — filial nomi ishlatiladi',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Filial nomini avtomatik ishlatish'),
          subtitle: const Text('Do\'kon nomi bo\'sh bo\'lsa, sotuv filial nomi chiqadi'),
          value: _config.useBranchNameWhenEmpty,
          onChanged: (v) => setState(() => _config = _config.copyWith(useBranchNameWhenEmpty: v)),
        ),
        if (_config.isCustom) ...[
          const SizedBox(height: 8),
          TextField(
            controller: _headerExtraController,
            decoration: InputDecoration(
              labelText: 'Sarlavha ostidagi qo\'shimcha matn',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Jadval sarlavhalari (Mahsulot, Miqdor...)'),
            value: _config.showTableHeaders,
            onChanged: (v) => setState(() => _config = _config.copyWith(showTableHeaders: v)),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Raqamlangan ro\'yxat uslubi'),
            subtitle: const Text('Jadval o\'chirilsa — 1) mahsulot ko\'rinishi'),
            value: !_config.showTableHeaders,
            onChanged: (v) => setState(() => _config = _config.copyWith(showTableHeaders: !v)),
          ),
        ],
        const SizedBox(height: 12),
        TextField(
          controller: _footerTextController,
          maxLines: 2,
          decoration: InputDecoration(
            labelText: 'Pastki matn',
            hintText: 'Masalan: Спасибо за покупку!',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        _imageRow(
          label: 'Logo (yuqori)',
          path: _config.logoPath,
          onPick: _pickLogo,
          onRemove: () => setState(() => _config = _mergedConfig().copyWith(clearLogo: true)),
        ),
        const SizedBox(height: 12),
        _imageRow(
          label: 'Pastki rasm',
          path: _config.footerImagePath,
          onPick: _pickFooterImage,
          onRemove: () => setState(() => _config = _mergedConfig().copyWith(clearFooterImage: true)),
        ),
        const SizedBox(height: 16),
        const Text('Ko\'rsatish', style: TextStyle(fontWeight: FontWeight.w700)),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Sotuvchi telefoni'),
          value: _config.showSellerPhone,
          onChanged: (v) => setState(() => _config = _config.copyWith(showSellerPhone: v)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Mijoz'),
          value: _config.showClient,
          onChanged: (v) => setState(() => _config = _config.copyWith(showClient: v)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Tavsif'),
          value: _config.showDescription,
          onChanged: (v) => setState(() => _config = _config.copyWith(showDescription: v)),
        ),
        if (_config.isCustom)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Shtrix-kod'),
            value: _config.showBarcode,
            onChanged: (v) => setState(() => _config = _config.copyWith(showBarcode: v)),
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Text('Shrift', style: TextStyle(fontWeight: FontWeight.w600)),
            Expanded(
              child: Slider(
                value: _config.fontScale,
                min: 0.85,
                max: 1.2,
                divisions: 7,
                label: '${(_config.fontScale * 100).round()}%',
                onChanged: (v) => setState(() => _config = _config.copyWith(fontScale: v)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: _showPreviewDialog,
              icon: const Icon(Icons.visibility_rounded),
              label: const Text('Ko\'rib chiqish'),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: _previewPrinting ? null : _printPreview,
              icon: _previewPrinting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.print_rounded),
              label: const Text('Test chop'),
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.save_rounded),
              label: Text(_saving ? 'Saqlanmoqda...' : 'Saqlash'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Text('Jonli ko‘rinish', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        Center(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.divider),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _previewWidget(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _templateCard({
    required String title,
    required String subtitle,
    required ReceiptTemplateKind kind,
    required IconData icon,
  }) {
    final selected = _config.template == kind;
    return SizedBox(
      width: 200,
      child: Material(
        color: selected ? const Color(0xFFEFF6FF) : Colors.white,
        elevation: selected ? 2 : 0,
        shadowColor: Colors.black26,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: _pickingImage ? null : () => _applyTemplate(kind, title),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? AppTheme.primary : AppTheme.divider,
                width: selected ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: selected ? AppTheme.primary : AppTheme.textSecondary, size: 28),
                    const Spacer(),
                    if (selected)
                      const Icon(Icons.check_circle_rounded, color: AppTheme.primary, size: 22),
                  ],
                ),
                const SizedBox(height: 8),
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _imageRow({
    required String label,
    required String? path,
    required VoidCallback onPick,
    required VoidCallback onRemove,
  }) {
    final hasFile = path != null && path.isNotEmpty && File(path).existsSync();
    return Row(
      children: [
        if (hasFile)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(File(path), width: 56, height: 56, fit: BoxFit.cover),
          )
        else
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.divider),
            ),
            child: const Icon(Icons.image_outlined, color: AppTheme.textSecondary),
          ),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
        FilledButton.tonal(
          onPressed: _pickingImage ? null : onPick,
          child: Text(_pickingImage ? 'Kutilmoqda...' : 'Tanlash'),
        ),
        if (hasFile)
          TextButton(
            onPressed: _pickingImage
                ? null
                : () async {
                    onRemove();
                    await _persistSilently();
                    if (mounted) AppNotify.info(context, 'Rasm o\'chirildi');
                  },
            child: const Text('O\'chirish'),
          ),
      ],
    );
  }
}
