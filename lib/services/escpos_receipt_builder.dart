import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';

import '../core/input_formatters.dart';
import '../models/receipt_design_config.dart';
import '../models/receipt_print_data.dart';
import '../utils/escpos_text_codec.dart';

/// 80mm termal printer uchun ESC/POS matn (aniq shrift, rasm emas).
class EscPosReceiptBuilder {
  EscPosReceiptBuilder._();

  /// 80mm, Font A — taxminan 48 belgi.
  static const int lineWidth = 48;

  static Future<List<int>> build(ReceiptPrintData data) async {
    final profile = await CapabilityProfile.load();
    final g = Generator(PaperSize.mm80, profile);
    final bytes = <int>[];

    bytes.addAll(g.reset());
    bytes.addAll(g.setGlobalCodeTable('CP1251'));

    final store = data.storeName.trim();
    bytes.addAll(
      await _text(
        g,
        store,
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
          codeTable: 'CP1251',
        ),
      ),
    );

    final extra = data.design.headerExtraText.trim();
    if (extra.isNotEmpty) {
      bytes.addAll(
        await _text(g, extra, styles: const PosStyles(align: PosAlign.center, codeTable: 'CP1251')),
      );
    }

    if (data.isPrecheck) {
      bytes.addAll(
        await _text(
          g,
          'OLDINDAN CHEK',
          styles: const PosStyles(align: PosAlign.center, bold: true, codeTable: 'CP1251'),
        ),
      );
    }

    bytes.addAll(g.feed(1));
    bytes.addAll(
      await _text(
        g,
        _dateTimeLine(data),
        styles: const PosStyles(align: PosAlign.center, codeTable: 'CP1251'),
      ),
    );

    bytes.addAll(g.feed(1));
    bytes.addAll(await _text(
      g,
      data.isPrecheck ? "Chek raqami: to'lov oldin" : 'Chek raqami: ${data.receiptNumber}',
    ));
    bytes.addAll(await _text(g, 'Sotuvchi: ${data.sellerName}'));

    if (data.design.showSellerPhone &&
        data.sellerPhone != null &&
        data.sellerPhone!.trim().isNotEmpty) {
      bytes.addAll(await _text(g, 'Sotuvchi nomeri: ${data.sellerPhone!.trim()}'));
    }

    if (data.design.showClient &&
        data.clientName != null &&
        data.clientName!.trim().isNotEmpty) {
      bytes.addAll(await _text(g, 'Mijoz: ${data.clientName!.trim()}'));
    }

    if (data.design.showDescription &&
        (data.description ?? '').trim().isNotEmpty) {
      bytes.addAll(await _text(g, 'Tavsif: ${data.description!.trim()}'));
    }

    bytes.addAll(g.feed(1));

    if (data.design.usesNumberedProducts) {
      bytes.addAll(await _numberedProducts(g, data));
    } else {
      bytes.addAll(await _tableProducts(g, data));
    }

    if (!data.isPrecheck) {
      for (final p in data.paymentRows) {
        bytes.addAll(await _text(g, _twoCol(p.methodName, _money(p.sum, data.design.useSomSuffix))));
      }
      bytes.addAll(await _text(g, _twoCol('Chegirma', _money(data.discount, data.design.useSomSuffix))));
      bytes.addAll(
        await _text(
          g,
          _twoCol('Umumiy summa', _money(data.totalSum, data.design.useSomSuffix)),
          styles: const PosStyles(bold: true, codeTable: 'CP1251'),
        ),
      );
    } else {
      bytes.addAll(await _text(g, _twoCol('Chegirma', _money(data.discount, data.design.useSomSuffix))));
      bytes.addAll(
        await _text(
          g,
          _twoCol('Umumiy summa', _money(data.totalSum, data.design.useSomSuffix)),
          styles: const PosStyles(bold: true, codeTable: 'CP1251'),
        ),
      );
      bytes.addAll(
        await _text(
          g,
          "To'lov hali amalga oshirilmagan",
          styles: const PosStyles(align: PosAlign.center, codeTable: 'CP1251'),
        ),
      );
    }

    final footer = data.design.footerText.trim();
    if (footer.isNotEmpty && !data.isPrecheck) {
      bytes.addAll(g.feed(1));
      bytes.addAll(
        await _text(g, footer, styles: const PosStyles(align: PosAlign.center, codeTable: 'CP1251')),
      );
    }

    bytes.addAll(g.feed(2));
    bytes.addAll(g.cut());
    return bytes;
  }

  static Future<List<int>> _text(
    Generator g,
    String text, {
    PosStyles styles = const PosStyles(codeTable: 'CP1251'),
  }) async {
    final enc = await EscPosTextCodec.encode(text);
    return g.textEncoded(enc, styles: styles);
  }

  static Future<List<int>> _numberedProducts(Generator g, ReceiptPrintData data) async {
    final out = <int>[];
    var i = 1;
    for (final row in data.productRows) {
      out.addAll(await _text(g, '$i) ${row.productName}'));
      final left = '${_qtyLabel(row.quantityStr)} x ${_money(row.price, data.design.useSomSuffix)}.';
      final right = _money(row.sum, data.design.useSomSuffix);
      out.addAll(await _text(g, _twoCol(left, right)));
      i++;
    }
    return out;
  }

  static Future<List<int>> _tableProducts(Generator g, ReceiptPrintData data) async {
    final out = <int>[];
    if (data.design.showTableHeaders) {
      out.addAll(
        await _row(g, [
          await _col('Mahsulot', 5, bold: true),
          await _col('Miq', 2, bold: true),
          await _col('Narx', 2, bold: true),
          await _col('Summa', 3, bold: true, align: PosAlign.right),
        ]),
      );
    }
    for (final row in data.productRows) {
      out.addAll(
        await _row(g, [
          await _col(row.productName, 5),
          await _col(_qtyLabel(row.quantityStr), 2),
          await _col(formatThousands(row.price), 2),
          await _col(formatThousands(row.sum), 3, align: PosAlign.right),
        ]),
      );
    }
    return out;
  }

  static Future<PosColumn> _col(
    String text,
    int width, {
    bool bold = false,
    PosAlign align = PosAlign.left,
  }) async {
    final enc = await EscPosTextCodec.encode(text);
    return PosColumn(
      textEncoded: enc,
      width: width,
      styles: PosStyles(
        bold: bold,
        align: align,
        codeTable: 'CP1251',
      ),
    );
  }

  static Future<List<int>> _row(Generator g, List<PosColumn> cols) async {
    return g.row(cols);
  }

  /// `1шт` → `1 sht` (kirill qisqartma ham CP1251 da ishlaydi, lekin xavfsiz).
  static String _qtyLabel(String qty) {
    return qty
        .replaceAll('шт', 'sht')
        .replaceAll('Шт', 'sht')
        .replaceAll('ШТ', 'sht');
  }

  static String _dateTimeLine(ReceiptPrintData data) {
    final d = data.dateTime;
    final date =
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final time =
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}:${d.second.toString().padLeft(2, '0')}';
    final sep = data.design.template == ReceiptTemplateKind.numberedList ? ' | ' : ' - ';
    return '$date$sep$time';
  }

  static String _money(int n, bool som) {
    final base = formatThousands(n);
    return som ? "$base so'm" : base;
  }

  static String _twoCol(String left, String right) {
    final r = right;
    final l = left;
    final rw = r.length;
    if (rw >= lineWidth) return r.substring(0, lineWidth);
    final lw = lineWidth - rw;
    if (l.length >= lw) return l.substring(0, lw) + r;
    return l.padRight(lw) + r;
  }
}
