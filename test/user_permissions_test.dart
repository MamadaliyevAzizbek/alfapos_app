import 'package:alfapos_app/core/user_permissions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await UserPermissionsStore.instance.clear();
  });

  group('UserPermissions.fromLoginResponse', () {
    test('reads data.user.permissions', () {
      final p = UserPermissions.fromLoginResponse({
        'success': true,
        'data': {
          'token': 't',
          'user': {
            'id': 5,
            'is_admin': 0,
            'permissions': {
              'can_access_inventory': true,
              'can_delete_products': false,
              'can_delete_customers': true,
            },
          },
        },
      });
      expect(p.canAccessInventory, isTrue);
      expect(p.canDeleteProducts, isFalse);
      expect(p.canDeleteCustomers, isTrue);
      expect(p.isAdmin, isFalse);
    });

    test('admin forces all true', () {
      final p = UserPermissions.fromLoginResponse({
        'data': {
          'user': {
            'is_admin': 1,
            'permissions': {
              'can_access_inventory': false,
              'can_delete_products': false,
              'can_delete_customers': false,
            },
          },
        },
      });
      expect(p.canAccessInventory, isTrue);
      expect(p.canDeleteProducts, isTrue);
      expect(p.canDeleteCustomers, isTrue);
      expect(p.isAdmin, isTrue);
    });
  });

  group('UserPermissions.fromUserResponse', () {
    test('reads root permissions beside success user', () {
      final p = UserPermissions.fromUserResponse({
        'success': {
          'id': 5,
          'is_admin': 0,
          'email': 'a@b.c',
        },
        'permissions': {
          'can_access_inventory': false,
          'can_delete_products': true,
          'can_delete_customers': false,
        },
      });
      expect(p.canAccessInventory, isFalse);
      expect(p.canDeleteProducts, isTrue);
      expect(p.canDeleteCustomers, isFalse);
    });
  });

  test('store persists and reloads from disk', () async {
    await UserPermissionsStore.instance.apply(
      const UserPermissions(
        canAccessInventory: true,
        canDeleteProducts: true,
        canDeleteCustomers: false,
      ),
    );
    expect(UserPermissionsStore.instance.canAccessInventory, isTrue);

    // Yangi "session" — diskdan o‘qish.
    await UserPermissionsStore.instance.clear();
    expect(UserPermissionsStore.instance.canAccessInventory, isFalse);

    // clear() diskni ham tozalaydi — apply qilib qayta load.
    await UserPermissionsStore.instance.apply(
      const UserPermissions(canDeleteCustomers: true),
    );
    await UserPermissionsStore.instance.loadFromDisk();
    expect(UserPermissionsStore.instance.canDeleteCustomers, isTrue);
    expect(UserPermissionsStore.instance.canAccessInventory, isFalse);
  });
}
