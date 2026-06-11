import 'package:shared_preferences/shared_preferences.dart';

import '../core/auth_storage.dart';

/// Restoran rejimida kunlik navbat tartib raqami (har kuni 1 dan boshlanadi).
class RestaurantQueueNumberService {
  RestaurantQueueNumberService._();

  static String _todayKey(DateTime now) {
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static Future<int> nextForToday({DateTime? now}) async {
    final day = _todayKey(now ?? DateTime.now());
    final prefs = await SharedPreferences.getInstance();
    final base = await companyStorageKey('restaurant_queue_v1');
    final dateKey = '${base}_date';
    final counterKey = '${base}_counter';

    final storedDate = prefs.getString(dateKey);
    var counter = prefs.getInt(counterKey) ?? 0;
    if (storedDate != day) {
      counter = 0;
    }
    counter += 1;
    await prefs.setString(dateKey, day);
    await prefs.setInt(counterKey, counter);
    return counter;
  }

  /// Sozlamalar / test uchun joriy kunlik hisoblagich (keyingi raqam).
  static Future<int> peekNextForToday({DateTime? now}) async {
    final day = _todayKey(now ?? DateTime.now());
    final prefs = await SharedPreferences.getInstance();
    final base = await companyStorageKey('restaurant_queue_v1');
    final storedDate = prefs.getString('${base}_date');
    final counter = prefs.getInt('${base}_counter') ?? 0;
    if (storedDate != day) return 1;
    return counter + 1;
  }
}
