import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/app_notify.dart';
import '../../core/theme.dart';
import '../../models/receipt_design_config.dart';
import '../../services/local_receipt_sample.dart';
import '../../services/receipt_design_storage.dart';
import '../../widgets/receipt_lines_preview.dart';

/// Sozlamalar: chek matnlari, logo va ko‘rinish tahriri.
class ReceiptDesignEditorPanel extends StatefulWidget {
  final VoidCallback? onSaved;

  const ReceiptDesignEditorPanel({super.key, this.onSaved});

  @override
  State<ReceiptDesignEditorPanel> createState() => _ReceiptDesignEditorPanelState();
}

class _ReceiptDesignEditorPanelState extends State<ReceiptDesignEditorPanel> {
  ReceiptDesignConfig _config = ReceiptDesignConfig.defaults;
  bool _loading = true;
  bool _saving = false;
  List<String> _previewLines = [];
  bool _previewLoading = false;

  late final TextEditingController _storeTitle;
  late final TextEditingController _receiptLabel;
  late final TextEditingController _sellerLabel;
  late final TextEditingController _sellerPhoneLabel;
  late final TextEditingController _clientLabel;
  late final TextEditingController _clientPhoneLabel;
  late final TextEditingController _clientAddressLabel;
  late final TextEditingController _discountLabel;
  late final TextEditingController _totalLabel;
  late final TextEditingController _footerText;
  late final TextEditingController _precheckBanner;
  late final TextEditingController _currencySuffix;
  late final TextEditingController _itemSeparator;

  @override
  void initState() {
    super.initState();
    _storeTitle = TextEditingController();
    _receiptLabel = TextEditingController();
    _sellerLabel = TextEditingController();
    _sellerPhoneLabel = TextEditingController();
    _clientLabel = TextEditingController();
    _clientPhoneLabel = TextEditingController();
    _clientAddressLabel = TextEditingController();
    _discountLabel = TextEditingController();
    _totalLabel = TextEditingController();
    _footerText = TextEditingController();
    _precheckBanner = TextEditingController();
    _currencySuffix = TextEditingController();
    _itemSeparator = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    _storeTitle.dispose();
    _receiptLabel.dispose();
    _sellerLabel.dispose();
    _sellerPhoneLabel.dispose();
    _clientLabel.dispose();
    _clientPhoneLabel.dispose();
    _clientAddressLabel.dispose();
    _discountLabel.dispose();
    _totalLabel.dispose();
    _footerText.dispose();
    _precheckBanner.dispose();
    _currencySuffix.dispose();
    _itemSeparator.dispose();
    super.dispose();
  }

  void _syncControllers(ReceiptDesignConfig c) {
    _storeTitle.text = c.storeTitle;
    _receiptLabel.text = c.receiptNumberLabel;
    _sellerLabel.text = c.sellerLabel;
    _sellerPhoneLabel.text = c.sellerPhoneLabel;
    _clientLabel.text = c.clientLabel;
    _clientPhoneLabel.text = c.clientPhoneLabel;
    _clientAddressLabel.text = c.clientAddressLabel;
    _discountLabel.text = c.discountLabel;
    _totalLabel.text = c.totalLabel;
    _footerText.text = c.footerText;
    _precheckBanner.text = c.precheckBanner;
    _currencySuffix.text = c.currencySuffix;
    _itemSeparator.text = c.itemSeparator;
  }

