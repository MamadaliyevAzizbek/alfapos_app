/// POST /contacts/customers/store — web bilan mos body.
class CustomerStoreBody {
  CustomerStoreBody._();

  static const defaultPriceTypeOptions = <({String value, String label})>[
    (value: 'selling', label: 'Sotish narxi'),
    (value: 'purchase', label: 'Kelish narxi'),
    (value: 'wholesale', label: 'Ulgurji narx'),
  ];

  static List<({String value, String label})> parsePriceTypeOptions(Map<String, dynamic>? res) {
    if (res == null) return defaultPriceTypeOptions;
    final raw = res['group_markup_price_base_options'] ??
        res['discount_price_types'] ??
        res['group_discount_price_types'] ??
        res['customer_group_discount_price_types'] ??
        res['price_types'];
    if (raw is! List) return defaultPriceTypeOptions;
    final out = <({String value, String label})>[];
    for (final item in raw) {
      if (item is Map) {
        final v = (item['value'] ?? item['id'] ?? item['key'] ?? '').toString();
        final l = (item['label'] ?? item['title'] ?? item['name'] ?? v).toString();
        if (v.isNotEmpty) out.add((value: v, label: l));
      } else if (item is String && item.isNotEmpty) {
        final match = defaultPriceTypeOptions.where((o) => o.value == item);
        out.add(match.isNotEmpty ? match.first : (value: item, label: item));
      }
    }
    return out.isEmpty ? defaultPriceTypeOptions : out;
  }

  static String? priceTypeFromGroup(Map<String, dynamic> group) {
    for (final key in [
      'group_markup_price_base',
      'customer_group_discount_price_type',
      'discount_price_type',
      'group_discount_price_type',
      'price_type',
      'discount_on',
    ]) {
      final v = group[key];
      if (v != null && v.toString().trim().isNotEmpty) return v.toString();
    }
    return null;
  }

  static Map<String, dynamic> build({
    required String firstName,
    String lastName = '',
    String? phone,
    String? address,
    required int customerGroupId,
    String? groupDiscountPriceType,
    String email = '',
    String company = '',
    String tinNumber = '',
  }) {
    final body = <String, dynamic>{
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'company': company,
      'tin_number': tinNumber,
      'phone_number': phone ?? '',
      'address': address ?? '',
      'customer_group': customerGroupId,
    };
    final priceBase = groupDiscountPriceType?.trim();
    if (priceBase != null && priceBase.isNotEmpty) {
      body['group_markup_price_base'] = priceBase;
    }
    return body;
  }
}
