import 'dart:typed_data';

import 'package:alfapos_app/utils/product_image_upload.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  test('resolveLocalPath ignores http and accepts local paths', () {
    expect(ProductImageUpload.resolveLocalPath('https://app.alfapos.uz/uploads/a.jpg'), isNull);
    expect(ProductImageUpload.resolveLocalPath('/tmp/photo.jpg'), '/tmp/photo.jpg');
    expect(
      ProductImageUpload.resolveLocalPath(r'C:\Users\test\img.png'),
      r'C:\Users\test\img.png',
    );
  });

  test('resolveLocalPath strips file URI prefix', () {
    final p = ProductImageUpload.resolveLocalPath('file:///tmp/x.jpg');
    expect(p, isNotNull);
    expect(p!.endsWith('x.jpg') || p.contains('x.jpg'), isTrue);
  });

  test('bakeOrientation 6 turns landscape pixels into portrait', () {
    final landscape = img.Image(width: 40, height: 20);
    img.fill(landscape, color: img.ColorRgb8(0, 180, 0));
    for (var y = 0; y < landscape.height; y++) {
      landscape.setPixelRgb(0, y, 220, 0, 0);
    }
    landscape.exif.imageIfd.orientation = 6;

    final baked = ProductImageUpload.bakeAndResizeForUpload(landscape, maxSide: 1280);
    expect(baked.width, 20);
    expect(baked.height, 40);
  });

  test('normalizeJpegBytesSync bakes EXIF and keeps portrait', () {
    final landscape = img.Image(width: 40, height: 20);
    img.fill(landscape, color: img.ColorRgb8(10, 10, 200));
    landscape.exif.imageIfd.orientation = 6;
    final raw = Uint8List.fromList(img.encodeJpg(landscape));

    final out = ProductImageUpload.normalizeJpegBytesSync(raw);
    expect(out, isNotNull);
    final decoded = img.decodeImage(out!);
    expect(decoded, isNotNull);
    expect(decoded!.height, greaterThan(decoded.width));
  });

  test('bakeAndResizeForUpload shrinks long side to maxSide', () {
    final big = img.Image(width: 2000, height: 1000);
    img.fill(big, color: img.ColorRgb8(30, 30, 30));
    final out = ProductImageUpload.bakeAndResizeForUpload(big, maxSide: 1280);
    expect(out.width, 1280);
    expect(out.height, 640);
  });

  test('normalizeJpegBytesSync returns smaller jpeg than huge source', () {
    final big = img.Image(width: 1600, height: 1200);
    img.fill(big, color: img.ColorRgb8(80, 80, 80));
    final raw = Uint8List.fromList(img.encodeJpg(big, quality: 100));
    final out = ProductImageUpload.normalizeJpegBytesSync(raw);
    expect(out, isNotNull);
    expect(out!.length, lessThan(raw.length));
    final decoded = img.decodeImage(out);
    expect(decoded!.width <= 1280, isTrue);
    expect(decoded.height <= 1280, isTrue);
  });
}
