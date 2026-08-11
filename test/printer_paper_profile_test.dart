import 'package:alfapos_app/services/printer_paper_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('XP-80C is treated as compact 80mm Xprinter', () {
    for (final name in [
      'XP-80C',
      'Xprinter XP-80C',
      'XP-80 C USB',
      'XP80C',
    ]) {
      expect(PrinterPaperProfile.isXprinter80(name), isTrue, reason: name);
      expect(PrinterPaperProfile.needsCompactLayout(name), isTrue, reason: name);
      expect(PrinterPaperProfile.feedBeforeCut(name), 8, reason: name);
    }
  });

  test('unknown printer keeps short feed, no false XP match', () {
    expect(PrinterPaperProfile.isXprinter80(null), isFalse);
    expect(PrinterPaperProfile.isXprinter80('HP LaserJet'), isFalse);
    expect(PrinterPaperProfile.feedBeforeCut(null), 2);
    expect(PrinterPaperProfile.feedBeforeCut('Generic'), 2);
  });

  test('restore spacing is ESC 3 44', () {
    expect(
      PrinterPaperProfile.restoreCompactSpacingBytes(),
      [27, 51, 44],
    );
  });
}
