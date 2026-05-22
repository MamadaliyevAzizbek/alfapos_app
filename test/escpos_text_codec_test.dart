import 'package:alfapos_app/utils/escpos_text_codec.dart';
import 'package:charset/charset.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('CP866 encodes Russian footer and product name', () async {
    const text = 'Спасибо за покупку! Молоко 1л';
    final bytes = await EscPosTextCodec.encode(text, codePage: 'CP866');
    expect(bytes.isNotEmpty, isTrue);
    expect(bytes.first, 145); // 'С' in CP866
    final decoded = cp866.decode(bytes);
    expect(decoded, contains('Спасибо'));
    expect(decoded, contains('Молоко'));
  });

  test('CP1251 encodes Russian text', () async {
    const text = 'Coca-Cola 0.5 литр';
    final bytes = await EscPosTextCodec.encode(text, codePage: 'CP1251');
    final decoded = windows1251.decode(bytes);
    expect(decoded, contains('литр'));
  });
}
