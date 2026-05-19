import 'package:flutter/scheduler.dart';

import '../models/product.dart';

/// Qidiruv matnini normallashtirish (bo'shliq, katta-kichik harf).
String normalizeProductSearchQuery(String query) =>
    query.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

/// Bo'shliq/tire siz: «kley8» ↔ «kley 8».
String compactProductSearchText(String text) =>
    normalizeProductSearchQuery(text).replaceAll(RegExp(r'[\s\-_]+'), '');

/// Nom ichidagi so'z yoki raqam (masalan «kley 8» dagi 8) — shtrix emas.
bool nameContainsSearchToken(String name, String token) {
  if (token.isEmpty) return false;
  if (RegExp(r'^\d+$').hasMatch(token)) {
    return RegExp(r'(?:^|[^0-9])' + RegExp.escape(token) + r'(?:[^0-9]|$)').hasMatch(name);
  }
  return name.contains(token);
}

/// Nom / SKU / shtrix bo'yicha mos keladimi (nomdagi raqamlar ham qidiruvda qatnashadi).
bool productMatchesSearchQuery(Product product, String query) {
  return productSearchRelevanceScore(product, query) > 0;
}

/// Qidiruv mosligi: katta qiymat = nomga yaqinroq. 0 = mos emas.
int productSearchRelevanceScore(Product product, String query) {
  final raw = query.trim();
  if (raw.isEmpty) return 1;

  final q = normalizeProductSearchQuery(raw);
  final name = normalizeProductSearchQuery(product.name);
  if (name.isEmpty) return 0;

  final qCompact = compactProductSearchText(raw);
  final nameCompact = compactProductSearchText(product.name);

  var best = 0;

  if (name == q) {
    best = 100000;
  } else if (name.startsWith(q)) {
    best = 95000 - (name.length - q.length);
  } else if (name.contains(q)) {
    best = 90000 - name.indexOf(q);
  } else if (qCompact.length >= 2 && nameCompact.contains(qCompact)) {
    final compactScore = 88000 - nameCompact.indexOf(qCompact);
    if (compactScore > best) best = compactScore;
  }

  final words = q.split(' ').where((w) => w.isNotEmpty).toList();
  if (words.isNotEmpty && words.every((w) => nameContainsSearchToken(name, w))) {
    var wordScore = 80000 - name.length;
    var pos = 0;
    var inOrder = true;
    for (final w in words) {
      final i = name.indexOf(w, pos);
      if (i < 0) {
        inOrder = false;
        break;
      }
      if (i < pos) inOrder = false;
      wordScore += 2000 - i;
      pos = i + w.length;
    }
    if (inOrder) wordScore += 1500;
    if (wordScore > best) best = wordScore;
  }

  final sku = product.sku?.trim();
  if (sku != null && sku.isNotEmpty) {
    final skuNorm = normalizeProductSearchQuery(sku);
    if (skuNorm == q) {
      best = best > 85000 ? best : 85000;
    } else if (skuNorm.contains(q)) {
      final skuScore = 82000 - skuNorm.indexOf(q);
      if (skuScore > best) best = skuScore;
    }
  }

  // To'liq shtrix (8+ raqam) yoki skaner.
  if (looksLikeBarcodeInput(raw) && product.matchesBarcode(raw)) {
    const barcodeScore = 88000;
    if (barcodeScore > best) best = barcodeScore;
  }

  // Faqat raqam: oxirgi 4–7 ta shtrix raqami (masalan …8479).
  if (looksLikeBarcodeSuffixInput(raw) && product.matchesBarcodeSuffix(raw)) {
    final suffixScore = 86000 + raw.replaceAll(RegExp(r'\D'), '').length;
    if (suffixScore > best) best = suffixScore;
  }

  return best;
}

/// Eng yaqin nom mosligi birinchi.
List<Product> sortProductsBySearchRelevance(List<Product> products, String query) {
  final raw = query.trim();
  if (raw.isEmpty) return products;
  final ranked = <({Product product, int score})>[];
  for (final p in products) {
    final score = productSearchRelevanceScore(p, raw);
    if (score > 0) ranked.add((product: p, score: score));
  }
  ranked.sort((a, b) {
    if (a.score != b.score) return b.score.compareTo(a.score);
    return a.product.name.toLowerCase().compareTo(b.product.name.toLowerCase());
  });
  return ranked.map((e) => e.product).toList();
}

/// Mahsulotlarni nom / SKU / shtrix-kod (asosiy + qo'shimcha) bo'yicha qidirish.
///
/// Eslatma: qidiruv logikasi bitta joyda bo'lishi uchun Katalog va Savatcha shu funksiyani ishlatadi.
List<Product> filterProductsByQuery(List<Product> products, String query) {
  final raw = query.trim();
  if (raw.isEmpty) return products;
  return sortProductsBySearchRelevance(products, raw);
}

/// Katalog (Mahsulotlar) bilan bir xil mahalliy filtr.
List<Product> filterCatalogProducts(List<Product> products, String query) =>
    filterProductsByQuery(products, query);

/// Katalogdagi kabi: bitta shtrix mos kelganda callback (sotuvda savatga qo'shish uchun).
void scheduleBarcodeAutoAction({
  required String query,
  required List<Product> filteredProducts,
  required void Function(Product product) onSingleBarcodeMatch,
  Duration delay = const Duration(milliseconds: 600),
}) {
  final raw = query.trim();
  if (raw.isEmpty) return;
  SchedulerBinding.instance.scheduleFrameCallback((_) {
    Future.delayed(delay, () {
      if (query.trim() != raw) return;
      if (filteredProducts.length != 1) return;
      final p = filteredProducts.single;
      if (p.matchesBarcode(raw)) onSingleBarcodeMatch(p);
    });
  });
}

/// Skaner / to'liq raqamli shtrix (faqat raqamlar, kamida 8 ta) — avtomatik qo'shish uchun.
bool looksLikeBarcodeInput(String query) {
  final trimmed = query.trim();
  if (trimmed.isEmpty) return false;
  final digitsOnly = trimmed.replaceAll(RegExp(r'\D'), '');
  if (digitsOnly.length < 8) return false;
  final compact = trimmed.replaceAll(RegExp(r'[\s\-]'), '');
  if (compact == digitsOnly) return true;
  if (RegExp(r'^[\d\s\-]+$').hasMatch(trimmed)) return true;
  return false;
}

/// Faqat raqamlar, 4–7 ta — shtrix oxirgi qismi (to'liq shtrix emas).
bool looksLikeBarcodeSuffixInput(String query) {
  final trimmed = query.trim();
  if (trimmed.isEmpty) return false;
  if (!RegExp(r'^\d+$').hasMatch(trimmed)) return false;
  return trimmed.length >= 4 && trimmed.length < 8;
}

/// Faqat shtrix kod / SKU (nom bo'yicha emas) — savatchaga avtomatik qo'shish uchun.
List<Product> filterProductsByBarcodeQuery(List<Product> products, String query) {
  final raw = query.trim();
  if (raw.isEmpty) return [];
  final q = raw.toLowerCase();
  return products.where((p) {
    if (p.matchesBarcode(raw)) return true;
    if (looksLikeBarcodeSuffixInput(raw) && p.matchesBarcodeSuffix(raw)) return true;
    if (p.sku != null && p.sku!.toLowerCase() == q) return true;
    return false;
  }).toList();
}

