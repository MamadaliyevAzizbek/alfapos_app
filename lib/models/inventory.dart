class InventoryDocument {
  final int id;
  final String documentNumber;
  final String status;
  final String? notes;
  final int? categoryId;
  final String? categoryName;
  final int? branchId;
  final int checkedCount;
  final int totalCount;
  final String? creatorName;
  final DateTime? completedAt;
  final DateTime? createdAt;

  const InventoryDocument({
    required this.id,
    required this.documentNumber,
    required this.status,
    this.notes,
    this.categoryId,
    this.categoryName,
    this.branchId,
    this.checkedCount = 0,
    this.totalCount = 0,
    this.creatorName,
    this.completedAt,
    this.createdAt,
  });

  bool get isCompleted => status == 'completed';
  bool get isEditable => status == 'draft' || status == 'in_progress';

  String get statusLabel {
    switch (status) {
      case 'completed':
        return 'Yakunlangan';
      case 'in_progress':
        return 'Jarayonda';
      case 'draft':
        return 'Qoralama';
      default:
        return status;
    }
  }

  factory InventoryDocument.fromJson(Map<String, dynamic> j) {
    final category = j['category'];
    String? categoryName;
    int? categoryId;
    if (category is Map) {
      final m = Map<String, dynamic>.from(category);
      categoryId = _asInt(m['id'] ?? m['value']);
      categoryName = (m['name'] ?? m['text'])?.toString();
    } else {
      categoryId = _asInt(j['category_id'] ?? j['categoryId']);
      categoryName = j['category_name']?.toString();
    }

    final creator = j['creator'];
    String? creatorName;
    if (creator is Map) {
      final m = Map<String, dynamic>.from(creator);
      final first = (m['first_name'] ?? m['firstName'] ?? '').toString();
      final last = (m['last_name'] ?? m['lastName'] ?? '').toString();
      creatorName = '$first $last'.trim();
      if (creatorName.isEmpty) {
        creatorName = (m['name'] ?? m['email'])?.toString();
      }
    }

    return InventoryDocument(
      id: _asInt(j['id']) ?? 0,
      documentNumber:
          (j['document_number'] ?? j['documentNumber'] ?? '').toString(),
      status: (j['status'] ?? 'in_progress').toString(),
      notes: j['notes']?.toString(),
      categoryId: categoryId,
      categoryName: categoryName,
      branchId: _asInt(j['branch_id'] ?? j['branchId']),
      checkedCount: _asInt(j['checked_count'] ?? j['checkedCount']) ?? 0,
      totalCount: _asInt(j['total_count'] ?? j['totalCount']) ?? 0,
      creatorName: creatorName,
      completedAt: _asDate(j['completed_at'] ?? j['completedAt']),
      createdAt: _asDate(j['created_at'] ?? j['createdAt']),
    );
  }

  static List<InventoryDocument> listFromResponse(Map<String, dynamic> res) {
    final raw = res['datarows'] ??
        res['data'] ??
        res['rows'] ??
        res['inventories'] ??
        const [];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => InventoryDocument.fromJson(Map<String, dynamic>.from(e)))
        .where((d) => d.id > 0)
        .toList();
  }

  static int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.round();
    return int.tryParse(v.toString());
  }

  static DateTime? _asDate(dynamic v) {
    if (v == null) return null;
    return DateTime.tryParse(v.toString());
  }
}

class InventoryStats {
  final int checked;
  final int unchecked;
  final int total;
  final int counted;
  final int pending;

  const InventoryStats({
    this.checked = 0,
    this.unchecked = 0,
    this.total = 0,
    this.counted = 0,
    this.pending = 0,
  });

  factory InventoryStats.fromJson(Map<String, dynamic>? j) {
    if (j == null) return const InventoryStats();
    int n(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.round();
      return int.tryParse(v?.toString() ?? '') ?? 0;
    }

    return InventoryStats(
      checked: n(j['checked'] ?? j['counted']),
      unchecked: n(j['unchecked'] ?? j['pending']),
      total: n(j['total'] ?? j['total_in_category']),
      counted: n(j['counted'] ?? j['checked']),
      pending: n(j['pending'] ?? j['unchecked']),
    );
  }
}

