import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api_sync_throttle.dart';
import '../core/auth_storage.dart';
import '../services/api_service.dart';
import '../core/api_client.dart';
import '../utils/category_image_storage.dart';

class CategoriesProvider extends ChangeNotifier {
  CategoriesProvider._() {
    _items = [];
  }
  static final CategoriesProvider _instance = CategoriesProvider._();
  static CategoriesProvider get instance => _instance;

  List<String> _items = [];
  List<Map<String, dynamic>> _rawList = [];
  Map<String, String> _localImages = {};
  Map<String, dynamic>? _lastRawResponse;
  final _controller = StreamController<List<String>>.broadcast();
  bool _loaded = false;
  String? _loadError;
  final Set<String> _addingKeys = {};
  static const _cacheKeyBase = 'alfapos_categories_v1';
  static const _staleAfter = Duration(hours: 12);
  String? _boundCompanyId;

  Future<String> _cacheKey() => companyStorageKey(_cacheKeyBase);

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
        return {
          'id': id,
          'name': name.isNotEmpty ? name : id,
          'imageUrl': categoryImageUrl(id),
        };
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

  /// Boshqa kompaniyaga kirganda xotira va keshni yangilash.
  Future<void> resetForCompanyChange() async {
    final cid = (await getCompanyId())?.trim();
    if (cid != null && cid.isNotEmpty && cid == _boundCompanyId && _rawList.isNotEmpty) {
      return;
    }
    await resetForAccountChange();
    await _loadCache();
  }

  /// Boshqa xodim yoki kompaniya — kategoriya keshi qayta yuklanadi.
  Future<void> resetForAccountChange() async {
    _boundCompanyId = null;
    _items = [];
    _rawList = [];
    _localImages = {};
    _loaded = false;
    _loadError = null;
    _controller.add(items);
    notifyListeners();
  }

  Future<void> _refreshLocalImages() async {
    _localImages = await CategoryImageStorage.loadMap();
  }

  String? _imageFromRaw(Map<String, dynamic> row) {
    for (final key in ['image', 'imageUrl', 'imageURL', 'image_url', 'photo', 'thumbnail']) {
      final value = row[key]?.toString().trim();
      if (value != null && value.isNotEmpty && value != 'null') return value;
    }
    return null;
  }

  /// Restoran POS va katalog ro‘yxati uchun rasm yo‘li / URL.
  String? categoryImageUrl(String? categoryId) {
    final id = categoryId?.trim();
    if (id == null || id.isEmpty) return null;

    final local = _localImages[id];
    if (local != null && local.isNotEmpty) {
      final file = File(local);
      if (file.existsSync()) return local;
    }

    for (final row in _rawList) {
      if (row['id']?.toString() == id) return _imageFromRaw(row);
    }
    return null;
  }

  Future<void> setCategoryImage(
    String categoryId, {
    String? localPath,
    bool remove = false,
  }) async {
    final id = categoryId.trim();
    if (id.isEmpty) return;
    if (remove) {
      await CategoryImageStorage.removeImage(id);
    } else if (localPath != null && localPath.trim().isNotEmpty) {
      await CategoryImageStorage.setImage(id, localPath);
    }
    await _refreshLocalImages();
    notifyListeners();
    _controller.add(items);
  }

  Future<void> _persistCache() async {
    if (_rawList.isEmpty) return;
    _boundCompanyId = (await getCompanyId())?.trim();
    final prefs = await SharedPreferences.getInstance();
    final key = await _cacheKey();
    await prefs.setString(key, jsonEncode(_rawList));
    await prefs.setInt('${key}_at', DateTime.now().millisecondsSinceEpoch);
  }

