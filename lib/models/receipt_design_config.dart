import '../utils/receipt_store_title.dart';

/// Termal chek dizayni — sozlamalar va chop etish uchun.
class ReceiptDesignConfig {
  final bool showLogo;
  final String? logoFilePath;
  final String storeTitle;
  final bool useBranchNameAsTitle;
  final bool showDateTime;
  final String receiptNumberLabel;
  final String sellerLabel;
  final String sellerPhoneLabel;
  final bool showSellerPhone;
  final String clientLabel;
  final bool showClientLine;
  final String clientPhoneLabel;
  final bool showClientPhone;
  final String clientAddressLabel;
  final bool showClientAddress;
  final String discountLabel;
  final String totalLabel;
  final String footerText;
  final bool showFooter;
  final bool showBarcode;
  final String precheckBanner;
  final String currencySuffix;
  final String itemSeparator;
  final bool showItemSeparator;
  final bool numberedProducts;

  const ReceiptDesignConfig({
    this.showLogo = true,
    this.logoFilePath,
    this.storeTitle = '',
    this.useBranchNameAsTitle = false,
    this.showDateTime = true,
    this.receiptNumberLabel = 'Chek raqami',
    this.sellerLabel = 'Sotuvchi',
    this.sellerPhoneLabel = 'Sotuvchi nomeri',
    this.showSellerPhone = true,
    this.clientLabel = 'Mijoz',
    this.showClientLine = true,
    this.clientPhoneLabel = 'Mijoz telefoni',
    this.showClientPhone = true,
    this.clientAddressLabel = 'Mijoz manzili',
    this.showClientAddress = false,
    this.discountLabel = 'Chegirma',
    this.totalLabel = 'Umumiy summa',
    this.footerText = 'Rahmat, xaridingiz uchun!',
    this.showFooter = true,
    this.showBarcode = true,
    this.precheckBanner = 'OLDINDAN CHEK',
    this.currencySuffix = "so'm",
    this.itemSeparator = '--------------------------------',
    this.showItemSeparator = true,
    this.numberedProducts = true,
  });

  static const defaults = ReceiptDesignConfig();

  ReceiptDesignConfig copyWith({
    bool? showLogo,
    String? logoFilePath,
    bool clearLogoPath = false,
    String? storeTitle,
    bool? useBranchNameAsTitle,
    bool? showDateTime,
    String? receiptNumberLabel,
    String? sellerLabel,
    String? sellerPhoneLabel,
    bool? showSellerPhone,
    String? clientLabel,
    bool? showClientLine,
    String? clientPhoneLabel,
    bool? showClientPhone,
    String? clientAddressLabel,
    bool? showClientAddress,
    String? discountLabel,
    String? totalLabel,
    String? footerText,
    bool? showFooter,
    bool? showBarcode,
    String? precheckBanner,
    String? currencySuffix,
    String? itemSeparator,
    bool? showItemSeparator,
    bool? numberedProducts,
  }) {
    return ReceiptDesignConfig(
      showLogo: showLogo ?? this.showLogo,
      logoFilePath: clearLogoPath ? null : (logoFilePath ?? this.logoFilePath),
      storeTitle: storeTitle ?? this.storeTitle,
      useBranchNameAsTitle: useBranchNameAsTitle ?? this.useBranchNameAsTitle,
      showDateTime: showDateTime ?? this.showDateTime,
      receiptNumberLabel: receiptNumberLabel ?? this.receiptNumberLabel,
      sellerLabel: sellerLabel ?? this.sellerLabel,
      sellerPhoneLabel: sellerPhoneLabel ?? this.sellerPhoneLabel,
      showSellerPhone: showSellerPhone ?? this.showSellerPhone,
      clientLabel: clientLabel ?? this.clientLabel,
      showClientLine: showClientLine ?? this.showClientLine,
      clientPhoneLabel: clientPhoneLabel ?? this.clientPhoneLabel,
      showClientPhone: showClientPhone ?? this.showClientPhone,
      clientAddressLabel: clientAddressLabel ?? this.clientAddressLabel,
      showClientAddress: showClientAddress ?? this.showClientAddress,
      discountLabel: discountLabel ?? this.discountLabel,
      totalLabel: totalLabel ?? this.totalLabel,
      footerText: footerText ?? this.footerText,
      showFooter: showFooter ?? this.showFooter,
      showBarcode: showBarcode ?? this.showBarcode,
      precheckBanner: precheckBanner ?? this.precheckBanner,
      currencySuffix: currencySuffix ?? this.currencySuffix,
      itemSeparator: itemSeparator ?? this.itemSeparator,
      showItemSeparator: showItemSeparator ?? this.showItemSeparator,
      numberedProducts: numberedProducts ?? this.numberedProducts,
    );
  }

