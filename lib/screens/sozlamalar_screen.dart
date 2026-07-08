import 'package:flutter/material.dart';

import '../core/app_notify.dart';
import '../core/theme.dart';
import '../services/product_catalog_sort_settings.dart';
import '../services/product_display_settings.dart';
import '../services/sales_cart_profit_display_settings.dart';
/// Mobil: savdo va mahsulot sozlamalari (desktop bilan bir xil SharedPreferences).
class SozlamalarScreen extends StatefulWidget {
  const SozlamalarScreen({super.key});

  @override
  State<SozlamalarScreen> createState() => _SozlamalarScreenState();
}

class _SozlamalarScreenState extends State<SozlamalarScreen> {
  bool _loading = true;
  bool _showCartProfit = false;
  bool _showSkuInProductTitle = false;
  ProductCatalogSortMode _productCatalogSortMode = ProductCatalogSortMode.defaultOrder;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final profit = await SalesCartProfitDisplaySettings.getVisible();
      final sku = await ProductDisplaySettings.getShowSkuInTitle();
      final sort = await ProductCatalogSortSettings.getMode();
      if (!mounted) return;
      setState(() {
        _showCartProfit = profit;
        _showSkuInProductTitle = sku;
        _productCatalogSortMode = sort;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        AppNotify.error(context, 'Sozlamalar: $e');
      }
    }
  }

  Future<void> _saveCartProfit(bool value) async {
    await SalesCartProfitDisplaySettings.setVisible(value);
    if (!mounted) return;
    setState(() => _showCartProfit = value);
    AppNotify.success(
      context,
      value ? 'Savat foydasi ko‘rsatiladi' : 'Savat foydasi yashirildi',
    );
  }

  Future<void> _saveProductSettings() async {
    await ProductDisplaySettings.setShowSkuInTitle(_showSkuInProductTitle);
    await ProductCatalogSortSettings.setMode(_productCatalogSortMode);
    if (!mounted) return;
    AppNotify.success(
      context,
      'Mahsulot sozlamalari saqlandi — '
      '${ProductCatalogSortSettings.modeLabel(_productCatalogSortMode)}',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sozlamalar'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _sectionTitle('Savdo'),
                _card(
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Savatda foyda foizini ko‘rsatish',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: const Text(
                        'Savatcha pastida «Umumiy» yonida foyda % ko‘rinadi.',
                        style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.35),
                      ),
                      value: _showCartProfit,
                      activeColor: AppTheme.primary,
                      onChanged: _saveCartProfit,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _sectionTitle('Mahsulotlar'),
                _card(
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Mahsulot nomidan keyin SKU ko‘rsatish',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: const Text(
                        'Katalog va qidiruv natijalarida «Nom - SKU» ko‘rinishi.',
                        style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.35),
                      ),
                      value: _showSkuInProductTitle,
                      activeColor: AppTheme.primary,
                      onChanged: (v) => setState(() => _showSkuInProductTitle = v),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Mahsulotlar tartibi',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
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
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _saveProductSettings,
                        icon: const Icon(Icons.save_rounded),
                        label: const Text('Saqlash'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppTheme.textSecondary,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _card({required List<Widget> children}) {
    return Material(
      color: AppTheme.cardBg,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
}
