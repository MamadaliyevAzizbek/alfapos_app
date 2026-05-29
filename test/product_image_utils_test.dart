import 'package:alfapos_app/core/product_image_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProductImageUtils', () {
    test('isLocalFilePath detects Windows and app-local paths', () {
      expect(ProductImageUtils.isLocalFilePath(r'C:\Users\test\product_images\img_1.jpg'), isTrue);
      expect(ProductImageUtils.isLocalFilePath('/var/mobile/product_images/img.jpg'), isTrue);
      expect(ProductImageUtils.isLocalFilePath('uploads/products/a.jpg'), isFalse);
      expect(ProductImageUtils.isLocalFilePath('https://app.alfapos.uz/uploads/a.jpg'), isFalse);
    });

    test('resolveToUrl maps foreign Windows path to server uploads by filename', () {
      final url = ProductImageUtils.resolveToUrl(r'C:\Users\Ali\product_images\img_12345.jpg');
      expect(url, 'https://app.alfapos.uz/uploads/products/img_12345.jpg');
    });

    test('resolveToUrl keeps normal server-relative paths', () {
      expect(
        ProductImageUtils.resolveToUrl('uploads/products/photo.png'),
        'https://app.alfapos.uz/uploads/products/photo.png',
      );
      expect(
        ProductImageUtils.resolveToUrl('product_99.jpg'),
        'https://app.alfapos.uz/uploads/products/product_99.jpg',
      );
    });
  });
}
