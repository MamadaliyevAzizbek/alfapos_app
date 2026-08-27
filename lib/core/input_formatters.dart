import 'package:flutter/services.dart';

/// Summani "1 111 111" (ixtiyoriy kasr: "0.687", "21 997.5") ko'rinishida kiritish.
class ThousandsInputFormatter extends TextInputFormatter {
  ThousandsInputFormatter({
    this.allowDecimal = false,
    this.maxDecimalPlaces = 3,
  });

  final bool allowDecimal;
  final int maxDecimalPlaces;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (!allowDecimal) {
      return _formatIntegerOnly(newValue);
    }
    return _formatWithDecimal(newValue);
  }

  TextEditingValue _formatIntegerOnly(TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }
    final formatted = _formatThousandsDigits(digits);
    final digitsBeforeCursor = _countDigitsBefore(
      newValue.text,
      newValue.selection.end.clamp(0, newValue.text.length),
    );
    final cursor = _offsetAfterDigitIndex(formatted, digitsBeforeCursor);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: cursor),
    );
  }

  TextEditingValue _formatWithDecimal(TextEditingValue newValue) {
    final raw = newValue.text;
    final sepIndex = _firstDecimalSepIndex(raw);
    String intRaw;
    String fracRaw;
    var hasSep = false;
    String sepChar = '.';
    if (sepIndex < 0) {
      intRaw = raw;
      fracRaw = '';
    } else {
      hasSep = true;
      sepChar = raw[sepIndex];
      if (sepChar != '.' && sepChar != ',') sepChar = '.';
      intRaw = raw.substring(0, sepIndex);
      fracRaw = raw.substring(sepIndex + 1);
    }

    // Faqat bitta ajratuvchi; qolgan ./, raqam emas — olib tashlanadi.
    final intDigits = intRaw.replaceAll(RegExp(r'\D'), '');
    var fracDigits = fracRaw.replaceAll(RegExp(r'\D'), '');
    if (fracDigits.length > maxDecimalPlaces) {
      fracDigits = fracDigits.substring(0, maxDecimalPlaces);
    }

    if (intDigits.isEmpty && !hasSep && fracDigits.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    final intFormatted =
        intDigits.isEmpty ? (hasSep ? '0' : '') : _formatThousandsDigits(intDigits);
    final formatted = hasSep
        ? '$intFormatted$sepChar$fracDigits'
        : intFormatted;

    final cursorDigits = _countDigitsBefore(
      raw,
      newValue.selection.end.clamp(0, raw.length),
    );
    final sepBeforeCursor = hasSep &&
        newValue.selection.end > sepIndex;
    // Kasr tomonda kursor: butun raqamlar + ajratuvchi + kasr raqamlari.
    int cursor;
    if (!hasSep) {
      cursor = _offsetAfterDigitIndex(formatted, cursorDigits);
    } else if (!sepBeforeCursor) {
      cursor = _offsetAfterDigitIndex(intFormatted, cursorDigits);
    } else {
      final digitsInInt = intDigits.isEmpty ? 0 : intDigits.length;
      final fracDigitsBefore = (cursorDigits - digitsInInt).clamp(0, fracDigits.length);
      cursor = intFormatted.length + 1 + fracDigitsBefore;
    }
    cursor = cursor.clamp(0, formatted.length);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: cursor),
    );
  }

  static int _firstDecimalSepIndex(String text) {
    final dot = text.indexOf('.');
    final comma = text.indexOf(',');
    if (dot < 0) return comma;
    if (comma < 0) return dot;
    return dot < comma ? dot : comma;
  }

  /// Kursor oldidagi raqamlar soni (formatdan mustaqil).
  static int _countDigitsBefore(String text, int endOffset) {
    var count = 0;
    final end = endOffset.clamp(0, text.length);
    for (var i = 0; i < end; i++) {
      final c = text[i];
      if (c.codeUnitAt(0) >= 48 && c.codeUnitAt(0) <= 57) count++;
    }
    return count;
  }

  /// Formatlangan qatorda `digitIndex` ta raqamdan keyingi kursor pozitsiyasi.
  static int _offsetAfterDigitIndex(String formatted, int digitIndex) {
    if (digitIndex <= 0) return 0;
    var count = 0;
    for (var i = 0; i < formatted.length; i++) {
      final c = formatted.codeUnitAt(i);
      if (c >= 48 && c <= 57) {
        count++;
        if (count == digitIndex) return i + 1;
      }
    }
    return formatted.length;
  }

  static String _formatThousandsDigits(String digits) {
    if (digits.length <= 3) return digits;
    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buf.write(' ');
      buf.write(digits[i]);
    }
    return buf.toString();
  }
}

/// "1 111 111" matnidan butun son olish.
int? parseFormattedSum(String? s) {
  final d = parseFormattedSumDouble(s);
  if (d == null) return null;
  return d.round();
}

/// Savat narxi kiritish: bo'shliq = minglik, `.` / `,` = kasr ("0.687", "21 997,5").
double? parseFormattedSumDouble(String? s) {
  if (s == null || s.isEmpty) return null;
  var t = s.replaceAll(' ', '').replaceAll('\u00A0', '').trim();
  if (t.isEmpty) return null;
  t = t.replaceAll(',', '.');
  if (t == '.' || t == '-' || t == '-.') return null;
  // Yozish jarayoni: "0." — hali to'liq emas.
  if (t.endsWith('.')) return null;
  return double.tryParse(t);
}

