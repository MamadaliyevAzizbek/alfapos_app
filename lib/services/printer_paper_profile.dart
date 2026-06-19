/// Printer modeliga qarab chek margin va kesish sozlamalari.
abstract class PrinterPaperProfile {
  PrinterPaperProfile._();

  static const _compactPatterns = [
    'btp',
    'snbc',
    'u60',
    'u80',
  ];

  /// SNBC / BTP kabi printerlarda chek atrofida katta bo‘sh joy qolmasin.
  static bool needsCompactLayout(String? printerName) {
    final n = printerName?.trim().toLowerCase() ?? '';
    if (n.isEmpty) return false;
    return _compactPatterns.any(n.contains);
  }

  /// Chop etish maydoni: chap margin 0, to‘liq 80mm kenglik (576 nuqta).
  static List<int> fullWidthMarginBytes() => const [
        29, 76, 0, 0, // GS L 0 — chap margin
        29, 87, 0x40, 2, // GS W 576 — print kengligi
        27, 51, 24, // ESC 3 24 — ixcham qator oralig‘i
      ];

  /// Kesishdan oldin minimal feed (cut() ichidagi 5 qator emas).
  static List<int> minimalCutBytes({bool partial = true}) => [
        27, 100, 2, // ESC d 2
        if (partial) ...[29, 86, 1] else ...[29, 86, 0], // GS V 1 yoki GS V 0
      ];
}
