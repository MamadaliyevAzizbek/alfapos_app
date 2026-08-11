import 'package:flutter/material.dart';
import '../../core/app_notify.dart';
import '../../core/theme.dart';
import 'dart:io' show Platform;

import '../../core/desktop_runtime.dart';
import '../../models/receipt_design_config.dart';
import '../../services/local_receipt_sample.dart';
import '../../services/printer_settings.dart';
import '../../services/product_catalog_sort_settings.dart';
import '../../services/product_display_settings.dart';
import '../../services/receipt_design_storage.dart';
import '../../services/desktop_sales_layout_settings.dart';
import '../../services/sales_keyboard_shortcuts_settings.dart';
import '../../widgets/app_dropdown.dart';
import '../../widgets/receipt_lines_preview.dart';
import 'desktop_shell_scope.dart';
import 'receipt_design_editor_panel.dart';

enum _SettingsTab { printer, sales, product, receipt }

/// Desktop: printer va boshqa sozlamalar (tabli ko‘rinish).
class SozlamalarDesktopScreen extends StatefulWidget {
  const SozlamalarDesktopScreen({super.key});

  @override
  State<SozlamalarDesktopScreen> createState() => _SozlamalarDesktopScreenState();
}

class _SozlamalarDesktopScreenState extends State<SozlamalarDesktopScreen>
    with DesktopShellSyncMixin {
  static const _tabs = <_SettingsTab, ({String title, IconData icon})>{
    _SettingsTab.printer: (title: 'Termal printer', icon: Icons.print_rounded),
    _SettingsTab.sales: (title: 'Savdo sozlamalari', icon: Icons.storefront_rounded),
    _SettingsTab.product: (title: 'Mahsulot sozlamalari', icon: Icons.inventory_2_outlined),
    _SettingsTab.receipt: (title: 'Chek sozlamalari', icon: Icons.receipt_long_outlined),
  };

  _SettingsTab _selectedTab = _SettingsTab.printer;

  List<String> _printers = [];
  String? _selected;
  bool _secondaryPrinterEnabled = false;
  String? _secondarySelected;
  bool _autoPrint = true;
  bool _openCashDrawerOnPrint = true;
  CashDrawerPin _cashDrawerPin = CashDrawerPin.pin2;
  CashDrawerPrinterTarget _cashDrawerPrinterTarget = CashDrawerPrinterTarget.primary;
  bool _loading = true;
  bool _testing = false;

  List<String> _sampleLines = [];
  List<String> _restaurantSampleLines = [];
  List<String> _xReportSampleLines = [];
  ReceiptDesignConfig _receiptDesign = ReceiptDesignConfig.defaults;
  bool _previewLoading = false;
  DesktopSalesLayoutMode _salesLayoutMode = DesktopSalesLayoutMode.standard;
  bool _showSkuInProductTitle = false;
  ProductCatalogSortMode _productCatalogSortMode = ProductCatalogSortMode.defaultOrder;
  Map<SalesShortcutAction, String> _shortcutKeys =
      Map.of(SalesKeyboardShortcutsSettings.defaults);

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
      final secondaryEnabled = await PrinterSettings.isSecondaryPrinterEnabled();
      final secondarySelected = await PrinterSettings.secondaryPrinterName();
      final auto = await PrinterSettings.isAutoPrintEnabled();
      final cashDrawer = await PrinterSettings.isCashDrawerOpenOnPrintEnabled();
      final drawerPin = await PrinterSettings.cashDrawerPin();
      final drawerPrinterTarget = await PrinterSettings.cashDrawerPrinterTarget();
      final salesMode = await DesktopSalesLayoutSettings.getMode();
      final showSku = await ProductDisplaySettings.getShowSkuInTitle();
      final productSort = await ProductCatalogSortSettings.getMode();
      final shortcutKeys = await SalesKeyboardShortcutsSettings.loadAll();
      if (!mounted) return;
      setState(() {
        _printers = names;
        _selected = selected != null && names.contains(selected) ? selected : null;
        _secondaryPrinterEnabled = secondaryEnabled;
        _secondarySelected = secondarySelected != null && names.contains(secondarySelected)
            ? secondarySelected
            : null;
        if (_secondarySelected != null && _secondarySelected == _selected) {
          _secondarySelected = null;
        }
        _autoPrint = auto;
        _openCashDrawerOnPrint = cashDrawer;
        _cashDrawerPin = drawerPin;
        _cashDrawerPrinterTarget = drawerPrinterTarget;
        _salesLayoutMode = salesMode;
        _showSkuInProductTitle = showSku;
        _productCatalogSortMode = productSort;
        _shortcutKeys = shortcutKeys;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        AppNotify.error(context, 'Sozlamalar: $e');
      }
    }
  }

  Future<void> _savePrinter() async {
    await PrinterSettings.setSelectedPrinterName(_selected);
    await PrinterSettings.setSecondaryPrinterEnabled(_secondaryPrinterEnabled);
    if (_secondaryPrinterEnabled) {
      if (_secondarySelected == null || _secondarySelected == _selected) {
        AppNotify.info(
          context,
          'Qo‘shimcha printer tanlang — asosiy printerdan farq qilishi kerak',
        );
        return;
      }
      await PrinterSettings.setSecondaryPrinterName(_secondarySelected);
    } else {
      await PrinterSettings.setSecondaryPrinterName(null);
    }
    await PrinterSettings.setAutoPrintEnabled(_autoPrint);
    await PrinterSettings.setCashDrawerOpenOnPrintEnabled(_openCashDrawerOnPrint);
    await PrinterSettings.setCashDrawerPin(_cashDrawerPin);
    await PrinterSettings.setCashDrawerPrinterTarget(_cashDrawerPrinterTarget);
    if (!mounted) return;
    AppNotify.success(context, 'Printer sozlamalari saqlandi');
  }

  Future<void> _saveSalesLayoutMode() async {
    await DesktopSalesLayoutSettings.setMode(_salesLayoutMode);
    if (!mounted) return;
    AppNotify.success(
      context,
      'Sotuv ko‘rinishi: ${DesktopSalesLayoutSettings.modeLabel(_salesLayoutMode)}',
    );
  }

  Future<void> _saveShortcutKeys() async {
    if (SalesKeyboardShortcutsSettings.hasDuplicateKeys(_shortcutKeys)) {
      AppNotify.info(context, 'Har bir tugma faqat bitta amal uchun ishlatilishi kerak');
      return;
    }
    await SalesKeyboardShortcutsSettings.saveAll(_shortcutKeys);
    if (!mounted) return;
    AppNotify.success(context, 'Tezkor klavishlar saqlandi');
  }

  Future<void> _resetShortcutKeys() async {
    await SalesKeyboardShortcutsSettings.resetAll();
    final keys = await SalesKeyboardShortcutsSettings.loadAll();
    if (!mounted) return;
    setState(() => _shortcutKeys = keys);
    AppNotify.success(context, 'Tezkor klavishlar standartga qaytarildi');
  }

  Future<void> _saveProductDisplay() async {
    await ProductDisplaySettings.setShowSkuInTitle(_showSkuInProductTitle);
    await ProductCatalogSortSettings.setMode(_productCatalogSortMode);
    if (!mounted) return;
    AppNotify.success(
      context,
      'Mahsulot sozlamalari saqlandi — '
      '${ProductCatalogSortSettings.modeLabel(_productCatalogSortMode)}',
    );
  }

  Future<void> _loadLocalReceiptPreview() async {
    setState(() => _previewLoading = true);
    try {
      ReceiptDesignStorage.invalidateCache();
      final design = await ReceiptDesignStorage.reload();
      final lines = await LocalReceiptSample.sampleSalePrintLines(design: design);
      final restaurantLines =
          await LocalReceiptSample.sampleRestaurantSalePrintLines(design: design);
      final xReportLines = await LocalReceiptSample.sampleXReportPrintLines(design: design);
      if (!mounted) return;
      setState(() {
        _receiptDesign = design;
        _sampleLines = lines;
        _restaurantSampleLines = restaurantLines;
        _xReportSampleLines = xReportLines;
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
    if (_secondaryPrinterEnabled &&
        (_secondarySelected == null || _secondarySelected == _selected)) {
      AppNotify.info(context, 'Qo‘shimcha printer tanlang yoki o‘chiring');
      return;
    }
    await PrinterSettings.setSelectedPrinterName(_selected);
    await PrinterSettings.setSecondaryPrinterEnabled(_secondaryPrinterEnabled);
    if (_secondaryPrinterEnabled) {
      await PrinterSettings.setSecondaryPrinterName(_secondarySelected);
    } else {
      await PrinterSettings.setSecondaryPrinterName(null);
    }
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

  List<String> get _secondaryPrinterOptions {
    if (_selected == null) return _printers;
    return _printers.where((n) => n != _selected).toList();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppTheme.surface,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSidebar(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(28, 24, 28, 32),
              child: _buildTabContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 248,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: AppTheme.divider)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 24, 20, 16),
            child: Row(
              children: [
                Icon(Icons.settings_rounded, color: AppTheme.primary, size: 22),
                SizedBox(width: 10),
                Text(
                  'Sozlamalar',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: _tabs.entries.map((e) => _sidebarItem(e.key, e.value.title, e.value.icon)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sidebarItem(_SettingsTab tab, String title, IconData icon) {
    final selected = _selectedTab == tab;
    return Material(
      color: selected ? AppTheme.primary.withValues(alpha: 0.08) : Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _selectedTab = tab),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: selected ? AppTheme.primary : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: selected ? AppTheme.primary : AppTheme.textSecondary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: selected ? AppTheme.primary : AppTheme.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    return switch (_selectedTab) {
      _SettingsTab.printer => _buildPrinterTab(),
      _SettingsTab.sales => _buildSalesTab(),
      _SettingsTab.product => _buildProductTab(),
      _SettingsTab.receipt => _buildReceiptTab(),
    };
  }

  Widget _buildPrinterTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionHeader(
          'Termal printer',
          'Xprinter 80mm yoki boshqa termal printerni tizimga ulang, ro\'yxatdan tanlang va saqlang.',
        ),
        const SizedBox(height: 20),
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  TextButton.icon(
                    onPressed: _loading ? null : _load,
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                    label: const Text('Printerlarni yangilash'),
                  ),
                ],
              ),
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
                        ? '${desktopPrinterHelpText()}\n\n«Printerlarni yangilash» tugmasini bosing.'
                        : 'Printer topilmadi. USB orqali ulang, drayver o\'rnating va «Printerlarni yangilash» bosing.',
                    style: const TextStyle(color: Color(0xFF9A3412)),
                  ),
                )
              else
                AppDropdownField<String>(
                  label: 'Asosiy printer',
                  hint: 'Printerni tanlang',
                  value: _selected,
                  items: _printers
                      .map((n) => appDropdownItem(value: n, label: n))
                      .toList(),
                  onChanged: (v) => setState(() {
                    _selected = v;
                    if (_secondarySelected == v) _secondarySelected = null;
                  }),
                ),
              const SizedBox(height: 16),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Qo‘shimcha printer (bir vaqtda nusxa)',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'To‘lovdan keyin bir xil chek asosiy va qo‘shimcha printerdan ketma-ket chiqadi '
                  '(masalan, kassa + oshxona). Naqd qutisi tanlangan printerda ochiladi.',
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.35),
                ),
                value: _secondaryPrinterEnabled,
                activeColor: AppTheme.primary,
                onChanged: _printers.isEmpty
                    ? null
                    : (v) => setState(() {
                          _secondaryPrinterEnabled = v;
                          if (!v) _secondarySelected = null;
                        }),
              ),
              if (_secondaryPrinterEnabled) ...[
                const SizedBox(height: 8),
                if (_secondaryPrinterOptions.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFDBA74)),
                    ),
                    child: const Text(
                      'Qo‘shimcha printer uchun boshqa printer kerak. Avval ikkinchi printerni tizimga ulang.',
                      style: TextStyle(color: Color(0xFF9A3412), fontSize: 13),
                    ),
                  )
                else
                  AppDropdownField<String>(
                    label: 'Qo‘shimcha printer',
                    hint: 'Ikkinchi printerni tanlang',
                    value: _secondarySelected,
                    items: _secondaryPrinterOptions
                        .map((n) => appDropdownItem(value: n, label: n))
                        .toList(),
                    onChanged: (v) => setState(() => _secondarySelected = v),
                  ),
              ],
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
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Chek chop etilganda naqd qutisini ochish',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Cash drawer printerning DK/RJ portiga ulangan bo‘lsa, sotuv cheki bilan birga ochiladi',
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.35),
                ),
                value: _openCashDrawerOnPrint,
                activeColor: AppTheme.primary,
                onChanged: (v) => setState(() => _openCashDrawerOnPrint = v),
              ),
              if (_openCashDrawerOnPrint) ...[
                const SizedBox(height: 8),
                SegmentedButton<CashDrawerPin>(
                  segments: const [
                    ButtonSegment(
                      value: CashDrawerPin.pin2,
                      label: Text('DK port 2'),
                      icon: Icon(Icons.point_of_sale_outlined, size: 18),
                    ),
                    ButtonSegment(
                      value: CashDrawerPin.pin5,
                      label: Text('DK port 5'),
                      icon: Icon(Icons.point_of_sale_outlined, size: 18),
                    ),
                  ],
                  selected: {_cashDrawerPin},
                  onSelectionChanged: (v) {
                    if (v.isEmpty) return;
                    setState(() => _cashDrawerPin = v.first);
                  },
                ),
                if (_secondaryPrinterEnabled && _secondarySelected != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Naqd qutisi qaysi printerda',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary.withValues(alpha: 0.85),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<CashDrawerPrinterTarget>(
                    segments: const [
                      ButtonSegment(
                        value: CashDrawerPrinterTarget.primary,
                        label: Text('Asosiy'),
                      ),
                      ButtonSegment(
                        value: CashDrawerPrinterTarget.secondary,
                        label: Text('Qo‘shimcha'),
                      ),
                    ],
                    selected: {_cashDrawerPrinterTarget},
                    onSelectionChanged: (v) {
                      if (v.isEmpty) return;
                      setState(() => _cashDrawerPrinterTarget = v.first);
                    },
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'DK/RJ kabeli ulangan printerni tanlang. Noto‘g‘ri tanlovda quti ochilmaydi.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary.withValues(alpha: 0.95),
                      height: 1.35,
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _testing ||
                            _selected == null ||
                            (_secondaryPrinterEnabled &&
                                (_secondarySelected == null ||
                                    _secondarySelected == _selected))
                        ? null
                        : _testPrint,
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
                    onPressed: _savePrinter,
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
      ],
    );
  }

  Widget _buildSalesTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionHeader(
          'Savdo sozlamalari',
          'Desktop sotuv ekranida mahsulotlar qanday ko‘rinishini tanlang. '
          'Restoran rejimida kategoriyalar qidiruv ostida gorizontal tugmalar, '
          'pastda mahsulotlar chiqadi.',
        ),
        const SizedBox(height: 20),
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<DesktopSalesLayoutMode>(
                segments: [
                  ButtonSegment(
                    value: DesktopSalesLayoutMode.standard,
                    label: Text(DesktopSalesLayoutSettings.modeLabel(DesktopSalesLayoutMode.standard)),
                    icon: const Icon(Icons.grid_view_rounded),
                  ),
                  ButtonSegment(
                    value: DesktopSalesLayoutMode.restaurant,
                    label: Text(DesktopSalesLayoutSettings.modeLabel(DesktopSalesLayoutMode.restaurant)),
                    icon: const Icon(Icons.restaurant_rounded),
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
        ),
        const SizedBox(height: 20),
        _sectionHeader(
          'Tezkor klavishlar',
          'Sotuv bo‘limida F-tugmalari orqali tez fokus o‘tish. '
          'Standart: F2 — mijoz, F7 — mahsulot, F5 — oxirgi miqdor, '
          'F12 — kelish narxini ko‘rsatish (faqat do‘kon rejimi), '
          'F6 — savat foydasini ko‘rsatish.',
        ),
        const SizedBox(height: 12),
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final action in SalesShortcutAction.values) ...[
                _shortcutKeyRow(action),
                if (action != SalesShortcutAction.values.last) const SizedBox(height: 12),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: _resetShortcutKeys,
                    icon: const Icon(Icons.restore_rounded, size: 20),
                    label: const Text('Standartga qaytarish'),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: _saveShortcutKeys,
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
      ],
    );
  }

  Widget _shortcutKeyRow(SalesShortcutAction action) {
    final current = _shortcutKeys[action] ?? SalesKeyboardShortcutsSettings.defaults[action]!;
    return Row(
      children: [
        Expanded(
          child: Text(
            SalesKeyboardShortcutsSettings.label(action),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
        SizedBox(
          width: 120,
          child: AppDropdownField<String>(
            label: 'Tugma',
            value: current,
            variant: AppDropdownVariant.compact,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            items: SalesKeyboardShortcutsSettings.allowedKeyIds
                .map(
                  (k) => appDropdownItem(
                    value: k,
                    label: SalesKeyboardShortcutsSettings.formatKeyLabel(k),
                  ),
                )
                .toList(),
            onChanged: (v) {
              if (v == null) return;
              setState(() => _shortcutKeys = {..._shortcutKeys, action: v});
            },
          ),
        ),
      ],
    );
  }

  Widget _buildProductTab() {
    final previewTitle = _showSkuInProductTitle ? 'Mahsulot nomi - 11195988' : 'Mahsulot nomi';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionHeader(
          'Mahsulot sozlamalari',
          'Katalog va sotuv ekranidagi mahsulot kartochkalari hamda tartib.',
        ),
        const SizedBox(height: 20),
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Mahsulot nomidan keyin SKU ko‘rsatish',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Yoqilganda kartochkada «Nom - SKU» ko‘rinishida chiqadi. '
                  'O‘chiq bo‘lsa faqat mahsulot nomi ko‘rsatiladi.',
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.35),
                ),
                value: _showSkuInProductTitle,
                activeColor: AppTheme.primary,
                onChanged: (v) => setState(() => _showSkuInProductTitle = v),
              ),
              const SizedBox(height: 20),
              const Text(
                'Mahsulotlar tartibi',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Text(
                'Sotuv bo‘limidagi mahsulotlar ro‘yxati qanday tartibda ko‘rsatiladi.',
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.35),
              ),
              const SizedBox(height: 12),
              ...ProductCatalogSortMode.values.map(
                (mode) => RadioListTile<ProductCatalogSortMode>(
                  contentPadding: EdgeInsets.zero,
                  value: mode,
                  groupValue: _productCatalogSortMode,
                  title: Text(ProductCatalogSortSettings.modeLabel(mode)),
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _productCatalogSortMode = v);
                  },
                ),
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ko‘rinish namunasi',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8EAED),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.image_not_supported_outlined, color: AppTheme.textSecondary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.inventory_2_outlined, size: 14, color: AppTheme.textSecondary),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      previewTitle,
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                '30 000 so\'m',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF16A34A),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: _saveProductDisplay,
                  icon: const Icon(Icons.save_rounded),
                  label: const Text('Saqlash'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReceiptTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionHeader(
          'Chek sozlamalari',
          'Matnlar standart. Faqat logo o‘zgartiriladi.',
        ),
        const SizedBox(height: 20),
        _card(child: ReceiptDesignEditorPanel(onSaved: _loadLocalReceiptPreview)),
        const SizedBox(height: 20),
        _buildReceiptPreviewCard(),
      ],
    );
  }

  Widget _sectionHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: const TextStyle(color: AppTheme.textSecondary, height: 1.4, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildReceiptPreviewCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
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
            'Chek serverdan emas — dastur o\'zi yig\'adi (savatcha, to\'lov, kassa X-otchot) va shu formatda termal printerga yuboriladi.',
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
            LayoutBuilder(
              builder: (context, c) {
                final threeAcross = c.maxWidth > 1040;
                final twoAcross = c.maxWidth > 680;
                final standard = _previewColumn(
                  title: "Do'kon sotuv cheki",
                  subtitle: 'Logo va matn printer tartibida',
                  child: SingleChildScrollView(
                    child: Center(
                      child: ReceiptLinesPreview(
                        lines: _sampleLines,
                        design: _receiptDesign,
                      ),
                    ),
                  ),
                );
                final restaurant = _previewColumn(
                  title: 'Restoran cheki',
                  subtitle: 'Navbat raqami bilan (restoran rejimi)',
                  child: SingleChildScrollView(
                    child: Center(
                      child: ReceiptLinesPreview(
                        lines: _restaurantSampleLines,
                        design: _receiptDesign,
                      ),
                    ),
                  ),
                );
                final xReport = _previewColumn(
                  title: 'Kassa X-otchot',
                  subtitle: 'Kassa smenalari → Chop etish',
                  child: SingleChildScrollView(
                    child: Center(
                      child: ReceiptLinesPreview(
                        lines: _xReportSampleLines,
                        design: _receiptDesign.copyWith(showLogo: false),
                      ),
                    ),
                  ),
                );
                if (threeAcross) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: standard),
                      const SizedBox(width: 16),
                      Expanded(child: restaurant),
                      const SizedBox(width: 16),
                      Expanded(child: xReport),
                    ],
                  );
                }
                if (twoAcross) {
                  return Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: standard),
                          const SizedBox(width: 16),
                          Expanded(child: restaurant),
                        ],
                      ),
                      const SizedBox(height: 16),
                      xReport,
                    ],
                  );
                }
                return Column(
                  children: [
                    standard,
                    const SizedBox(height: 16),
                    restaurant,
                    const SizedBox(height: 16),
                    xReport,
                  ],
                );
              },
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