  ReceiptDesignConfig _readFromControllers() {
    return _config.copyWith(
      storeTitle: _storeTitle.text.trim(),
      receiptNumberLabel: _receiptLabel.text.trim(),
      sellerLabel: _sellerLabel.text.trim(),
      sellerPhoneLabel: _sellerPhoneLabel.text.trim(),
      clientLabel: _clientLabel.text.trim(),
      clientPhoneLabel: _clientPhoneLabel.text.trim(),
      clientAddressLabel: _clientAddressLabel.text.trim(),
      discountLabel: _discountLabel.text.trim(),
      totalLabel: _totalLabel.text.trim(),
      footerText: _footerText.text.trim(),
      precheckBanner: _precheckBanner.text.trim(),
      currencySuffix: _currencySuffix.text.trim(),
      itemSeparator: _itemSeparator.text.trim(),
    );
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      var c = await ReceiptDesignStorage.load();
      if (c.showLogo && !await ReceiptDesignStorage.logoFileExists(c.logoFilePath)) {
        final path = await ReceiptDesignStorage.copyBundledDefaultLogoIfNeeded();
        if (path != null) {
          c = c.copyWith(logoFilePath: path);
          await ReceiptDesignStorage.save(c);
        }
      }
      if (!mounted) return;
      _config = c;
      _syncControllers(c);
      setState(() => _loading = false);
      await _refreshPreview();
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        AppNotify.error(context, 'Chek dizayni: $e');
      }
    }
  }

  Future<void> _refreshPreview() async {
    setState(() => _previewLoading = true);
    try {
      final lines = await LocalReceiptSample.sampleSalePrintLines(design: _readFromControllers());
      if (!mounted) return;
      setState(() {
        _previewLines = lines;
        _previewLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _previewLoading = false);
        AppNotify.error(context, 'Ko\'rinish: $e');
      }
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final c = _readFromControllers();
      await ReceiptDesignStorage.save(c);
      _config = c;
      if (!mounted) return;
      setState(() => _saving = false);
      AppNotify.success(context, 'Chek dizayni saqlandi');
      widget.onSaved?.call();
      await _refreshPreview();
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        AppNotify.error(context, 'Saqlash: $e');
      }
    }
  }

  Future<void> _pickLogo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;
    final path = result.files.single.path;
    if (path == null || path.isEmpty) return;
    try {
      var c = await ReceiptDesignStorage.saveLogoFromPath(_readFromControllers(), path);
      await ReceiptDesignStorage.save(c);
      if (!mounted) return;
      setState(() => _config = c);
      AppNotify.success(context, 'Logo saqlandi');
      await _refreshPreview();
    } catch (e) {
      if (mounted) AppNotify.error(context, 'Logo: $e');
    }
  }

  Future<void> _removeLogo() async {
    var c = await ReceiptDesignStorage.removeLogo(_readFromControllers());
    await ReceiptDesignStorage.save(c);
    if (!mounted) return;
    setState(() => _config = c);
    await _refreshPreview();
  }

  void _applyLocal(ReceiptDesignConfig c) {
    setState(() => _config = c);
    _syncControllers(c);
    _refreshPreview();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(color: AppTheme.primary),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.edit_note_rounded, color: AppTheme.primary, size: 28),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Chek dizayni',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.save_rounded),
              label: const Text('Saqlash'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Do\'kon nomi maydoni chek boshida chiqadi (4-rasmdagi kabi). Bo\'sh qoldirsangiz — filial nomi ishlatiladi.',
          style: TextStyle(color: AppTheme.textSecondary, height: 1.4),
        ),
        const SizedBox(height: 20),
        _logoSection(),
        const SizedBox(height: 20),
        _switchRow(
          'API filial nomidan foydalanish (tavsiya)',
          _config.useBranchNameAsTitle,
          (v) => _applyLocal(_config.copyWith(useBranchNameAsTitle: v)),
        ),
        const SizedBox(height: 12),
        _field(
          'Do\'kon nomi (chek sarlavhasi)',
          _storeTitle,
          onChanged: (_) => _refreshPreview(),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            _switchChip('Sana/vaqt', _config.showDateTime, (v) => _applyLocal(_config.copyWith(showDateTime: v))),
            _switchChip('Sotuvchi telefoni', _config.showSellerPhone, (v) => _applyLocal(_config.copyWith(showSellerPhone: v))),
            _switchChip('Mijoz qatori', _config.showClientLine, (v) => _applyLocal(_config.copyWith(showClientLine: v))),
            _switchChip('Mijoz telefoni', _config.showClientPhone, (v) => _applyLocal(_config.copyWith(showClientPhone: v))),
            _switchChip('Mijoz manzili', _config.showClientAddress, (v) => _applyLocal(_config.copyWith(showClientAddress: v))),
            _switchChip('Mahsulot ajratgichi', _config.showItemSeparator, (v) => _applyLocal(_config.copyWith(showItemSeparator: v))),
            _switchChip('Raqamlangan mahsulot', _config.numberedProducts, (v) => _applyLocal(_config.copyWith(numberedProducts: v))),
            _switchChip('Pastki matn', _config.showFooter, (v) => _applyLocal(_config.copyWith(showFooter: v))),
            _codePageChip('CP866 (rus)', 'CP866'),
            _codePageChip('CP1251', 'CP1251'),
          ],
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, c) {
            final w = c.maxWidth;
            final cols = w > 900 ? 3 : (w > 560 ? 2 : 1);
            return GridView.count(
              crossAxisCount: cols,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: cols == 1 ? 4.5 : 3.2,
              children: [
                _field('Chek raqami yozuvi', _receiptLabel, onChanged: (_) => _refreshPreview()),
                _field('Sotuvchi yozuvi', _sellerLabel, onChanged: (_) => _refreshPreview()),
                _field('Telefon yozuvi', _sellerPhoneLabel, onChanged: (_) => _refreshPreview()),
                _field('Mijoz yozuvi', _clientLabel, onChanged: (_) => _refreshPreview()),
                _field('Mijoz telefon yozuvi', _clientPhoneLabel, onChanged: (_) => _refreshPreview()),
                _field('Mijoz manzil yozuvi', _clientAddressLabel, onChanged: (_) => _refreshPreview()),
                _field('Chegirma yozuvi', _discountLabel, onChanged: (_) => _refreshPreview()),
                _field('Jami yozuvi', _totalLabel, onChanged: (_) => _refreshPreview()),
                _field('Valyuta (so\'m)', _currencySuffix, onChanged: (_) => _refreshPreview()),
                _field('Ajratgich belgisi (-)', _itemSeparator, onChanged: (_) => _refreshPreview()),
                _field('Oldindan chek banner', _precheckBanner, onChanged: (_) => _refreshPreview()),
                _field('Pastki matn', _footerText, onChanged: (_) => _refreshPreview()),
              ],
            );
          },
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Printer ko‘rinishi', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              if (_previewLoading)
                const Center(child: CircularProgressIndicator(color: AppTheme.primary))
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 360),
                  child: SingleChildScrollView(
                    child: Center(child: ReceiptLinesPreview(lines: _previewLines)),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _logoSection() {
    final path = _config.logoFilePath;
    final hasFile = path != null && path.isNotEmpty && File(path).existsSync();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.divider),
          ),
          clipBehavior: Clip.antiAlias,
          child: _config.showLogo && hasFile
              ? Image.file(File(path), fit: BoxFit.contain)
              : Icon(Icons.image_outlined, size: 40, color: Colors.grey.shade400),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Chek boshida logo'),
                value: _config.showLogo,
                onChanged: (v) => _applyLocal(_config.copyWith(showLogo: v)),
              ),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _pickLogo,
                    icon: const Icon(Icons.upload_file_rounded, size: 18),
                    label: const Text('Logo yuklash'),
                  ),
                  if (hasFile)
                    TextButton.icon(
                      onPressed: _removeLogo,
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      label: const Text('O‘chirish'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _field(String label, TextEditingController ctrl, {ValueChanged<String>? onChanged}) {
    return TextField(
      controller: ctrl,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      onChanged: onChanged,
    );
  }

  Widget _switchRow(String title, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      value: value,
      onChanged: onChanged,
    );
  }

  Widget _switchChip(String label, bool value, ValueChanged<bool> onChanged) {
    return FilterChip(
      label: Text(label),
      selected: value,
      onSelected: onChanged,
      selectedColor: AppTheme.primary.withValues(alpha: 0.15),
      checkmarkColor: AppTheme.primary,
    );
  }

  Widget _codePageChip(String label, String value) {
    final selected = _config.printerCodePage.toUpperCase() == value.toUpperCase();
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => _applyLocal(_config.copyWith(printerCodePage: value)),
      selectedColor: AppTheme.primary.withValues(alpha: 0.15),
      checkmarkColor: AppTheme.primary,
    );
  }
}
