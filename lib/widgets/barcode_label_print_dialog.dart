import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme.dart';
import '../models/barcode_label_config.dart';
import '../models/product.dart';
import '../services/barcode_label_settings.dart';
import '../utils/platform_layout.dart';
import 'ios_style_modals.dart';

/// Shtrix kod yorlig‘i: shablon + o‘lcham + soni.
/// - Desktopda: `AlertDialog`
/// - Mobilda: to‘liq ekran (`Scaffold`)
Future<BarcodeLabelConfig?> showBarcodeLabelPrintDialog({
  required BuildContext context,
  required Product product,
  required String barcode,
  BarcodeLabelConfig? initial,
  String confirmLabel = 'Chop etish',
}) async {
  final defaults = initial ?? await BarcodeLabelSettings.loadDefaults();
  if (!context.mounted) return null;

  if (isDesktopPosLayout) {
    return IosStyleModals.showPopupPanel<BarcodeLabelConfig>(
      context: context,
      insetPadding: const EdgeInsets.symmetric(horizontal: 120, vertical: 60),
      child: SizedBox(
        width: 640,
        child: _BarcodeLabelPrintDialog(
          product: product,
          barcode: barcode,
          initial: defaults,
          confirmLabel: confirmLabel,
          fullScreen: false,
        ),
      ),
    );
  }

  return Navigator.of(context).push<BarcodeLabelConfig>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (ctx) => _BarcodeLabelPrintDialog(
        product: product,
        barcode: barcode,
        initial: defaults,
        confirmLabel: confirmLabel,
        fullScreen: true,
      ),
    ),
  );
}

class _BarcodeLabelPrintDialog extends StatefulWidget {
  const _BarcodeLabelPrintDialog({
    required this.product,
    required this.barcode,
    required this.initial,
    required this.confirmLabel,
    required this.fullScreen,
  });

  final Product product;
  final String barcode;
  final BarcodeLabelConfig initial;
  final String confirmLabel;
  final bool fullScreen;

  @override
  State<_BarcodeLabelPrintDialog> createState() =>
      _BarcodeLabelPrintDialogState();
}

class _BarcodeLabelPrintDialogState extends State<_BarcodeLabelPrintDialog> {
  late final TextEditingController _copiesCtrl;
  late final TextEditingController _widthCtrl;
  late final TextEditingController _heightCtrl;
  late final TextEditingController _shopNameCtrl;

  late BarcodeLabelTemplate _template;
  String? _error;

  @override
  void initState() {
    super.initState();
    _template = widget.initial.template;
    _copiesCtrl = TextEditingController(text: '${widget.initial.copies}');
    _widthCtrl = TextEditingController(text: _formatMm(widget.initial.widthMm));
    _heightCtrl =
        TextEditingController(text: _formatMm(widget.initial.heightMm));
    _shopNameCtrl = TextEditingController(text: widget.initial.shopName);
  }

  @override
  void dispose() {
    _copiesCtrl.dispose();
    _widthCtrl.dispose();
    _heightCtrl.dispose();
    _shopNameCtrl.dispose();
    super.dispose();
  }

  String _formatMm(double v) {
    if (v == v.roundToDouble()) return '${v.toInt()}';
    return v.toStringAsFixed(1);
  }

  double? _parseMm(String raw) {
    final v = double.tryParse(raw.trim().replaceAll(',', '.'));
    if (v == null || v <= 0) return null;
    return v;
  }

  int? _parseCopies(String raw) {
    final v = int.tryParse(raw.trim());
    if (v == null || v <= 0) return null;
    return v;
  }

  void _submit() {
    setState(() => _error = null);

    final copies = _parseCopies(_copiesCtrl.text);
    final width = _parseMm(_widthCtrl.text);
    final height = _parseMm(_heightCtrl.text);
    final shopName = _shopNameCtrl.text.trim();

    if (copies == null || width == null || height == null) {
      setState(() => _error = 'Barcha maydonlarni to‘g‘ri kiriting');
      return;
    }
    if (_template == BarcodeLabelTemplate.shopName && shopName.isEmpty) {
      setState(() => _error = 'Do‘kon nomini kiriting');
      return;
    }

    Navigator.pop(
      context,
      BarcodeLabelConfig(
        widthMm: width,
        heightMm: height,
        copies: copies,
        template: _template,
        shopName: shopName,
      ).normalized(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = _formBody();

    if (widget.fullScreen) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text('Shtrix kod yorlig‘i'),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(child: SingleChildScrollView(child: content)),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: IosStyleModals.sheetPillCancelSaveRow(
                  onCancel: () => Navigator.pop(context),
                  onSave: _submit,
                  cancelLabel: 'Bekor',
                  saveLabel: widget.confirmLabel,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(28, 24, 28, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Shtrix kod yorlig‘i',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Shablon va chop etish parametrlarini tanlang',
                style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: content,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 20, 28, 24),
          child: IosStyleModals.sheetPillCancelSaveRow(
            onCancel: () => Navigator.pop(context),
            onSave: _submit,
            cancelLabel: 'Bekor',
            saveLabel: widget.confirmLabel,
          ),
        ),
      ],
    );
  }

  Widget _formBody() {
    return Padding(
      padding: EdgeInsets.fromLTRB(widget.fullScreen ? 16 : 0, 12, widget.fullScreen ? 16 : 0, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Shablon',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 8),
          SegmentedButton<BarcodeLabelTemplate>(
            segments: const [
              ButtonSegment(
                value: BarcodeLabelTemplate.standard,
                label: Text('Narx bilan'),
                icon: Icon(Icons.sell_outlined, size: 18),
              ),
              ButtonSegment(
                value: BarcodeLabelTemplate.shopName,
                label: Text('Do‘kon nomi bilan'),
                icon: Icon(Icons.storefront_outlined, size: 18),
              ),
            ],
            selected: {_template},
            onSelectionChanged: (s) {
              setState(() => _template = s.first);
              setState(() => _error = null);
            },
          ),
          if (_template == BarcodeLabelTemplate.shopName) ...[
            const SizedBox(height: 12),
            _textField(
              label: 'Do‘kon nomi',
              controller: _shopNameCtrl,
              hint: 'Masalan: Alfa market',
            ),
          ],
          const SizedBox(height: 16),
          _numberField(
            label: 'Nechta chiqsin',
            controller: _copiesCtrl,
            suffix: 'ta',
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _numberField(
                  label: 'Eni (mm)',
                  controller: _widthCtrl,
                  suffix: 'mm',
                  decimal: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _numberField(
                  label: 'Bo‘yi (mm)',
                  controller: _heightCtrl,
                  suffix: 'mm',
                  decimal: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Standart: 40×30 mm',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: TextStyle(fontSize: 13, color: Colors.red.shade700),
            ),
          ],
        ],
      ),
    );
  }

  Widget _numberField({
    required String label,
    required TextEditingController controller,
    required String suffix,
    bool decimal = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: decimal
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.number,
          inputFormatters: [
            if (decimal)
              FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))
            else
              FilteringTextInputFormatter.digitsOnly,
          ],
          decoration: InputDecoration(
            isDense: true,
            suffixText: suffix,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
      ],
    );
  }

  Widget _textField({
    required String label,
    required TextEditingController controller,
    required String hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            isDense: true,
            hintText: hint,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
      ],
    );
  }
}
