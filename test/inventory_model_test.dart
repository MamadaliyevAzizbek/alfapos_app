import 'package:alfapos_app/models/inventory.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses inventory list datarows', () {
    final docs = InventoryDocument.listFromResponse({
      'success': true,
      'count': 1,
      'datarows': [
        {
          'id': 62,
          'document_number': 'INV-000012',
          'status': 'in_progress',
          'category': {'id': 22, 'name': 'ichimliklar'},
          'creator': {'id': 2, 'first_name': 'Ali', 'last_name': 'Valiyev'},
          'checked_count': 3,
          'total_count': 5,
        },
      ],
    });

    expect(docs, hasLength(1));
    expect(docs.single.documentNumber, 'INV-000012');
    expect(docs.single.categoryName, 'ichimliklar');
    expect(docs.single.creatorName, 'Ali Valiyev');
    expect(docs.single.isEditable, isTrue);
    expect(docs.single.statusLabel, 'Jarayonda');
  });

  test('parses search product rows and difference', () {
    final rows = InventoryProductRow.listFromResponse({
      'datarows': [
        {
          'variant_id': 31189,
          'product_id': 31199,
          'product_title': 'coca cola 0.5',
          'variant_title': 'default_variant',
          'system_quantity': 100,
          'counted_quantity': 12,
          'is_checked': true,
        },
      ],
    });

    expect(rows, hasLength(1));
    expect(rows.single.displayName, 'coca cola 0.5');
    expect(rows.single.difference, -88);
    expect(rows.single.isCounted, isTrue);
  });

  test('null counted quantity means pending', () {
    final row = InventoryProductRow.fromJson({
      'variant_id': 1,
      'product_id': 2,
      'product_title': 'Non',
      'system_quantity': 5,
      'counted_quantity': null,
    });
    expect(row.isCounted, isFalse);
    expect(row.difference, 0);
  });

  test('zero counted quantity is still counted', () {
    final row = InventoryProductRow.fromJson({
      'variant_id': 1,
      'product_id': 2,
      'product_title': 'Non',
      'system_quantity': 5,
      'counted_quantity': 0,
    });
    expect(row.isCounted, isTrue);
    expect(row.difference, -5);
  });

  test('parses category filter options', () {
    final cats = InventoryCategoryOption.fromFilterResponse({
      'categoryName': [
        {'text': 'Barchasi', 'value': 'all'},
        {'text': 'ichimliklar', 'value': '22'},
      ],
    });
    expect(cats, hasLength(2));
    expect(cats.first.value, 'all');
  });

  test('stats aliases counted/pending', () {
    final stats = InventoryStats.fromJson({
      'checked': 3,
      'unchecked': 2,
      'total': 5,
    });
    expect(stats.counted, 3);
    expect(stats.pending, 2);
  });
}
