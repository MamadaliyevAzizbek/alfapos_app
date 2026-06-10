import 'package:alfapos_app/utils/category_image_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  test('removeImage clears saved entry', () async {
    SharedPreferences.setMockInitialValues({
      'alfapos_category_images_v1': '{"12":"/app/category_images/cat_12.jpg"}',
    });
    expect(await CategoryImageStorage.loadMap(), {'12': '/app/category_images/cat_12.jpg'});
    await CategoryImageStorage.removeImage('12');
    expect(await CategoryImageStorage.loadMap(), isEmpty);
  });
}
