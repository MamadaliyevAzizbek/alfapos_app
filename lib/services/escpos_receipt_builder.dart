import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';

import '../utils/escpos_text_codec.dart';

/// API dan parse qilingan matn qatorlarini ESC/POS ga aylantirish.
class EscPosReceiptBuilder {
  EscPosReceiptBuilder._();

  static Future<List<int>> buildFromLines(List<String> lines) async {
    final profile = await CapabilityProfile.load();
    final g = Generator(PaperSize.mm80, profile);
    final bytes = <int>[];

    bytes.addAll(g.reset());
    bytes.addAll(g.setGlobalCodeTable('CP1251'));

    for (final line in lines) {
      if (line.isEmpty) {
        bytes.addAll(g.feed(1));
        continue;
      }
      final enc = await EscPosTextCodec.encode(line);
      bytes.addAll(
        g.textEncoded(
          enc,
          styles: const PosStyles(codeTable: 'CP1251'),
        ),
      );
    }

    bytes.addAll(g.feed(2));
    bytes.addAll(g.cut());
    return bytes;
  }
}
