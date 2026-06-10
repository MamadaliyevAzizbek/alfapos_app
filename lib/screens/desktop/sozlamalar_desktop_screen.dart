import 'package:flutter/material.dart';
import '../../core/app_notify.dart';
import '../../core/theme.dart';
import 'dart:io' show Platform;

import '../../core/desktop_runtime.dart';
import '../../services/local_receipt_sample.dart';
import '../../services/printer_settings.dart';
import '../../services/desktop_sales_layout_settings.dart';
import '../../widgets/receipt_lines_preview.dart';
import 'desktop_shell_scope.dart';
import 'receipt_design_editor_panel.dart';

/// Desktop: printer va boshqa sozlamalar.
class SozlamalarDesktopScreen extends StatefulWidget {
  const SozlamalarDesktopScreen({super.key});

  @override
  State<SozlamalarDesktopScreen> createState() => _SozlamalarDesktopScreenState();
}

class _SozlamalarDesktopScreenState extends State<SozlamalarDesktopScreen>
    with DesktopShellSyncMixin {
  List<String> _printers = [];
  String? _selected;
  bool _autoPrint = true;
  bool _loading = true;
  bool _testing = false;

  List<String> _sampleLines = [];
  bool _previewLoading = false;
  DesktopSalesLayoutMode _salesLayoutMode = DesktopSalesLayoutMode.standard;

  @override
  void initState() {
    super.initState();
    _load();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadLocalReceiptPreview());
  }

  @override
  Future<void> onDesktopShellSync() async => _load();

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final names = await PrinterSettings.discoverPrinters();
      final selected = await PrinterSettings.selectedPrinterName();
      final auto = await PrinterSettings.isAutoPrintEnabled();
      final salesMode = await DesktopSalesLayoutSettings.getMode();
      if (!mounted) return;
      setState(() {
        _printers = names;
        _selected = selected != null && names.contains(selected) ? selected : null;
        _autoPrint = auto;
        _salesLayoutMode = salesMode;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        AppNotify.error(context, 'Printerlar: $e');
      }
    }
  }

  Future<void> _save() async {
    await PrinterSettings.setSelectedPrinterName(_selected);
    await PrinterSettings.setAutoPrintEnabled(_autoPrint);
    await DesktopSalesLayoutSettings.setMode(_salesLayoutMode);
    if (!mounted) return;
    AppNotify.success(context, 'Sozlamalar saqlandi');
  }

  Future<void> _saveSalesLayoutMode() async {
    await DesktopSalesLayoutSettings.setMode(_salesLayoutMode);
    if (!mounted) return;
    AppNotify.success(
      context,
      'Sotuv ko‘rinishi: ${DesktopSalesLayoutSettings.modeLabel(_salesLayoutMode)}',
    );
  }

  Future<void> _loadLocalReceiptPreview() async {
    setState(() => _previewLoading = true);
    try {
      final lines = await LocalReceiptSample.sampleSalePrintLines();
      if (!mounted) return;
      setState(() {
        _sampleLines = lines;
        _previewLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _previewLoading = false);
      AppNotify.error(context, 'Chek namunasi: $e');
    }
  }

  Future<void> _testPrint() async {
    if (_selected == null) {
      AppNotify.info(context, 'Avval printerni tanlang');
      return;
    }
    await PrinterSettings.setSelectedPrinterName(_selected);
    setState(() => _testing = true);
    final result = await PrinterSettings.testPrint();
    if (!mounted) return;
    setState(() => _testing = false);
    if (result.ok) {
      AppNotify.success(context, result.message);
    } else {
      AppNotify.error(context, result.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppTheme.surface,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'Sozlamalar',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 20),
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.print_rounded, color: AppTheme.primary, size: 28),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Termal printer',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _loading ? null : _load,
                      icon: const Icon(Icons.refresh_rounded, size: 20),
                      label: const Text('Yangilash'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Xprinter 80mm yoki boshqa termal printerni tizimga ulang, '
                  'ro\'yxatdan tanlang va saqlang. To\'lovdan keyin chek avtomatik chop etiladi.',
                  style: TextStyle(color: AppTheme.textSecondary, height: 1.4),
                ),
                const SizedBox(height: 20),
                if (_loading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(color: AppTheme.primary),
                    ),
                  )
                else if (_printers.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFDBA74)),
                    ),
                    child: Text(
                      Platform.isWindows
                          ? '${desktopPrinterHelpText()}\n\n«Yangilash» tugmasini bosing.'
                          : 'Printer topilmadi. USB orqali ulang, drayver o\'rnating va «Yangilash» bosing.',
                      style: const TextStyle(color: Color(0xFF9A3412)),
                    ),
                  )
                else
                  DropdownButtonFormField<String>(
                    value: _selected,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Printer',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    hint: const Text('Printerni tanlang'),
                    items: _printers
                        .map(
                          (n) => DropdownMenuItem(
                            value: n,
                            child: Text(n, overflow: TextOverflow.ellipsis),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _selected = v),
                  ),
                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'To\'lovdan keyin avtomatik chop etish',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'To\'lov yakunlangach chek darhol printerdan chiqadi',
                    style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                  ),
                  value: _autoPrint,
                  activeColor: AppTheme.primary,
                  onChanged: (v) => setState(() => _autoPrint = v),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _testing || _selected == null ? null : _testPrint,
                      icon: _testing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.receipt_long_rounded),
                      label: Text(_testing ? 'Chop etilmoqda...' : 'Test chop etish'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      ),
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.save_rounded),
                      label: const Text('Saqlash'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _buildSalesLayoutCard(),
          const SizedBox(height: 20),
          _card(child: ReceiptDesignEditorPanel(onSaved: _loadLocalReceiptPreview)),
          const SizedBox(height: 20),
          _buildReceiptPreviewCard(),
        ],
      ),
    );
  }

  Widget _buildSalesLayoutCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.storefront_rounded, color: AppTheme.primary, size: 28),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Sotuv bo‘limi ko‘rinishi',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Desktop sotuv ekranida mahsulotlar qanday ko‘rinishini tanlang. '
            'Restoran rejimida avval kategoriyalar, keyin mahsulotlar chiqadi.',
            style: TextStyle(color: AppTheme.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 20),
          SegmentedButton<DesktopSalesLayoutMode>(
            segments: const [
              ButtonSegment(
                value: DesktopSalesLayoutMode.standard,
                label: Text('Oddiy'),
                icon: Icon(Icons.grid_view_rounded),
              ),
              ButtonSegment(
                value: DesktopSalesLayoutMode.restaurant,
                label: Text('Restoran'),
                icon: Icon(Icons.restaurant_rounded),
              ),
            ],
            selected: {_salesLayoutMode},
            onSelectionChanged: (v) {
              if (v.isEmpty) return;
              setState(() => _salesLayoutMode = v.first);
            },
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _saveSalesLayoutMode,
              icon: const Icon(Icons.save_rounded),
              label: const Text('Saqlash'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptPreviewCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long_outlined, color: AppTheme.primary, size: 28),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Mahalliy chek ko\'rinishi',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              TextButton.icon(
                onPressed: _previewLoading ? null : _loadLocalReceiptPreview,
                icon: const Icon(Icons.refresh_rounded, size: 20),
                label: const Text('Yangilash'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Chek serverdan emas — dastur o\'zi yig\'adi (savatcha, to\'lov, filial nomi) va shu formatda termal printerga yuboriladi.',
            style: TextStyle(color: AppTheme.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 20),
          if (_previewLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(color: AppTheme.primary),
              ),
            )
          else
            _previewColumn(
              title: 'Printerdan chiqadigan chek',
              subtitle: 'Sotuv yakunlanganda shu ko\'rinish chop etiladi',
              child: SingleChildScrollView(
                child: Center(
                  child: ReceiptLinesPreview(lines: _sampleLines),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _previewColumn({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 420),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}
