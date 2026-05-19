/// Bir xil og‘ir so‘rovni qisqa vaqt ichida takrorlamaslik.
class ApiSyncThrottle {
  ApiSyncThrottle._();

  static final Map<String, DateTime> _lastRun = {};

  static bool shouldRun(String key, Duration minInterval) {
    final last = _lastRun[key];
    if (last == null) return true;
    return DateTime.now().difference(last) >= minInterval;
  }

  static void markRan(String key) => _lastRun[key] = DateTime.now();

  /// [minInterval] ichida chaqirilmasa `null` qaytaradi.
  static Future<T?> runIfDue<T>(
    String key,
    Duration minInterval,
    Future<T> Function() action,
  ) async {
    if (!shouldRun(key, minInterval)) return null;
    markRan(key);
    return action();
  }
}
