import 'dart:io';

import 'package:alfapos_app/models/cart_item.dart';
import 'package:alfapos_app/models/product.dart';
import 'package:alfapos_app/utils/hold_order_precheck_excel_export.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HoldOrderPrecheckExcelExport', () {
    test('buildSpreadsheetXml matches nakladnoy layout', () {
      final xml = HoldOrderPrecheckExcelExport.buildSpreadsheetXmlForTest(
        storeTitle: 'Alfa market',
        receiptNumber: 'POS10451',
        items: [
          CartItem(
            product: Product(
              id: '1',
              name: 'Cola',
              priceUzs: 5000,
              sku: 'SKU1',
            ),
            quantity: 2,
          ),
        ],
        total: 10000,
      );

      expect(xml, contains('Nakladnoy № POS10451, 12.06.2026'));
      expect(xml, contains("Do'kon:"));
      expect(xml, contains('Alfa market'));
      expect(xml, contains('Mahsulot kodi'));
      expect(xml, contains("O'lchov birligi"));
      expect(xml, contains('SKU1'));
      expect(xml, contains('Cola'));
      expect(xml, contains('10,000'));
      expect(xml, contains('Jami:'));
      expect(xml, contains('Ombordan:'));
      expect(xml, contains('ss:StyleID="TableHead"'));
      expect(xml, contains('<?mso-application progid="Excel.Sheet"?>'));
    });

    test('normalizeSavePath appends .xls when missing', () {
      expect(
        HoldOrderPrecheckExcelExport.normalizeSavePathForTest(r'C:\Users\me\chek_POS10169'),
        r'C:\Users\me\chek_POS10169.xls',
      );
      expect(
        HoldOrderPrecheckExcelExport.normalizeSavePathForTest('/Users/me/chek_POS10169'),
        '/Users/me/chek_POS10169.xls',
      );
      expect(
        HoldOrderPrecheckExcelExport.normalizeSavePathForTest('/Users/me/chek_POS10169.xls'),
        '/Users/me/chek_POS10169.xls',
      );
    });

    test('saveBytesToPath writes non-empty file', () async {
      final dir = await Directory.systemTemp.createTemp('alfapos_excel_test');
      final path = '${dir.path}${Platform.pathSeparator}chek_test.xls';
      final bytes = [0xEF, 0xBB, 0xBF, ...'test'.codeUnits];

      await HoldOrderPrecheckExcelExport.saveBytesToPath(
        bytes: bytes,
        selectedPath: path,
      );

      final file = File(path);
      expect(await file.exists(), isTrue);
      expect(await file.length(), greaterThan(0));

      await dir.delete(recursive: true);
    });
  });
}
