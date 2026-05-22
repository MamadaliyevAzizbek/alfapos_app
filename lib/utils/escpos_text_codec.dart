import 'dart:convert';
import 'dart:typed_data';

import 'package:charset/charset.dart';

/// ESC/POS matn kodi — CP866 / CP1251 (rus mahsulot nomlari va footer).
///
/// macOS da [charset_converter] plugin yo‘q; shuning uchun pure-Dart [charset] ishlatiladi.
class EscPosTextCodec {
  EscPosTextCodec._();

  static Future<Uint8List> encode(String text, {String codePage = 'CP866'}) async {
    final normalized = _normalize(text);
    final enc = _encodingFor(codePage);
    final out = <int>[];
    for (final rune in normalized.runes) {
      final ch = String.fromCharCode(rune);
      try {
        out.addAll(enc.encode(ch));
      } on FormatException {
        final fallback = _fallbackChar(ch);
        if (fallback.isEmpty) {
          out.add(0x3F); // ?
          continue;
        }
        for (final r2 in fallback.runes) {
          final ch2 = String.fromCharCode(r2);
          try {
            out.addAll(enc.encode(ch2));
          } on FormatException {
            out.add(0x3F);
          }
        }
      }
    }
    return Uint8List.fromList(out);
  }

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

  /// CP866/1251 da yo‘q harflar (o‘zbek) — lotin transliteratsiya.
  static String _fallbackChar(String ch) {
    const uz = {
      'ғ': "g'", 'Ғ': "G'", 'қ': 'q', 'Қ': 'Q', 'ў': "o'", 'Ў': "O'",
      'ҳ': 'h', 'Ҳ': 'H',
    };
    if (uz.containsKey(ch)) return uz[ch]!;
    return _transliterateCyrillic(ch);
  }

  static String _normalize(String s) {
    return s
        .replaceAll('‘', "'")
        .replaceAll('’', "'")
        .replaceAll('“', '"')
        .replaceAll('”', '"')
        .replaceAll('—', '-')
        .replaceAll('…', '...')
        .replaceAll('₽', 'sum')
        .replaceAll('×', 'x')
        .replaceAll('’', "'");
  }

  static String _transliterateCyrillic(String s) {
    if (s.length == 1) {
      const map = {
        'А': 'A', 'Б': 'B', 'В': 'V', 'Г': 'G', 'Д': 'D', 'Е': 'E', 'Ж': 'Zh',
        'З': 'Z', 'И': 'I', 'Й': 'Y', 'К': 'K', 'Л': 'L', 'М': 'M', 'Н': 'N',
        'О': 'O', 'П': 'P', 'Р': 'R', 'С': 'S', 'Т': 'T', 'У': 'U', 'Ф': 'F',
        'Х': 'H', 'Ц': 'Ts', 'Ч': 'Ch', 'Ш': 'Sh', 'Щ': 'Sch', 'Ъ': '', 'Ы': 'Y',
        'Ь': '', 'Э': 'E', 'Ю': 'Yu', 'Я': 'Ya',
        'а': 'a', 'б': 'b', 'в': 'v', 'г': 'g', 'д': 'd', 'е': 'e', 'ж': 'zh',
        'з': 'z', 'и': 'i', 'й': 'y', 'к': 'k', 'л': 'l', 'м': 'm', 'н': 'n',
        'о': 'o', 'п': 'p', 'р': 'r', 'с': 's', 'т': 't', 'у': 'u', 'ф': 'f',
        'х': 'h', 'ц': 'ts', 'ч': 'ch', 'ш': 'sh', 'щ': 'sch', 'ъ': '', 'ы': 'y',
        'ь': '', 'э': 'e', 'ю': 'yu', 'я': 'ya',
        'ё': 'yo', 'Ё': 'Yo',
      };
      return map[s] ?? '';
    }
    var r = s;
    const map = {
      'А': 'A', 'Б': 'B', 'В': 'V', 'Г': 'G', 'Д': 'D', 'Е': 'E', 'Ж': 'Zh',
      'З': 'Z', 'И': 'I', 'Й': 'Y', 'К': 'K', 'Л': 'L', 'М': 'M', 'Н': 'N',
      'О': 'O', 'П': 'P', 'Р': 'R', 'С': 'S', 'Т': 'T', 'У': 'U', 'Ф': 'F',
      'Х': 'H', 'Ц': 'Ts', 'Ч': 'Ch', 'Ш': 'Sh', 'Щ': 'Sch', 'Ъ': '', 'Ы': 'Y',
      'Ь': '', 'Э': 'E', 'Ю': 'Yu', 'Я': 'Ya',
      'а': 'a', 'б': 'b', 'в': 'v', 'г': 'g', 'д': 'd', 'е': 'e', 'ж': 'zh',
      'з': 'z', 'и': 'i', 'й': 'y', 'к': 'k', 'л': 'l', 'м': 'm', 'н': 'n',
      'о': 'o', 'п': 'p', 'р': 'r', 'с': 's', 'т': 't', 'у': 'u', 'ф': 'f',
      'х': 'h', 'ц': 'ts', 'ч': 'ch', 'ш': 'sh', 'щ': 'sch', 'ъ': '', 'ы': 'y',
      'ь': '', 'э': 'e', 'ю': 'yu', 'я': 'ya',
      'ғ': "g'", 'Ғ': "G'", 'қ': 'q', 'Қ': 'Q', 'ў': "o'", 'Ў': "O'",
      'ҳ': 'h', 'Ҳ': 'H', 'ё': 'yo', 'Ё': 'Yo',
    };
    for (final e in map.entries) {
      r = r.replaceAll(e.key, e.value);
    }
    return r;
  }
}
