import 'dart:io';

import 'package:alfapos_app/utils/hold_order_precheck_excel_export.dart';
import 'package:alfapos_app/widgets/receipt_widget.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HoldOrderPrecheckExcelExport', () {
    test('buildSpreadsheetXml contains product rows and total', () {
      final xml = HoldOrderPrecheckExcelExport.buildSpreadsheetXmlForTest(
        storeTitle: 'Test do\'kon',
        receiptNumber: 'POS10169',
        productRows: const [
          ReceiptRow(
            productName: 'Cola',
            quantityStr: '2 dona',
            price: 5000,
            sum: 10000,
          ),
        ],
        total: 10000,
      );

      expect(xml, contains('Test do\'kon'));
      expect(xml, contains('POS10169'));
      expect(xml, contains('Cola'));
      expect(xml, contains('10 000'));
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
