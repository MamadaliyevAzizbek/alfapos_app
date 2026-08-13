import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Chek logosi — shaffof chetlarni kesadi, oq fonda tekislaydi,
/// qattiq qora-oq qilib 80/58 mm ramkaga sig‘diradi.
abstract class ThermalReceiptLogoFit {
  ThermalReceiptLogoFit._();

  /// 80mm (~203 DPI): ~48×27 mm — o‘qilishi uchun yetarli, qog‘oz isrofi yo‘q.
  static const int width80 = 384;
  static const int height80 = 220;

  /// 58mm: ixchamroq.
  static const int width58 = 256;
  static const int height58 = 144;

  /// Sozlamalar / ekran preview (logical px).
  static const double previewWidth = 200;
  static const double previewHeight = 112;

  static const int _nearWhiteLum = 248;
  static const int _printThreshold = 168;

  static ({int width, int height}) boxFor({required bool mm58}) => mm58
      ? (width: width58, height: height58)
      : (width: width80, height: height80);

  /// Shaffof/oq chetlarni kesib, oq fonda tekislaydi (resize dan oldin).
  static img.Image prepareSource(img.Image src) {
    var work = src;
    if (work.hasAlpha) {
      work = _cropTrim(
        work,
        img.findTrim(work, mode: img.TrimMode.transparent),
        pad: 8,
      );
      work = _flattenOnWhite(work);
    }
    work = _trimNearWhite(work, pad: 4);
    return work;
  }

  /// Diskka saqlash: kesilgan, ixcham PNG (preview va keyingi chop tezroq).
  static img.Image prepareForStorage(img.Image src, {int maxSide = 960}) {
    var work = prepareSource(src);
    final side = work.width > work.height ? work.width : work.height;
    if (side > maxSide) {
      final scale = maxSide / side;
      work = img.copyResize(
        work,
        width: (work.width * scale).round().clamp(1, maxSide),
        height: (work.height * scale).round().clamp(1, maxSide),
        interpolation: img.Interpolation.average,
      );
    }
    return work;
  }

  static Uint8List? preparePngBytes(Uint8List raw, {int maxSide = 960}) {
    if (raw.length < 24) return null;
    try {
      final decoded = img.decodeImage(raw);
      if (decoded == null) return null;
      return Uint8List.fromList(
        img.encodePng(prepareForStorage(decoded, maxSide: maxSide)),
      );
    } catch (_) {
      return null;
    }
  }

  /// Rasmni [maxW]×[maxH] ichiga to‘liq sig‘diradi (contain), kichik bo‘lsa ham.
  static img.Image fitToBox(img.Image src, int maxW, int maxH) {
    if (src.width <= 0 || src.height <= 0 || maxW <= 0 || maxH <= 0) return src;
    var work = prepareSource(src);
    final scaleW = maxW / work.width;
    final scaleH = maxH / work.height;
    final scale = scaleW < scaleH ? scaleW : scaleH;
    final w = (work.width * scale).round().clamp(1, maxW);
    final h = (work.height * scale).round().clamp(1, maxH);
    if (w != work.width || h != work.height) {
      work = img.copyResize(
        work,
        width: w,
        height: h,
        interpolation:
            scale < 1 ? img.Interpolation.average : img.Interpolation.cubic,
      );
    }
    return _padWidthMultipleOf8(_toHighContrast(work));
  }

  /// GS v 0 kenglikni 8 ga bo‘lishi shart — aks holda printer kutubxonasi yiqiladi.
  static img.Image _padWidthMultipleOf8(img.Image src) {
    final w = ((src.width + 7) ~/ 8) * 8;
    if (w == src.width) return src;
    final out = img.Image(width: w, height: src.height, numChannels: 3);
    img.fill(out, color: img.ColorRgb8(255, 255, 255));
    img.compositeImage(out, src, dstX: (w - src.width) ~/ 2);
    return out;
  }

