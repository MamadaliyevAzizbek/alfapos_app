import 'package:flutter/material.dart';

import '../core/app_notify.dart';
import '../core/theme.dart';
import '../services/printer_settings.dart';
import '../services/receipt_font_settings.dart';

/// Chek shriftini tanlash va printerda sinash.
class ReceiptFontSelectorPanel extends StatefulWidget {
  final VoidCallback? onFontChanged;

  const ReceiptFontSelectorPanel({super.key, this.onFontChanged});

  @override
  State<ReceiptFontSelectorPanel> createState() => _ReceiptFontSelectorPanelState();
}

class _ReceiptFontSelectorPanelState extends State<ReceiptFontSelectorPanel> {
  ReceiptFontId _selected = ReceiptFontId.arial;
  bool _loading = true;
  bool _testing = false;

  static const _sampleText = "Do'kon — O'zbekiston noni, 125 000 so'm";

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final font = await ReceiptFontSettings.getSelectedFont();
    if (!mounted) return;
    setState(() {
      _selected = font;
      _loading = false;
    });
  }

  Future<void> _saveFont(ReceiptFontId font) async {
    setState(() => _selected = font);
    await ReceiptFontSettings.setSelectedFont(font);
    widget.onFontChanged?.call();
  }

  Future<void> _testPrint() async {
    final ready = await PrinterSettings.isPrinterReady();
    if (!ready) {
      if (!mounted) return;
      AppNotify.info(
        context,
        'Avval Termal printer tabida printerni tanlang',
      );
      return;
    }

    setState(() => _testing = true);
    try {
      final result = await PrinterSettings.testPrint();
      if (!mounted) return;
      if (result.ok) {
        AppNotify.success(context, 'Test chek chop etildi');
      } else {
        AppNotify.error(context, result.message);
      }
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Chek shrifti',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        const Text(
          'Tanlangan shrift chek ko‘rinishi va termal printerga chop etishda ishlatiladi.',
          style: TextStyle(color: AppTheme.textSecondary, height: 1.4, fontSize: 13),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<ReceiptFontId>(
          value: _selected,
          decoration: const InputDecoration(
            labelText: 'Shrift',
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
          items: ReceiptFontSettings.choices
              .map(
                (f) => DropdownMenuItem(
                  value: f,
                  child: Text(f.label, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
          onChanged: (v) {
            if (v == null) return;
            _saveFont(v);
          },
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Namuna',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _sampleText,
                style: ReceiptFontSettings.style(
                  font: _selected,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Navbat: 42',
                style: ReceiptFontSettings.style(
                  font: _selected,
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: _testing ? null : _testPrint,
            icon: _testing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.print_rounded),
            label: Text(_testing ? 'Chop etilmoqda...' : 'Shriftni printerda sinash'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            ),
          ),
        ),
      ],
    );
  }
}
