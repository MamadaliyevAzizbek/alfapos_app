import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';

import '../core/input_formatters.dart';
import '../models/receipt_design_config.dart';
import '../models/receipt_print_data.dart';

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

    final store = _safe(data.storeName);
    bytes.addAll(
      g.text(
        store,
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      ),
    );

    final extra = data.design.headerExtraText.trim();
    if (extra.isNotEmpty) {
      bytes.addAll(g.text(_safe(extra), styles: const PosStyles(align: PosAlign.center)));
    }

    if (data.isPrecheck) {
      bytes.addAll(
        g.text(
          'OLDINDAN CHEK',
          styles: const PosStyles(align: PosAlign.center, bold: true),
        ),
      );
    }

    bytes.addAll(g.feed(1));
    bytes.addAll(
      g.text(
        _dateTimeLine(data),
        styles: const PosStyles(align: PosAlign.center),
      ),
    );

    bytes.addAll(g.feed(1));
    bytes.addAll(g.text(_safe(
      data.isPrecheck ? "Chek raqami: to'lov oldin" : 'Chek raqami: ${data.receiptNumber}',
    )));
    bytes.addAll(g.text(_safe('Sotuvchi: ${data.sellerName}')));

    if (data.design.showSellerPhone &&
        data.sellerPhone != null &&
        data.sellerPhone!.trim().isNotEmpty) {
      bytes.addAll(g.text(_safe('Sotuvchi nomeri: ${data.sellerPhone!.trim()}')));
    }

    if (data.design.showClient &&
        data.clientName != null &&
        data.clientName!.trim().isNotEmpty) {
      bytes.addAll(g.text(_safe('Mijoz: ${data.clientName!.trim()}')));
    }

    if (data.design.showDescription &&
        (data.description ?? '').trim().isNotEmpty) {
      bytes.addAll(g.text(_safe('Tavsif: ${data.description!.trim()}')));
    }

    bytes.addAll(g.feed(1));

    if (data.design.usesNumberedProducts) {
      bytes.addAll(_numberedProducts(g, data));
    } else {
      bytes.addAll(_tableProducts(g, data));
    }

    if (!data.isPrecheck) {
      for (final p in data.paymentRows) {
        bytes.addAll(g.text(_twoCol(p.methodName, _money(p.sum, data.design.useSomSuffix))));
      }
      bytes.addAll(g.text(_twoCol('Chegirma', _money(data.discount, data.design.useSomSuffix))));
      bytes.addAll(
        g.text(
          _twoCol('Umumiy summa', _money(data.totalSum, data.design.useSomSuffix)),
          styles: const PosStyles(bold: true),
        ),
      );
    } else {
      bytes.addAll(g.text(_twoCol('Chegirma', _money(data.discount, data.design.useSomSuffix))));
      bytes.addAll(
        g.text(
          _twoCol('Umumiy summa', _money(data.totalSum, data.design.useSomSuffix)),
          styles: const PosStyles(bold: true),
        ),
      );
      bytes.addAll(
        g.text(
          "To'lov hali amalga oshirilmagan",
          styles: const PosStyles(align: PosAlign.center),
        ),
      );
    }

    final footer = data.design.footerText.trim();
    if (footer.isNotEmpty && !data.isPrecheck) {
      bytes.addAll(g.feed(1));
      bytes.addAll(g.text(_safe(footer), styles: const PosStyles(align: PosAlign.center)));
    }

    bytes.addAll(g.feed(2));
    bytes.addAll(g.cut());
    return bytes;
  }

  static List<int> _numberedProducts(Generator g, ReceiptPrintData data) {
    final out = <int>[];
    var i = 1;
    for (final row in data.productRows) {
      out.addAll(g.text(_safe('$i) ${row.productName}')));
      final left = '${row.quantityStr} x ${_money(row.price, data.design.useSomSuffix)}.';
      final right = _money(row.sum, data.design.useSomSuffix);
      out.addAll(g.text(_twoCol(left, right)));
      i++;
    }
    return out;
  }

  static List<int> _tableProducts(Generator g, ReceiptPrintData data) {
    final out = <int>[];
    if (data.design.showTableHeaders) {
      out.addAll(
        g.row([
          PosColumn(text: 'Mahsulot', width: 5, styles: const PosStyles(bold: true)),
          PosColumn(text: 'Miq', width: 2, styles: const PosStyles(bold: true)),
          PosColumn(text: 'Narx', width: 2, styles: const PosStyles(bold: true)),
          PosColumn(
            text: 'Summa',
            width: 3,
            styles: const PosStyles(bold: true, align: PosAlign.right),
          ),
        ]),
      );
    }
    for (final row in data.productRows) {
      out.addAll(
        g.row([
          PosColumn(text: _safe(row.productName), width: 5),
          PosColumn(text: _safe(row.quantityStr), width: 2),
          PosColumn(text: formatThousands(row.price), width: 2),
          PosColumn(
            text: formatThousands(row.sum),
            width: 3,
            styles: const PosStyles(align: PosAlign.right),
          ),
        ]),
      );
    }
    return out;
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
    final r = _safe(right);
    final l = _safe(left);
    final rw = r.length;
    if (rw >= lineWidth) return r.substring(0, lineWidth);
    final lw = lineWidth - rw;
    if (l.length >= lw) return l.substring(0, lw) + r;
    return l.padRight(lw) + r;
  }

  /// Printer CP1251 — noaniq belgilarni almashtirish.
  static String _safe(String s) {
    return s
        .replaceAll('‘', "'")
        .replaceAll('’', "'")
        .replaceAll('“', '"')
        .replaceAll('”', '"')
        .replaceAll('—', '-')
        .replaceAll('…', '...');
  }
}
