import '../core/product_image_utils.dart';
import '../utils/product_weight.dart';
import '../utils/scale_barcode.dart';

class Product {
  final String id;
  final String name;
  final String? imageUrl;
  final int priceUzs; // sotish narxi (dona)
  final int? costPriceUzs; // kelish narxi (dona)
  final String? sku;
  final String? barcode;
  /// API: `plu_code` — tarozi / PLU (max 10).
  final String? pluCode;
  /// API: additionalBarcodes / additional_barcodes — 2 yoki undan ortiq qo'shimcha shtrix kodlar
  final List<String>? additionalBarcodes;
  /// API: default variant ID (variants[].id) — sales/store da variantID sifatida yuborish uchun
  final int? variantId;
  final String quantityInfo;
  final String? unit; // dona, kg, pachka
  final String? category;
  final String? categoryId;
  final String? brandId;
  final String? brand;
  final String? description;
  final bool quantityInPack; // pachka mavjud: API da units_per_package > 1
  final int quantityPerPack; // 1 pachkada nechta dona (API: units_per_package)
  final int? costPricePerPack; // pachka kelish narxi (API: package_purchase_price)
  final int? sellPricePerPack; // pachka sotish narxi (API: package_selling_price)
  final int? wholesalePriceUzs; // ulgurji narx (dona) — API da faqat dona
  final int reorderLevel;
  final int initialQuantity; // ombor miqdori (dona)

  /// API: `sellingPriceCurrency` — `uzs` | `usd`
  final String sellingPriceCurrency;
  /// API: `purchasePriceCurrency` — `uzs` | `usd`
  final String purchasePriceCurrency;
  /// USD yoki o'nlik sotish narxi bo'lsa API qiymati; null bo'lsa [priceUzs] ishlatiladi
  final num? sellingPriceApi;
  /// USD yoki o'nlik kirim narxi; null bo'lsa [costPriceUzs]
  final num? purchasePriceApi;
  /// API: `wholesalePriceCurrency` — `uzs` | `usd`
  final String wholesalePriceCurrency;
  /// USD yoki o'nlik ulgurji narxi; null bo'lsa [wholesalePriceUzs]
  final num? wholesalePriceApi;
  /// API: `weight` — 1 dona og'irligi (kg), nullable.
  final double? weightKg;

  const Product({
    required this.id,
    required this.name,
    this.imageUrl,
    required this.priceUzs,
    this.costPriceUzs,
    this.sku,
    this.barcode,
    this.pluCode,
    this.additionalBarcodes,
    this.variantId,
    this.quantityInfo = '0 sht',
    this.unit,
    this.category,
    this.categoryId,
    this.brandId,
    this.brand,
    this.description,
    this.quantityInPack = false,
    this.quantityPerPack = 0,
    this.costPricePerPack,
    this.sellPricePerPack,
    this.wholesalePriceUzs,
    this.reorderLevel = 0,
    this.initialQuantity = 0,
    this.sellingPriceCurrency = 'uzs',
    this.purchasePriceCurrency = 'uzs',
    this.sellingPriceApi,
    this.purchasePriceApi,
    this.wholesalePriceCurrency = 'uzs',
    this.wholesalePriceApi,
    this.weightKg,
  });

  /// Ombordagi mavjud miqdor (dona).
  int get availableStockQuantity {
    if (initialQuantity != 0) return initialQuantity;
    final m = RegExp(r'(-?\d+)').firstMatch(quantityInfo);
    if (m != null) {
      final n = int.tryParse(m.group(1)!);
      if (n != null) return n;
    }
    return initialQuantity;
  }

  bool get hasStock => availableStockQuantity > 0;

  /// Sotuv katalog kartochkasi: «Nomi - SKU» (SKU bo‘lmasa faqat nom).
  String get nameWithSku {
    final s = (sku ?? '').trim();
    if (s.isEmpty) return name;
    return '$name - $s';
  }

  /// UI uchun tozalangan birlik (API Map yoki saqlangan xom matn emas).
  String get unitDisplayLabel => Product.sanitizeUnitLabel(unit) ?? 'dona';

  /// Ombor qatori: «12 dona» — hech qachon xom JSON ko‘rinmaydi.
  String get stockDisplayText => '$availableStockQuantity $unitDisplayLabel';

  /// 1 dona sotish narxi
  num get pieceSellPriceNum => sellingPriceApi ?? priceUzs;

  /// 1 pachka sotish narxi (pachka yo'q bo'lsa null)
  num? get packSellUnitPriceNum {
    if (quantityInPack && quantityPerPack > 1 && sellPricePerPack != null && sellPricePerPack! > 0) {
      return sellPricePerPack;
    }
    return null;
  }

  /// Sotuvda pachka yoki dona tanlash mumkinmi
  bool get canSellByPack => packSellUnitPriceNum != null;

  /// Eski: pachka ustunlik. UI ro‘yxatlarida [pieceSellPriceNum] ishlating.
  num get sellUnitPriceNum => packSellUnitPriceNum ?? pieceSellPriceNum;

  /// Dona sotish narxi (yaxlitlangan)
  int get effectiveSellPrice => pieceSellPriceNum.round();

  /// Dona ulgurji narxi (yo'q bo'lsa sotish narxi).
  num get wholesalePiecePriceNum {
    if (wholesalePriceUzs != null && wholesalePriceUzs! > 0) return wholesalePriceUzs!;
    return pieceSellPriceNum;
  }

  /// Pachka kelish narxi (API: package_purchase_price yoki dona × pachka).
  num? get purchasePackUnitPriceNum {
    if (costPricePerPack != null && costPricePerPack! > 0) {
      return costPricePerPack;
    }
    if (costPriceUzs != null &&
        costPriceUzs! > 0 &&
        quantityInPack &&
        quantityPerPack > 1) {
      return costPriceUzs! * quantityPerPack;
    }
    return null;
  }

  /// Pachka ulgurji — API da alohida maydon yo'q: dona ulgurji × pachkadagi dona.
  num? get wholesalePackUnitPriceNum {
    if (!quantityInPack || quantityPerPack <= 1) return null;
    if (wholesalePriceUzs != null && wholesalePriceUzs! > 0) {
      return wholesalePriceUzs! * quantityPerPack;
    }
    return null;
  }

  bool get hasWholesalePrice =>
      (wholesalePriceUzs != null && wholesalePriceUzs! > 0) ||
      (wholesalePriceApi != null && wholesalePriceApi! > 0);

