/// Chek shabloni: PDF namunalariga mos (Alfapos.pdf / Alfapos chek.pdf).
enum ReceiptTemplateKind {
  /// Raqamlangan ro'yxat: `1) mahsulot` + `1 x narx so'm. summa`
  numberedList,

  /// Jadval: Mahsulot | Miqdor | Narx | Summa
  tableColumns,

  /// O'z sozlamalari (logo, footer, matnlar)
  custom,
}

/// Mahalliy chek dizayni — API emas, Xprinter 80mm uchun.
class ReceiptDesignConfig {
  final ReceiptTemplateKind template;
  final String storeName;
  final bool useBranchNameWhenEmpty;
  final String? logoPath;
  final String? footerImagePath;
  final String footerText;
  final String headerExtraText;
  final bool showSellerPhone;
  final bool showClient;
  final bool showDescription;
  final bool showBarcode;
  final bool showTableHeaders;
  final bool useSomSuffix;
  final double fontScale;

  const ReceiptDesignConfig({
    this.template = ReceiptTemplateKind.tableColumns,
    this.storeName = '',
    this.useBranchNameWhenEmpty = true,
    this.logoPath,
    this.footerImagePath,
    this.footerText = 'Спасибо за покупку!',
    this.headerExtraText = '',
    this.showSellerPhone = true,
    this.showClient = true,
    this.showDescription = true,
    this.showBarcode = false,
    this.showTableHeaders = true,
    this.useSomSuffix = true,
    this.fontScale = 1.0,
  });

  bool get isCustom => template == ReceiptTemplateKind.custom;

  bool get usesNumberedProducts =>
      template == ReceiptTemplateKind.numberedList ||
      (isCustom && !showTableHeaders);

  String resolveStoreName({String branchName = '', String cashRegisterName = ''}) {
    final manual = storeName.trim();
    if (manual.isNotEmpty) return manual;
    if (!useBranchNameWhenEmpty) return 'Do\'kon';
    if (branchName.trim().isNotEmpty) return branchName.trim();
    if (cashRegisterName.trim().isNotEmpty) return cashRegisterName.trim();
    return 'Do\'kon';
  }

  ReceiptDesignConfig copyWith({
    ReceiptTemplateKind? template,
    String? storeName,
    bool? useBranchNameWhenEmpty,
    String? logoPath,
    String? footerImagePath,
    bool clearLogo = false,
    bool clearFooterImage = false,
    String? footerText,
    String? headerExtraText,
    bool? showSellerPhone,
    bool? showClient,
    bool? showDescription,
    bool? showBarcode,
    bool? showTableHeaders,
    bool? useSomSuffix,
    double? fontScale,
  }) {
    return ReceiptDesignConfig(
      template: template ?? this.template,
      storeName: storeName ?? this.storeName,
      useBranchNameWhenEmpty: useBranchNameWhenEmpty ?? this.useBranchNameWhenEmpty,
      logoPath: clearLogo ? null : (logoPath ?? this.logoPath),
      footerImagePath: clearFooterImage ? null : (footerImagePath ?? this.footerImagePath),
      footerText: footerText ?? this.footerText,
      headerExtraText: headerExtraText ?? this.headerExtraText,
      showSellerPhone: showSellerPhone ?? this.showSellerPhone,
      showClient: showClient ?? this.showClient,
      showDescription: showDescription ?? this.showDescription,
      showBarcode: showBarcode ?? this.showBarcode,
      showTableHeaders: showTableHeaders ?? this.showTableHeaders,
      useSomSuffix: useSomSuffix ?? this.useSomSuffix,
      fontScale: fontScale ?? this.fontScale,
    );
  }

  Map<String, dynamic> toJson() => {
        'template': template.name,
        'storeName': storeName,
        'useBranchNameWhenEmpty': useBranchNameWhenEmpty,
        'logoPath': logoPath,
        'footerImagePath': footerImagePath,
        'footerText': footerText,
        'headerExtraText': headerExtraText,
        'showSellerPhone': showSellerPhone,
        'showClient': showClient,
        'showDescription': showDescription,
        'showBarcode': showBarcode,
        'showTableHeaders': showTableHeaders,
        'useSomSuffix': useSomSuffix,
        'fontScale': fontScale,
      };

  factory ReceiptDesignConfig.fromJson(Map<String, dynamic> json) {
    final tName = (json['template'] ?? 'tableColumns').toString();
    final template = ReceiptTemplateKind.values.firstWhere(
      (e) => e.name == tName,
      orElse: () => ReceiptTemplateKind.tableColumns,
    );
    return ReceiptDesignConfig(
      template: template,
      storeName: (json['storeName'] ?? '').toString(),
      useBranchNameWhenEmpty: json['useBranchNameWhenEmpty'] != false,
      logoPath: json['logoPath'] as String?,
      footerImagePath: json['footerImagePath'] as String?,
      footerText: (json['footerText'] ?? 'Спасибо за покупку!').toString(),
      headerExtraText: (json['headerExtraText'] ?? '').toString(),
      showSellerPhone: json['showSellerPhone'] != false,
      showClient: json['showClient'] != false,
      showDescription: json['showDescription'] != false,
      showBarcode: json['showBarcode'] == true,
      showTableHeaders: json['showTableHeaders'] != false,
      useSomSuffix: json['useSomSuffix'] != false,
      fontScale: (json['fontScale'] is num) ? (json['fontScale'] as num).toDouble() : 1.0,
    );
  }

  static ReceiptDesignConfig presetNumberedList() => const ReceiptDesignConfig(
        template: ReceiptTemplateKind.numberedList,
        showTableHeaders: false,
        showBarcode: false,
        useSomSuffix: true,
      );

  static ReceiptDesignConfig presetTableColumns() => const ReceiptDesignConfig(
        template: ReceiptTemplateKind.tableColumns,
        showTableHeaders: true,
        showBarcode: false,
        useSomSuffix: false,
      );

  static ReceiptDesignConfig presetCustom() => const ReceiptDesignConfig(
        template: ReceiptTemplateKind.custom,
        showTableHeaders: true,
        showBarcode: false,
        useSomSuffix: false,
      );
}
