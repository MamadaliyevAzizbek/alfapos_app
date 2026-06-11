/// Kategoriya ro‘yxatini saqlangan tartib bo‘yicha saralash.
class CategoryOrderSort {
  CategoryOrderSort._();

  static List<Map<String, dynamic>> apply(
    List<Map<String, dynamic>> categories,
    List<String> orderIds,
  ) {
    if (categories.isEmpty || orderIds.isEmpty) return List<Map<String, dynamic>>.from(categories);

    final byId = <String, Map<String, dynamic>>{};
    for (final row in categories) {
      final id = row['id']?.toString().trim();
      if (id == null || id.isEmpty) continue;
      byId[id] = row;
    }

    final sorted = <Map<String, dynamic>>[];
    final seen = <String>{};
    for (final id in orderIds) {
      final row = byId[id];
      if (row == null) continue;
      sorted.add(row);
      seen.add(id);
    }
    for (final row in categories) {
      final id = row['id']?.toString().trim();
      if (id == null || id.isEmpty || seen.contains(id)) continue;
      sorted.add(row);
    }
    return sorted;
  }
}