class InventoryProductRow {
  final int productId;
  final int variantId;
  final int? inventoryItemId;
  final String productTitle;
  final String? variantTitle;
  final String? categoryName;
  final String? sku;
  final String? barcode;
  final num systemQuantity;
  num? countedQuantity;
  bool isChecked;

  InventoryProductRow({
    required this.productId,
    required this.variantId,
    this.inventoryItemId,
    required this.productTitle,
    this.variantTitle,
    this.categoryName,
    this.sku,
    this.barcode,
    required this.systemQuantity,
    this.countedQuantity,
    this.isChecked = false,
  });

  num get difference {
    final counted = countedQuantity;
    if (counted == null) return 0;
    return counted - systemQuantity;
  }

  bool get isCounted => countedQuantity != null;

  String get displayName {
    final v = (variantTitle ?? '').trim();
    if (v.isEmpty || v == 'default_variant') return productTitle;
    return '$productTitle ($v)';
  }

  factory InventoryProductRow.fromJson(Map<String, dynamic> j) {
    num? asNum(dynamic v) {
      if (v == null || v == '') return null;
      if (v is num) return v;
      return num.tryParse(v.toString().replaceAll(',', '.'));
    }

    int asInt(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.round();
      return int.tryParse(v?.toString() ?? '') ?? 0;
    }

    final counted = asNum(j['counted_quantity'] ?? j['countedQuantity']);
    return InventoryProductRow(
      productId: asInt(j['product_id'] ?? j['productId']),
      variantId: asInt(j['variant_id'] ?? j['variantId']),
      inventoryItemId: asInt(j['inventory_item_id'] ?? j['inventoryItemId']) == 0
          ? null
          : asInt(j['inventory_item_id'] ?? j['inventoryItemId']),
      productTitle:
          (j['product_title'] ?? j['productTitle'] ?? j['title'] ?? 'Mahsulot')
              .toString(),
      variantTitle: (j['variant_title'] ?? j['variantTitle'])?.toString(),
      categoryName: (j['category_name'] ?? j['categoryName'])?.toString(),
      sku: j['sku']?.toString(),
      barcode: (j['bar_code'] ?? j['barcode'] ?? j['barCode'])?.toString(),
      systemQuantity:
          asNum(j['system_quantity'] ?? j['systemQuantity']) ?? 0,
      countedQuantity: counted,
      isChecked: j['is_checked'] == true ||
          j['isChecked'] == true ||
          j['is_checked'] == 1 ||
          counted != null,
    );
  }

  static List<InventoryProductRow> listFromResponse(Map<String, dynamic> res) {
    final raw = res['datarows'] ?? res['data'] ?? res['rows'] ?? const [];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => InventoryProductRow.fromJson(Map<String, dynamic>.from(e)))
        .where((r) => r.variantId > 0)
        .toList();
  }
}

class InventoryCategoryOption {
  final String text;
  final String value;

  const InventoryCategoryOption({required this.text, required this.value});

  factory InventoryCategoryOption.fromJson(Map<String, dynamic> j) {
    return InventoryCategoryOption(
      text: (j['text'] ?? j['name'] ?? j['label'] ?? '').toString(),
      value: (j['value'] ?? j['id'] ?? '').toString(),
    );
  }

  static List<InventoryCategoryOption> fromFilterResponse(
    Map<String, dynamic> res,
  ) {
    final raw = res['categoryName'] ??
        res['categories'] ??
        (res['data'] is Map
            ? (res['data'] as Map)['categoryName']
            : null) ??
        const [];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) =>
            InventoryCategoryOption.fromJson(Map<String, dynamic>.from(e)))
        .where((c) => c.value.isNotEmpty)
        .toList();
  }
}
