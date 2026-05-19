import 'package:flutter/material.dart';
import 'package:screenshot/screenshot.dart';

import '../../core/app_notify.dart';
import '../../core/theme.dart';
import '../../models/receipt_block_layout.dart';
import '../../models/receipt_design_config.dart';
import '../../services/printer_settings.dart';
import '../../services/receipt_design_storage.dart';
import '../../services/thermal_receipt_printer.dart';
import '../../utils/receipt_sample_data.dart';
import '../../widgets/receipt_widget.dart';

/// Jonli ko‘rinish + elementlarni bosib tanlash, sudrab joylashtirish, kattalashtirish.
class ReceiptVisualEditor extends StatefulWidget {
  const ReceiptVisualEditor({super.key});

  @override
  State<ReceiptVisualEditor> createState() => _ReceiptVisualEditorState();
}

class _ReceiptVisualEditorState extends State<ReceiptVisualEditor> {
  ReceiptDesignConfig _config = ReceiptDesignConfig.presetTableColumns();
  ReceiptEditableBlock? _selected;
  bool _loading = true;
  bool _saving = false;
  bool _printing = false;
  bool _pickingImage = false;
  double _dragAccum = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final c = await ReceiptDesignStorage.load();
    if (!mounted) return;
    setState(() {
      _config = c;
      _loading = false;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await ReceiptDesignStorage.save(_config);
    if (!mounted) return;
    setState(() => _saving = false);
    AppNotify.success(context, 'Chek dizayni saqlandi');
  }

  ReceiptWidget _previewReceipt() {
    return ReceiptWidget(
      design: _config,
      storeName: _config.storeName.trim().isNotEmpty
          ? _config.storeName.trim()
          : 'Alfa market',
      dateTime: DateTime(2026, 5, 19, 19, 59, 38),
      receiptNumber: ReceiptSampleData.receiptNumber,
      sellerName: ReceiptSampleData.sellerName,
      sellerPhone: ReceiptSampleData.sellerPhone,
      productRows: ReceiptSampleData.products,
      paymentRows: ReceiptSampleData.payments,
      discount: ReceiptSampleData.discount,
      totalSum: ReceiptSampleData.total,
      barcodeData: ReceiptSampleData.receiptNumber,
      showEditorPlaceholders: true,
    );
  }

  ReceiptBlockLayout _layoutFor(ReceiptEditableBlock block) {
    switch (block) {
      case ReceiptEditableBlock.logo:
        return _config.logoLayout;
      case ReceiptEditableBlock.storeName:
        return _config.storeNameLayout;
      case ReceiptEditableBlock.footerText:
        return _config.footerTextLayout;
      case ReceiptEditableBlock.footerImage:
        return _config.footerImageLayout;
      case ReceiptEditableBlock.barcode:
        return _config.barcodeLayout;
    }
  }

  void _setLayout(ReceiptEditableBlock block, ReceiptBlockLayout layout) {
    setState(() {
      switch (block) {
        case ReceiptEditableBlock.logo:
          _config = _config.copyWith(logoLayout: layout);
          break;
        case ReceiptEditableBlock.storeName:
          _config = _config.copyWith(storeNameLayout: layout);
          break;
        case ReceiptEditableBlock.footerText:
          _config = _config.copyWith(footerTextLayout: layout);
          break;
        case ReceiptEditableBlock.footerImage:
          _config = _config.copyWith(footerImageLayout: layout);
          break;
        case ReceiptEditableBlock.barcode:
          _config = _config.copyWith(barcodeLayout: layout);
          break;
      }
    });
  }

  Future<void> _pickLogo() async {
    setState(() => _pickingImage = true);
    final r = await ReceiptDesignStorage.pickAndSaveLogo();
    if (!mounted) return;
    setState(() => _pickingImage = false);
    if (r.cancelled) return;
    if (!r.ok) {
      AppNotify.error(context, r.error ?? 'Logo tanlanmadi');
      return;
    }
    setState(() {
      _config = _config.copyWith(logoPath: r.path);
      _selected = ReceiptEditableBlock.logo;
    });
    AppNotify.success(context, 'Logo qo\'shildi — sudrab joylashtiring');
  }

  Future<void> _pickFooterImage() async {
    setState(() => _pickingImage = true);
    final r = await ReceiptDesignStorage.pickAndSaveFooterImage();
    if (!mounted) return;
    setState(() => _pickingImage = false);
    if (r.cancelled) return;
    if (!r.ok) {
      AppNotify.error(context, r.error ?? 'Rasm tanlanmadi');
      return;
    }
    setState(() {
      _config = _config.copyWith(footerImagePath: r.path);
      _selected = ReceiptEditableBlock.footerImage;
    });
    AppNotify.success(context, 'Pastki rasm qo\'shildi');
  }

  Future<void> _editStoreName() async {
    final ctrl = TextEditingController(text: _config.storeName);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Do\'kon nomi'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Bo\'sh — filial nomi'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Bekor')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('OK')),
        ],
      ),
    );
    if (ok == true) {
      setState(() => _config = _config.copyWith(storeName: ctrl.text.trim()));
    }
    ctrl.dispose();
  }

  Future<void> _editFooterText() async {
    final ctrl = TextEditingController(text: _config.footerText);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pastki matn'),
        content: TextField(controller: ctrl, maxLines: 3),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Bekor')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('OK')),
        ],
      ),
    );
    if (ok == true) {
      setState(() => _config = _config.copyWith(footerText: ctrl.text));
    }
    ctrl.dispose();
  }

  Future<void> _testPrint() async {
    setState(() => _printing = true);
    try {
      await ReceiptDesignStorage.save(_config);
      final controller = ScreenshotController();
      if (!mounted) return;
      final png = await controller.captureFromWidget(
        _previewReceipt(),
        context: context,
        pixelRatio: 2,
        delay: const Duration(milliseconds: 100),
      );
      final result = await ThermalReceiptPrinter.printPngBytes(
        png,
        directOnly: await PrinterSettings.isPrinterReady(),
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
      if (mounted) setState(() => _printing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
      );
    }

    final sel = _selected;
    final selLayout = sel != null ? _layoutFor(sel) : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Chek dizayni — jonli tahrir',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        const Text(
          'Avval chekni ko‘ring, pastdan elementni tanlang. Tanlangan qismni chek ustida suring / kattalashtiring.',
          style: TextStyle(color: AppTheme.textSecondary, height: 1.4, fontSize: 13),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 420,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.divider),
            ),
            child: GestureDetector(
              onVerticalDragStart: sel == null ? null : (_) => _dragAccum = 0,
              onVerticalDragUpdate: sel == null
                  ? null
                  : (d) {
                      _dragAccum += d.delta.dy;
                      if (_dragAccum.abs() < 2) return;
                      final step = _dragAccum > 0 ? 2.0 : -2.0;
                      _dragAccum = 0;
                      final cur = _layoutFor(sel);
                      final nextY = (cur.offsetY + step).clamp(-24.0, 48.0);
                      _setLayout(sel, cur.copyWith(offsetY: nextY));
                    },
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: _previewReceipt(),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        const Text('Elementni tanlang:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _blockChip(ReceiptEditableBlock.logo, 'Logo (yuqori)', Icons.image_rounded),
            _blockChip(ReceiptEditableBlock.storeName, 'Do\'kon nomi', Icons.store_rounded),
            _blockChip(ReceiptEditableBlock.footerText, 'Pastki matn', Icons.text_fields_rounded),
            _blockChip(ReceiptEditableBlock.footerImage, 'Pastki rasm', Icons.photo_rounded),
            _blockChip(ReceiptEditableBlock.barcode, 'Shtrix-kod', Icons.qr_code_rounded),
          ],
        ),
        if (sel != null && selLayout != null) ...[
          const SizedBox(height: 10),
          _buildSelectedControls(sel, selLayout),
        ],
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SegmentedButton<ThermalPaperWidth>(
              segments: const [
                ButtonSegment(value: ThermalPaperWidth.mm58, label: Text('58mm')),
                ButtonSegment(value: ThermalPaperWidth.mm80, label: Text('80mm')),
              ],
              selected: {_config.paperWidth},
              onSelectionChanged: (s) {
                if (s.isEmpty) return;
                setState(() => _config = _config.copyWith(paperWidth: s.first));
              },
            ),
            ChoiceChip(
              label: const Text('Ro\'yxat'),
              selected: _config.template == ReceiptTemplateKind.numberedList,
              onSelected: (_) => setState(() {
                _config = ReceiptDesignConfig.presetNumberedList().copyWith(
                  storeName: _config.storeName,
                  logoPath: _config.logoPath,
                  footerImagePath: _config.footerImagePath,
                  footerText: _config.footerText,
                  paperWidth: _config.paperWidth,
                  logoLayout: _config.logoLayout,
                  storeNameLayout: _config.storeNameLayout,
                  footerTextLayout: _config.footerTextLayout,
                  footerImageLayout: _config.footerImageLayout,
                  barcodeLayout: _config.barcodeLayout,
                  showBarcode: _config.showBarcode,
                );
              }),
            ),
            ChoiceChip(
              label: const Text('Jadval'),
              selected: _config.template == ReceiptTemplateKind.tableColumns,
              onSelected: (_) => setState(() {
                _config = ReceiptDesignConfig.presetTableColumns().copyWith(
                  storeName: _config.storeName,
                  logoPath: _config.logoPath,
                  footerImagePath: _config.footerImagePath,
                  footerText: _config.footerText,
                  paperWidth: _config.paperWidth,
                  logoLayout: _config.logoLayout,
                  storeNameLayout: _config.storeNameLayout,
                  footerTextLayout: _config.footerTextLayout,
                  footerImageLayout: _config.footerImageLayout,
                  barcodeLayout: _config.barcodeLayout,
                  showBarcode: _config.showBarcode,
                );
              }),
            ),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save_rounded, size: 18),
              label: Text(_saving ? 'Saqlanmoqda...' : 'Saqlash'),
            ),
            OutlinedButton.icon(
              onPressed: _printing ? null : _testPrint,
              icon: const Icon(Icons.print_rounded, size: 18),
              label: const Text('Test chop'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSelectedControls(ReceiptEditableBlock sel, ReceiptBlockLayout selLayout) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(_blockTitle(sel), style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text(
            'Yuqori chek maydonida suring (joylashuv). Slayder — kattalik.',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
          Slider(
            value: selLayout.scale.clamp(0.4, 2.0),
            min: 0.4,
            max: 2.0,
            divisions: 16,
            label: '${(selLayout.scale * 100).round()}%',
            onChanged: (v) => _setLayout(sel, selLayout.copyWith(scale: v)),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (sel == ReceiptEditableBlock.logo)
                FilledButton.tonal(
                  onPressed: _pickingImage ? null : _pickLogo,
                  child: Text(_pickingImage ? '...' : 'Logo tanlash'),
                ),
              if (sel == ReceiptEditableBlock.footerImage)
                FilledButton.tonal(
                  onPressed: _pickingImage ? null : _pickFooterImage,
                  child: Text(_pickingImage ? '...' : 'Pastki rasm tanlash'),
                ),
              if (sel == ReceiptEditableBlock.storeName)
                TextButton(onPressed: _editStoreName, child: const Text('Do\'kon nomini tahrirlash')),
              if (sel == ReceiptEditableBlock.footerText)
                TextButton(onPressed: _editFooterText, child: const Text('Pastki matnni tahrirlash')),
              if (sel == ReceiptEditableBlock.barcode)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Chop etish'),
                    Switch(
                      value: _config.showBarcode,
                      onChanged: (v) => setState(() => _config = _config.copyWith(showBarcode: v)),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _blockChip(ReceiptEditableBlock block, String label, IconData icon) {
    final selected = _selected == block;
    return FilterChip(
      avatar: Icon(icon, size: 18, color: selected ? Colors.white : AppTheme.textSecondary),
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _selected = selected ? null : block),
      selectedColor: AppTheme.primary,
      checkmarkColor: Colors.white,
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppTheme.textPrimary,
        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }

  String _blockTitle(ReceiptEditableBlock b) {
    switch (b) {
      case ReceiptEditableBlock.logo:
        return 'Logo';
      case ReceiptEditableBlock.storeName:
        return 'Do\'kon nomi';
      case ReceiptEditableBlock.footerText:
        return 'Pastki matn';
      case ReceiptEditableBlock.footerImage:
        return 'Pastki rasm';
      case ReceiptEditableBlock.barcode:
        return 'Shtrix-kod (Code128 — chek raqami)';
    }
  }
}
