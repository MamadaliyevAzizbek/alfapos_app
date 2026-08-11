import 'package:image/image.dart' as img;

/// Chek logosi — bitta standart ramka: kichik rasm kattalashtiriladi,
/// katta rasm kichraytiriladi. Balandlik cheklangan (qog‘oz isrofi yo‘q).
abstract class ThermalReceiptLogoFit {
  ThermalReceiptLogoFit._();

  /// 80mm: kvadrat logo ~32 mm — 72 px tushunarsiz kichik edi.
  static const int width80 = 384;
  static const int height80 = 256;

  /// 58mm: biroz ixchamroq.
  static const int width58 = 256;
  static const int height58 = 160;

  /// Sozlamalar / ekran preview (logical px).
  static const double previewWidth = 192;
  static const double previewHeight = 128;

  static ({int width, int height}) boxFor({required bool mm58}) => mm58
      ? (width: width58, height: height58)
      : (width: width80, height: height80);

  /// Rasmni [maxW]×[maxH] ichiga to‘liq sig‘diradi (contain), kichik bo‘lsa ham.
  static img.Image fitToBox(img.Image src, int maxW, int maxH) {
    if (src.width <= 0 || src.height <= 0 || maxW <= 0 || maxH <= 0) return src;
    final scaleW = maxW / src.width;
    final scaleH = maxH / src.height;
    final scale = scaleW < scaleH ? scaleW : scaleH;
    final w = (src.width * scale).round().clamp(1, maxW);
    final h = (src.height * scale).round().clamp(1, maxH);
    var work = src;
    if (w != src.width || h != src.height) {
      work = img.copyResize(
        src,
        width: w,
        height: h,
        interpolation: scale < 1 ? img.Interpolation.average : img.Interpolation.cubic,
      );
    }
    return _padWidthMultipleOf8(_flattenOnWhite(work));
  }

  /// GS v 0 kenglikni 8 ga bo‘lishi shart — aks holda printer kutubxonasi yiqiladi.
  static img.Image _padWidthMultipleOf8(img.Image src) {
    final w = ((src.width + 7) ~/ 8) * 8;
    if (w == src.width) return src;
    final out = img.Image(width: w, height: src.height);
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
          if (lum < 160) {
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
      27, 97, 0, // chapga qaytarish
    ];
  }

  static img.Image fit(img.Image src, {required bool mm58}) {
    final box = boxFor(mm58: mm58);
    return fitToBox(src, box.width, box.height);
  }
}