  Map<String, dynamic> toJson() => {
        'showLogo': showLogo,
        'logoFilePath': logoFilePath,
        'storeTitle': storeTitle,
        'useBranchNameAsTitle': useBranchNameAsTitle,
        'showDateTime': showDateTime,
        'receiptNumberLabel': receiptNumberLabel,
        'sellerLabel': sellerLabel,
        'sellerPhoneLabel': sellerPhoneLabel,
        'showSellerPhone': showSellerPhone,
        'clientLabel': clientLabel,
        'showClientLine': showClientLine,
        'clientPhoneLabel': clientPhoneLabel,
        'showClientPhone': showClientPhone,
        'clientAddressLabel': clientAddressLabel,
        'showClientAddress': showClientAddress,
        'discountLabel': discountLabel,
        'totalLabel': totalLabel,
        'footerText': footerText,
        'showFooter': showFooter,
        'showBarcode': showBarcode,
        'precheckBanner': precheckBanner,
        'currencySuffix': currencySuffix,
        'itemSeparator': itemSeparator,
        'showItemSeparator': showItemSeparator,
        'numberedProducts': numberedProducts,
      };

  factory ReceiptDesignConfig.fromJson(Map<String, dynamic> json) {
    return ReceiptDesignConfig(
      showLogo: json['showLogo'] as bool? ?? true,
      logoFilePath: json['logoFilePath'] as String?,
      storeTitle: json['storeTitle'] as String? ?? '',
      useBranchNameAsTitle: json['useBranchNameAsTitle'] as bool? ?? false,
      showDateTime: json['showDateTime'] as bool? ?? true,
      receiptNumberLabel: json['receiptNumberLabel'] as String? ?? 'Chek raqami',
      sellerLabel: json['sellerLabel'] as String? ?? 'Sotuvchi',
      sellerPhoneLabel: json['sellerPhoneLabel'] as String? ?? 'Sotuvchi nomeri',
      showSellerPhone: json['showSellerPhone'] as bool? ?? true,
      clientLabel: json['clientLabel'] as String? ?? 'Mijoz',
      showClientLine: json['showClientLine'] as bool? ?? true,
      clientPhoneLabel: json['clientPhoneLabel'] as String? ?? 'Mijoz telefoni',
      showClientPhone: json['showClientPhone'] as bool? ?? true,
      clientAddressLabel: json['clientAddressLabel'] as String? ?? 'Mijoz manzili',
      showClientAddress: json['showClientAddress'] as bool? ?? false,
      discountLabel: json['discountLabel'] as String? ?? 'Chegirma',
      totalLabel: json['totalLabel'] as String? ?? 'Umumiy summa',
      footerText: json['footerText'] as String? ?? 'Rahmat, xaridingiz uchun!',
      showFooter: json['showFooter'] as bool? ?? true,
      showBarcode: json['showBarcode'] as bool? ?? true,
      precheckBanner: json['precheckBanner'] as String? ?? 'OLDINDAN CHEK',
      currencySuffix: json['currencySuffix'] as String? ?? "so'm",
      itemSeparator: json['itemSeparator'] as String? ?? '--------------------------------',
      showItemSeparator: json['showItemSeparator'] as bool? ?? true,
      numberedProducts: json['numberedProducts'] as bool? ?? true,
    );
  }

  String titleForBranch(String branchName) =>
      ReceiptStoreTitle.resolve(design: this, branchName: branchName);
}

