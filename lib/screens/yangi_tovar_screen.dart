import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../core/app_notify.dart';
import '../core/constants.dart';
import '../core/input_formatters.dart';
import '../core/theme.dart';
import '../models/product.dart';
import '../providers/products_provider.dart';
import '../providers/categories_provider.dart';
import '../services/api_service.dart';
import 'scanner_screen.dart' show showCompactScanner;
import '../widgets/ios_style_modals.dart';

class YangiTovarScreen extends StatefulWidget {
  final Product? product;

  const YangiTovarScreen({super.key, this.product});

  @override
  State<YangiTovarScreen> createState() => _YangiTovarScreenState();
}

class _YangiTovarScreenState extends State<YangiTovarScreen> {
  final _nameController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _additionalBarcode1Controller = TextEditingController();
  final _additionalBarcode2Controller = TextEditingController();
  final _additionalBarcodesController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _costPriceController = TextEditingController();
  final _sellPriceController = TextEditingController();
  final _initialQtyController = TextEditingController();
  final _quantityPerPackController = TextEditingController(text: '1');
  final _costPricePerPackController = TextEditingController();
  final _sellPricePerPackController = TextEditingController();

  String _unit = 'dona';
  String _category = 'Tanlanmagan';
  bool _quantityInPack = false;
  bool _addInitialQuantity = true;
  String? _imagePath;
  /// API: `purchasePriceCurrency` / `sellingPriceCurrency` — `uzs` yoki `usd`
  String _purchaseCurrency = 'uzs';
  String _sellingCurrency = 'uzs';
  bool _isSaving = false;

  /// API dan yuklangan birlik nomlari (supporting-data); bo'sh bo'lsa fallback
  List<String> _unitNames = [];
  static const _unitsFallback = ['dona', 'kg', 'pachka'];
  List<String> get _units => _unitNames.isNotEmpty ? _unitNames : _unitsFallback;
  List<String> get _categories => CategoriesProvider.instance.items;

  @override
  void initState() {
    super.initState();
    CategoriesProvider.instance.addListener(_onCategoriesChanged);
    CategoriesProvider.instance.loadFromStorage();
    _loadUnitsFromApi();
    final p = widget.product;
    if (p != null) {
      _nameController.text = p.name;
      _barcodeController.text = p.barcode ?? '';
      final ab = p.additionalBarcodes ?? [];
      if (ab.isNotEmpty) _additionalBarcode1Controller.text = ab[0];
      if (ab.length >= 2) _additionalBarcode2Controller.text = ab[1];
      if (ab.length > 2) _additionalBarcodesController.text = ab.sublist(2).join(', ');
      _descriptionController.text = p.description ?? '';
      _purchaseCurrency = p.purchasePriceCurrency.toLowerCase();
      _sellingCurrency = p.sellingPriceCurrency.toLowerCase();
      _costPriceController.text = _priceFieldInitial(
        currency: _purchaseCurrency,
        api: p.purchasePriceApi,
        uzsInt: p.costPriceUzs,
      );
      _sellPriceController.text = _priceFieldInitial(
        currency: _sellingCurrency,
        api: p.sellingPriceApi,
        uzsInt: p.priceUzs,
      );
      _initialQtyController.text = p.initialQuantity > 0 ? p.initialQuantity.toString() : '';
      _unit = p.unit ?? 'dona';
      _category = p.category ?? Strings.tanlanmagan;
      _quantityInPack = p.quantityInPack;
      _addInitialQuantity = p.initialQuantity > 0;
      _imagePath = p.imageUrl;
      _quantityPerPackController.text = p.quantityPerPack > 0 ? p.quantityPerPack.toString() : '1';
      _costPricePerPackController.text = p.costPricePerPack != null && p.costPricePerPack! > 0 ? formatThousands(p.costPricePerPack!) : '';
      _sellPricePerPackController.text = p.sellPricePerPack != null && p.sellPricePerPack! > 0 ? formatThousands(p.sellPricePerPack!) : '';
      // Tahrirlashda pachka narxlari ro'yxatda bo'lmasa, bitta mahsulot API dan yuklab to'ldiramiz
      _loadFullProductForEdit(p);
    }
  }

