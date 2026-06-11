import 'package:alfapos_app/services/category_order_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  test('merge adds new categories to the end', () async {
    await CategoryOrderStorage.saveOrderedIds(const ['2', '1']);
    final merged = await CategoryOrderStorage.mergeWithCategoryIds(const ['1', '2', '3']);
    expect(merged, ['2', '1', '3']);
  });

  test('merge removes deleted categories', () async {
    await CategoryOrderStorage.saveOrderedIds(const ['9', '2', '1']);
    final merged = await CategoryOrderStorage.mergeWithCategoryIds(const ['2', '1']);
    expect(merged, ['2', '1']);
  });
}
