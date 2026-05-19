import 'dart:convert';
import 'dart:typed_data';

import 'package:charset_converter/charset_converter.dart';

/// ESC/POS uchun matnni CP1251 (kirill + o'zbek lotin) ga kodlash.
class EscPosTextCodec {
  EscPosTextCodec._();

  static Future<Uint8List> encode(String text) async {
    final normalized = _normalize(text);
    try {
      final bytes = await CharsetConverter.encode('windows-1251', normalized);
      return Uint8List.fromList(bytes);
    } catch (_) {
      return Uint8List.fromList(latin1.encode(_asciiFallback(normalized)));
    }
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
        .replaceAll('’', "'");
  }

  /// Printerda bo'lmasa — lotin/alifbo almashtirish.
  static String _asciiFallback(String s) {
    const map = {
      'щ': 'sh', 'Щ': 'Sh', 'ш': 'sh', 'Ш': 'Sh',
      'ч': 'ch', 'Ч': 'Ch', 'ё': 'yo', 'Ё': 'Yo',
      'ю': 'yu', 'Ю': 'Yu', 'я': 'ya', 'Я': 'Ya',
      'ғ': "g'", 'Ғ': "G'", 'қ': 'q', 'Қ': 'Q',
      'ў': "o'", 'Ў': "O'", 'ҳ': 'h', 'Ҳ': 'H',
      'э': 'e', 'Э': 'E',
    };
    var r = s;
    for (final e in map.entries) {
      r = r.replaceAll(e.key, e.value);
    }
    final buf = StringBuffer();
    for (final c in r.runes) {
      if (c <= 0x7E || c == 0xA3 || (c >= 0xA0 && c <= 0xFF)) {
        buf.writeCharCode(c);
      } else if (c >= 0x0410 && c <= 0x044F) {
        // Kirill → taxminiy lotin (qolganlari olib tashlanadi)
        buf.write(_cyrillicToLatin(String.fromCharCode(c)));
      }
    }
    return buf.toString();
  }

  static String _cyrillicToLatin(String ch) {
    const table = {
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
    };
    return table[ch] ?? '?';
  }
}
