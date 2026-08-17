import 'dart:convert';

import 'package:alfapos_app/core/api_http.dart';
import 'package:alfapos_app/core/theme.dart';
import 'package:alfapos_app/models/inventory.dart';
import 'package:alfapos_app/screens/inventarizatsiya_count_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Soxta backend: INVENTORY_API_UZ.md dagi javob shakllarini qaytaradi.
class _FakeInventoryApi {
  final List<Map<String, dynamic>> searchRequests = [];
  final List<Map<String, dynamic>> updateRequests = [];

  /// Hujjatdagi barcha mahsulotlar (server tomonidagi holat).
  final List<Map<String, dynamic>> products = [
    {
      'variant_id': 31189,
      'product_id': 31199,
      'product_title': 'coca cola 0.5',
      'variant_title': 'default_variant',
      'category_name': 'ichimliklar',
      'sku': null,
      'bar_code': '3430111154755',
      'system_quantity': 100,
      'counted_quantity': null,
      'is_checked': false,
      'inventory_item_id': 680,
    },
    {
      'variant_id': 31190,
      'product_id': 31200,
      'product_title': 'fanta 1L',
      'variant_title': 'default_variant',
      'category_name': 'ichimliklar',
      'sku': 'FN-1',
      'bar_code': '3430111100002',
      'system_quantity': 40,
      'counted_quantity': 12,
      'is_checked': true,
      'inventory_item_id': 681,
    },
  ];

  MockClient build() {
    return MockClient((request) async {
      final path = request.url.path;
      final body = request.body.isEmpty
          ? <String, dynamic>{}
          : Map<String, dynamic>.from(jsonDecode(request.body) as Map);

      Map<String, dynamic> ok(Map<String, dynamic> json) => json;

      if (path.endsWith('/inventory/search-products')) {
        searchRequests.add(body);
        final q = (body['searchValue'] ?? '').toString().trim().toLowerCase();
        final filter = (body['count_filter'] ?? 'all').toString();
        var rows = products.where((p) {
          if (q.isEmpty) return true;
          final hay = [
            p['product_title'],
            p['sku'],
            p['bar_code'],
          ].where((e) => e != null).join(' ').toLowerCase();
          return hay.contains(q);
        }).toList();
        if (filter == 'counted') {
          rows = rows.where((p) => p['counted_quantity'] != null).toList();
        } else if (filter == 'pending') {
          rows = rows.where((p) => p['counted_quantity'] == null).toList();
        }
        return _json(ok({
          'success': true,
          'count': rows.length,
          'datarows': rows,
        }));
      }

      if (path.endsWith('/inventory/items')) {
        final counted =
            products.where((p) => p['counted_quantity'] != null).length;
        return _json(ok({
          'success': true,
          'data': [],
          'stats': {
            'checked': counted,
            'unchecked': products.length - counted,
            'total': products.length,
            'counted': counted,
            'pending': products.length - counted,
          },
        }));
      }

      if (path.endsWith('/inventory/update-quantity')) {
        updateRequests.add(body);
        final variantId = body['variant_id'] as int;
        final qty = body['counted_quantity'];
        final product =
            products.firstWhere((p) => p['variant_id'] == variantId);
        product['counted_quantity'] = qty;
        product['is_checked'] = qty != null;
        return _json(ok({
          'success': true,
          'data': {
            'inventory_item': {
              'id': product['inventory_item_id'],
              'variant_id': variantId,
              'counted_quantity': qty?.toString(),
              'system_quantity': product['system_quantity'].toString(),
              'is_checked': qty != null,
            },
            'difference': qty == null
                ? 0
                : (qty as num) - (product['system_quantity'] as num),
          },
        }));
      }

      // GET /inventory/{id}
      return _json(ok({
        'success': true,
        'data': {
          'id': 62,
          'document_number': 'INV-000012',
          'status': 'in_progress',
          'category': {'id': 22, 'name': 'ichimliklar'},
        },
      }));
    });
  }

  static http.Response _json(Map<String, dynamic> body) => http.Response(
        jsonEncode(body),
        200,
        headers: {'content-type': 'application/json'},
      );
}

