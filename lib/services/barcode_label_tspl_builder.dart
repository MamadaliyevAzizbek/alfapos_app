import 'dart:typed_data';

import '../models/barcode_label_config.dart';
import '../models/product.dart';
import '../utils/escpos_text_codec.dart';
import '../utils/barcode_label_format.dart';

/// Xprinter TSPL2 yorliq — native TEXT+BARCODE.
///
/// Xprinter XP-365B `alignment` parametrini qo‘llamaydi — faqat qo‘lda markazlash.
class BarcodeLabelTsplBuilder {
  BarcodeLabelTsplBuilder._();

  static const double _dpi = 203;

  // TSPL font o‘lchamlari (dot) — markazlash uchun biroz kengroq taxmin.
  static const int _f2w = 14;
  static const int _f2h = 20;
  static const int _f3w = 18;
  static const int _f3h = 24;

  static Future<Uint8List> buildNative({
    required Product product,
    required String barcode,
    required BarcodeLabelConfig config,
  }) async {
    final cfg = config.normalized();
    final wMm = cfg.widthMm.round().clamp(20, 100);
    final hMm = cfg.heightMm.round().clamp(15, 80);
    final copies = cfg.copies;

    final header = _headerText(cfg, product);
    final name = product.name.trim().toUpperCase();
    final code = barcode.trim();

    final labelW = _mmToDots(wMm);
    final labelH = _mmToDots(hMm);

    final isShop = cfg.template == BarcodeLabelTemplate.shopName;
    const headerXMul = 1;
    final headerYMul = isShop ? 2 : (labelH >= 200 ? 2 : 1);
    final headerCharW = isShop ? _f2w : _f3w;
    final headerH = (isShop ? _f2h : _f3h) * headerYMul;
    final headerY = 8;

    final barcodeType = _tsplBarcodeType(code);
    final barcodeData = _tsplBarcodeData(code, barcodeType);
    final modules = _barcodeModulesTotal(barcodeType);

    var narrow = 2;
    for (var n = 3; n >= 1; n--) {
      if (modules * n <= labelW - 20) {
        narrow = n;
        break;
      }
    }
    final wide = (narrow + 1).clamp(narrow, 4);
    final barcodePrintW = modules * narrow;
    final barcodeX = _centerBlockX(labelW, barcodePrintW);

    final barcodeY = headerY + headerH + 8;
    final barcodeH = (labelH * 0.32).round().clamp(40, labelH ~/ 2);

    final codeY = barcodeY + barcodeH + 6;
    final nameY = codeY + _f2h + 6;

    final out = BytesBuilder(copy: false);
    void cmd(String line) {
      out.add(EscPosTextCodec.encodeSync('$line\r\n', codePage: 'CP1251'));
    }

    cmd('SIZE $wMm mm,$hMm mm');
    cmd('GAP 2 mm,0 mm');
    cmd('DENSITY 12');
    cmd('SPEED 3');
    cmd('DIRECTION 0');
    cmd('REFERENCE 0,0');
    cmd('CLS');

    // 1) Narx yoki do‘kon nomi
    final headerX = _centerTextX(
      header,
      labelW,
      charW: headerCharW,
      xMul: headerXMul,
    );
    if (isShop) {
      cmd(
        'TEXT $headerX,$headerY,"2",0,$headerXMul,$headerYMul,"${_escape(header)}"',
      );
    } else {
      cmd(
        'TEXT $headerX,$headerY,"3",0,$headerXMul,$headerYMul,"${_escape(header)}"',
      );
    }

    // 2) Shtrix
    cmd(
      'BARCODE $barcodeX,$barcodeY,"$barcodeType",$barcodeH,0,0,$narrow,$wide,"${_escape(barcodeData)}"',
    );

    // 3) Raqam
    final codeX = _centerTextX(code, labelW, charW: _f2w, xMul: 1);
    cmd('TEXT $codeX,$codeY,"2",0,1,1,"${_escape(code)}"');

    // 4) Mahsulot nomi
    final maxChars = ((labelW - 16) / _f2w).floor().clamp(8, 28);
    final nameLines = _wrapName(name, maxChars: maxChars);
    var ny = nameY;
    for (final line in nameLines.take(2)) {
      if (ny + _f2h > labelH - 6) break;
      final nx = _centerTextX(line, labelW, charW: _f2w, xMul: 1);
      cmd('TEXT $nx,$ny,"2",0,1,1,"${_escape(line)}"');
      ny += _f2h + 2;
    }

    cmd('PRINT 1,$copies');
    return out.toBytes();
  }

  static String _headerText(BarcodeLabelConfig cfg, Product product) {
    if (cfg.template == BarcodeLabelTemplate.shopName) {
      return cfg.shopName.trim().toUpperCase();
    }
    return BarcodeLabelFormat.labelPriceText(product);
  }

  static int _mmToDots(int mm) => (mm * _dpi / 25.4).round();

  static String _tsplBarcodeType(String code) {
    final digits = code.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 13) return 'EAN13';
    if (digits.length == 8) return 'EAN8';
    return '128';
  }

  static String _tsplBarcodeData(String code, String type) {
    final digits = code.replaceAll(RegExp(r'\D'), '');
    if (type == 'EAN13') {
      return digits.length >= 13 ? digits.substring(0, 13) : digits;
    }
    if (type == 'EAN8') {
      return digits.length >= 8 ? digits.substring(0, 8) : digits;
    }
    return code.trim();
  }

  /// EAN13: 95 modul + quiet zone.
  static int _barcodeModulesTotal(String type) {
    switch (type) {
      case 'EAN13':
        return 110;
      case 'EAN8':
        return 82;
      default:
        return 100;
    }
  }

  static int _centerBlockX(int labelW, int blockW) {
    if (blockW >= labelW - 8) return 4;
    return ((labelW - blockW) / 2).round().clamp(4, labelW - blockW - 4);
  }

  static int _centerTextX(
    String text,
    int labelW, {
    required int charW,
    required int xMul,
  }) {
    final w = text.runes.length * charW * xMul;
    return _centerBlockX(labelW, w);
  }

  static List<String> _wrapName(String name, {required int maxChars}) {
    if (name.length <= maxChars) return [name];
    final words = name.split(RegExp(r'\s+'));
    final lines = <String>[];
    var cur = '';
    for (final w in words) {
      if (cur.isEmpty) {
        cur = w.length <= maxChars ? w : w.substring(0, maxChars);
      } else if (('$cur $w').length <= maxChars) {
        cur = '$cur $w';
      } else {
        lines.add(cur);
        cur = w.length <= maxChars ? w : w.substring(0, maxChars);
      }
    }
    if (cur.isNotEmpty) lines.add(cur);
    return lines.isEmpty
        ? [name.substring(0, name.length.clamp(0, maxChars))]
        : lines;
  }

  static String _escape(String s) =>
      s.replaceAll('\\', '\\\\').replaceAll('"', '\\"');
}
