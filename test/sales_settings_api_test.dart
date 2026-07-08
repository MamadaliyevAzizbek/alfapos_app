import 'package:alfapos_app/utils/sales_settings_api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SalesSettingsApi', () {
    test('parseAllowNegativeStockSales reads camelCase and snake_case', () {
      expect(
        SalesSettingsApi.parseAllowNegativeStockSales({'allowNegativeStockSales': '1'}),
        isTrue,
      );
      expect(
        SalesSettingsApi.parseAllowNegativeStockSales({'allow_negative_stock_sales': '0'}),
        isFalse,
      );
    });

    test('prepareSaveBody updates allowNegativeStockSales', () {
      final body = SalesSettingsApi.prepareSaveBody(
        {
          'offlineMode': '0',
          'outOfStock': '1',
          'allowNegativeStockSales': '0',
        },
        allowNegativeStockSales: true,
      );
      expect(body['allowNegativeStockSales'], '1');
      expect(body['outOfStock'], '1');
    });

    test('unwrapSettings merges nested data', () {
      final merged = SalesSettingsApi.unwrapSettings({
        'offlineMode': '0',
        'data': {'allowNegativeStockSales': '1'},
      });
      expect(SalesSettingsApi.parseAllowNegativeStockSales(merged), isTrue);
    });
  });
}