void main() {
  late _FakeInventoryApi fake;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    fake = _FakeInventoryApi();
    ApiHttp.debugClient = fake.build();
  });

  tearDown(() => ApiHttp.debugClient = null);

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const InventarizatsiyaCountScreen(
          document: InventoryDocument(
            id: 62,
            documentNumber: 'INV-000012',
            status: 'in_progress',
            categoryId: 22,
            categoryName: 'ichimliklar',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Qatorlardagi miqdor maydonlari (0-chi EditableText — qidiruv maydoni).
  List<String> qtyTexts(WidgetTester tester) => tester
      .widgetList<EditableText>(find.byType(EditableText))
      .skip(1)
      .map((e) => e.controller.text)
      .toList();

  testWidgets('ochilganda mahsulotlar va statistika yuklanadi',
      (tester) async {
    await pumpScreen(tester);

    expect(find.text('coca cola 0.5'), findsOneWidget);
    expect(find.text('fanta 1L'), findsOneWidget);
    // Server miqdori maydonga tushgan.
    expect(qtyTexts(tester), ['', '12']);
    // «Jami» badge.
    expect(find.text('2'), findsWidgets);
  });

  testWidgets('qidiruv searchValue ni API ga yuboradi va ro‘yxatni filtrlaydi',
      (tester) async {
    await pumpScreen(tester);
    fake.searchRequests.clear();

    await tester.enterText(find.byType(TextField).first, 'fanta');
    // Debounce 400ms.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(fake.searchRequests, isNotEmpty);
    expect(fake.searchRequests.last['searchValue'], 'fanta');
    expect(fake.searchRequests.last['inventory_id'], 62);
    expect(find.text('fanta 1L'), findsOneWidget);
    expect(find.text('coca cola 0.5'), findsNothing);
  });

  testWidgets('shtrix-kod bo‘yicha qidiruv ishlaydi', (tester) async {
    await pumpScreen(tester);

    await tester.enterText(find.byType(TextField).first, '3430111154755');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.text('coca cola 0.5'), findsOneWidget);
    expect(find.text('fanta 1L'), findsNothing);
  });

  testWidgets('bir xil matn uchun qayta so‘rov yuborilmaydi', (tester) async {
    await pumpScreen(tester);

    await tester.enterText(find.byType(TextField).first, 'fanta');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    final afterFirst = fake.searchRequests.length;

    // Ayni matn qayta kiritildi — yangi so‘rov bo‘lmasligi kerak.
    await tester.enterText(find.byType(TextField).first, 'fanta');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(fake.searchRequests.length, afterFirst);
  });

  testWidgets('magnit tugmasi tizim miqdorini qo‘yadi va saqlaydi',
      (tester) async {
    await pumpScreen(tester);
    expect(qtyTexts(tester).first, '');

    // Birinchi qator (coca cola, tizim: 100).
    await tester.tap(find.byTooltip('Tizim miqdorini qo‘yish (100)'));
    await tester.pumpAndSettle();

    expect(qtyTexts(tester).first, '100');
    expect(fake.updateRequests, hasLength(1));
    expect(fake.updateRequests.single['variant_id'], 31189);
    expect(fake.updateRequests.single['counted_quantity'], 100);
    expect(fake.updateRequests.single['inventory_id'], 62);
  });

  testWidgets('magnitdan keyin farq 0 bo‘ladi va sanalgan deb belgilanadi',
      (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byTooltip('Tizim miqdorini qo‘yish (100)'));
    await tester.pumpAndSettle();

    // Farq ustuni: 100 - 100 = 0.
    expect(find.text('Farq'), findsNWidgets(2));
    expect(find.text('0'), findsWidgets);
    // Statistika yangilandi: ikkalasi ham sanalgan.
    expect(fake.products.every((p) => p['counted_quantity'] != null), isTrue);
  });

  testWidgets('qo‘lda kiritilgan miqdor debounce bilan saqlanadi',
      (tester) async {
    await pumpScreen(tester);

    // Ikkinchi qator maydoni (fanta).
    await tester.enterText(find.byType(TextField).at(2), '37');
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    expect(fake.updateRequests, hasLength(1));
    expect(fake.updateRequests.single['variant_id'], 31190);
    expect(fake.updateRequests.single['counted_quantity'], 37);
  });

  testWidgets('saqlanmagan miqdor qidiruvdan oldin yuboriladi',
      (tester) async {
    await pumpScreen(tester);

    // Debounce tugashidan oldin qidiruvni ishga tushiramiz.
    await tester.enterText(find.byType(TextField).at(1), '55');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(find.byType(TextField).first, 'fanta');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    // Kiritilgan 55 yo‘qolib ketmagan.
    expect(fake.updateRequests, hasLength(1));
    expect(fake.updateRequests.single['variant_id'], 31189);
    expect(fake.updateRequests.single['counted_quantity'], 55);
  });
}
