import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// 80mm termal printer (203 DPI) uchun standart chop kengligi.
const int thermalPrintWidthPx = 576;

/// Chek skrinshotini termal printer uchun: o'lcham + qattiq qora-oq (xira emas).
Uint8List prepareThermalBitmap(Uint8List pngBytes, {int targetWidth = thermalPrintWidthPx}) {
  final decoded = img.decodeImage(pngBytes);
  if (decoded == null) return pngBytes;

  final resized = decoded.width == targetWidth
      ? decoded
      : img.copyResize(
          decoded,
          width: targetWidth,
          interpolation: img.Interpolation.nearest,
        );

  final mono = img.grayscale(resized);
  const threshold = 168;

  for (var y = 0; y < mono.height; y++) {
    for (var x = 0; x < mono.width; x++) {
      final p = mono.getPixel(x, y);
      final lum = p.r.toInt();
      final v = lum < threshold ? 0 : 255;
      mono.setPixelRgba(x, y, v, v, v, 255);
    }
  }

  return Uint8List.fromList(img.encodePng(mono));
}

/// ReceiptWidget (302 logical px) uchun skrinshot pixelRatio.
double thermalReceiptCapturePixelRatio({int targetWidth = thermalPrintWidthPx}) {
  const logicalWidth = 302.0;
  return (targetWidth / logicalWidth).clamp(2.5, 4.0);
}
