import 'package:alfapos_app/models/product.dart';
import 'package:alfapos_app/utils/barcode_validation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Product catalogItem({
    required String id,
    required String name,
    String? barcode,
    List<String>? additional,
  }) {
    return Product(
      id: id,
      name: name,
      barcode: barcode,
      additionalBarcodes: additional,
      priceUzs: 1000,
    );
  }

  group('BarcodeValidation', () {
    test('detects duplicate within form', () {
      final msg = BarcodeValidation.validateForSave(
        barcodes: ['123', '456', '123'],
        catalog: [],
      );
      expect(msg, isNotNull);
      expect(msg, contains('forma ichida'));
    });

    test('detects duplicate in catalog', () {
      final catalog = [
        catalogItem(id: '1', name: 'Non', barcode: '7788649878923'),
      ];
      final msg = BarcodeValidation.validateForSave(
        barcodes: ['7788649878923'],
        catalog: catalog,
      );
      expect(msg, isNotNull);
      expect(msg, contains('Non'));
    });

    test('allows same product on edit', () {
      final catalog = [
        catalogItem(
          id: '42',
          name: 'Suv',
          barcode: '111',
          additional: ['222'],
        ),
      ];
      final msg = BarcodeValidation.validateForSave(
        barcodes: ['111', '222'],
        catalog: catalog,
        excludeProductId: '42',
      );
      expect(msg, isNull);
    });

    test('detects additional barcode conflict', () {
      final catalog = [
        catalogItem(id: '1', name: 'Choy', barcode: '100', additional: ['200']),
      ];
      final msg = BarcodeValidation.validateForSave(
        barcodes: ['200'],
        catalog: catalog,
      );
      expect(msg, isNotNull);
      expect(msg, contains('Choy'));
    });

    test('catalog purge removes product and same-barcode ghosts', () {
      final removed = catalogItem(id: '10', name: 'Eski', barcode: '7788649878923');
      final ghost = catalogItem(id: 'local_99', name: 'Eski nusxa', barcode: '7788649878923');
      final other = catalogItem(id: '2', name: 'Boshqa', barcode: '999');
      expect(BarcodeValidation.catalogEntryConflictsWithRemoved(removed, removed), isTrue);
      expect(BarcodeValidation.catalogEntryConflictsWithRemoved(ghost, removed), isTrue);
      expect(BarcodeValidation.catalogEntryConflictsWithRemoved(other, removed), isFalse);
    });

    test('leading zeros treated as same', () {
      final catalog = [
        catalogItem(id: '1', name: 'Yog', barcode: '00123'),
      ];
      final msg = BarcodeValidation.validateForSave(
        barcodes: ['123'],
        catalog: catalog,
      );
      expect(msg, isNotNull);
    });
  });
}
