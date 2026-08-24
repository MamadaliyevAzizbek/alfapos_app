import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Desktop: telefonlar uchun TCP relay (USB printer orqali chop etish).
class MobilePrinterRelaySettings {
  MobilePrinterRelaySettings._();

  static const _enabledKey = 'mobile_printer_relay_enabled_v1';
  static const _portKey = 'mobile_printer_relay_port_v1';

  static const int defaultPort = 9100;
  static const int minPort = 1024;
  static const int maxPort = 65535;

  static final ValueNotifier<bool> enabled = ValueNotifier(true);
  static final ValueNotifier<int> port = ValueNotifier(defaultPort);

  static bool? _enabledCache;
  static int? _portCache;

  static Future<void> load() async {
    enabled.value = await isEnabled();
    port.value = await getPort();
  }

  static Future<bool> isEnabled() async {
    if (_enabledCache != null) return _enabledCache!;
    final prefs = await SharedPreferences.getInstance();
    _enabledCache = prefs.getBool(_enabledKey) ?? true;
    return _enabledCache!;
  }

  static Future<void> setEnabled(bool value) async {
    _enabledCache = value;
    enabled.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, value);
  }

  static Future<int> getPort() async {
    if (_portCache != null) return _portCache!;
    final prefs = await SharedPreferences.getInstance();
    _portCache = clampPort(prefs.getInt(_portKey) ?? defaultPort);
    return _portCache!;
  }

  static Future<void> setPort(int value) async {
    final clamped = clampPort(value);
    _portCache = clamped;
    port.value = clamped;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_portKey, clamped);
  }

  static int clampPort(int value) => value.clamp(minPort, maxPort);
}
