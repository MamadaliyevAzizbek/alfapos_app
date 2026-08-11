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
    final prepared = _flattenOnWhite(src);
    final scaleW = maxW / prepared.width;
    final scaleH = maxH / prepared.height;
    final scale = scaleW < scaleH ? scaleW : scaleH;
    final w = (prepared.width * scale).round().clamp(1, maxW);
    final h = (prepared.height * scale).round().clamp(1, maxH);
    if (w == prepared.width && h == prepared.height) return prepared;
    return img.copyResize(
      prepared,
      width: w,
      height: h,
      interpolation: scale < 1 ? img.Interpolation.average : img.Interpolation.cubic,
    );
  }

  /// PNG shaffofligi termalda qora dog‘ bo‘lmasin.
  static img.Image _flattenOnWhite(img.Image src) {
    if (!src.hasAlpha) return src;
    final out = img.Image(width: src.width, height: src.height);
    img.fill(out, color: img.ColorRgb8(255, 255, 255));
    img.compositeImage(out, src);
    return out;
  }

  static img.Image fit(img.Image src, {required bool mm58}) {
    final box = boxFor(mm58: mm58);
    return fitToBox(src, box.width, box.height);
  }
}