  /// Tahrirlashda GET /products/{id} dan pachka narxlari va boshqa maydonlarni to'ldirish
  void _loadFullProductForEdit(Product p) {
    final idNum = int.tryParse(p.id);
    if (idNum == null) return;
    Future.microtask(() async {
      try {
        final res = await ProductsApi.getProduct(idNum);
        final raw = res['data'] ?? res['product'] ?? res;
        if (raw is! Map<String, dynamic> || raw.isEmpty) return;
        final full = Product.fromApiJson(Map<String, dynamic>.from(raw), unitIdToName: null);
        if (!mounted) return;
        setState(() {
          _purchaseCurrency = full.purchasePriceCurrency.toLowerCase();
          _sellingCurrency = full.sellingPriceCurrency.toLowerCase();
          _costPriceController.text = _priceFieldInitial(
            currency: _purchaseCurrency,
            api: full.purchasePriceApi,
            uzsInt: full.costPriceUzs,
          );
          _sellPriceController.text = _priceFieldInitial(
            currency: _sellingCurrency,
            api: full.sellingPriceApi,
            uzsInt: full.priceUzs,
          );
          if (full.quantityInPack || full.quantityPerPack > 1 || full.sellPricePerPack != null || full.costPricePerPack != null) {
            _quantityInPack = true;
          }
          if (full.quantityPerPack > 0) {
            _quantityPerPackController.text = full.quantityPerPack.toString();
          }
          if (full.costPricePerPack != null && full.costPricePerPack! > 0) {
            _costPricePerPackController.text = formatThousands(full.costPricePerPack!);
          }
          if (full.sellPricePerPack != null && full.sellPricePerPack! > 0) {
            _sellPricePerPackController.text = formatThousands(full.sellPricePerPack!);
          }
        });
      } catch (_) {}
    });
  }

