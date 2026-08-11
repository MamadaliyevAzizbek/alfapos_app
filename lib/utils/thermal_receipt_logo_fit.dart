import 'package:image/image.dart' as img;

/// Chek logosi — bitta standart ramka: kichik rasm kattalashtiriladi,
/// katta rasm kichraytiriladi. Balandlik cheklangan (qog‘oz isrofi yo‘q).
abstract class ThermalReceiptLogoFit {
  ThermalReceiptLogoFit._();

  /// 80mm: ~32 mm kenglik, ~10 mm balandlik.
  static const int width80 = 240;
  static const int height80 = 72;

  /// 58mm: biroz ixchamroq.
  static const int width58 = 184;
  static const int height58 = 56;

  /// Sozlamalar / ekran preview (logical px).
  static const double previewWidth = 240;
  static const double previewHeight = 72;

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
    if (w == src.width && h == src.height) return src;
    return img.copyResize(
      src,
      width: w,
      height: h,
      interpolation: scale < 1 ? img.Interpolation.average : img.Interpolation.linear,
    );
  }

  static img.Image fit(img.Image src, {required bool mm58}) {
    final box = boxFor(mm58: mm58);
    return fitToBox(src, box.width, box.height);
  }
}
