import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// MOBILE_PERMISSIONS_API_UZ.md — login / GET /user `permissions` flaglari.
class UserPermissions {
  final bool canAccessInventory;
  final bool canDeleteProducts;
  final bool canDeleteCustomers;
  final bool isAdmin;

  const UserPermissions({
    this.canAccessInventory = false,
    this.canDeleteProducts = false,
    this.canDeleteCustomers = false,
    this.isAdmin = false,
  });

  static const none = UserPermissions();

  UserPermissions copyWith({
    bool? canAccessInventory,
    bool? canDeleteProducts,
    bool? canDeleteCustomers,
    bool? isAdmin,
  }) {
    return UserPermissions(
      canAccessInventory: canAccessInventory ?? this.canAccessInventory,
      canDeleteProducts: canDeleteProducts ?? this.canDeleteProducts,
      canDeleteCustomers: canDeleteCustomers ?? this.canDeleteCustomers,
      isAdmin: isAdmin ?? this.isAdmin,
    );
  }

  Map<String, dynamic> toJson() => {
        'can_access_inventory': canAccessInventory,
        'can_delete_products': canDeleteProducts,
        'can_delete_customers': canDeleteCustomers,
        'is_admin': isAdmin,
      };

  factory UserPermissions.fromFlags(
    Map<String, dynamic>? flags, {
    bool isAdmin = false,
  }) {
    if (isAdmin) {
      return const UserPermissions(
        canAccessInventory: true,
        canDeleteProducts: true,
        canDeleteCustomers: true,
        isAdmin: true,
      );
    }
    if (flags == null) return none;
    return UserPermissions(
      canAccessInventory: _flag(flags['can_access_inventory']),
      canDeleteProducts: _flag(flags['can_delete_products']),
      canDeleteCustomers: _flag(flags['can_delete_customers']),
      isAdmin: false,
    );
  }

  /// POST /login → `data.user.permissions` (+ `is_admin`).
  factory UserPermissions.fromLoginResponse(Map<String, dynamic> res) {
    final data = res['data'];
    Map<String, dynamic>? user;
    if (data is Map) {
      final u = data['user'];
      if (u is Map) user = Map<String, dynamic>.from(u);
    }
    user ??= res['user'] is Map
        ? Map<String, dynamic>.from(res['user'] as Map)
        : null;
    return _fromUserMap(user);
  }

  /// GET /user → root `permissions` (+ `success.is_admin`).
  factory UserPermissions.fromUserResponse(Map<String, dynamic> res) {
    Map<String, dynamic>? user;
    if (res['success'] is Map) {
      user = Map<String, dynamic>.from(res['success'] as Map);
    } else if (res['data'] is Map) {
      user = Map<String, dynamic>.from(res['data'] as Map);
    } else {
      user = Map<String, dynamic>.from(res);
    }
    final flags = res['permissions'] is Map
        ? Map<String, dynamic>.from(res['permissions'] as Map)
        : (user['permissions'] is Map
            ? Map<String, dynamic>.from(user['permissions'] as Map)
            : null);
    final admin = _flag(user['is_admin']);
    return UserPermissions.fromFlags(flags, isAdmin: admin);
  }

  static UserPermissions _fromUserMap(Map<String, dynamic>? user) {
    if (user == null) return none;
    final flags = user['permissions'] is Map
        ? Map<String, dynamic>.from(user['permissions'] as Map)
        : null;
    return UserPermissions.fromFlags(flags, isAdmin: _flag(user['is_admin']));
  }

  static bool _flag(dynamic v) {
    if (v == true || v == 1) return true;
    if (v is String) {
      final s = v.trim().toLowerCase();
      return s == '1' || s == 'true' || s == 'yes';
    }
    return false;
  }
}

const String _keyAccessInventory = 'alfapos_perm_can_access_inventory';
const String _keyDeleteProducts = 'alfapos_perm_can_delete_products';
const String _keyDeleteCustomers = 'alfapos_perm_can_delete_customers';
const String _keyIsAdmin = 'alfapos_perm_is_admin';

/// Session davomida UI gate — SharedPreferences + ChangeNotifier.
class UserPermissionsStore extends ChangeNotifier {
  UserPermissionsStore._();
  static final UserPermissionsStore instance = UserPermissionsStore._();

  UserPermissions _current = UserPermissions.none;
  bool _loaded = false;

  UserPermissions get current => _current;
  bool get loaded => _loaded;

  bool get canAccessInventory => _current.canAccessInventory;
  bool get canDeleteProducts => _current.canDeleteProducts;
  bool get canDeleteCustomers => _current.canDeleteCustomers;

  Future<void> loadFromDisk() async {
    final prefs = await SharedPreferences.getInstance();
    _current = UserPermissions(
      canAccessInventory: prefs.getBool(_keyAccessInventory) ?? false,
      canDeleteProducts: prefs.getBool(_keyDeleteProducts) ?? false,
      canDeleteCustomers: prefs.getBool(_keyDeleteCustomers) ?? false,
      isAdmin: prefs.getBool(_keyIsAdmin) ?? false,
    );
    _loaded = true;
    notifyListeners();
  }

  Future<void> apply(UserPermissions permissions) async {
    _current = permissions;
    _loaded = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAccessInventory, permissions.canAccessInventory);
    await prefs.setBool(_keyDeleteProducts, permissions.canDeleteProducts);
    await prefs.setBool(_keyDeleteCustomers, permissions.canDeleteCustomers);
    await prefs.setBool(_keyIsAdmin, permissions.isAdmin);
    notifyListeners();
  }

  Future<void> applyFromLoginResponse(Map<String, dynamic> res) async {
    await apply(UserPermissions.fromLoginResponse(res));
  }

  Future<void> applyFromUserResponse(Map<String, dynamic> res) async {
    await apply(UserPermissions.fromUserResponse(res));
  }

  Future<void> clear() async {
    _current = UserPermissions.none;
    _loaded = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyAccessInventory);
    await prefs.remove(_keyDeleteProducts);
    await prefs.remove(_keyDeleteCustomers);
    await prefs.remove(_keyIsAdmin);
    notifyListeners();
  }
}