  /// PNG shaffofligi termalda qora dog‘ bo‘lmasin.
  static img.Image _flattenOnWhite(img.Image src) {
    if (!src.hasAlpha) return src;
    final out = img.Image(width: src.width, height: src.height, numChannels: 3);
    img.fill(out, color: img.ColorRgb8(255, 255, 255));
    img.compositeImage(out, src);
    return out;
  }

  static img.Image _cropTrim(img.Image src, List<int> crop, {int pad = 0}) {
    if (crop.length < 4) return src;
    final cw = crop[2];
    final ch = crop[3];
    if (cw <= 0 || ch <= 0) return src;
    if (cw >= src.width && ch >= src.height && crop[0] == 0 && crop[1] == 0) {
      return src;
    }
    final x = (crop[0] - pad).clamp(0, src.width - 1);
    final y = (crop[1] - pad).clamp(0, src.height - 1);
    final x2 = (crop[0] + cw + pad).clamp(1, src.width);
    final y2 = (crop[1] + ch + pad).clamp(1, src.height);
    final w = x2 - x;
    final h = y2 - y;
    if (w <= 0 || h <= 0) return src;
    return img.copyCrop(src, x: x, y: y, width: w, height: h);
  }

  static img.Image _trimNearWhite(img.Image src, {int pad = 4}) {
    var minX = src.width;
    var minY = src.height;
    var maxX = -1;
    var maxY = -1;
    for (var y = 0; y < src.height; y++) {
      for (var x = 0; x < src.width; x++) {
        final p = src.getPixel(x, y);
        final lum = (p.r * 299 + p.g * 587 + p.b * 114) / 1000;
        if (lum >= _nearWhiteLum) continue;
        if (x < minX) minX = x;
        if (y < minY) minY = y;
        if (x > maxX) maxX = x;
        if (y > maxY) maxY = y;
      }
    }
    if (maxX < minX) return src;
    return _cropTrim(
      src,
      [minX, minY, maxX - minX + 1, maxY - minY + 1],
      pad: pad,
    );
  }

  /// Termal: faqat qora yoki oq — xira kulrang chekkalarni yo‘qotadi.
  static img.Image _toHighContrast(img.Image src) {
    final out = img.Image(width: src.width, height: src.height, numChannels: 3);
    for (var y = 0; y < src.height; y++) {
      for (var x = 0; x < src.width; x++) {
        final p = src.getPixel(x, y);
        final lum = (p.r * 299 + p.g * 587 + p.b * 114) / 1000;
        final v = lum < _printThreshold ? 0 : 255;
        out.setPixelRgb(x, y, v, v, v);
      }
    }
    return out;
  }

  /// ESC/POS GS v 0 — growable ro‘yxat, kutubxona `List.filled` xatosiz.
  static List<int> rasterGsV0(img.Image src) {
    final width = src.width;
    final height = src.height;
    if (width <= 0 || height <= 0) return const [];
    final widthBytes = (width + 7) ~/ 8;
    final packed = <int>[];
    for (var y = 0; y < height; y++) {
      for (var xb = 0; xb < widthBytes; xb++) {
        var byte = 0;
        for (var bit = 0; bit < 8; bit++) {
          final x = xb * 8 + bit;
          if (x >= width) continue;
          final p = src.getPixel(x, y);
          final lum = (p.r * 299 + p.g * 587 + p.b * 114) / 1000;
          if (lum < _printThreshold) {
            byte |= 0x80 >> bit;
          }
        }
        packed.add(byte);
      }
    }
    return <int>[
      27, 97, 1, // ESC a 1 — markaz
      29, 118, 48, 0, // GS v 0 m=0
      widthBytes & 0xFF,
      (widthBytes >> 8) & 0xFF,
      height & 0xFF,
      (height >> 8) & 0xFF,
      ...packed,
      10, // LF
      27, 97, 0, // chapga qaytarish
    ];
  }

  static img.Image fit(img.Image src, {required bool mm58}) {
    final box = boxFor(mm58: mm58);
    return fitToBox(src, box.width, box.height);
  }
}
