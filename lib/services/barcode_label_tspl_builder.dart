import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';

import '../models/barcode_label_config.dart';
import '../models/product.dart';
import '../utils/barcode_label_format.dart';
import '../utils/escpos_text_codec.dart';

/// Xprinter TSPL2 yorliq — native TEXT+BARCODE.
///
/// Kirill: printer ichki shriftida glif yo‘q — telefonda Noto Sans bilan
/// raster (BITMAP) qilib yuboriladi.
class BarcodeLabelTsplBuilder {
  BarcodeLabelTsplBuilder._();

  static const double _dpi = 203;
  static const String _printerTextCodePage = 'CP866';
  static const String _tsplCodePage = '1251';
  static const String _cyrillicFontFamily = 'AlfaPosLabelCyrillic';

  /// TSC spec: 0 = qora. Xprinter ko‘pincha shu formatni qabul qiladi.
  @visibleForTesting
  static const bool bitmapBlackIsOne = false;

  static bool _cyrillicFontReady = false;

  static const int _f2w = 14;
  static const int _f2h = 20;
  static const int _f3w = 18;
  static const int _f3h = 24;
  /// Kirill nomi BITMAP — native TEXT "2" dan biroz kattaroq.
  static const int _cyrillicNameFontSize = 21;
  static const int _cyrillicNameLineH = 26;

  static Future<Uint8List> buildNative({
    required Product product,
    required String barcode,
    required BarcodeLabelConfig config,
  }) async {
    await _ensureCyrillicFontLoaded();

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
    const headerY = 8;

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
      out.add(
        EscPosTextCodec.encodeSync(
          '$line\r\n',
          codePage: _printerTextCodePage,
        ),
      );
    }

    cmd('SIZE $wMm mm,$hMm mm');
    cmd('GAP 2 mm,0 mm');
    cmd('DENSITY 12');
    cmd('SPEED 3');
    cmd('DIRECTION 0');
    cmd('REFERENCE 0,0');
    cmd('CLS');
    cmd('CODEPAGE $_tsplCodePage');

    if (isShop && _containsCyrillic(header)) {
      out.add(
        await _buildTextBitmap(
          header,
          labelW: labelW,
          startY: headerY,
          height: headerH,
          fontSize: (18 * headerYMul).toDouble(),
        ),
      );
    } else {
      final headerX = _centerTextX(
        header,
        labelW,
        charW: headerCharW,
        xMul: headerXMul,
      );
      cmd(
        'TEXT $headerX,$headerY,"${isShop ? '2' : '3'}",0,$headerXMul,$headerYMul,"${_escape(header)}"',
      );
    }

    cmd(
      'BARCODE $barcodeX,$barcodeY,"$barcodeType",$barcodeH,0,0,$narrow,$wide,"${_escape(barcodeData)}"',
    );

    final codeX = _centerTextX(code, labelW, charW: _f2w, xMul: 1);
    cmd('TEXT $codeX,$codeY,"2",0,1,1,"${_escape(code)}"');

    final maxChars = _containsCyrillic(name)
        ? ((labelW - 16) / 11).floor().clamp(8, 24)
        : ((labelW - 16) / _f2w).floor().clamp(8, 28);
    final nameLines = _wrapName(name, maxChars: maxChars);
    if (_containsCyrillic(name)) {
      var ny = nameY;
      for (final line in nameLines.take(2)) {
        if (ny + _cyrillicNameLineH > labelH - 6) break;
        out.add(
          await _buildTextBitmap(
            line,
            labelW: labelW,
            startY: ny,
            height: _cyrillicNameLineH,
            fontSize: _cyrillicNameFontSize.toDouble(),
          ),
        );
        ny += _cyrillicNameLineH + 2;
      }
    } else {
      _appendNativeNameText(
        cmd,
        nameLines,
        labelW: labelW,
        labelH: labelH,
        startY: nameY,
      );
    }

