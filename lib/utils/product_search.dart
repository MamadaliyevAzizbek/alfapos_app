import 'package:flutter/scheduler.dart';

import '../models/product.dart';

/// Qidiruv matnini normallashtirish (bo'shliq, katta-kichik harf).
String normalizeProductSearchQuery(String query) =>
    query.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

/// Nom / SKU / shtrix bo'yicha mos keladimi (nomdagi raqamlar ham qidiruvda qatnashadi).
bool productMatchesSearchQuery(Product product, String query) {
  final q = normalizeProductSearchQuery(query);
  if (q.isEmpty) return true;

  final name = normalizeProductSearchQuery(product.name);
  if (name.contains(q)) return true;

  final words = q.split(' ').where((w) => w.isNotEmpty);
  if (words.isNotEmpty && words.every((w) => name.contains(w))) return true;

  final sku = product.sku?.trim();
  if (sku != null && sku.isNotEmpty) {
    final skuNorm = normalizeProductSearchQuery(sku);
    if (skuNorm.contains(q)) return true;
  }

  final raw = query.trim();
  if (raw.isNotEmpty && product.matchesBarcode(raw)) return true;

  return false;
}

/// Mahsulotlarni nom / SKU / shtrix-kod (asosiy + qo'shimcha) bo'yicha qidirish.
///
/// Eslatma: qidiruv logikasi bitta joyda bo'lishi uchun Katalog va Savatcha shu funksiyani ishlatadi.
List<Product> filterProductsByQuery(List<Product> products, String query) {
  final raw = query.trim();
  if (raw.isEmpty) return products;
  return products.where((p) => productMatchesSearchQuery(p, raw)).toList();
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

/// Faqat shtrix kod / SKU (nom bo'yicha emas) — savatchaga avtomatik qo'shish uchun.
List<Product> filterProductsByBarcodeQuery(List<Product> products, String query) {
  final raw = query.trim();
  if (raw.isEmpty) return [];
  final q = raw.toLowerCase();
  return products.where((p) {
    if (p.matchesBarcode(raw)) return true;
    if (p.sku != null && p.sku!.toLowerCase() == q) return true;
    return false;
  }).toList();
}

