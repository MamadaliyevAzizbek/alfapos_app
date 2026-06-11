import 'dart:convert';
import 'dart:typed_data';

import 'package:charset/charset.dart';

/// ESC/POS matn kodi — CP866 / CP1251 (rus mahsulot nomlari va footer).
class EscPosTextCodec {
  EscPosTextCodec._();

  /// Tez yo‘l: butun qatorni bir martada (rus chek uchun muhim).
  static Uint8List encodeSync(String text, {String codePage = 'CP866'}) {
    final normalized = _normalize(text);
    final enc = _encodingFor(codePage);
    return Uint8List.fromList(_encodeLossy(enc, normalized));
  }

  /// CP866/CP1251 da bo‘lmagan belgilar chekni buzmasligi uchun almashtiriladi.
  static List<int> _encodeLossy(Encoding enc, String text) {
    try {
      return enc.encode(text);
    } on FormatException {
      final out = <int>[];
      for (final rune in text.runes) {
        final ch = String.fromCharCode(rune);
        try {
          out.addAll(enc.encode(ch));
        } on FormatException {
          out.addAll(enc.encode('?'));
        }
      }
      return out;
    }
  }

  static Future<Uint8List> encode(String text, {String codePage = 'CP866'}) async =>
      encodeSync(text, codePage: codePage);

  static Encoding _encodingFor(String codePage) {
    switch (codePage.toUpperCase()) {
      case 'CP1251':
      case 'WINDOWS-1251':
        return windows1251;
      case 'CP866':
      case 'IBM866':
      default:
        return cp866;
    }
  }

  static String _normalize(String s) {
    return s
        .replaceAll('‘', "'")
        .replaceAll('’', "'")
        .replaceAll('ʻ', "'")
        .replaceAll('ʼ', "'")
        .replaceAll('“', '"')
        .replaceAll('”', '"')
        .replaceAll('—', '-')
        .replaceAll('–', '-')
        .replaceAll('…', '...')
        .replaceAll('₽', 'sum')
        .replaceAll('×', 'x')
        .replaceAll('§', '');
  }
}
