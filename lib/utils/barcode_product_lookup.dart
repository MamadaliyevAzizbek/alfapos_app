import '../core/api_client.dart';
import '../models/product.dart';
import '../providers/products_provider.dart';
import '../services/api_service.dart';
import '../utils/product_search.dart';
import '../utils/sales_products.dart';
import '../utils/scale_barcode.dart';

/// Shtrix kod bo‘yicha mahsulot — Katalog va Sotuv bir xil zanjir.
/// Taroz etiketkasi: avval [SalesApi.scaleBarcode] (DESKTOP_SCALE_BARCODE_API.md).
class BarcodeProductLookup {
  BarcodeProductLookup._();

  /// Faqat mahsulot (miqdor 1). Taroz uchun [resolveDetailed] ishlating.
  static Future<Product?> resolve({
    required String query,
    List<Product> salesScreenProducts = const [],
    int branchId = 1,
  }) async {
    final r = await resolveDetailed(
      query: query,
      salesScreenProducts: salesScreenProducts,
      branchId: branchId,
    );
    return r.product;
  }

  /// 1) Taroz scale-barcode  2) mahalliy katalog  3) sotuv ro‘yxati
  /// 4) barcode-search  5) sales/products.
  static Future<BarcodeLookupResult> resolveDetailed({
    required String query,
    List<Product> salesScreenProducts = const [],
    int branchId = 1,
  }) async {
    final q = query.trim();
    if (q.isEmpty) return const BarcodeLookupResult();

    // Taroz: oddiy bar_code match ishlamaydi — avval server parse.
    if (looksLikePossibleScaleBarcode(q)) {
      final scale = await _tryScaleBarcode(q, branchId: branchId);
      if (scale != null) return scale;
    }

    final catalog = ProductsProvider.instance;
    if (!catalog.isLoaded || catalog.items.isEmpty) {
      try {
        await catalog.loadFromStorage();
      } catch (_) {}
    }

    final localScale = _localScaleHit(catalog.items, q) ??
        (salesScreenProducts.isNotEmpty ? _localScaleHit(salesScreenProducts, q) : null);
    if (localScale != null) return localScale;

    final fromCatalog = filterProductsByBarcodeQuery(catalog.items, q);
    if (fromCatalog.length == 1) {
      return BarcodeLookupResult(product: fromCatalog.single);
    }

    if (salesScreenProducts.isNotEmpty) {
      final fromSalesList = filterProductsByBarcodeQuery(salesScreenProducts, q);
      if (fromSalesList.length == 1) {
        return BarcodeLookupResult(product: fromSalesList.single);
      }
    }

    try {
      final res = await SalesApi.barcodeSearch(
        searchValue: q,
        branchId: branchId,
      );

      // barcode-search ham tarozni boyitishi mumkin.
      final scaleHit = ScaleBarcode.parseSuccess(res);
      if (scaleHit != null &&
          (scaleHit.isScaleItem || ScaleBarcode.isScaleBarcodeResponse(res))) {
        return BarcodeLookupResult(
          product: scaleHit.product,
          quantity: scaleHit.quantity,
          isScaleItem: true,
        );
      }

      final direct = SalesProducts.fromBarcodeResult(res);
      if (direct != null &&
          (direct.matchesBarcode(q) ||
              looksLikePossibleScaleBarcode(q) ||
              looksLikePluCode(q))) {
        final qty = looksLikePossibleScaleBarcode(q)
            ? (extractScaleWeightKg(q) ?? 1)
            : 1;
        return BarcodeLookupResult(
          product: direct,
          quantity: qty,
          isScaleItem: qty != 1,
        );
      }
      final picked = SalesProducts.pickAutoAddBarcode(res, allowSingleResult: true);
      if (picked != null &&
          (picked.matchesBarcode(q) ||
              looksLikePossibleScaleBarcode(q) ||
              looksLikePluCode(q))) {
        final qty = looksLikePossibleScaleBarcode(q)
            ? (extractScaleWeightKg(q) ?? 1)
            : 1;
        return BarcodeLookupResult(
          product: picked,
          quantity: qty,
          isScaleItem: qty != 1,
        );
      }

      if (ScaleBarcode.isScaleBarcodeResponse(res) && scaleHit == null) {
        return BarcodeLookupResult(
          scalePluNotFound: true,
          isScaleItem: true,
          message: ScaleBarcode.errorMessage(res) ??
              'PLU kodli mahsulot topilmadi',
        );
      }
    } on ApiException catch (e) {
      if (_looksLikeScalePluError(e.message) && looksLikePossibleScaleBarcode(q)) {
        return BarcodeLookupResult(
          scalePluNotFound: true,
          isScaleItem: true,
          message: e.message,
        );
      }
    } catch (_) {}

    try {
      final fromProductsApi = await catalog.findProductByBarcode(q);
      if (fromProductsApi != null) {
        final qty = looksLikePossibleScaleBarcode(q)
            ? (extractScaleWeightKg(q) ?? 1)
            : 1;
        return BarcodeLookupResult(
          product: fromProductsApi,
          quantity: qty,
          isScaleItem: qty != 1,
        );
      }
    } catch (_) {}

    return const BarcodeLookupResult();
  }

  /// Server ishlamasa: mahalliy PLU + etiketkadagi vazn.
  static BarcodeLookupResult? _localScaleHit(List<Product> products, String q) {
    if (!looksLikePossibleScaleBarcode(q)) return null;
    final weight = extractScaleWeightKg(q);
    if (weight == null) return null;
    final hits = filterProductsByBarcodeQuery(products, q);
    if (hits.length != 1) return null;
    return BarcodeLookupResult(
      product: hits.single,
      quantity: weight,
      isScaleItem: true,
    );
  }

  static Future<BarcodeLookupResult?> _tryScaleBarcode(
    String q, {
    required int branchId,
  }) async {
    try {
      final res = await SalesApi.scaleBarcode(barcode: q, branchId: branchId);
      final hit = ScaleBarcode.parseSuccess(res);
      if (hit != null) {
        return BarcodeLookupResult(
          product: hit.product,
          quantity: hit.quantity,
          isScaleItem: hit.isScaleItem,
          message: ScaleBarcode.errorMessage(res),
        );
      }
      if (ScaleBarcode.isScaleBarcodeResponse(res)) {
        return BarcodeLookupResult(
          scalePluNotFound: true,
          isScaleItem: true,
          message: ScaleBarcode.errorMessage(res) ??
              'PLU kodli mahsulot topilmadi',
        );
      }
      // is_scale_barcode=false → oddiy barcode zanjiriga o‘tish.
      return null;
    } on ApiException catch (e) {
      // success:false yoki 404 — message odatda "PLU kodli mahsulot topilmadi…"
      if (_looksLikeScalePluError(e.message) ||
          (e.statusCode == 404 && looksLikePossibleScaleBarcode(q))) {
        return BarcodeLookupResult(
          scalePluNotFound: true,
          isScaleItem: true,
          message: e.message.trim().isEmpty
              ? 'PLU kodli mahsulot topilmadi'
              : e.message,
        );
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static bool _looksLikeScalePluError(String message) {
    final m = message.toLowerCase();
    return m.contains('plu') ||
        m.contains('taroz') ||
        m.contains('scale') ||
        m.contains('vazn');
  }
}
