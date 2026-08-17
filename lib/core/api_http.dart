import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import 'api_config.dart';
import 'app_version.dart';
import 'connectivity_service.dart';

/// Barcha `dart:io` HTTP so‘rovlari uchun (cache manager, va h.k.).
class AlfaposHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    if (ApiHttp._creatingHttpClient) {
      return super.createHttpClient(context);
    }
    return ApiHttp.createHttpClient(securityContext: context);
  }
}

/// Barcha platformalar uchun HTTPS klient (mobil bilan bir xil ishonchlilik).
class ApiHttp {
  static http.Client? _client;

  /// [HttpClient] konstruktori [HttpOverrides] orqali qaytib kelmasligi uchun.
  static bool _creatingHttpClient = false;

  static http.Client get shared {
    _client ??= IOClient(createHttpClient());
    return _client!;
  }

  /// Faqat testlar uchun: tarmoqqa chiqmasdan soxta klient qo‘yish.
  /// `null` berilsa keyingi so‘rovda haqiqiy klient qayta yaratiladi.
  @visibleForTesting
  static set debugClient(http.Client? client) {
    _client?.close();
    _client = client;
  }

  static const Duration timeout = Duration(seconds: 45);

  /// Desktop POS: default — to‘g‘ridan-to‘g‘ri HTTPS (tizim/ENV proksisiz).
  /// Brauzer ishlasa ham Windows dagi eski HTTP_PROXY Dart HTTP ni buzishi mumkin.
  /// Kerak bo‘lsa: muhit o‘zgaruvchisi `ALFAPOS_USE_SYSTEM_PROXY=1`.
  static bool get useSystemProxy {
    if (kIsWeb) return false;
    final v = Platform.environment['ALFAPOS_USE_SYSTEM_PROXY']?.trim().toLowerCase();
    return v == '1' || v == 'true' || v == 'yes';
  }

  /// Desktop: tizim sertifikatlari, proksi, SSL.
  static HttpClient createHttpClient({SecurityContext? securityContext}) {
    _creatingHttpClient = true;
    try {
      final context = securityContext ?? SecurityContext(withTrustedRoots: true);
      final client = HttpClient(context: context);
      _configureHttpClient(client);
      return client;
    } finally {
      _creatingHttpClient = false;
    }
  }

  static void _configureHttpClient(HttpClient client) {
    client.connectionTimeout = timeout;
    client.idleTimeout = timeout;
    client.autoUncompress = true;
    // Mobil: ENV proksi; desktop POS: odatda DIRECT (bitta mijozda FormatException oldini olish).
    if (!kIsWeb &&
        (Platform.isWindows || Platform.isMacOS || Platform.isLinux) &&
        !useSystemProxy) {
      client.findProxy = (_) => 'DIRECT';
    } else {
      client.findProxy = HttpClient.findProxyFromEnvironment;
    }
    client.userAgent = 'AlfaposPOS/${AppVersion.name} (${Platform.operatingSystem})';
    if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      client.badCertificateCallback = (cert, host, port) =>
          host == 'app.alfapos.uz' || host.endsWith('.alfapos.uz');
    }
  }

  /// SSL/proksi holatini yangilash (bir marta qayta ulanish).
  static void resetClient() {
    _client?.close();
    _client = null;
  }

  static bool get _retryTransientNetwork =>
      !kIsWeb && (Platform.isWindows || Platform.isMacOS);

  /// Windows/macOS: birinchi SSL/proksi urinishi muvaffaqiyatsiz bo‘lsa qayta urinish.
  static Future<T> withTransientRetry<T>(Future<T> Function() action) async {
    try {
      final result = await action();
      ConnectivityService.instance.reportNetworkSuccess();
      return result;
    } on SocketException {
      ConnectivityService.instance.reportNetworkFailure();
      if (!_retryTransientNetwork) rethrow;
      resetClient();
      try {
        final result = await action();
        ConnectivityService.instance.reportNetworkSuccess();
        return result;
      } catch (_) {
        ConnectivityService.instance.reportNetworkFailure();
        rethrow;
      }
    } on HandshakeException {
      ConnectivityService.instance.reportNetworkFailure();
      if (!_retryTransientNetwork) rethrow;
      resetClient();
      try {
        final result = await action();
        ConnectivityService.instance.reportNetworkSuccess();
        return result;
      } catch (_) {
        ConnectivityService.instance.reportNetworkFailure();
        rethrow;
      }
    } on TlsException {
      ConnectivityService.instance.reportNetworkFailure();
      if (!_retryTransientNetwork) rethrow;
      resetClient();
      try {
        final result = await action();
        ConnectivityService.instance.reportNetworkSuccess();
        return result;
      } catch (_) {
        ConnectivityService.instance.reportNetworkFailure();
        rethrow;
      }
    } on http.ClientException {
      ConnectivityService.instance.reportNetworkFailure();
      if (!_retryTransientNetwork) rethrow;
      resetClient();
      try {
        final result = await action();
        ConnectivityService.instance.reportNetworkSuccess();
        return result;
      } catch (_) {
        ConnectivityService.instance.reportNetworkFailure();
        rethrow;
      }
    } on TimeoutException {
      ConnectivityService.instance.reportNetworkFailure();
      rethrow;
    }
  }

  /// Ilova ochilganda SSL zanjirini ishga tushirish (Windows/macOS).
  static Future<void> warmUp() async {
    if (kIsWeb) return;
    final attempts = Platform.isWindows ? 2 : 1;
    for (var i = 0; i < attempts; i++) {
      try {
        final client = createHttpClient();
        try {
          final req = await client.headUrl(Uri.parse(ApiConfig.baseUrl));
          final res = await req.close().timeout(const Duration(seconds: 12));
          await res.drain();
        } finally {
          client.close(force: true);
        }
        return;
      } catch (e) {
        debugLog('warmUp attempt ${i + 1}: $e');
        if (i + 1 < attempts) resetClient();
      }
    }
  }

  /// Serverga HEAD — login oldidan diagnostika.
  static Future<String?> reachabilityDetail() async {
    if (kIsWeb) return null;
    final client = createHttpClient();
    try {
      final req = await client.headUrl(Uri.parse(ApiConfig.baseUrl));
      final res = await req.close().timeout(const Duration(seconds: 12));
      await res.drain();
      if (res.statusCode >= 500) {
        return 'Server javob berdi (${res.statusCode})';
      }
      return null;
    } on SocketException catch (e) {
      return e.message;
    } on HandshakeException catch (e) {
      return e.message;
    } on TlsException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    } finally {
      client.close(force: true);
    }
  }

  static Future<http.Response> get(Uri uri, {Map<String, String>? headers}) {
    return withTransientRetry(
      () => shared.get(uri, headers: headers).timeout(timeout),
    );
  }

  static Future<http.Response> post(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
  }) {
    return withTransientRetry(
      () => shared.post(uri, headers: headers, body: body).timeout(timeout),
    );
  }

  static Future<http.Response> delete(Uri uri, {Map<String, String>? headers}) {
    return withTransientRetry(
      () => shared.delete(uri, headers: headers).timeout(timeout),
    );
  }

  static Future<http.StreamedResponse> send(http.BaseRequest request) {
    return withTransientRetry(
      () => shared.send(request).timeout(timeout),
    );
  }

  static void debugLog(String message) {
    if (kDebugMode) {
      debugPrint('[ApiHttp] $message');
    }
  }
}