  static bool _isUsableDisplayName(String? s) {
    if (s == null || s.trim().isEmpty || s.trim() == '—') return false;
    return !_isVariantLikeTitle(s);
  }

  static bool _hasNonEmptyText(String? s) => s != null && s.trim().isNotEmpty;

  /// Serverdagi rasm yo'lini mahalliy disk yo'lidan ustun qo'yadi (boshqa POS cache).
  static String? _mergeImageUrl(String? server, String? local) {
    final s = server?.trim() ?? '';
    final l = local?.trim() ?? '';
    if (s.isNotEmpty && !ProductImageUtils.isLocalFilePath(s)) return s;
    if (l.isNotEmpty && ProductImageUtils.isLocalFilePath(l)) {
      return s.isNotEmpty ? s : l;
    }
    if (s.isNotEmpty) return s;
    return l.isEmpty ? null : l;
  }

  static bool _isCategoryIdOnly(String? s) {
    if (s == null || s.trim().isEmpty) return true;
    return int.tryParse(s.trim()) != null;
  }

  /// Server javobi qisman bo‘lsa — foydalanuvchi kiritgan lokal qiymatlarni saqlaydi.
  /// [preferServerStock] — ro‘yxat yangilanganda serverdagi ombor miqdori (0 ham) ustun.
  Product mergeWithLocalFallback(Product local, {bool preferServerStock = false}) {
    final serverId = !id.startsWith('local_') && id.isNotEmpty ? id : local.id;
    final mergedName = _isUsableDisplayName(name) ? name : local.name;
    final mergedBarcode = _hasNonEmptyText(barcode) ? barcode : local.barcode;
    final mergedAdditional = (additionalBarcodes != null && additionalBarcodes!.isNotEmpty)
        ? additionalBarcodes
        : local.additionalBarcodes;
    final mergedSell = priceUzs > 0 ? priceUzs : local.priceUzs;
    final mergedCost = (costPriceUzs != null && costPriceUzs! > 0) ? costPriceUzs : local.costPriceUzs;
    final mergedQty = preferServerStock
        ? initialQuantity
        : (initialQuantity != 0 ? initialQuantity : local.initialQuantity);
    final mergedImage = _mergeImageUrl(imageUrl, local.imageUrl);
    final mergedUnitRaw = _hasNonEmptyText(unit) ? unit : local.unit;
    final mergedUnit = sanitizeUnitLabel(mergedUnitRaw) ?? mergedUnitRaw ?? 'dona';
    final mergedQtyInfoRaw = preferServerStock
        ? quantityInfo
        : (mergedQty != 0
            ? (initialQuantity != 0 ? quantityInfo : local.quantityInfo)
            : (_hasNonEmptyText(quantityInfo) ? quantityInfo : local.quantityInfo));
    final mergedQtyInfo = _sanitizeQuantityInfo(mergedQtyInfoRaw, mergedQty, mergedUnit)!;
    final mergedCategory = (!_isCategoryIdOnly(category) && _hasNonEmptyText(category))
        ? category
        : (local.category ?? category);
    final mergedDescription = _hasNonEmptyText(description) ? description : local.description;
    final mergedVariantId = (variantId != null && variantId! > 0) ? variantId : local.variantId;
    final mergedSku = _hasNonEmptyText(sku) ? sku : local.sku;
    final mergedPlu = _hasNonEmptyText(pluCode) ? pluCode : local.pluCode;

    final mergedSellPack = (sellPricePerPack != null && sellPricePerPack! > 0)
        ? sellPricePerPack
        : local.sellPricePerPack;
    final mergedCostPack = (costPricePerPack != null && costPricePerPack! > 0)
        ? costPricePerPack
        : local.costPricePerPack;
    final mergedQtyPerPack = quantityPerPack > 1 ? quantityPerPack : local.quantityPerPack;
    final mergedQtyInPack = quantityInPack || local.quantityInPack;

    final mergedSellCur = priceUzs > 0 ? sellingPriceCurrency : local.sellingPriceCurrency;
    final mergedPurchaseCur =
        (costPriceUzs != null && costPriceUzs! > 0) ? purchasePriceCurrency : local.purchasePriceCurrency;
    final mergedSellApi = priceUzs > 0 ? sellingPriceApi : local.sellingPriceApi;
    final mergedPurchaseApi =
        (costPriceUzs != null && costPriceUzs! > 0) ? purchasePriceApi : local.purchasePriceApi;

    final mergedWholesaleUzs = hasWholesalePrice ? wholesalePriceUzs : local.wholesalePriceUzs;
    final mergedWholesaleApi = wholesalePriceApi ?? local.wholesalePriceApi;
    final mergedWholesaleCur =
        hasWholesalePrice ? wholesalePriceCurrency : local.wholesalePriceCurrency;
    final mergedWeight = (weightKg != null && weightKg! > 0) ? weightKg : local.weightKg;

    return Product(
      id: serverId,
      name: mergedName.isEmpty ? local.name : mergedName,
      imageUrl: mergedImage,
      priceUzs: mergedSell,
      costPriceUzs: mergedCost,
      sku: mergedSku,
      barcode: mergedBarcode,
      pluCode: mergedPlu,
      additionalBarcodes: mergedAdditional,
      variantId: mergedVariantId,
      quantityInfo: mergedQtyInfo,
      unit: mergedUnit,
      category: mergedCategory,
      categoryId: categoryId ?? local.categoryId,
      brandId: brandId ?? local.brandId,
      brand: brand ?? local.brand,
      description: mergedDescription,
      quantityInPack: mergedQtyInPack,
      quantityPerPack: mergedQtyPerPack,
      costPricePerPack: mergedCostPack,
      sellPricePerPack: mergedSellPack,
      wholesalePriceUzs: mergedWholesaleUzs,
      reorderLevel: reorderLevel > 0 ? reorderLevel : local.reorderLevel,
      initialQuantity: mergedQty,
      sellingPriceCurrency: mergedSellCur,
      purchasePriceCurrency: mergedPurchaseCur,
      sellingPriceApi: mergedSellApi,
      purchasePriceApi: mergedPurchaseApi,
      wholesalePriceCurrency: mergedWholesaleCur,
      wholesalePriceApi: mergedWholesaleApi,
      weightKg: mergedWeight,
    );
  }

  /// Ro'yxat API ulgurji bermasa — lokal/saqlangan qiymatni saqlash.
  Product mergePreservingPrices(Product fallback) => mergeWithLocalFallback(fallback);

