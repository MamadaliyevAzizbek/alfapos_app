import 'package:alfapos_app/utils/product_search.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('looksLikeBarcodeInput detects numeric codes', () {
    expect(looksLikeBarcodeInput('1234567890123'), isTrue);
    expect(looksLikeBarcodeInput('1234'), isFalse);
    expect(looksLikeBarcodeInput('123 456 78901234'), isTrue);
    expect(looksLikeBarcodeInput('cola'), isFalse);
    expect(looksLikeBarcodeInput('123 cola'), isFalse);
    expect(looksLikeBarcodeInput(''), isFalse);
  });
}