    cmd('PRINT 1,$copies');
    return out.toBytes();
  }

  static Future<void> _ensureCyrillicFontLoaded() async {
    if (_cyrillicFontReady) return;
    try {
      final loader = FontLoader(_cyrillicFontFamily)
        ..addFont(rootBundle.load('assets/fonts/NotoSans-Regular.ttf'));
      await loader.load();
    } catch (_) {
      // pubspec.yaml dagi font ro‘yxati orqali ham ishlashi mumkin.
    }
    _cyrillicFontReady = true;
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
    if (digits.length == 13 && _validEan(digits)) return 'EAN13';
    if (digits.length == 8 && _validEan(digits)) return 'EAN8';
    return '128';
  }

  static String _tsplBarcodeData(String code, String type) {
    final digits = code.replaceAll(RegExp(r'\D'), '');
    if (type == 'EAN13') {
      return digits.length >= 13 ? digits.substring(0, 12) : digits;
    }
    if (type == 'EAN8') {
      return digits.length >= 8 ? digits.substring(0, 7) : digits;
    }
    return code.trim();
  }

  static bool _validEan(String digits) {
    if (digits.length != 8 && digits.length != 13) return false;
    final body = digits.substring(0, digits.length - 1);
    final expected = (10 -
            (List<int>.generate(
                  body.length,
                  (i) => int.parse(body[body.length - 1 - i]),
                ).indexed.fold<int>(
                      0,
                      (sum, entry) =>
                          sum + entry.$2 * (entry.$1.isEven ? 3 : 1),
                    ) %
                10)) %
        10;
    return expected == int.parse(digits[digits.length - 1]);
  }

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

  static bool _containsCyrillic(String text) =>
      RegExp(r'[\u0400-\u04FF]').hasMatch(text);

  static TextStyle _labelTextStyle(double fontSize) => TextStyle(
        color: const ui.Color(0xFF000000),
        fontSize: fontSize.clamp(10, 28),
        fontWeight: FontWeight.w600,
        fontFamily: _cyrillicFontFamily,
        fontFamilyFallback: const ['Noto Sans', 'Roboto', 'Arial'],
      );

  static Future<Uint8List> _buildTextBitmap(
    String text, {
    required int labelW,
    required int startY,
    required int height,
    required double fontSize,
  }) async {
    const scale = 2;
    final painter = TextPainter(
      text: TextSpan(text: text, style: _labelTextStyle(fontSize * scale)),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: (labelW - 16).toDouble() * scale);

    final contentW = painter.width.ceil().clamp(8, (labelW - 16) * scale);
    final renderW = ((contentW + 7) ~/ 8) * 8;
    final renderH = (height * scale).clamp(24, 400);
    if (renderH <= 0 || text.trim().isEmpty) return Uint8List(0);

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, renderW.toDouble(), renderH.toDouble()),
      ui.Paint()..color = const ui.Color(0xFFFFFFFF),
    );
    painter.paint(
      canvas,
      Offset(
        ((renderW - painter.width) / 2).clamp(0, renderW.toDouble()),
        ((renderH - painter.height) / 2).clamp(0, renderH.toDouble()),
      ),
    );

    final image = await recorder.endRecording().toImage(renderW, renderH);
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    if (data == null) return Uint8List(0);

    final rgba = data.buffer.asUint8List();
    final dstW = (((renderW / scale).ceil() + 7) ~/ 8) * 8;
    final dstH = (renderH / scale).ceil();
    final downscaled = _downscaleRgba(
      rgba: rgba,
      srcW: renderW,
      srcH: renderH,
      dstW: dstW,
      dstH: dstH,
    );

    final widthBytes = dstW ~/ 8;
    final bitmapHeight = downscaled.height;
    final packed = _packBitmapRgba(
      rgba: downscaled.rgba,
      width: dstW,
      widthBytes: widthBytes,
      height: bitmapHeight,
    );
    if (_countBlackPixels(packed) < 8) return Uint8List(0);

    final x = _centerBlockX(labelW, dstW);
    final out = BytesBuilder(copy: false);
    out.add('BITMAP $x,$startY,$widthBytes,$bitmapHeight,0,'.codeUnits);
    out.add(packed);
    out.add(const [13, 10]);
    return out.toBytes();
  }

  static ({Uint8List rgba, int width, int height}) _downscaleRgba({
    required Uint8List rgba,
    required int srcW,
    required int srcH,
    required int dstW,
    required int dstH,
  }) {
    final out = Uint8List(dstW * dstH * 4);
    for (var y = 0; y < dstH; y++) {
      final sy = (y * srcH / dstH).floor().clamp(0, srcH - 1);
      for (var x = 0; x < dstW; x++) {
        final sx = (x * srcW / dstW).floor().clamp(0, srcW - 1);
        final si = (sy * srcW + sx) * 4;
        final di = (y * dstW + x) * 4;
        out[di] = rgba[si];
        out[di + 1] = rgba[si + 1];
        out[di + 2] = rgba[si + 2];
        out[di + 3] = rgba[si + 3];
      }
    }
    return (rgba: out, width: dstW, height: dstH);
  }

  @visibleForTesting
  static Uint8List packBitmapRgbaForTest({
    required Uint8List rgba,
    required int width,
    required int widthBytes,
    required int height,
  }) =>
      _packBitmapRgba(
        rgba: rgba,
        width: width,
        widthBytes: widthBytes,
        height: height,
      );

  static Uint8List _packBitmapRgba({
    required Uint8List rgba,
    required int width,
    required int widthBytes,
    required int height,
  }) {
    final packed = Uint8List(widthBytes * height);
    if (bitmapBlackIsOne) {
      for (var y = 0; y < height; y++) {
        for (var x = 0; x < width; x++) {
          if (_rgbaIsDark(rgba, width, x, y)) {
            packed[y * widthBytes + x ~/ 8] |= 0x80 >> (x % 8);
          }
        }
      }
    } else {
      packed.fillRange(0, packed.length, 0xFF);
      for (var y = 0; y < height; y++) {
        for (var x = 0; x < width; x++) {
          if (_rgbaIsDark(rgba, width, x, y)) {
            packed[y * widthBytes + x ~/ 8] &= 0xFF ^ (0x80 >> (x % 8));
          }
        }
      }
    }
    return packed;
  }

  static bool _rgbaIsDark(Uint8List rgba, int width, int x, int y) {
    final i = (y * width + x) * 4;
    final alpha = rgba[i + 3];
    final luminance =
        (rgba[i] * 299 + rgba[i + 1] * 587 + rgba[i + 2] * 114) / 1000;
    return alpha > 32 && luminance < 180;
  }

  @visibleForTesting
  static int countBlackPixelsForTest(Uint8List packed) =>
      _countBlackPixels(packed);

  static int _countBlackPixels(Uint8List packed) {
    var count = 0;
    for (final b in packed) {
      for (var bit = 0; bit < 8; bit++) {
        final isOne = (b & (0x80 >> bit)) != 0;
        final isBlack = bitmapBlackIsOne ? isOne : !isOne;
        if (isBlack) count++;
      }
    }
    return count;
  }

  static void _appendNativeNameText(
    void Function(String) cmd,
    List<String> nameLines, {
    required int labelW,
    required int labelH,
    required int startY,
  }) {
    var ny = startY;
    for (final line in nameLines.take(2)) {
      if (ny + _f2h > labelH - 6) break;
      final nx = _centerTextX(line, labelW, charW: _f2w, xMul: 1);
      cmd('TEXT $nx,$ny,"2",0,1,1,"${_escape(line)}"');
      ny += _f2h + 2;
    }
  }

  static String _escape(String s) =>
      s.replaceAll('\\', '\\\\').replaceAll('"', '\\"');
}
