import 'package:alfapos_app/utils/sale_store_response.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SaleStoreResponse stock quantity', () {
    test('detects checkAvailableQuantity failure', () {
      expect(
        SaleStoreResponse.isStockQuantityCheckFailed({'checkAvailableQuantity': 'true'}),
        isTrue,
      );
      expect(
        SaleStoreResponse.isStockQuantityCheckFailed({'checkAvailableQuantity': true}),
        isTrue,
      );
      expect(
        SaleStoreResponse.isStockQuantityCheckFailed({'success': true}),
        isFalse,
      );
    });

    test('extracts message list', () {
      expect(
        SaleStoreResponse.stockQuantityErrorMessage({
          'message': ['Mahsulot omborda yo\'q!', 'Mavjud miqdor: 3.'],
        }),
        "Mahsulot omborda yo'q!\nMavjud miqdor: 3.",
      );
    });
  });
}
