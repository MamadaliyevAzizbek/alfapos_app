import '../models/product.dart';
import 'receive_products.dart';

/// Taroz barcode natijasi — [DESKTOP_SCALE_BARCODE_API.md].
class ScaleBarcodeHit {
  final Product product;
  final num quantity;
  final String? pluCode;
  final String? normalizedBarcode;
  final bool isScaleItem;

  const ScaleBarcodeHit({
    required this.product,
    required this.quantity,
    this.pluCode,
    this.normalizedBarcode,
    this.isScaleItem = true,
  });
}

/// Shtrix kod qidiruv natijasi (oddiy yoki taroz).
class BarcodeLookupResult {
  final Product? product;
  final num quantity;
  final bool isScaleItem;

  /// Taroz formati, lekin PLU topilmadi — oddiy qidiruvga o‘tmaslik kerak.
  final bool scalePluNotFound;
  final String? message;

  const BarcodeLookupResult({
    this.product,
    this.quantity = 1,
    this.isScaleItem = false,
    this.scalePluNotFound = false,
    this.message,
  });

  bool get found => product != null;
}

/// Taroz etiketkasi bo‘lishi mumkinmi (server formatni o‘zi parse qiladi).
/// Masalan: `0100087004509` (PLU 00087, vazn 0.450 kg).
bool looksLikePossibleScaleBarcode(String raw) {
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  // Skanner leading 0 ni yutishi mumkin → 12 yoki 13 raqam.
  return digits.length >= 11 && digits.length <= 14;
}

/// Qisqa PLU (API: max 10).
bool looksLikePluCode(String query) {
  final t = query.trim();
  if (t.isEmpty) return false;
  if (!RegExp(r'^\d{3,10}$').hasMatch(t)) return false;
  if (looksLikePossibleScaleBarcode(t)) return false;
  return true;
}

/// Etiketkadagi raqamlardan PLU nomzodlari (masalan 00087 / 87).
List<String> extractScalePluCandidates(String query) {
  final d = query.replaceAll(RegExp(r'\D'), '');
  if (d.length < 12 || d.length > 13) return const [];
  final out = <String>[];
  void add(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return;
    if (!out.contains(t)) out.add(t);
    final stripped = t.replaceFirst(RegExp(r'^0+'), '');
    if (stripped.isNotEmpty && stripped != t && !out.contains(stripped)) {
      out.add(stripped);
    }
  }
  if (d.length >= 7) add(d.substring(2, 7));
  if (d.length >= 6) add(d.substring(2, 6));
  return out;
}

/// Etiketkadagi vazn (kg). `0100087004509` → 0.450.
num? extractScaleWeightKg(String query) {
  final d = query.replaceAll(RegExp(r'\D'), '');
  if (d.length < 12 || d.length > 13) return null;
  final grams = int.tryParse(d.substring(7, 12));
  if (grams == null || grams <= 0 || grams >= 100000) return null;
  return grams / 1000.0;
}

/// POST /sales/scale-barcode (yoki barcode-search) javobini parse.
class ScaleBarcode {
  ScaleBarcode._();

  static ScaleBarcodeHit? parseSuccess(Map<String, dynamic> res) {
    if (res['success'] != true && res['success'] != 1 && res['success'] != 'true') {
      // Ba'zi endpointlar success bermaydi — product / barcodeResultValue bo'lsa ham OK.
      final hasProduct = res['product'] is Map || res['barcodeResultValue'] is Map;
      if (!hasProduct) return null;
    }

    final productRaw = res['product'] is Map
        ? Map<String, dynamic>.from(res['product'] as Map)
        : (res['barcodeResultValue'] is Map
            ? Map<String, dynamic>.from(res['barcodeResultValue'] as Map)
            : null);
    if (productRaw == null) return null;

    final product = ReceiveProducts.productFromBarcodeResult(productRaw);
    if (product == null || product.id.isEmpty) return null;

    final isScale = isScaleBarcodeResponse(res) ||
        _truthy(productRaw['isScaleItem']) ||
        productRaw['scaleWeight'] != null ||
        productRaw['scale_weight'] != null;

    // Oddiy barcode scale-barcode ichida topsa — miqdor 1 (ombor quantity emas!).
    final qty = isScale ? (_scaleQuantity(res, productRaw) ?? 1) : 1;
    if (qty <= 0) return null;

    return ScaleBarcodeHit(
      product: product,
      quantity: qty,
      pluCode: (res['plu_code'] ?? productRaw['pluCode'] ?? productRaw['plu_code'])
          ?.toString(),
      normalizedBarcode: (res['normalized_barcode'] ?? res['normalizedBarcode'])
          ?.toString(),
      isScaleItem: isScale,
    );
  }

  /// Taroz formati ekanligi (mahsulot topilmasa ham).
  static bool isScaleBarcodeResponse(Map<String, dynamic> res) =>
      _truthy(res['is_scale_barcode']);

  static String? errorMessage(Map<String, dynamic> res) {
    final m = res['message']?.toString().trim();
    if (m != null && m.isNotEmpty) return m;
    return null;
  }

  static num? _scaleQuantity(Map<String, dynamic> res, Map<String, dynamic> product) {
    for (final key in [
      'weight',
      'scale_weight',
      'scaleWeight',
      'quantity',
    ]) {
      final fromRes = _positiveNum(res[key]);
      if (fromRes != null) return fromRes;
    }
    for (final key in ['scaleWeight', 'scale_weight', 'weight', 'quantity']) {
      final fromProduct = _positiveNum(product[key]);
      if (fromProduct != null) return fromProduct;
    }
    return null;
  }

  static num? _positiveNum(dynamic v) {
    if (v == null) return null;
    if (v is num) return v > 0 ? v : null;
    final n = num.tryParse(v.toString().trim().replaceAll(',', '.'));
    if (n == null || n <= 0) return null;
    return n;
  }

  static bool _truthy(dynamic v) {
    if (v == true || v == 1) return true;
    final s = v?.toString().trim().toLowerCase();
    return s == '1' || s == 'true' || s == 'yes';
  }
}
