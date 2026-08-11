/// Printer modeliga qarab chek margin va kesish sozlamalari.
abstract class PrinterPaperProfile {
  PrinterPaperProfile._();

  static const _compactPatterns = [
    'btp',
    'snbc',
    'u60',
    'u80',
  ];

  /// Xprinter XP-80 / XP-80C / XP-80C USB.
  static bool isXprinter80(String? printerName) {
    final n = printerName?.trim().toLowerCase() ?? '';
    if (n.isEmpty) return false;
    return n.contains('xprinter') ||
        n.contains('xp-80') ||
        n.contains('xp 80') ||
        n.contains('xp80') ||
        n.contains('xp-80c') ||
        n.contains('80c');
  }

  /// SNBC / BTP kabi printerlarda chek atrofida katta bo‘sh joy qolmasin.
  static bool needsCompactLayout(String? printerName) {
    final n = printerName?.trim().toLowerCase() ?? '';
    if (n.isEmpty) return false;
    if (isXprinter80(n)) return true;
    return _compactPatterns.any(n.contains);
  }

  /// XP-80C pichoq ~15–18 mm: 6 qator — oxirgi qatorlar kesilmasin.
  static int feedBeforeCut(String? printerName) {
    if (isXprinter80(printerName)) return 6;
    return 2;
  }

  /// ESC 3 n — 24 yopishib ketadi; 32 qatorlar orasini ozgina ochadi.
  static const int lineSpacingDots = 32;

  /// Chop etish maydoni: chap margin 0, to‘liq 80mm kenglik (576 nuqta).
  static List<int> fullWidthMarginBytes() => const [
        29, 76, 0, 0, // GS L 0 — chap margin
        29, 87, 0x40, 2, // GS W 576 — print kengligi
        27, 51, lineSpacingDots,
      ];

  /// Logo `image()` dan keyin ESC 2 qator oralig‘ini kengaytiradi — qayta tiklash.
  static List<int> restoreCompactSpacingBytes() =>
      const [27, 51, lineSpacingDots];

  /// Kesishdan oldin minimal feed (cut() ichidagi 5 qator emas).
  static List<int> minimalCutBytes({
    bool partial = true,
    int feedLines = 2,
  }) => [
        27, 100, feedLines.clamp(0, 255), // ESC d n
        if (partial) ...[29, 86, 1] else ...[29, 86, 0], // GS V 1 yoki GS V 0
      ];
}
