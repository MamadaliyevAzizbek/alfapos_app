import 'package:flutter/services.dart';

/// Summani "1 111 111" ko'rinishida kiritish uchun.
class ThousandsInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) {
      return TextEditingValue(
        text: '',
        selection: const TextSelection.collapsed(offset: 0),
      );
    }
    final formatted = _formatThousands(digits);
    final cursor = formatted.length.clamp(0, newValue.selection.end);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: cursor),
    );
  }

  static String _formatThousands(String digits) {
    if (digits.length <= 3) return digits;
    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buf.write(' ');
      buf.write(digits[i]);
    }
    return buf.toString();
  }
}

/// "1 111 111" matnidan son olish.
int? parseFormattedSum(String? s) {
  if (s == null || s.isEmpty) return null;
  final t = s.replaceAll(' ', '').replaceAll('\u00A0', '').trim();
  if (t.isEmpty) return null;
  return int.tryParse(t);
}

/// API dan kelgan total (int, num yoki "20000.00" string) ni butun songa aylantiradi.
int parseAmountFromApi(dynamic v) {
  if (v == null) return 0;
  if (v is int) return v;
  if (v is num) return v.toInt();
  final s = v.toString().trim();
  if (s.isEmpty) return 0;
  final d = double.tryParse(s);
  return d != null ? d.round() : 0;
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
  final s = n.toString();
  if (s.length <= 3) return s;
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
    buf.write(s[i]);
  }
  return buf.toString();
}
