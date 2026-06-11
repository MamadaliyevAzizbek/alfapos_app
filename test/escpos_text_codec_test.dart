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

  test('strikethrough marker does not break CP866 encoding', () {
    const text = "2 sht x §5,750§ 6,890 so'm";
    expect(() => EscPosTextCodec.encodeSync(text), returnsNormally);
    final bytes = EscPosTextCodec.encodeSync(text);
    final decoded = cp866.decode(bytes);
    expect(decoded, isNot(contains('§')));
    expect(decoded, contains('5,750'));
    expect(decoded, contains('6,890'));
  });

  test('unknown unicode falls back without throwing', () {
    const text = 'Test \u{1F600} price';
    expect(() => EscPosTextCodec.encodeSync(text), returnsNormally);
  });
}