  /// Chek va boshqa joylarda birlikni qisqartmada ko'rsatish (API chekdagiga mos: sht, kg, ...)
  static String unitDisplayShort(String? unit) {
    final clean = sanitizeUnitLabel(unit);
    if (clean == null || clean.isEmpty) return 'sht';
    final lower = clean.toLowerCase();
    if (lower.length <= 5 && !lower.contains(' ')) return lower;
    if (lower.contains('kilo') || lower == 'kg') return 'kg';
    if (lower.contains('dona') || lower.contains('piece') || lower.contains('шт') || lower.contains('sht') || lower.contains('ta')) return 'sht';
    if (lower.contains('qop') || lower.contains('paket') || lower.contains('pak')) return 'qop';
    if (lower.contains('pachka')) return 'pachka';
    if (lower.contains('litr') || lower == 'l' || lower == 'л') return 'l';
    if (lower.contains('gram') || lower == 'g') return 'g';
    return clean;
  }

  /// API `unit` maydoni: string, Map yoki xato saqlangan `{id: ...}` matn.
  static String? sanitizeUnitLabel(String? unit) {
    if (unit == null) return null;
    final fromJson = _unitLabelFromJson(unit);
    if (fromJson != null && fromJson.isNotEmpty) return fromJson;
    final t = unit.trim();
    if (t.isEmpty || _looksLikeSerializedMap(t)) return _unitLabelFromSerializedMapString(t);
    return t;
  }

  static String? _unitLabelFromJson(dynamic v) {
    if (v == null) return null;
    if (v is String) {
      final s = v.trim();
      if (s.isEmpty || _looksLikeSerializedMap(s)) {
        return _unitLabelFromSerializedMapString(s);
      }
      return s;
    }
    if (v is Map) {
      final m = Map<String, dynamic>.from(v);
      for (final key in ['short_name', 'shortname', 'shortName', 'name', 'title', 'label', 'unit']) {
        final label = _stringFromJson(m[key]);
        if (label != null && label.isNotEmpty && !_looksLikeSerializedMap(label)) {
          return label.trim();
        }
      }
      return null;
    }
    final s = v.toString().trim();
    if (s.isEmpty || _looksLikeSerializedMap(s)) return _unitLabelFromSerializedMapString(s);
    return s;
  }

  static String? _unitLabelFromSerializedMapString(String s) {
    final short = RegExp(r'short_name:\s*([^,}]+)', caseSensitive: false).firstMatch(s);
    if (short != null) {
      final v = short.group(1)!.trim();
      if (v.isNotEmpty) return v;
    }
    final name = RegExp(r'name:\s*([^,}]+)', caseSensitive: false).firstMatch(s);
    if (name != null) {
      final v = name.group(1)!.trim();
      if (v.isNotEmpty) return v;
    }
    return null;
  }

  static String _quantityInfoLabel(int qty, String unitLabel) {
    final u = unitLabel.isEmpty ? 'dona' : unitLabel;
    return '$qty $u';
  }

  static String? _sanitizeQuantityInfo(String? info, int qty, String unitLabel) {
    if (info == null || info.trim().isEmpty) return _quantityInfoLabel(qty, unitLabel);
    if (_looksLikeSerializedMap(info) || info.contains('company_id')) {
      return _quantityInfoLabel(qty, unitLabel);
    }
    return info;
  }

  /// Barcode qidiruvda ishlatish uchun: faqat raqamlar (bo'shliq, tire va h.k. olib tashlanadi)
  static String normalizeBarcode(String? s) {
    if (s == null || s.isEmpty) return '';
    return s.replaceAll(RegExp(r'\D'), '');
  }

  /// Taqqoslash uchun: raqamlardan keyin boshidagi nollarni olib tashlash (076950450479 == 76950450479)
  static String _barcodeForMatch(String? s) {
    final digits = normalizeBarcode(s);
    if (digits.isEmpty) return '';
    final trimmed = digits.replaceFirst(RegExp(r'^0+'), '');
    return trimmed.isEmpty ? '0' : trimmed;
  }

  /// UI / saqlash: API obyektini yoki noto'g'ri matnni haqiqiy barcode qatoriga aylantirish
  static String? parseAdditionalBarcodeValue(dynamic value) => _additionalBarcodeStringFromItem(value);

  static List<String> parseAdditionalBarcodes(Iterable<dynamic>? values) {
    if (values == null) return [];
    final out = <String>[];
    for (final v in values) {
      final s = _additionalBarcodeStringFromItem(v);
      if (s != null && s.isNotEmpty) out.add(s);
    }
    return out;
  }

  /// Berilgan qator asosiy barcode, PLU yoki qo'shimcha barcode'lardan biriga to'g'ri kelsa true
  bool matchesBarcode(String query) {
    final rawNorm = normalizeBarcode(query);
    if (rawNorm.isEmpty) return false;
    bool same(String? a, String b) {
      if (a == null || a.isEmpty) return false;
      final an = normalizeBarcode(a);
      if (an.isEmpty) return false;
      if (an == b || an.contains(b) || b.contains(an)) return true;
      final am = _barcodeForMatch(a);
      final bm = _barcodeForMatch(b);
      return am == bm || am.contains(bm) || bm.contains(am);
    }
    if (barcode != null && barcode!.isNotEmpty) {
      if (same(barcode, rawNorm)) return true;
    }
    if (additionalBarcodes != null) {
      for (final ab in additionalBarcodes!) {
        if (ab.isEmpty) continue;
        if (same(ab, rawNorm)) return true;
      }
    }
    if (matchesPlu(query)) return true;

    // Tarozi shtrixi: ichidagi PLU bilan solishtirish
    for (final plu in extractScalePluCandidates(query)) {
      if (matchesPlu(plu)) return true;
      if (sku != null && sku!.trim().isNotEmpty) {
        final skuDigits = normalizeBarcode(sku);
        final pluDigits = normalizeBarcode(plu);
        if (skuDigits.isNotEmpty &&
            pluDigits.isNotEmpty &&
            (skuDigits == pluDigits || _barcodeForMatch(sku) == _barcodeForMatch(plu))) {
          return true;
        }
      }
    }
    return false;
  }

  /// `plu_code` bilan mos keladimi (boshidagi nollar farqi e’tiborsiz).
  bool matchesPlu(String query) {
    final p = pluCode?.trim();
    if (p == null || p.isEmpty) return false;
    final q = query.trim();
    if (q.isEmpty) return false;
    if (p == q) return true;
    final pn = normalizeBarcode(p);
    final qn = normalizeBarcode(q);
    if (pn.isEmpty || qn.isEmpty) return false;
    if (pn == qn) return true;
    return _barcodeForMatch(p) == _barcodeForMatch(q);
  }

