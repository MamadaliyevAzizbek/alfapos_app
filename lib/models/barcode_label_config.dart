/// Shtrix kod yorliq shabloni.
enum BarcodeLabelTemplate {
  /// Narx yuqorida (standart).
  standard,

  /// Do‘kon nomi yuqorida (bold), narx o‘rniga.
  shopName,
}

extension BarcodeLabelTemplateX on BarcodeLabelTemplate {
  String get title => switch (this) {
        BarcodeLabelTemplate.standard => 'Standart (narx)',
        BarcodeLabelTemplate.shopName => 'Do‘kon nomi',
      };
}

/// Shtrix kod yorliq chop etish sozlamalari.
class BarcodeLabelConfig {
  const BarcodeLabelConfig({
    required this.widthMm,
    required this.heightMm,
    required this.copies,
    this.template = BarcodeLabelTemplate.standard,
    this.shopName = '',
  });

  static const double defaultWidthMm = 40;
  static const double defaultHeightMm = 30;
  static const int defaultCopies = 1;

  static const double minWidthMm = 20;
  static const double maxWidthMm = 100;
  static const double minHeightMm = 15;
  static const double maxHeightMm = 80;
  static const int minCopies = 1;
  static const int maxCopies = 999;

  final double widthMm;
  final double heightMm;
  final int copies;
  final BarcodeLabelTemplate template;
  final String shopName;

  static const defaults = BarcodeLabelConfig(
    widthMm: defaultWidthMm,
    heightMm: defaultHeightMm,
    copies: defaultCopies,
  );

  double clampWidth(double v) => v.clamp(minWidthMm, maxWidthMm);
  double clampHeight(double v) => v.clamp(minHeightMm, maxHeightMm);
  int clampCopies(int v) => v.clamp(minCopies, maxCopies);

  BarcodeLabelConfig normalized() => BarcodeLabelConfig(
        widthMm: clampWidth(widthMm),
        heightMm: clampHeight(heightMm),
        copies: clampCopies(copies),
        template: template,
        shopName: shopName.trim(),
      );

  BarcodeLabelConfig copyWith({
    double? widthMm,
    double? heightMm,
    int? copies,
    BarcodeLabelTemplate? template,
    String? shopName,
  }) {
    return BarcodeLabelConfig(
      widthMm: widthMm ?? this.widthMm,
      heightMm: heightMm ?? this.heightMm,
      copies: copies ?? this.copies,
      template: template ?? this.template,
      shopName: shopName ?? this.shopName,
    );
  }

  int get widthPx => (widthMm * _dotsPerMm).round();
  int get heightPx => (heightMm * _dotsPerMm).round();

  static const double _dotsPerMm = 203 / 25.4;
}
