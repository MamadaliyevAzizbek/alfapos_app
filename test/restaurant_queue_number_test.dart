import 'package:alfapos_app/services/restaurant_queue_number.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  test('starts at 1 each day and increments', () async {
    final day = DateTime(2026, 6, 10, 12);
    expect(await RestaurantQueueNumberService.nextForToday(now: day), 1);
    expect(await RestaurantQueueNumberService.nextForToday(now: day), 2);
    expect(await RestaurantQueueNumberService.nextForToday(now: day), 3);
  });

  test('resets to 1 on a new day', () async {
    final day1 = DateTime(2026, 6, 10, 12);
    final day2 = DateTime(2026, 6, 11, 9);
    expect(await RestaurantQueueNumberService.nextForToday(now: day1), 1);
    expect(await RestaurantQueueNumberService.nextForToday(now: day1), 2);
    expect(await RestaurantQueueNumberService.nextForToday(now: day2), 1);
  });

  test('peekNextForToday reflects next value', () async {
    final day = DateTime(2026, 6, 10, 12);
    expect(await RestaurantQueueNumberService.peekNextForToday(now: day), 1);
    await RestaurantQueueNumberService.nextForToday(now: day);
    expect(await RestaurantQueueNumberService.peekNextForToday(now: day), 2);
  });
}