/// API dan kelgan total (int, num, "20000.00", "21 000", "21,000", "10.000") ni butun songa aylantiradi.
int parseAmountFromApi(dynamic v) {
  if (v == null) return 0;
  if (v is int) return v;
  if (v is num) return v.round();
  final d = parseAmountFromApiDouble(v);
  return d != null ? d.round() : 0;
}

/// API summalarini `double` ga — minglik ajratuvchi (`,`, `.`) chalkashmasin.
///
/// - `"10,000"` / `"10.000"` → 10000 (minglik)
/// - `"10.50"` / `"10,5"` → 10.5 (kasr)
/// - `"0.687"` / `"0,687"` → 0.687 (kasr; 0.xxx minglik emas)
/// - `"1.234,56"` → 1234.56 (EU)
/// - `"1,234.56"` → 1234.56 (US)
double? parseAmountFromApiDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  var s = v.toString().trim();
  if (s.isEmpty) return null;
  s = s.replaceAll(RegExp(r'[\s\u00A0]'), '');
  if (s.isEmpty) return null;

  final lastComma = s.lastIndexOf(',');
  final lastDot = s.lastIndexOf('.');

  if (lastComma >= 0 && lastDot >= 0) {
    if (lastDot > lastComma) {
      // 1,234.56
      s = s.replaceAll(',', '');
    } else {
      // 1.234,56
      s = s.replaceAll('.', '').replaceAll(',', '.');
    }
  } else if (lastComma >= 0) {
    final after = s.length - lastComma - 1;
    final intPart = s.substring(0, lastComma).replaceAll(RegExp(r'\D'), '');
    // 0,687 → kasr; 10,5 → kasr; 10,000 → minglik
    if (after <= 2 || intPart.isEmpty || intPart == '0') {
      s = s.replaceAll(',', '.');
    } else {
      s = s.replaceAll(',', '');
    }
  } else if (lastDot >= 0) {
    final after = s.length - lastDot - 1;
    final dotCount = RegExp(r'\.').allMatches(s).length;
    final intPart = s.substring(0, lastDot).replaceAll(RegExp(r'\D'), '');
    // POS: "10.000" = 10000 so'm (3 xona = minglik), "10.50" = kasr, "0.687" = kasr.
    if (dotCount > 1) {
      s = s.replaceAll('.', '');
    } else if (after == 3 && intPart.isNotEmpty && intPart != '0') {
      s = s.replaceAll('.', '');
    }
  }

  return double.tryParse(s);
}

/// invoice_id "POS10076" yoki 10076 dan orderId (int) olish — invoice-details/{id} uchun.
int? parseOrderIdFromInvoiceId(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  final s = v.toString().trim();
  if (s.isEmpty) return null;
  final n = int.tryParse(s);
  if (n != null) return n;
  final match = RegExp(r'\d+').firstMatch(s);
  return match != null ? int.tryParse(match.group(0)!) : null;
}

/// Savdo ro'yxati (reports/sales) qatoridan order_id — MOBILE_INVOICE_AND_RECEIPT_API: id (raqam) ustun.
int? getOrderIdFromSale(Map<String, dynamic> sale) {
  final id = sale['id'];
  if (id != null && id is int) return id;
  if (id != null) {
    final n = int.tryParse(id.toString());
    if (n != null) return n;
  }
  return parseOrderIdFromInvoiceId(sale['order_id'] ?? sale['invoice_id']);
}

/// Songa bo'shliq qo'shish: 1111111 -> "1 111 111"
String formatThousands(int n) {
  final negative = n < 0;
  final s = n.abs().toString();
  if (s.length <= 3) return negative ? '-$s' : s;
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
    buf.write(s[i]);
  }
  final out = buf.toString();
  return negative ? '-$out' : out;
}

/// Kasrli summa: 0.687 → "0.687", 21997.5 → "21 997.5", 50000 → "50 000".
String formatThousandsNum(num n, {int maxDecimals = 3}) {
  if (n.isNaN || n.isInfinite) return '0';
  final negative = n < 0;
  final abs = n.abs();
  if ((abs - abs.roundToDouble()).abs() < 1e-9) {
    final out = formatThousands(abs.round());
    return negative ? '-$out' : out;
  }
  final fixed = abs.toStringAsFixed(maxDecimals);
  final trimmed = fixed.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  final parts = trimmed.split('.');
  final intPart = formatThousands(int.tryParse(parts[0]) ?? 0);
  final out = parts.length == 1 ? intPart : '$intPart.${parts[1]}';
  return negative ? '-$out' : out;
}

/// Chekda: 38000 -> "38,000" (Alfapos.pdf)
String formatThousandsComma(int n) {
  final s = n.abs().toString();
  if (s.length <= 3) return s;
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return n < 0 ? '-${buf.toString()}' : buf.toString();
}

/// Matndan raqamni ajratib chek formatida qaytarish.
String formatAmountForReceipt(String raw) {
  final digits = raw.replaceAll(RegExp(r'[^\d]'), '');
  if (digits.isEmpty) return raw.trim();
  return formatThousandsComma(int.parse(digits));
}