  /// API supporting-data dan birliklar — API qanday nomlar yuborsa shunday ko'rsatiladi
  Future<void> _loadUnitsFromApi() async {
    try {
      final res = await ProductsApi.getSupportingData();
      // Ro'yxat: units, data.units, unit_list, data.unit_list yoki to'g'ridan-to'g'ri massiv
      List<dynamic> raw = res['units'] as List<dynamic>? ?? res['data']?['units'] as List<dynamic>? ?? [];
      if (raw.isEmpty) raw = res['unit_list'] as List<dynamic>? ?? res['data']?['unit_list'] as List<dynamic>? ?? [];
      if (raw.isEmpty && res['data'] is Map) {
        final data = res['data'] as Map<String, dynamic>;
        raw = data['units'] as List<dynamic>? ?? data['unit_list'] as List<dynamic>? ?? [];
      }
      final names = <String>[];
      for (final e in raw) {
        if (e is String && e.trim().isNotEmpty) {
          names.add(e.trim());
          continue;
        }
        if (e is! Map) continue;
        final m = Map<String, dynamic>.from(e as Map);
        // Yangi mahsulotda to'liq nom ko'rsatiladi: name (to'liq) birinchi, keyin short_name
        final name = m['name'] ?? m['title'] ?? m['unit_name'] ?? m['short_name'] ?? m['shortname'] ?? m['label'] ?? m['value'] ?? m['unit'] ?? m['name_uz'] ?? m['name_ru'] ?? m['title_uz'];
        if (name != null && name.toString().trim().isNotEmpty) {
          names.add(name.toString().trim());
        } else if (m['id'] != null) {
          names.add(m['id'].toString());
        }
      }
      if (mounted) {
        setState(() {
          _unitNames = names;
          if (widget.product == null && names.isNotEmpty && !names.contains(_unit)) {
            _unit = names.first;
          }
          // Tahrirlashda: mahsulotda qisqartma keladi (product.unit) — ro'yxatdan to'liq nomni tanlash
          if (widget.product != null && _unit.trim().isNotEmpty) {
            final lower = _unit.toLowerCase();
            String? match;
            for (final n in names) {
              if (n.toLowerCase() == lower) { match = n; break; }
            }
            if (match != null) _unit = match;
            else if (!names.any((n) => n.toLowerCase() == lower)) {
              _unitNames = [...names, _unit];
            }
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _unitNames = []);
    }
  }

  void _onCategoriesChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    CategoriesProvider.instance.removeListener(_onCategoriesChanged);
    _nameController.dispose();
    _barcodeController.dispose();
    _additionalBarcode1Controller.dispose();
    _additionalBarcode2Controller.dispose();
    _additionalBarcodesController.dispose();
    _descriptionController.dispose();
    _costPriceController.dispose();
    _sellPriceController.dispose();
    _initialQtyController.dispose();
    _quantityPerPackController.dispose();
    _costPricePerPackController.dispose();
    _sellPricePerPackController.dispose();
    super.dispose();
  }

  void _generateBarcode() {
    final random = DateTime.now().millisecondsSinceEpoch % 1000000000000;
    final base = random.toString().padLeft(12, '0').substring(0, 12);
    int sum = 0;
    for (var i = 0; i < 12; i++) {
      final d = int.parse(base[i]);
      sum += (i.isOdd ? d * 3 : d);
    }
    final check = (10 - (sum % 10)) % 10;
    setState(() => _barcodeController.text = '$base$check');
  }

  void _openBarcodeScanner() {
    showCompactScanner(context, onResult: (barcode) {
      if (barcode != null && barcode.isNotEmpty && mounted) {
        setState(() => _barcodeController.text = barcode);
      }
    });
  }

  void _openBarcodeScannerFor(void Function(String) onResult) {
    showCompactScanner(context, onResult: (barcode) {
      if (barcode != null && barcode.isNotEmpty && mounted) {
        setState(() => onResult(barcode));
      }
    });
  }

  void _showImageSourcePicker() {
    IosStyleModals.showSheet(
      context: context,
      showGrabber: true,
      child: Builder(
        builder: (sheetCtx) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: AppTheme.primary),
              title: const Text("Kameradan olish"),
              onTap: () async {
                Navigator.pop(sheetCtx);
                await _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: AppTheme.primary),
              title: const Text("Galereyadan tanlash"),
              onTap: () async {
                Navigator.pop(sheetCtx);
                await _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final xFile = await picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 88,
        requestFullMetadata: false,
      );
      if (!mounted) return;
      if (xFile != null) {
        setState(() => _imagePath = xFile.path);
      }
    } catch (e) {
      if (mounted) {
        AppNotify.warning(
          context,
          "Rasm tanlanmadi. Galereya/kamera ruxsatini tekshiring (Sozlamalar → Ilova). Xato: $e",
          duration: const Duration(seconds: 5),
        );
      }
    }
  }

  /// Narx matnidan son olish (probel, vergul, "so'm" va b. dan tozalab)
  static int _parsePrice(String? s, [int fallback = 0]) {
    if (s == null || s.trim().isEmpty) return fallback;
    String cleaned = s.replaceAll(RegExp(r'[\s\u00a0]'), '').replaceAll(RegExp(r"so'm|sum|uzs", caseSensitive: false), '');
    cleaned = cleaned.replaceAll(',', '').replaceAll(' ', '');
    return int.tryParse(cleaned) ?? fallback;
  }

  /// USD: nuqta/vergul bilan o'nlik
  static double? _parseUsd(String? s) {
    if (s == null || s.trim().isEmpty) return null;
    var t = s.replaceAll(RegExp(r'[\s\u00a0]'), '').replaceAll(RegExp(r'\$|usd', caseSensitive: false), '');
    t = t.replaceAll(',', '.');
    if (t.split('.').length > 2) return null;
    return double.tryParse(t);
  }

  static String _formatUsdForField(num n) {
    final d = n.toDouble();
    if (d == d.roundToDouble()) return '${d.round()}';
    var s = d.toStringAsFixed(4);
    s = s.replaceFirst(RegExp(r'0+$'), '');
    s = s.replaceFirst(RegExp(r'\.$'), '');
    return s;
  }

  static String _priceFieldInitial({
    required String currency,
    required num? api,
    required int? uzsInt,
  }) {
    final u = uzsInt ?? 0;
    if (currency == 'usd' && api != null) return _formatUsdForField(api);
    if (currency == 'usd') return u > 0 ? _formatUsdForField(u) : '';
    return u > 0 ? formatThousands(u) : '';
  }

  /// Miqdor matnidan son (probel, vergul olib tashlanadi)
  static int _parseQty(String? s, [int fallback = 0]) {
    if (s == null || s.trim().isEmpty) return fallback;
    final cleaned = s.replaceAll(RegExp(r'[\s\u00a0]'), '').replaceAll(',', '');
    return int.tryParse(cleaned) ?? fallback;
  }

  Future<void> _save() async {
    if (_isSaving) return;
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      AppNotify.info(context, "Mahsulot nomini kiriting");
      return;
    }
    final existing = widget.product;
    late final num sellForApi;
    late final int sellDisplayInt;
    if (_sellingCurrency == 'usd') {
      final d = _parseUsd(_sellPriceController.text) ?? 0;
      if (d <= 0) {
        AppNotify.info(context, "Sotish narxini kiriting (USD)");
        return;
      }
      sellForApi = d;
      sellDisplayInt = d.round();
    } else {
      final sellPrice = _parsePrice(_sellPriceController.text, existing?.priceUzs ?? 0);
      if (sellPrice <= 0) {
        AppNotify.info(context, "Sotish narxini kiriting");
        return;
      }
      sellForApi = sellPrice;
      sellDisplayInt = sellPrice;
    }
    if (_quantityInPack) {
      final qtyPerPack = _parseQty(_quantityPerPackController.text, 0);
      final sellPerPack = _parsePrice(_sellPricePerPackController.text, 0);
      if (qtyPerPack <= 1 || sellPerPack <= 0) {
        AppNotify.info(context, "Pachkada 2 yoki undan ortiq dona va pachka sotish narxini kiriting");
        return;
      }
    }
    num? purchaseForApi;
    int? costDisplayInt;
    final costText = _costPriceController.text.trim();
    if (costText.isEmpty) {
      purchaseForApi = null;
      costDisplayInt = null;
    } else if (_purchaseCurrency == 'usd') {
      final d = _parseUsd(_costPriceController.text);
      if (d == null) {
        AppNotify.info(context, "Kelish narxi noto'g'ri (USD)");
        return;
      }
      purchaseForApi = d;
      costDisplayInt = d.round();
    } else {
      final costPrice = _parsePrice(_costPriceController.text, existing?.costPriceUzs ?? 0);
      purchaseForApi = costPrice;
      costDisplayInt = costPrice > 0 ? costPrice : null;
    }
    // Tahrirlashda miqdor o'zgartirilmaydi — faqat mavjud qiymat saqlanadi
    final initialQty = existing != null
        ? existing!.initialQuantity
        : _parseQty(_initialQtyController.text, 0);
    final qtyPerPack = _parseQty(_quantityPerPackController.text, 0);
    // Pachka narxlari — faqat pachka maydonlaridan (dona narxlari emas)
    final costPerPack = _parsePrice(_costPricePerPackController.text, 0);
    final sellPerPack = _parsePrice(_sellPricePerPackController.text, 0);
    final qtyInfo = _addInitialQuantity && initialQty > 0
        ? '$initialQty $_unit'
        : '0 $_unit';

    final productId = existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString();
    // Rasm lokal saqlanmaydi — API ga yuborishda faqat vaqtincha fayl yo'li (_imagePath) ishlatiladi.
    final savedImagePath = _imagePath;
    final ab1 = _additionalBarcode1Controller.text.trim();
    final ab2 = _additionalBarcode2Controller.text.trim();
    final abRest = _additionalBarcodesController.text
        .split(RegExp(r'[,\s]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final additionalBarcodesRaw = [ab1, ab2, ...abRest].where((e) => e.isNotEmpty).toList();
    final product = Product(
      id: productId,
      name: name,
      sku: existing?.sku,
      barcode: _barcodeController.text.trim().isEmpty ? null : _barcodeController.text.trim(),
      additionalBarcodes: additionalBarcodesRaw.isNotEmpty ? additionalBarcodesRaw : null,
      priceUzs: sellDisplayInt,
      costPriceUzs: costDisplayInt,
      sellingPriceCurrency: _sellingCurrency,
      purchasePriceCurrency: _purchaseCurrency,
      sellingPriceApi: _sellingCurrency == 'usd' ? sellForApi : null,
      purchasePriceApi: (_purchaseCurrency == 'usd' && purchaseForApi != null) ? purchaseForApi : null,
      quantityInfo: qtyInfo,
      unit: _unit,
      category: _category == Strings.tanlanmagan ? null : _category,
      description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
      quantityInPack: _quantityInPack && qtyPerPack > 1,
      quantityPerPack: (_quantityInPack && qtyPerPack > 1) ? qtyPerPack : 0,
      costPricePerPack: (_quantityInPack && qtyPerPack > 1) ? costPerPack : null,
      sellPricePerPack: (_quantityInPack && qtyPerPack > 1) ? sellPerPack : null,
      reorderLevel: 0,
      initialQuantity: initialQty,
      imageUrl: savedImagePath ?? _imagePath,
    );

    setState(() => _isSaving = true);
    try {
      if (existing != null) {
        await ProductsProvider.instance.updateProduct(product);
      } else {
        await ProductsProvider.instance.addProduct(product);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) AppNotify.error(context, 'Xatolik: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isSaving,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
          ),
          title: Text(widget.product != null ? "Mahsulotni tahrirlash" : Strings.yangiMahsulotQoshish),
          centerTitle: true,
        ),
        body: Stack(
          children: [
            SafeArea(
              top: false,
              bottom: true,
              child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).padding.bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: Strings.nomi,
                hintText: Strings.tovarNomi,
              ),
            ),
            const SizedBox(height: 16),
            _rowChoice(
              label: Strings.olchovBirlik,
              value: _unit,
              onTap: () => _showChoice(Strings.olchovBirlik, _units, (v) => setState(() => _unit = v)),
            ),
            const SizedBox(height: 16),
            _rowWithAdd(
              label: Strings.kategoriya,
              value: _category,
              onTap: () => _showChoice(Strings.kategoriya, [Strings.tanlanmagan, ..._categories], (v) => setState(() => _category = v)),
              onAdd: () => _showAddCategoryDialog(),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Material(
                  color: AppTheme.primaryLight,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    onTap: _generateBarcode,
                    borderRadius: BorderRadius.circular(10),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.qr_code_2_rounded, color: AppTheme.primary, size: 20),
                          SizedBox(width: 6),
                          Text("Yaratish", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.primary)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _barcodeController,
                    readOnly: true,
                    onTap: _openBarcodeScanner,
                    decoration: const InputDecoration(
                      labelText: Strings.shtrixKod,
                      hintText: "Skaner uchun bosing",
                      suffixIcon: Icon(Icons.qr_code_scanner_rounded, color: AppTheme.textSecondary, size: 22),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _additionalBarcode1Controller,
              decoration: InputDecoration(
                labelText: "Qo'shimcha shtrix kod 1",
                hintText: "Kiriting yoki skaner bosing",
                suffixIcon: IconButton(
                  icon: const Icon(Icons.qr_code_scanner_rounded, color: AppTheme.textSecondary, size: 22),
                  onPressed: () => _openBarcodeScannerFor((v) => _additionalBarcode1Controller.text = v),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _additionalBarcode2Controller,
              decoration: InputDecoration(
                labelText: "Qo'shimcha shtrix kod 2",
                hintText: "Kiriting yoki skaner bosing",
                suffixIcon: IconButton(
                  icon: const Icon(Icons.qr_code_scanner_rounded, color: AppTheme.textSecondary, size: 22),
                  onPressed: () => _openBarcodeScannerFor((v) => _additionalBarcode2Controller.text = v),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _additionalBarcodesController,
              decoration: const InputDecoration(
                labelText: "Yana qo'shimcha (vergul bilan, ixtiyoriy)",
                hintText: "4601234567893, 4601234567894",
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              Strings.tavsif,
              style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: Strings.tavsif,
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),
            _imageUploadArea(),
            const SizedBox(height: 20),
            const Text(
              Strings.narxlari,
              style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 12),
            _priceFieldWithCurrency(
              label: Strings.kelishNarxi,
              controller: _costPriceController,
              currency: _purchaseCurrency,
              onCurrency: (v) => setState(() => _purchaseCurrency = v),
            ),
            const SizedBox(height: 12),
            _priceFieldWithCurrency(
              label: Strings.sotuvNarxi,
              controller: _sellPriceController,
              currency: _sellingCurrency,
              onCurrency: (v) => setState(() => _sellingCurrency = v),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  Strings.pachkadaMiqdori,
                  style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                ),
                CupertinoSwitch(
                  value: _quantityInPack,
                  onChanged: (v) => setState(() => _quantityInPack = v),
                  activeColor: AppTheme.primary,
                ),
              ],
            ),
            if (_quantityInPack) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _quantityPerPackController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "1 pachkada nechta (dona)",
                  hintText: "12",
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _costPricePerPackController,
                keyboardType: TextInputType.number,
                inputFormatters: [ThousandsInputFormatter()],
                decoration: const InputDecoration(
                  labelText: "Pachka kelish narxi",
                  suffixText: Strings.som,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _sellPricePerPackController,
                keyboardType: TextInputType.number,
                inputFormatters: [ThousandsInputFormatter()],
                decoration: const InputDecoration(
                  labelText: "Pachka sotish narxi",
                  suffixText: Strings.som,
                ),
              ),
            ],
            const SizedBox(height: 20),
            // Tahrirlashda miqdor ko'rsatilmaydi va o'zgartirilmaydi (faqat yangi mahsulotda)
            if (widget.product == null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    Strings.boshlangichMiqdorQoshish,
                    style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                  ),
                  CupertinoSwitch(
                    value: _addInitialQuantity,
                    onChanged: (v) => setState(() => _addInitialQuantity = v),
                    activeColor: AppTheme.primary,
                  ),
                ],
              ),
              if (_addInitialQuantity) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _initialQtyController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: Strings.miqdori,
                    hintText: '0',
                  ),
                ),
              ],
            ],
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: CupertinoButton(
                    onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    color: AppTheme.cardBg,
                    borderRadius: BorderRadius.circular(12),
                    child: Text(
                      Strings.bekorQilish,
                      style: TextStyle(
                        color: _isSaving ? AppTheme.textSecondary : AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CupertinoButton(
                    onPressed: _isSaving ? null : _save,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(12),
                    child: _isSaving
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            Strings.saqlash,
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                          ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
            ),
            ),
            if (_isSaving) ...[
              ModalBarrier(
                color: Colors.black.withValues(alpha: 0.35),
                dismissible: false,
              ),
              const Center(
                child: Card(
                  elevation: 6,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 28, vertical: 22),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 36,
                          height: 36,
                          child: CircularProgressIndicator(strokeWidth: 3, color: AppTheme.primary),
                        ),
                        SizedBox(height: 14),
                        Text(
                          'Saqlanmoqda…',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Narx maydoni + UZS/USD bir qatorda, bir xil balandlikda
  Widget _priceFieldWithCurrency({
    required String label,
    required TextEditingController controller,
    required String currency,
    required ValueChanged<String> onCurrency,
  }) {
    final isUsd = currency.toLowerCase() == 'usd';
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
        const SizedBox(height: 8),
        DecoratedBox(
          decoration: BoxDecoration(
            color: AppTheme.cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.divider),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: isUsd
                      ? const TextInputType.numberWithOptions(decimal: true)
                      : TextInputType.number,
                  inputFormatters: isUsd ? <TextInputFormatter>[] : [ThousandsInputFormatter()],
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    hintText: isUsd ? 'Masalan: 1.25' : null,
                    suffixText: isUsd ? 'USD' : Strings.som,
                    suffixStyle: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                  ),
                ),
              ),
              Container(
                width: 1,
                height: 36,
                color: AppTheme.divider,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _currencyChip(
                      label: 'UZS',
                      selected: !isUsd,
                      onTap: () => onCurrency('uzs'),
                    ),
                    const SizedBox(width: 4),
                    _currencyChip(
                      label: 'USD',
                      selected: isUsd,
                      onTap: () => onCurrency('usd'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _currencyChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppTheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? AppTheme.primary : AppTheme.divider,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : AppTheme.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _rowChoice({required String label, required String value, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: AppTheme.textSecondary)),
            Row(
              children: [
                Text(value, style: const TextStyle(color: AppTheme.textSecondary)),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppTheme.primary),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _rowWithAdd({required String label, required String value, required VoidCallback onTap, VoidCallback? onAdd}) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppTheme.cardBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(label, style: const TextStyle(color: AppTheme.textSecondary)),
                  Row(
                    children: [
                      Text(value, style: const TextStyle(color: AppTheme.textSecondary)),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppTheme.primary),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Material(
          color: AppTheme.primary,
          borderRadius: BorderRadius.circular(12),
          child: IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: onAdd,
          ),
        ),
      ],
    );
  }

  void _showAddCategoryDialog() {
    final controller = TextEditingController();
    IosStyleModals.showSheet<void>(
      context: context,
      isScrollControlled: true,
      showGrabber: true,
      child: Builder(
        builder: (ctx) => SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + MediaQuery.viewInsetsOf(ctx).bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(Strings.yangiKategoriya, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Kategoriya nomi',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text(Strings.bekorQilish),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () async {
                        final name = controller.text.trim();
                        if (name.isNotEmpty) {
                          await CategoriesProvider.instance.addCategory(name);
                          if (ctx.mounted) Navigator.pop(ctx);
                          setState(() => _category = name);
                        }
                      },
                      child: const Text(Strings.saqlash),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _imageUploadArea() {
    final hasImage = _imagePath != null && _imagePath!.isNotEmpty && File(_imagePath!).existsSync();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Mahsulot rasmi',
          style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
        ),
        const SizedBox(height: 8),
        Material(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: _showImageSourcePicker,
            child: Container(
              height: hasImage ? 168 : 100,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.divider),
              ),
              child: hasImage
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.file(
                          File(_imagePath!),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Center(
                            child: Icon(Icons.broken_image_outlined, color: AppTheme.textSecondary, size: 48),
                          ),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            color: Colors.black.withValues(alpha: 0.45),
                            child: const Text(
                              'Almashtirish uchun bosing',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 6,
                          right: 6,
                          child: Material(
                            color: Colors.black54,
                            shape: const CircleBorder(),
                            clipBehavior: Clip.antiAlias,
                            child: IconButton(
                              icon: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
                              onPressed: () => setState(() => _imagePath = null),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate_outlined, size: 32, color: AppTheme.primary.withValues(alpha: 0.9)),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Text(
                              'Galereya yoki kameradan rasm qo‘shish',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: AppTheme.textSecondary,
                                height: 1.25,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  void _showChoice(String title, List<String> options, ValueChanged<String> onSelect) {
    IosStyleModals.showSheet(
      context: context,
      showGrabber: true,
      child: Builder(
        builder: (sheetCtx) {
          final maxHeight = MediaQuery.of(sheetCtx).size.height * 0.68;
          return ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 8),
                    itemCount: options.length,
                    itemBuilder: (_, i) {
                      final s = options[i];
                      return ListTile(
                        title: Text(s),
                        onTap: () {
                          onSelect(s);
                          Navigator.pop(sheetCtx);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
