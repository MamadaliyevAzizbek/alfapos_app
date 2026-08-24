import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// WiFi orqali chop etish rejimi.
enum NetworkPrinterMode {
  /// Kompyuter relay (USB + Mac/Windows) — PNG, TSPL/ZPL label printerlar.
  computerRelay,
  /// To‘g‘ridan-to‘g‘ri ESC/POS WiFi printer (port 9100).
  directEscPos,
}

/// WiFi termal printer (ESC/POS TCP, odatda port 9100).
class NetworkPrinterSettings {
  NetworkPrinterSettings._();

  static const _enabledKey = 'network_printer_enabled_v1';
  static const _hostKey = 'network_printer_host_v1';
  static const _portKey = 'network_printer_port_v1';
  static const _modeKey = 'network_printer_mode_v1';

  static const int defaultPort = 9100;
  static const int minPort = 1;
  static const int maxPort = 65535;

  static final ValueNotifier<bool> enabled = ValueNotifier(false);
  static final ValueNotifier<String> host = ValueNotifier('');
  static final ValueNotifier<int> port = ValueNotifier(defaultPort);
  static final ValueNotifier<NetworkPrinterMode> mode =
      ValueNotifier(NetworkPrinterMode.computerRelay);

  static bool? _enabledCache;
  static String? _hostCache;
  static int? _portCache;
  static NetworkPrinterMode? _modeCache;
  static Future<void>? _loadFuture;

  /// Bitta SharedPreferences o‘qish — tezroq.
  static Future<void> load() {
    return _loadFuture ??= _loadImpl().whenComplete(() => _loadFuture = null);
  }

  static Future<void> _loadImpl() async {
    await _applyBuildTimeDefaults();
    final prefs = await SharedPreferences.getInstance();

    _enabledCache = prefs.getBool(_enabledKey) ?? false;
    final rawHost = prefs.getString(_hostKey)?.trim();
    _hostCache = (rawHost == null || rawHost.isEmpty) ? null : rawHost;
    _portCache = clampPort(prefs.getInt(_portKey) ?? defaultPort);
    _modeCache = _parseMode(prefs.getString(_modeKey));

    enabled.value = _enabledCache!;
    host.value = _hostCache ?? '';
    port.value = _portCache!;
    mode.value = _modeCache!;
  }

  /// `flutter run --dart-define=ALFAPOS_PRINTER_HOST=192.168.x.x`
  static Future<void> _applyBuildTimeDefaults() async {
    const hostFromEnv = String.fromEnvironment('ALFAPOS_PRINTER_HOST');
    if (hostFromEnv.trim().isEmpty || !isValidHost(hostFromEnv)) return;
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_hostKey)?.trim();
    if (existing != null && existing.isNotEmpty) return;
    await setEnabled(true);
    await setHost(hostFromEnv.trim());
    await setPort(defaultPort);
  }

  static Future<NetworkPrinterMode> getMode() async {
    if (_modeCache != null) return _modeCache!;
    await load();
    return _modeCache ?? NetworkPrinterMode.computerRelay;
  }

  static Future<void> setMode(NetworkPrinterMode value) async {
    _modeCache = value;
    mode.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modeKey, value.name);
  }

  static NetworkPrinterMode _parseMode(String? raw) {
    if (raw == NetworkPrinterMode.directEscPos.name) {
      return NetworkPrinterMode.directEscPos;
    }
    return NetworkPrinterMode.computerRelay;
  }

  static Future<bool> usesComputerRelay() async =>
      await getMode() == NetworkPrinterMode.computerRelay;

  static Future<bool> isEnabled() async {
    if (_enabledCache != null) return _enabledCache!;
    await load();
    return _enabledCache ?? false;
  }

  static Future<void> setEnabled(bool value) async {
    _enabledCache = value;
    enabled.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, value);
  }

  static Future<String?> getHost() async {
    if (_hostCache != null) return _hostCache!.isEmpty ? null : _hostCache;
    await load();
    return _hostCache;
  }

  static Future<void> setHost(String? value) async {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      _hostCache = null;
      host.value = '';
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_hostKey);
      return;
    }
    _hostCache = trimmed;
    host.value = trimmed;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_hostKey, trimmed);
  }

  static Future<int> getPort() async {
    if (_portCache != null) return _portCache!;
    await load();
    return _portCache ?? defaultPort;
  }

  static Future<void> setPort(int value) async {
    final clamped = clampPort(value);
    _portCache = clamped;
    port.value = clamped;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_portKey, clamped);
  }

  static int clampPort(int value) => value.clamp(minPort, maxPort);

  static bool isValidHost(String raw) {
    final h = raw.trim();
    if (h.isEmpty || h.length > 253) return false;

    if (_looksLikeIpv4(h)) return _isValidIpv4(h);

    final hostname = RegExp(
      r'^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*$',
    );
    return hostname.hasMatch(h);
  }

  static bool _looksLikeIpv4(String h) => RegExp(r'^[\d.]+$').hasMatch(h);

  static bool _isValidIpv4(String h) {
    final parts = h.split('.');
    if (parts.length != 4) return false;
    for (final part in parts) {
      final n = int.tryParse(part);
      if (n == null || n < 0 || n > 255) return false;
    }
    return true;
  }

  static bool get isConfiguredSync {
    if (_enabledCache != true) return false;
    final h = _hostCache?.trim();
    return h != null && h.isNotEmpty && isValidHost(h);
  }

  static Future<bool> isConfigured() async {
    if (_enabledCache != null) return isConfiguredSync;
    await load();
    return isConfiguredSync;
  }

  static Future<({String host, int port})?> activeEndpoint() async {
    if (!await isConfigured()) return null;
    final h = _hostCache?.trim();
    if (h == null || h.isEmpty) return null;
    return (host: h, port: _portCache ?? defaultPort);
  }
}
