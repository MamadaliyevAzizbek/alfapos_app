import 'dart:convert';

import '../lib/models/product.dart';

void main() {
  // API /products/list dagi bitta datarow namunasi (user yuborganiga o'xshash)
  const rawJson = r'''
{
  "id": 16555,
  "company_id": 1,
  "title": "test 6",
  "unit_id": 2,
  "product_quantity": 474.4,
  "purchase_price": 6000,
  "selling_price": 70000,
  "variants": [
    {
      "id": 16554,
      "product_id": 16555,
      "variant_title": "default_variant",
      "bar_code": "076950450479",
      "purchase_price": 6000,
      "selling_price": 70000,
      "units_per_package": 20,
      "package_purchase_price": "500.00",
      "package_selling_price": "8000.00",
      "availableQuantity": 500,
      "additionalBarcodes": ["998833333"]
    }
  ]
}
''';

  final map = jsonDecode(rawJson) as Map<String, dynamic>;
  final p = Product.fromApiJson(map);

  print('Parsed product: id=${p.id} name=${p.name}');
  print('barcode=${p.barcode}');
  print('additionalBarcodes=${p.additionalBarcodes}');
  print('quantityInPack=${p.quantityInPack} quantityPerPack=${p.quantityPerPack}');
  print('sellPricePerPack=${p.sellPricePerPack} costPricePerPack=${p.costPricePerPack}');

  final byMain = p.matchesBarcode('076950450479');
  final byMainNoZero = p.matchesBarcode('76950450479');
  final byAdd = p.matchesBarcode('998833333');

  print('Match main (same): $byMain');
  print('Match main (no leading zeros): $byMainNoZero');
  print('Match additional: $byAdd');

  if (!byMain || !byMainNoZero || !byAdd) {
    throw StateError('Barcode matching failed');
  }
}

