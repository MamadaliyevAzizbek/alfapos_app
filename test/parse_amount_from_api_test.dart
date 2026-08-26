import 'package:alfapos_app/core/input_formatters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseAmountFromApi', () {
    test('keeps plain integers and decimals', () {
      expect(parseAmountFromApi(10000), 10000);
      expect(parseAmountFromApi(10000.0), 10000);
      expect(parseAmountFromApi('10000'), 10000);
      expect(parseAmountFromApi('10000.00'), 10000);
      expect(parseAmountFromApi('10.5'), 11); // round
    });

    test('parses space and comma thousands without becoming 10', () {
      expect(parseAmountFromApi('10 000'), 10000);
      expect(parseAmountFromApi('10,000'), 10000);
      expect(parseAmountFromApi('21,000'), 21000);
    });

    test('parses European dot thousands (10.000 → 10000, not 10)', () {
      expect(parseAmountFromApi('10.000'), 10000);
      expect(parseAmountFromApi('1.000.000'), 1000000);
    });

    test('parseAmountFromApiDouble handles US and EU mixed', () {
      expect(parseAmountFromApiDouble('1,234.56'), 1234.56);
      expect(parseAmountFromApiDouble('1.234,56'), 1234.56);
      expect(parseAmountFromApiDouble('10,5'), 10.5);
    });
  });
}
