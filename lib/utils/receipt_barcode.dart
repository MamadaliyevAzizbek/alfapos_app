/// Chek shtrix-kodi — skaner o‘qiydigan Code128 (chek raqami).
class ReceiptBarcode {
  ReceiptBarcode._();

  /// Code128 uchun xavfsiz satr (asosan raqamli chek ID).
  static String encode(String receiptNumber) {
    var s = receiptNumber.trim();
    if (s.isEmpty) return '0';
    s = s.replaceFirst(RegExp(r'^POS', caseSensitive: false), '').trim();
    if (RegExp(r'^\d+$').hasMatch(s)) return s;
    final cleaned = receiptNumber.replaceAll(RegExp(r'[^\w\-\.]'), '');
    return cleaned.isEmpty ? '0' : cleaned;
  }

  static bool get looksValid => true;
}
