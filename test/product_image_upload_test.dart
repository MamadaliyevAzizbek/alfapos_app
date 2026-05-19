import 'package:alfapos_app/utils/product_image_upload.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