  /// Shtrix oxirgi [minSuffix]… raqam (masalan oxirgi 4 ta) bilan mos keladimi.
  bool matchesBarcodeSuffix(String query, {int minSuffix = 4}) {
    final suffix = normalizeBarcode(query);
    if (suffix.length < minSuffix) return false;

    bool endsOk(String? code) {
      if (code == null || code.isEmpty) return false;
      final digits = normalizeBarcode(code);
      return digits.length >= suffix.length && digits.endsWith(suffix);
    }

    if (endsOk(barcode)) return true;
    if (additionalBarcodes != null) {
      for (final ab in additionalBarcodes!) {
        if (endsOk(ab)) return true;
      }
    }
    return false;
  }

  String get priceFormatted {
    if (sellingPriceCurrency.toLowerCase() == 'usd') {
      final v = sellingPriceApi ?? priceUzs;
      final d = v.toDouble();
      if (d == 0) return '0 USD';
      final text = d == d.roundToDouble() ? '${d.round()}' : d.toStringAsFixed(2);
      return '$text USD';
    }
    final s = priceUzs.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
      buf.write(s[i]);
    }
    return '$buf so\'m';
  }

  /// Tafsilot ekrani: ulgurji narx matni
  String get wholesalePriceDisplayText {
    if (!hasWholesalePrice) return '—';
    if (wholesalePriceCurrency.toLowerCase() == 'usd') {
      final v = wholesalePriceApi ?? (wholesalePriceUzs ?? 0);
      final d = v.toDouble();
      if (d == 0) return '—';
      final text = d == d.roundToDouble() ? '${d.round()}' : d.toStringAsFixed(2);
      return '$text USD';
    }
    final uzs = wholesalePriceUzs ?? wholesalePriceApi?.round() ?? 0;
    if (uzs <= 0) return '—';
    return '${_formatThousandsInt(uzs)} so\'m';
  }

  static String _formatThousandsInt(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  /// Tafsilot ekrani: kirim narxi matni
  String get purchasePriceDisplayText {
    if (purchasePriceCurrency.toLowerCase() == 'usd') {
      final v = purchasePriceApi ?? (costPriceUzs ?? 0);
      final d = v.toDouble();
      if (d == 0) return '—';
      final text = d == d.roundToDouble() ? '${d.round()}' : d.toStringAsFixed(2);
      return '$text USD';
    }
    if (costPriceUzs == null) return '0 so\'m';
    final s = costPriceUzs!.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
      buf.write(s[i]);
    }
    return '$buf so\'m';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'imageUrl': imageUrl,
      'priceUzs': priceUzs,
      'costPriceUzs': costPriceUzs,
      'sku': sku,
      'barcode': barcode,
      'pluCode': pluCode,
      'additionalBarcodes': additionalBarcodes,
      'variantId': variantId,
      'quantityInfo': quantityInfo,
      'unit': unit,
      'category': category,
      'categoryId': categoryId,
      'brandId': brandId,
      'brand': brand,
      'description': description,
      'quantityInPack': quantityInPack,
      'quantityPerPack': quantityPerPack,
      'costPricePerPack': costPricePerPack,
      'sellPricePerPack': sellPricePerPack,
      'reorderLevel': reorderLevel,
      'initialQuantity': initialQuantity,
      'sellingPriceCurrency': sellingPriceCurrency,
      'purchasePriceCurrency': purchasePriceCurrency,
      'sellingPriceApi': sellingPriceApi,
      'purchasePriceApi': purchasePriceApi,
      'wholesalePriceUzs': wholesalePriceUzs,
      'wholesalePriceCurrency': wholesalePriceCurrency,
      'wholesalePriceApi': wholesalePriceApi,
      'weightKg': weightKg,
    };
  }

  static String? _stringFromJson(dynamic v) {
    if (v == null) return null;
    if (v is String) {
      final s = v.trim();
      if (s.isEmpty || _looksLikeSerializedMap(s)) return null;
      return s;
    }
    if (v is Map) return null;
    final s = v.toString().trim();
    if (s.isEmpty || _looksLikeSerializedMap(s)) return null;
    return s;
  }

  /// Variant sarlavhasi (default_variant) mahsulot nomi sifatida qabul qilinmasin.
  static bool _isVariantLikeTitle(String? s) {
    if (s == null || s.trim().isEmpty) return false;
    final t = s.trim().toLowerCase();
    if (t == 'default_variant' || t == 'default' || t == 'variant') return true;
    return RegExp(r'^variant[-_]?\d+$').hasMatch(t) || RegExp(r'^default[-_]?variant').hasMatch(t);
  }

  static String _resolveDisplayName(Map<String, dynamic> m) {
    final title = _stringFromJson(m['title']);
    final productTitle = _stringFromJson(m['productTitle']) ?? _stringFromJson(m['product_title']);
    final nameField = _stringFromJson(m['name']);
    final productName = _stringFromJson(m['product_name']);
    if (_isVariantLikeTitle(title)) {
      return productTitle ?? productName ?? nameField ?? title ?? '';
    }
    return title ?? productTitle ?? nameField ?? productName ?? '';
  }

  /// Rasm yo'li: string yoki `{ url, path, src }`
  static String? _imagePathFromDynamic(dynamic v) {
    if (v == null) return null;
    if (v is String) {
      final s = v.trim();
      if (s.isEmpty || s == 'null') return null;
      return s;
    }
    if (v is Map) {
      final m = v;
      return _imagePathFromDynamic(m['url'] ?? m['path'] ?? m['src'] ?? m['full_url']);
    }
    return null;
  }

  /// API javob / list qatoridan rasm yo'li (`uploads/products/...` yoki fayl nomi).
  static String? imageUrlFromApiMap(Map<String, dynamic> m) =>
      _productImageFromRowFields(m);

  static String? _productImageFromRowFields(Map<String, dynamic> m) {
    const keys = <String>[
      'productImage',
      'imageURL',
      'imageUrl',
      'image_url',
      'photo',
      'thumbnail',
      'thumb',
      'product_image',
      'variant_image',
      'image_path',
    ];
    for (final k in keys) {
      final p = _imagePathFromDynamic(m[k]);
      if (p != null) return p;
    }
    return _imagePathFromDynamic(m['image']);
  }

  /// Barcode kabi maydonlar ba'zan ob'ekt bo'ladi: { value: "..." } yoki { code: "..." }
  static String? _barcodeLikeFromJson(dynamic v) {
    if (v == null) return null;
    if (v is Map) {
      final m = v;
      const keys = [
        'barcode',
        'bar_code',
        'barCode',
        'code',
        'value',
        'data',
        'newBarcode',
        'barcode_number',
        'barcodeNumber',
        'shtrix_kod',
        'shtrixKod',
      ];
      for (final k in keys) {
        if (!m.containsKey(k)) continue;
        final raw = m[k];
        if (raw is Map) {
          final nested = _barcodeLikeFromJson(raw);
          if (nested != null && nested.trim().isNotEmpty) return nested.trim();
          continue;
        }
        final fromVal = _stringFromJson(raw);
        if (fromVal != null && fromVal.trim().isNotEmpty && !_looksLikeSerializedMap(fromVal)) {
          return fromVal.trim();
        }
      }
      return null;
    }
    final s = _stringFromJson(v);
    if (s == null || s.isEmpty || s.trim().startsWith('<') || _looksLikeSerializedMap(s)) return null;
    return s.trim();
  }

  static bool _looksLikeSerializedMap(String s) {
    final t = s.trim();
    return t.startsWith('{') && (t.contains('company_id') || t.contains('product_id') || t.contains('id:'));
  }

  /// API qo'shimcha barcode massivi: string yoki { id, company_id, bar_code, ... } obyektlar
  static String? _additionalBarcodeStringFromItem(dynamic e) {
    if (e == null) return null;
    if (e is String) {
      final s = e.trim();
      if (s.isEmpty || _looksLikeSerializedMap(s)) return null;
      return s;
    }
    if (e is num) return e.toString();
    final fromMap = _barcodeLikeFromJson(e);
    if (fromMap != null && fromMap.isNotEmpty) return fromMap;
    final s = e.toString().trim();
    if (s.isEmpty || _looksLikeSerializedMap(s)) return null;
    return s;
  }

  static List<String>? _additionalBarcodeListFromJson(dynamic v) {
    if (v == null) return null;
    if (v is List) {
      final list = <String>[];
      for (final e in v) {
        final bc = _additionalBarcodeStringFromItem(e);
        if (bc != null && bc.isNotEmpty) list.add(bc);
      }
      return list.isEmpty ? null : list;
    }
    final single = _additionalBarcodeStringFromItem(v);
    if (single != null && single.isNotEmpty) return [single];
    return _stringListFromJson(v);
  }

  static int _intFromJson(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.round();
    if (v is num) return v.toInt();
    final s = v.toString().trim();
    final n = int.tryParse(s);
    if (n != null) return n;
    final digits = RegExp(r'(-?\d+)').firstMatch(s);
    if (digits != null) {
      final parsed = int.tryParse(digits.group(1)!);
      if (parsed != null) return parsed;
    }
    final d = double.tryParse(s);
    return d != null ? d.round() : 0;
  }

  static int? _intOrNullFromJson(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is double) return v.round();
    if (v is num) return v.toInt();
    final s = v.toString().trim();
    final n = int.tryParse(s);
    if (n != null) return n;
    final d = double.tryParse(s);
    return d != null ? d.round() : null;
  }

  static String _normalizePriceCurrency(dynamic v) {
    final s = (_stringFromJson(v) ?? '').toLowerCase().trim();
    if (s == 'usd' || s == 'dollar' || s == 'dol') return 'usd';
    return 'uzs';
  }

  static num? _numPreserveFromJson(dynamic v) {
    if (v == null) return null;
    if (v is num) return v;
    return num.tryParse(v.toString().trim());
  }

  static List<String>? _stringListFromJson(dynamic v) {
    if (v == null) return null;
    if (v is List) {
      final list = v.map((e) => _stringFromJson(e)).whereType<String>().where((s) => s.isNotEmpty).toList();
      return list.isEmpty ? null : list;
    }
    final s = _stringFromJson(v);
    if (s == null || s.isEmpty) return null;
    return s.split(RegExp(r'[,\s]+')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }

  static Product fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as String,
      name: json['name'] as String,
      imageUrl: json['imageUrl'] as String?,
      priceUzs: json['priceUzs'] as int,
      costPriceUzs: json['costPriceUzs'] as int?,
      sku: json['sku'] as String?,
      barcode: _stringFromJson(json['barcode']),
      pluCode: _stringFromJson(json['pluCode'] ?? json['plu_code']),
      additionalBarcodes: _additionalBarcodeListFromJson(json['additionalBarcodes']),
      variantId: json['variantId'] as int?,
      quantityInfo: _sanitizeQuantityInfo(
        json['quantityInfo'] as String?,
        json['initialQuantity'] as int? ?? 0,
        sanitizeUnitLabel(json['unit'] as String?) ?? 'dona',
      )!,
      unit: sanitizeUnitLabel(json['unit'] as String?),
      category: json['category'] as String?,
      categoryId: json['categoryId'] as String?,
      brandId: json['brandId'] as String?,
      brand: json['brand'] as String?,
      description: json['description'] as String?,
      quantityInPack: json['quantityInPack'] as bool? ?? false,
      quantityPerPack: json['quantityPerPack'] as int? ?? 0,
      costPricePerPack: json['costPricePerPack'] as int?,
      sellPricePerPack: json['sellPricePerPack'] as int?,
      reorderLevel: json['reorderLevel'] as int? ?? 0,
      initialQuantity: json['initialQuantity'] as int? ?? 0,
      sellingPriceCurrency: json['sellingPriceCurrency'] as String? ?? 'uzs',
      purchasePriceCurrency: json['purchasePriceCurrency'] as String? ?? 'uzs',
      sellingPriceApi: json['sellingPriceApi'] as num?,
      purchasePriceApi: json['purchasePriceApi'] as num?,
      wholesalePriceUzs: json['wholesalePriceUzs'] as int?,
      wholesalePriceCurrency: json['wholesalePriceCurrency'] as String? ?? 'uzs',
      wholesalePriceApi: json['wholesalePriceApi'] as num?,
      weightKg: ProductWeight.parse(json['weightKg'] ?? json['weight']),
    );
  }

  /// Server API javobidan Product — nom, narxlar, barcode, miqdor, dona/pachka barcha variantlar
  /// [unitIdToName] — to'liq nom (yangi mahsulot qo'shishda); [unitIdToShortName] — qisqartma (barcha joyda ko'rsatish)
  static Product fromApiJson(Map<String, dynamic> json, {Map<int, String>? unitIdToName, Map<int, String>? unitIdToShortName}) {
    // Ichki ob'ekt / edit-data: productDetails + variantDetails
    final Map<String, dynamic> rootJson = json['product'] is Map
        ? Map<String, dynamic>.from(json['product'] as Map)
        : Map<String, dynamic>.from(json);
    final List<dynamic>? variantDetailsList =
        rootJson['variantDetails'] as List<dynamic>? ?? json['variantDetails'] as List<dynamic>?;
    final Map<String, dynamic> m = rootJson['productDetails'] is Map
        ? Map<String, dynamic>.from(rootJson['productDetails'] as Map)
        : rootJson;
    Map<String, dynamic>? variantDetail0;
    if (variantDetailsList != null && variantDetailsList.isNotEmpty && variantDetailsList.first is Map) {
      variantDetail0 = Map<String, dynamic>.from(variantDetailsList.first as Map);
    }

    // API: id (son), productID
    final id = m['id'] ?? m['productID'];
    final idStr = id == null ? '' : (id is int ? id.toString() : id.toString());

    // Nom: variant `title` (masalan default_variant) mahsulot nomi emas — productTitle ustun.
    final name = _resolveDisplayName(m);

    // variants — narx/rasm uchun avval (POST create javobida narx ko'pincha variantda)
    List<dynamic>? variants = m['variants'] as List<dynamic>?;
    if (variants == null && json != m && json['variants'] is List) {
      variants = json['variants'] as List<dynamic>;
    }
    if (variants == null && m['default_variant'] != null) {
      variants = [m['default_variant']];
    }
    Map<String, dynamic>? firstVariantMap;
    if (variants != null && variants.isNotEmpty && variants.first is Map) {
      firstVariantMap = Map<String, dynamic>.from(variants.first as Map);
    }
    if (firstVariantMap == null && variantDetail0 != null) {
      firstVariantMap = variantDetail0;
    }

    // Sotish narxi + valyuta (MOBILE_API_DOCS.md)
    final sellingPriceCurrency = _normalizePriceCurrency(m['sellingPriceCurrency'] ?? m['selling_price_currency']);
    dynamic sellPriceRaw = m['selling_price'] ?? m['sell_price'] ?? m['price'] ?? m['sale_price'] ?? m['price_uzs'] ?? m['priceUzs'] ?? 0;
    if (_intFromJson(sellPriceRaw) == 0 && firstVariantMap != null) {
      sellPriceRaw = firstVariantMap['selling_price'] ??
          firstVariantMap['sell_price'] ??
          firstVariantMap['price'] ??
          sellPriceRaw;
    }
    num? sellingPriceApi;
    if (sellingPriceCurrency == 'usd') {
      sellingPriceApi = _numPreserveFromJson(sellPriceRaw);
    }
    final priceUzs = sellingPriceApi != null && sellingPriceCurrency == 'usd'
        ? sellingPriceApi!.round()
        : _intFromJson(sellPriceRaw);

    // Kirim narxi + valyuta
    final purchasePriceCurrency = _normalizePriceCurrency(m['purchasePriceCurrency'] ?? m['purchase_price_currency']);
    dynamic purchasePriceRaw = m['purchase_price'] ?? m['cost_price'] ?? m['buying_price'] ?? m['costPriceUzs'] ?? m['cost_uzs'];
    if ((purchasePriceRaw == null || _intOrNullFromJson(purchasePriceRaw) == null || _intFromJson(purchasePriceRaw) == 0) &&
        firstVariantMap != null) {
      final vUsd = firstVariantMap['purchase_price_usd'];
      if (purchasePriceCurrency == 'usd' && vUsd != null) {
        purchasePriceRaw = vUsd;
      } else {
        purchasePriceRaw = firstVariantMap['purchase_price'] ??
            firstVariantMap['cost_price'] ??
            firstVariantMap['buying_price'] ??
            purchasePriceRaw;
      }
    }
    num? purchasePriceApi;
    if (purchasePriceRaw != null && purchasePriceCurrency == 'usd') {
      purchasePriceApi = _numPreserveFromJson(purchasePriceRaw);
    }
    final int? costPriceUzs = purchasePriceRaw == null
        ? null
        : (purchasePriceApi != null && purchasePriceCurrency == 'usd'
            ? purchasePriceApi!.round()
            : _intOrNullFromJson(purchasePriceRaw));

    // Miqdor: product_quantity (API), quantity, availableQuantity (receives/products variants), variants[0].availableQuantity
    int initialQuantity = _intFromJson(m['product_quantity'] ?? m['quantity'] ?? m['stock_quantity'] ?? m['qty'] ?? m['stock'] ?? m['initial_quantity'] ?? m['initialQuantity'] ?? m['availableQuantity'] ?? 0);
    if (initialQuantity == 0 && variants != null && variants.isNotEmpty) {
      final v = variants.first;
      if (v is Map) {
        final vMap = Map<String, dynamic>.from(v as Map);
        initialQuantity = _intFromJson(vMap['availableQuantity'] ?? vMap['quantity']);
      }
    }

    // Birlik: barcha joyda qisqartma (unitIdToShortName), yangi mahsulotda to'liq nom; API da unit_id yoki unit_name
    final int unitId = _intFromJson(m['unit_id']);
    final unitFromName = _unitLabelFromJson(m['unit']) ??
        _unitLabelFromJson(m['unit_name']) ??
        _unitLabelFromJson(m['measure']) ??
        _unitLabelFromJson(m['unit_type']);
    String unit = '';
    if (unitIdToShortName != null && unitIdToShortName.containsKey(unitId)) {
      unit = unitIdToShortName[unitId]!;
    }
    if (unit.isEmpty && unitIdToName != null && unitIdToName.containsKey(unitId)) {
      unit = unitIdToName[unitId]!;
    }
    if (unit.isEmpty && unitFromName != null && unitFromName.isNotEmpty) unit = unitFromName;
    if (variants != null && unit.isEmpty) {
      for (final v in variants) {
        if (v is! Map) continue;
        final vMap = Map<String, dynamic>.from(v as Map);
        final fromV = _unitLabelFromJson(vMap['unit']) ?? _unitLabelFromJson(vMap['unit_name']);
        if (fromV != null && fromV.isNotEmpty) {
          unit = fromV;
          break;
        }
      }
    }
    unit = sanitizeUnitLabel(unit) ?? (unitId == 2 ? 'dona' : (unitId == 1 ? 'kg' : 'dona'));

    // Barcode: avval product (m) darajasida, keyin variants ichidan — list API har xil formatda yuborishi mumkin
    String? barcode = _barcodeLikeFromJson(m['barcode']) ??
        _barcodeLikeFromJson(m['bar_code']) ??
        _barcodeLikeFromJson(m['barcode_number']) ??
        _barcodeLikeFromJson(m['barcodeNumber']) ??
        _barcodeLikeFromJson(m['barCode']) ??
        _barcodeLikeFromJson(m['product_barcode']) ??
        _barcodeLikeFromJson(m['code']) ??
        _barcodeLikeFromJson(m['ean']) ??
        _barcodeLikeFromJson(m['upc']);
    Map<String, dynamic>? vFirstNonEmptyBarcode;
    if ((barcode == null || barcode.trim().isEmpty) && variants != null && variants.isNotEmpty) {
      for (final v in variants) {
        if (v is! Map) continue;
        final vMap = Map<String, dynamic>.from(v as Map);
        final bc = _barcodeLikeFromJson(vMap['bar_code']) ??
            _barcodeLikeFromJson(vMap['barCode']) ??
            _barcodeLikeFromJson(vMap['barcode']) ??
            _barcodeLikeFromJson(vMap['barcode_number']) ??
            _barcodeLikeFromJson(vMap['barcodeNumber']) ??
            _barcodeLikeFromJson(vMap['code']);
        if (bc != null && bc.trim().isNotEmpty && !bc.trim().startsWith('<')) {
          barcode = bc;
          vFirstNonEmptyBarcode = vMap;
          break;
        }
        final newBc = _barcodeLikeFromJson(vMap['newBarcode']);
        if (newBc != null && newBc.trim().isNotEmpty && !newBc.trim().startsWith('<')) {
          barcode = newBc;
          vFirstNonEmptyBarcode = vMap;
          break;
        }
      }
    }
    barcode = barcode?.trim();
    if (barcode != null && (barcode.isEmpty || barcode.startsWith('<'))) {
      barcode = null;
    }
    String? skuFinal = _stringFromJson(m['sku']) ?? _stringFromJson(m['sku_code']);
    if (skuFinal == null && variants != null && variants.isNotEmpty && variants.first is Map) {
      skuFinal = _stringFromJson((variants.first as Map)['sku']);
    }
    final pluFinal = _stringFromJson(m['plu_code']) ??
        _stringFromJson(m['pluCode']) ??
        _stringFromJson(m['plu']) ??
        _stringFromJson(m['PLU']);

    // Qo'shimcha barcode'lar: variant yoki product da additionalBarcodes / additional_barcodes
    List<String>? additionalBarcodes = _additionalBarcodeListFromJson(
      m['additionalBarcodes'] ?? m['additional_barcodes'] ?? m['additional_barcodes_list'],
    );
    if (additionalBarcodes == null && vFirstNonEmptyBarcode != null) {
      additionalBarcodes = _additionalBarcodeListFromJson(
        vFirstNonEmptyBarcode!['additionalBarcodes'] ??
            vFirstNonEmptyBarcode!['additional_barcodes'] ??
            vFirstNonEmptyBarcode!['additional_barcodes_list'],
      );
    }
    if (additionalBarcodes == null && variants != null && variants.isNotEmpty) {
      for (final v in variants) {
        if (v is! Map) continue;
        final vMap = Map<String, dynamic>.from(v as Map);
        additionalBarcodes = _additionalBarcodeListFromJson(
          vMap['additionalBarcodes'] ?? vMap['additional_barcodes'] ?? vMap['additional_barcodes_list'],
        );
        if (additionalBarcodes != null && additionalBarcodes!.isNotEmpty) break;
      }
    }

    // Kategoriya: ob'ekt yoki string
    final cat = m['category'];
    String? categoryIdStr = _stringFromJson(m['category_id'] ?? m['categoryId']);
    String? categoryNameStr;
    if (cat is Map) {
      categoryIdStr ??= _stringFromJson((cat as Map)['id']);
      categoryNameStr = _stringFromJson((cat as Map)['name']) ?? _stringFromJson((cat as Map)['title']);
    } else {
      categoryNameStr = _stringFromJson(m['category_name']) ?? _stringFromJson(cat);
    }
    if ((categoryNameStr == null || categoryNameStr.isEmpty) &&
        categoryIdStr != null &&
        !_isCategoryIdOnly(categoryIdStr)) {
      categoryNameStr = categoryIdStr;
    }
    final categoryStr = categoryNameStr ?? categoryIdStr;

    final brandRaw = m['brand'] ?? m['brand_id'] ?? m['brandId'];
    String? brandIdStr;
    String? brandNameStr = _stringFromJson(m['brand_name']);
    if (brandRaw is Map) {
      brandIdStr = _stringFromJson((brandRaw as Map)['id']);
      brandNameStr ??= _stringFromJson((brandRaw as Map)['name']) ?? _stringFromJson((brandRaw as Map)['title']);
    } else {
      brandIdStr = _stringFromJson(brandRaw);
    }
    if ((brandNameStr == null || brandNameStr.isEmpty) &&
        brandIdStr != null &&
        brandIdStr.isNotEmpty &&
        !RegExp(r'^\d+$').hasMatch(brandIdStr)) {
      brandNameStr = brandIdStr;
      brandIdStr = null;
    }

    // Pachka: API da variant ichida — units_per_package, package_selling_price, package_purchase_price (1.2)
    // Avval variants ichidan pachka maydonlari bor variantni topamiz (odatda default_variant)
    int quantityPerPack = 0;
    int? sellPricePerPack;
    int? costPricePerPack;
    if (variants != null && variants.isNotEmpty) {
      for (final v in variants) {
        if (v is! Map) continue;
        final v0 = Map<String, dynamic>.from(v as Map);
        final qpp = _intFromJson(v0['units_per_package'] ?? v0['unitsPerPackage'] ?? v0['quantity_per_pack'] ?? v0['quantityPerPack'] ?? v0['pack_quantity'] ?? 0);
        final sPack = _intOrNullFromJson(v0['package_selling_price'] ?? v0['packageSellingPrice']);
        final cPack = _intOrNullFromJson(v0['package_purchase_price'] ?? v0['packagePurchasePrice']);
        if (qpp > 0 || (sPack != null && sPack > 0) || (cPack != null && cPack > 0)) {
          quantityPerPack = qpp;
          sellPricePerPack = sPack;
          costPricePerPack = cPack;
          break;
        }
      }
    }
    if (quantityPerPack == 0) quantityPerPack = _intFromJson(m['units_per_package'] ?? m['unitsPerPackage'] ?? m['quantity_per_pack'] ?? m['quantityPerPack'] ?? m['pack_quantity'] ?? 0);
    if (sellPricePerPack == null) sellPricePerPack = _intOrNullFromJson(m['package_selling_price'] ?? m['packageSellingPrice']);
    if (costPricePerPack == null) costPricePerPack = _intOrNullFromJson(m['package_purchase_price'] ?? m['packagePurchasePrice']);
    int? wholesalePriceUzs = _intOrNullFromJson(
      m['wholesale_price'] ?? m['wholesalePrice'] ?? m['wholesale_price_uzs'] ?? m['price_wholesale'],
    );
    String? wholesaleCurrencyHint;
    num? wholesalePriceApi;
    void applyWholesaleFromMap(Map<String, dynamic> src) {
      final uzs = _intOrNullFromJson(
        src['wholesale_price'] ?? src['wholesalePrice'] ?? src['wholesale_price_uzs'] ?? src['price_wholesale'],
      );
      if (uzs != null && uzs > 0) {
        wholesalePriceUzs = uzs;
        wholesaleCurrencyHint ??= _stringFromJson(src['wholesalePriceCurrency'] ?? src['wholesale_price_currency']);
        return;
      }
      final api = _numPreserveFromJson(src['wholesalePrice'] ?? src['wholesale_price']);
      if (api != null && api > 0) {
        wholesalePriceApi = api;
        wholesalePriceUzs = api.round();
        wholesaleCurrencyHint ??= _stringFromJson(src['wholesalePriceCurrency'] ?? src['wholesale_price_currency']);
      }
    }

    if (wholesalePriceUzs == null || wholesalePriceUzs == 0) {
      applyWholesaleFromMap(m);
    }
    if ((wholesalePriceUzs == null || wholesalePriceUzs == 0) && variants != null) {
      for (final v in variants) {
        if (v is! Map) continue;
        applyWholesaleFromMap(Map<String, dynamic>.from(v as Map));
        if (wholesalePriceUzs != null && wholesalePriceUzs! > 0) break;
      }
    }
    if ((wholesalePriceUzs == null || wholesalePriceUzs == 0) && variantDetail0 != null) {
      applyWholesaleFromMap(variantDetail0);
    }
    final wholesalePriceCurrency = _normalizePriceCurrency(
      m['wholesalePriceCurrency'] ??
          m['wholesale_price_currency'] ??
          wholesaleCurrencyHint ??
          firstVariantMap?['wholesalePriceCurrency'] ??
          firstVariantMap?['wholesale_price_currency'] ??
          variantDetail0?['wholesalePriceCurrency'] ??
          variantDetail0?['wholesale_price_currency'],
    );
    if (wholesalePriceCurrency == 'usd') {
      final usd = wholesalePriceApi ??
          _numPreserveFromJson(
            m['wholesalePrice'] ??
                m['wholesale_price'] ??
                firstVariantMap?['wholesalePrice'] ??
                firstVariantMap?['wholesale_price'] ??
                variantDetail0?['wholesalePrice'] ??
                variantDetail0?['wholesale_price'],
          );
      if (usd != null) {
        wholesalePriceApi = usd;
        wholesalePriceUzs = usd.round();
      }
    } else if ((wholesalePriceUzs == null || wholesalePriceUzs == 0) && wholesalePriceApi == null) {
      final api = _numPreserveFromJson(
        m['wholesalePrice'] ??
            m['wholesale_price'] ??
            firstVariantMap?['wholesalePrice'] ??
            firstVariantMap?['wholesale_price'] ??
            variantDetail0?['wholesalePrice'] ??
            variantDetail0?['wholesale_price'],
      );
      if (api != null && api > 0) {
        wholesalePriceApi = api;
        wholesalePriceUzs = api.round();
      }
    }
    // API: units_per_package null yoki 1 = faqat dona; > 1 = pachka mavjud (1.4)
    final quantityInPack = quantityPerPack > 1;

    // Variant ID: product darajasida yoki vFirstNonEmptyBarcode (yoki birinchi variant) dan
    int? variantId;
    if (m['variantID'] != null) {
      variantId = _intOrNullFromJson(m['variantID']);
    }
    if (variantId == null && vFirstNonEmptyBarcode != null) {
      variantId = _intOrNullFromJson(vFirstNonEmptyBarcode!['id']);
    }
    if (variantId == null && variants != null && variants.isNotEmpty) {
      final firstV = variants.first;
      if (firstV is Map) {
        variantId = _intOrNullFromJson((firstV as Map)['id']);
      }
    }

    String? imageUrlStr = _productImageFromRowFields(m);
    if ((imageUrlStr == null || imageUrlStr.isEmpty) && variants != null) {
      for (final v in variants) {
        if (v is! Map) continue;
        final vm = Map<String, dynamic>.from(v as Map);
        imageUrlStr = _productImageFromRowFields(vm);
        if (imageUrlStr != null && imageUrlStr.isNotEmpty) break;
      }
    }

    return Product(
      id: idStr,
      name: name.isEmpty ? '—' : name,
      imageUrl: imageUrlStr,
      priceUzs: priceUzs,
      costPriceUzs: costPriceUzs,
      sku: skuFinal,
      barcode: barcode,
      pluCode: pluFinal,
      additionalBarcodes: additionalBarcodes,
      variantId: variantId,
      quantityInfo: _quantityInfoLabel(initialQuantity, unit),
      unit: unit,
      category: categoryStr,
      categoryId: categoryIdStr,
      brandId: brandIdStr,
      brand: brandNameStr,
      description: _stringFromJson(m['description']),
      quantityInPack: quantityInPack,
      quantityPerPack: quantityPerPack,
      costPricePerPack: costPricePerPack,
      sellPricePerPack: sellPricePerPack,
      wholesalePriceUzs: wholesalePriceUzs,
      reorderLevel: _intFromJson(m['reorder_level'] ?? m['reorderLevel'] ?? m['min_stock']),
      initialQuantity: initialQuantity,
      sellingPriceCurrency: sellingPriceCurrency,
      purchasePriceCurrency: purchasePriceCurrency,
      sellingPriceApi: sellingPriceApi,
      purchasePriceApi: purchasePriceApi,
      wholesalePriceCurrency: wholesalePriceCurrency,
      wholesalePriceApi: wholesalePriceApi,
      weightKg: ProductWeight.parse(m['weight'] ?? m['product_weight'] ?? m['weight_kg']),
    );
  }
}
