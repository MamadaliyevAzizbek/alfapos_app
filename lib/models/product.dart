class Product {
  final String id;
  final String name;
  final String? imageUrl;
  final int priceUzs; // sotish narxi (dona)
  final int? costPriceUzs; // kelish narxi (dona)
  final String? sku;
  final String? barcode;
  /// API: additionalBarcodes / additional_barcodes — 2 yoki undan ortiq qo'shimcha shtrix kodlar
  final List<String>? additionalBarcodes;
  /// API: default variant ID (variants[].id) — sales/store da variantID sifatida yuborish uchun
  final int? variantId;
  final String quantityInfo;
  final String? unit; // dona, kg, pachka
  final String? category;
  final String? description;
  final bool quantityInPack; // pachka mavjud: API da units_per_package > 1
  final int quantityPerPack; // 1 pachkada nechta dona (API: units_per_package)
  final int? costPricePerPack; // pachka kelish narxi (API: package_purchase_price)
  final int? sellPricePerPack; // pachka sotish narxi (API: package_selling_price)
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

  const Product({
    required this.id,
    required this.name,
    this.imageUrl,
    required this.priceUzs,
    this.costPriceUzs,
    this.sku,
    this.barcode,
    this.additionalBarcodes,
    this.variantId,
    this.quantityInfo = '0 sht',
    this.unit,
    this.category,
    this.description,
    this.quantityInPack = false,
    this.quantityPerPack = 0,
    this.costPricePerPack,
    this.sellPricePerPack,
    this.reorderLevel = 0,
    this.initialQuantity = 0,
    this.sellingPriceCurrency = 'uzs',
    this.purchasePriceCurrency = 'uzs',
    this.sellingPriceApi,
    this.purchasePriceApi,
  });

  /// 1 dona sotish narxi (savatcha / jami); pachkada — pachka narxi
  num get sellUnitPriceNum {
    if (quantityInPack && sellPricePerPack != null && sellPricePerPack! > 0) {
      return sellPricePerPack!;
    }
    return sellingPriceApi ?? priceUzs;
  }

  /// Sotish narxi: pachkada bo'lsa pachka narxi, aks holda dona (yaxlitlangan, eski kod uchun)
  int get effectiveSellPrice => sellUnitPriceNum.round();

  /// Chek va boshqa joylarda birlikni qisqartmada ko'rsatish (API chekdagiga mos: sht, kg, ...)
  static String unitDisplayShort(String? unit) {
    if (unit == null || unit.trim().isEmpty) return 'sht';
    final lower = unit.trim().toLowerCase();
    if (lower.length <= 5 && !lower.contains(' ')) return lower;
    if (lower.contains('kilo') || lower == 'kg') return 'kg';
    if (lower.contains('dona') || lower.contains('piece') || lower.contains('шт') || lower.contains('sht') || lower.contains('ta')) return 'sht';
    if (lower.contains('qop') || lower.contains('paket') || lower.contains('pak')) return 'qop';
    if (lower.contains('pachka')) return 'pachka';
    if (lower.contains('litr') || lower == 'l' || lower == 'л') return 'l';
    if (lower.contains('gram') || lower == 'g') return 'g';
    return unit.trim();
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

  /// Berilgan qator asosiy barcode yoki qo'shimcha barcode'lardan biriga to'g'ri kelsa true
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
      'additionalBarcodes': additionalBarcodes,
      'variantId': variantId,
      'quantityInfo': quantityInfo,
      'unit': unit,
      'category': category,
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
    };
  }

  static String? _stringFromJson(dynamic v) {
    if (v == null) return null;
    if (v is String) return v.isEmpty ? null : v;
    return v.toString();
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
      final m = v as Map;
      final fromVal = _stringFromJson(m['value'] ?? m['code'] ?? m['barcode'] ?? m['data']);
      if (fromVal != null && fromVal.trim().isNotEmpty && !fromVal.trim().startsWith('<')) return fromVal;
      return null;
    }
    final s = _stringFromJson(v);
    return (s != null && s.isNotEmpty && !s.trim().startsWith('<')) ? s : null;
  }

  static int _intFromJson(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.round();
    if (v is num) return v.toInt();
    final s = v.toString().trim();
    final n = int.tryParse(s);
    if (n != null) return n;
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
      additionalBarcodes: _stringListFromJson(json['additionalBarcodes']),
      variantId: json['variantId'] as int?,
      quantityInfo: json['quantityInfo'] as String? ?? '0 sht',
      unit: json['unit'] as String?,
      category: json['category'] as String?,
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
    );
  }

  /// Server API javobidan Product — nom, narxlar, barcode, miqdor, dona/pachka barcha variantlar
  /// [unitIdToName] — to'liq nom (yangi mahsulot qo'shishda); [unitIdToShortName] — qisqartma (barcha joyda ko'rsatish)
  static Product fromApiJson(Map<String, dynamic> json, {Map<int, String>? unitIdToName, Map<int, String>? unitIdToShortName}) {
    // Ichki ob'ekt bo'lsa (masalan product: { name, ... }) — undan olamiz
    final Map<String, dynamic> m = json['product'] is Map
        ? Map<String, dynamic>.from(json['product'] as Map)
        : json;

    // API: id (son), productID
    final id = m['id'] ?? m['productID'];
    final idStr = id == null ? '' : (id is int ? id.toString() : id.toString());

    // Nom: API da title, shuningdek name, product_name
    final name = _stringFromJson(m['title']) ??
        _stringFromJson(m['name']) ??
        _stringFromJson(m['product_name']) ??
        _stringFromJson(m['product_title']) ??
        '';

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
    final unitFromName = _stringFromJson(m['unit']) ?? _stringFromJson(m['unit_name']) ?? _stringFromJson(m['measure']) ?? _stringFromJson(m['unit_type']);
    String unit = '';
    if (unitIdToShortName != null && unitIdToShortName.containsKey(unitId)) {
      unit = unitIdToShortName[unitId]!;
    }
    if (unit.isEmpty && unitIdToName != null && unitIdToName.containsKey(unitId)) {
      unit = unitIdToName[unitId]!;
    }
    if (unit.isEmpty && unitFromName != null && unitFromName.isNotEmpty) unit = unitFromName;
    if (unit.isEmpty) unit = unitId == 2 ? 'dona' : (unitId == 1 ? 'kg' : 'dona');

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

    // Qo'shimcha barcode'lar: variant yoki product da additionalBarcodes / additional_barcodes
    List<String>? additionalBarcodes = _stringListFromJson(m['additionalBarcodes'] ?? m['additional_barcodes']);
    if (additionalBarcodes == null && vFirstNonEmptyBarcode != null) {
      additionalBarcodes = _stringListFromJson(
        vFirstNonEmptyBarcode!['additionalBarcodes'] ??
            vFirstNonEmptyBarcode!['additional_barcodes'] ??
            vFirstNonEmptyBarcode!['additional_barcodes_list'],
      );
    }
    if (additionalBarcodes == null && variants != null && variants.isNotEmpty) {
      for (final v in variants) {
        if (v is! Map) continue;
        final vMap = Map<String, dynamic>.from(v as Map);
        additionalBarcodes = _stringListFromJson(vMap['additionalBarcodes'] ?? vMap['additional_barcodes'] ?? vMap['additional_barcodes_list']);
        if (additionalBarcodes != null && additionalBarcodes!.isNotEmpty) break;
      }
    }

    // Kategoriya: ob'ekt yoki string
    final cat = m['category'];
    final categoryStr = cat is Map
        ? _stringFromJson((cat as Map)['name']) ?? _stringFromJson((cat as Map)['title'])
        : _stringFromJson(m['category_name']) ?? _stringFromJson(m['category_id']?.toString());

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
      additionalBarcodes: additionalBarcodes,
      variantId: variantId,
      quantityInfo: '$initialQuantity ${unit == 'dona' ? 'dona' : unit}',
      unit: unit.isEmpty ? 'dona' : unit,
      category: categoryStr,
      description: _stringFromJson(m['description']),
      quantityInPack: quantityInPack,
      quantityPerPack: quantityPerPack,
      costPricePerPack: costPricePerPack,
      sellPricePerPack: sellPricePerPack,
      reorderLevel: _intFromJson(m['reorder_level'] ?? m['reorderLevel'] ?? m['min_stock']),
      initialQuantity: initialQuantity,
      sellingPriceCurrency: sellingPriceCurrency,
      purchasePriceCurrency: purchasePriceCurrency,
      sellingPriceApi: sellingPriceApi,
      purchasePriceApi: purchasePriceApi,
    );
  }
}
