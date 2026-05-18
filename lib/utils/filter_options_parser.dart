/// Kategoriya / brend filtrlari uchun API javobini id + name ro'yxatiga.
class FilterOptionsParser {
  FilterOptionsParser._();

  static List<Map<String, dynamic>> parseIdNameList(dynamic source) {
    final rows = _collectMaps(source);
    final seen = <String>{};
    final out = <Map<String, dynamic>>[];

    for (final m in rows) {
      final id = (m['id'] ?? m['value'] ?? m['category_id'] ?? m['brand_id'] ?? m['key'] ?? '')
          .toString()
          .trim();
      if (id.isEmpty) continue;
      final name = (m['name'] ??
              m['title'] ??
              m['text'] ??
              m['label'] ??
              m['category_name'] ??
              m['brand_name'] ??
              m['group_name'] ??
              id)
          .toString()
          .trim();
      if (name.isEmpty) continue;
      if (seen.contains(id)) continue;
      seen.add(id);
      out.add({'id': id, 'name': name});
    }
    out.sort((a, b) => (a['name'] as String).toLowerCase().compareTo((b['name'] as String).toLowerCase()));
    return out;
  }

  static List<Map<String, dynamic>> _collectMaps(dynamic source) {
    if (source == null) return [];
    if (source is List) {
      return source
          .map((e) {
            if (e is Map) return Map<String, dynamic>.from(e);
            if (e is String && e.trim().isNotEmpty) {
              return {'id': e.trim(), 'name': e.trim()};
            }
            return null;
          })
          .whereType<Map<String, dynamic>>()
          .toList();
    }
    if (source is Map) {
      final m = Map<String, dynamic>.from(source);
      final out = <Map<String, dynamic>>[];
      for (final key in [
        'datarows',
        'data',
        'categories',
        'brands',
        'items',
        'rows',
        'list',
        'results',
        'category_list',
        'brand_list',
      ]) {
        if (!m.containsKey(key)) continue;
        out.addAll(_collectMaps(m[key]));
      }
      if (out.isEmpty) {
        final id = (m['id'] ?? m['value'] ?? '').toString().trim();
        final name = (m['name'] ?? m['title'] ?? '').toString().trim();
        if (id.isNotEmpty && name.isNotEmpty) out.add(m);
      }
      return out;
    }
    return [];
  }
}