  Future<void> _loadCache() async {
    await _refreshLocalImages();
    _boundCompanyId = (await getCompanyId())?.trim();
    final prefs = await SharedPreferences.getInstance();
    final key = await _cacheKey();
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return;
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      _rawList = list
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      _items = _rawList
          .map((e) {
            final name = e['name'] as String? ??
                e['title'] as String? ??
                e['category_name'] as String? ??
                e['text'] as String? ??
                '';
            return name.toString().trim();
          })
          .where((s) => s.isNotEmpty)
          .toList();
      _loaded = true;
      _controller.add(items);
      notifyListeners();
    } catch (_) {}
  }

  /// Diskdan tez, API ixtiyoriy.
  Future<void> loadFromStorage({bool refreshInBackground = true}) async {
    await resetForCompanyChange();
    if (refreshInBackground) {
      unawaited(loadFromApiIfStale());
    }
  }

  /// Kategoriyalar eskirgan bo‘lsa yoki kesh bo‘sh bo‘lsa API.
  Future<void> loadFromApiIfStale({bool force = false}) async {
    if (force) {
      ApiSyncThrottle.invalidate('categories_api');
      _loaded = false;
      await loadFromApi();
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final key = await _cacheKey();
    final ms = prefs.getInt('${key}_at');
    if (_loaded && _items.isNotEmpty && ms != null) {
      final last = DateTime.fromMillisecondsSinceEpoch(ms);
      if (DateTime.now().difference(last) < _staleAfter) return;
    }
    await ApiSyncThrottle.runIfDue(
      'categories_api',
      const Duration(minutes: 10),
      loadFromApi,
    );
  }

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
    await _refreshLocalImages();
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
      final cid = (await getCompanyId())?.trim();
      _rawList = list
          .where((e) => e is Map)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .where((m) {
            if (cid == null || cid.isEmpty) return true;
            final rowCid = (m['company_id'] ?? m['companyId'])?.toString().trim();
            if (rowCid == null || rowCid.isEmpty) return true;
            return rowCid == cid;
          })
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
      unawaited(_persistCache());
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

  /// `true` — qo‘shildi (optimistik + server). `false` — bo‘sh, dublikat yoki allaqachon qo‘shilmoqda.
  Future<bool> addCategory(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return false;
    final key = trimmed.toLowerCase();
    if (_items.any((c) => c.toLowerCase() == key)) return false;
    if (_addingKeys.contains(key)) return false;

    _addingKeys.add(key);
    _items = [..._items, trimmed];
    _rawList = [
      ..._rawList,
      {'id': 'local_$key', 'name': trimmed},
    ];
    _controller.add(items);
    notifyListeners();

    try {
      await CategoriesApi.createCategory(trimmed);
      unawaited(loadFromApi());
      return true;
    } catch (e) {
      _items.removeWhere((c) => c.toLowerCase() == key);
      _rawList.removeWhere((e) {
        final n = (e['name'] as String? ?? e['title'] as String? ?? '').trim().toLowerCase();
        return n == key;
      });
      _controller.add(items);
      notifyListeners();
      rethrow;
    } finally {
      _addingKeys.remove(key);
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

  Future<void> updateCategory(
    String oldName,
    String newName, {
    String? imagePath,
    bool removeImage = false,
  }) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) return;
    final i = _items.indexWhere((c) => c == oldName);
    if (i < 0) return;
    try {
      final catList = await CategoriesApi.getCategories();
      final list = catList['data'] as List<dynamic>? ?? catList['categories'] as List<dynamic>? ?? [];
      final id = _findCategoryId(list, oldName);
      if (id != null) {
        if (trimmed != oldName) {
          await CategoriesApi.updateCategory(id, trimmed);
        }
        if (removeImage) {
          await setCategoryImage(id.toString(), remove: true);
        } else if (imagePath != null && imagePath.trim().isNotEmpty) {
          await setCategoryImage(id.toString(), localPath: imagePath);
        }
        if (trimmed != oldName) {
          _items[i] = trimmed;
          for (final row in _rawList) {
            final name = (row['name'] as String? ?? row['title'] as String? ?? '').trim();
            if (name == oldName) {
              row['name'] = trimmed;
              break;
            }
          }
        }
        _controller.add(items);
        notifyListeners();
        unawaited(_persistCache());
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
        await setCategoryImage(id.toString(), remove: true);
        _items.removeWhere((c) => c == name);
        _rawList.removeWhere((e) {
          final n = (e['name'] as String? ?? e['title'] as String? ?? '').trim();
          return n == name;
        });
        _controller.add(items);
        notifyListeners();
        unawaited(_persistCache());
      }
    } catch (_) {
      rethrow;
    }
  }

  void dispose() {
    _controller.close();
  }
}
