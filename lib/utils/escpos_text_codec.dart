import 'dart:convert';
import 'dart:typed_data';

import 'package:charset_converter/charset_converter.dart';

/// ESC/POS matn kodi — ko‘p termal printerlar uchun CP866 (rus/kirill).
class EscPosTextCodec {
  EscPosTextCodec._();

  static Future<Uint8List> encode(String text, {String codePage = 'CP866'}) async {
    final normalized = _normalize(text);
    final encodings = switch (codePage.toUpperCase()) {
      'CP1251' || 'WINDOWS-1251' => ['windows-1251', 'IBM866'],
      _ => ['IBM866', 'windows-1251'],
    };
    for (final enc in encodings) {
      try {
        final bytes = await CharsetConverter.encode(enc, normalized);
        if (bytes.isNotEmpty) {
          return Uint8List.fromList(bytes);
        }
      } catch (_) {}
    }
    return Uint8List.fromList(latin1.encode(_transliterateCyrillic(normalized)));
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
    var r = s;
    for (final e in map.entries) {
      r = r.replaceAll(e.key, e.value);
    }
    return r;
  }
}
