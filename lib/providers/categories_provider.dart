import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import '../core/api_client.dart';

class CategoriesProvider extends ChangeNotifier {
  CategoriesProvider._() {
    _items = [];
  }
  static final CategoriesProvider _instance = CategoriesProvider._();
  static CategoriesProvider get instance => _instance;

  List<String> _items = [];
  List<Map<String, dynamic>> _rawList = [];
  Map<String, dynamic>? _lastRawResponse;
  final _controller = StreamController<List<String>>.broadcast();
  bool _loaded = false;
  String? _loadError;

  List<String> get items => List.unmodifiable(_items);

  /// Filtr dropdown: {id, name}
  List<Map<String, dynamic>> get idNameOptions => _rawList
      .map((e) {
        final id = (e['id'] ?? e['value'] ?? '').toString().trim();
        final name = (e['name'] as String? ??
                e['title'] as String? ??
                e['category_name'] as String? ??
                e['text'] as String? ??
                '')
            .trim();
        return {'id': id, 'name': name.isNotEmpty ? name : id};
      })
      .where((e) => (e['id'] as String).isNotEmpty)
      .toList();
  Stream<List<String>> get stream => _controller.stream;
  String? get loadError => _loadError;
  Map<String, dynamic>? get lastRawCategories => _lastRawResponse;

  /// Kategoriya nomi bo'yicha API dagi id (mahsulot qo'shishda category_id uchun)
  int? getCategoryIdByName(String? name) {
    if (name == null || name.trim().isEmpty) return null;
    final n = name.trim().toLowerCase();
    for (final e in _rawList) {
      final mapName = (e['name'] as String? ?? e['title'] as String? ?? e['category_name'] as String? ?? '').trim().toLowerCase();
      if (mapName == n || mapName.isNotEmpty && n.contains(mapName) || mapName.contains(n)) {
        final id = e['id'];
        if (id != null) return id is int ? id : int.tryParse(id.toString());
      }
    }
    return null;
  }

  /// Lokal saqlash yo'q — faqat API dan yuklash (eski chaqiriqlar uchun nom).
  Future<void> loadFromStorage() async => loadFromApi();

  /// API javobidan ro'yxatni chiqarish (data, categories, datarows — to'g'ri yoki ichida)
  static List<dynamic> _extractList(Map<String, dynamic> res) {
    final raw = res['data'] ?? res['categories'] ?? res['datarows'];
    if (raw is List<dynamic>) return raw;
    if (raw is Map<String, dynamic>) {
      final inner = raw['data'] ?? raw['categories'] ?? raw['items'];
      if (inner is List<dynamic>) return inner;
    }
    return [];
  }

  Future<void> loadFromApi() async {
    _loadError = null;
    try {
      final res = await CategoriesApi.getCategories();
      _lastRawResponse = res;
      List<dynamic> list = _extractList(res);
      if (list.isEmpty) {
        try {
          final support = await ProductsApi.getSupportingData();
          list = _extractList(support is Map<String, dynamic> ? support : <String, dynamic>{});
          if (list.isEmpty && support['categories'] is List) list = support['categories'] as List<dynamic>;
        } catch (_) {}
      }
      _rawList = list
          .where((e) => e is Map)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      _items = _rawList
          .map((e) {
            final name = e['name'] as String? ?? e['title'] as String? ?? e['category_name'] as String? ?? e['text'] as String? ?? '';
            return name.toString().trim();
          })
          .where((s) => s.isNotEmpty)
          .toList();
      _loaded = true;
      _controller.add(items);
      notifyListeners();
    } on ApiException catch (e) {
      _loadError = e.message;
      _loaded = true;
      _items = [];
      _rawList = [];
      _controller.add(items);
      notifyListeners();
    } catch (_) {
      _loadError = 'Kategoriyalar yuklanmadi';
      _loaded = true;
      _items = [];
      _rawList = [];
      _controller.add(items);
      notifyListeners();
    }
  }

  Future<void> addCategory(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    if (_items.any((c) => c.toLowerCase() == trimmed.toLowerCase())) return;
    try {
      await CategoriesApi.createCategory(trimmed);
      await loadFromApi();
    } catch (_) {
      rethrow;
    }
  }

  int? _findCategoryId(List<dynamic> list, String name) {
    for (final e in list) {
      if (e is! Map) continue;
      final m = Map<String, dynamic>.from(e as Map);
      if ((m['name'] as String? ?? m['title'] as String? ?? '') == name) {
        final id = m['id'];
        return id is int ? id : int.tryParse(id?.toString() ?? '');
      }
    }
    return null;
  }

  List<Map<String, dynamic>> get rawList => List.unmodifiable(_rawList);

  Future<void> updateCategory(String oldName, String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) return;
    final i = _items.indexWhere((c) => c == oldName);
    if (i < 0) return;
    try {
      final catList = await CategoriesApi.getCategories();
      final list = catList['data'] as List<dynamic>? ?? catList['categories'] as List<dynamic>? ?? [];
      final id = _findCategoryId(list, oldName);
      if (id != null) {
        await CategoriesApi.updateCategory(id, trimmed);
        _items[i] = trimmed;
        _controller.add(items);
        notifyListeners();
      }
    } catch (_) {
      rethrow;
    }
  }

  Future<void> removeCategory(String name) async {
    try {
      final catList = await CategoriesApi.getCategories();
      final list = catList['data'] as List<dynamic>? ?? catList['categories'] as List<dynamic>? ?? [];
      final id = _findCategoryId(list, name);
      if (id != null) {
        await CategoriesApi.deleteCategory(id);
        _items.removeWhere((c) => c == name);
        _controller.add(items);
        notifyListeners();
      }
    } catch (_) {
      rethrow;
    }
  }

  void dispose() {
    _controller.close();
  }
}
