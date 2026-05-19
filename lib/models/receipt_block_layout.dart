/// Chekdagi bir blok (logo, matn, rasm) joylashuvi — vizual tahrirchi uchun.
class ReceiptBlockLayout {
  final double scale;
  final double offsetY;

  const ReceiptBlockLayout({
    this.scale = 1.0,
    this.offsetY = 0,
  });

  ReceiptBlockLayout copyWith({double? scale, double? offsetY}) {
    return ReceiptBlockLayout(
      scale: scale ?? this.scale,
      offsetY: offsetY ?? this.offsetY,
    );
  }

  Map<String, dynamic> toJson() => {
        'scale': scale,
        'offsetY': offsetY,
      };

  factory ReceiptBlockLayout.fromJson(dynamic json) {
    if (json is! Map) return const ReceiptBlockLayout();
    final m = Map<String, dynamic>.from(json);
    return ReceiptBlockLayout(
      scale: (m['scale'] is num) ? (m['scale'] as num).toDouble().clamp(0.4, 2.5) : 1.0,
      offsetY: (m['offsetY'] is num) ? (m['offsetY'] as num).toDouble().clamp(-80, 80) : 0,
    );
  }
}

/// Tahrirlash rejimida tanlangan blok.
enum ReceiptEditableBlock {
  logo,
  storeName,
  footerText,
  footerImage,
  barcode,
}
