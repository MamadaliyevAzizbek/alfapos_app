import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import 'api_config.dart';

/// Barcha `dart:io` HTTP so‘rovlari uchun (cache manager, va h.k.).
class AlfaposHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return ApiHttp.createHttpClient(securityContext: context);
  }
}

/// Barcha platformalar uchun HTTPS klient (mobil bilan bir xil ishonchlilik).
class ApiHttp {
  static http.Client? _client;

  static http.Client get shared {
    _client ??= IOClient(createHttpClient());
    return _client!;
  }

  static const Duration timeout = Duration(seconds: 45);

  /// Desktop: tizim sertifikatlari, proksi, SSL.
  static HttpClient createHttpClient({SecurityContext? securityContext}) {
    final context = securityContext ?? SecurityContext(withTrustedRoots: true);
    final client = HttpClient(context: context);
    client.connectionTimeout = timeout;
    client.idleTimeout = timeout;
    client.autoUncompress = true;
    client.findProxy = HttpClient.findProxyFromEnvironment;
    client.userAgent = 'AlfaposPOS/1.0.6 (${Platform.operatingSystem})';
    if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      client.badCertificateCallback = (cert, host, port) =>
          host == 'app.alfapos.uz' || host.endsWith('.alfapos.uz');
    }
    return client;
  }

  /// SSL/proksi holatini yangilash (bir marta qayta ulanish).
  static void resetClient() {
    _client?.close();
    _client = null;
  }

  /// Ilova ochilganda SSL zanjirini ishga tushirish (Windows).
  static Future<void> warmUp() async {
    if (kIsWeb) return;
    try {
      final client = createHttpClient();
      try {
        final req = await client.headUrl(Uri.parse(ApiConfig.baseUrl));
        final res = await req.close().timeout(const Duration(seconds: 12));
        await res.drain();
      } finally {
        client.close(force: true);
      }
    } catch (e) {
      debugLog('warmUp: $e');
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
    return shared.get(uri, headers: headers).timeout(timeout);
  }

  static Future<http.Response> post(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
  }) {
    return shared.post(uri, headers: headers, body: body).timeout(timeout);
  }

  static Future<http.Response> delete(Uri uri, {Map<String, String>? headers}) {
    return shared.delete(uri, headers: headers).timeout(timeout);
  }

  static Future<http.StreamedResponse> send(http.BaseRequest request) {
    return shared.send(request).timeout(timeout);
  }

  static void debugLog(String message) {
    if (kDebugMode) {
      debugPrint('[ApiHttp] $message');
    }
  }
}
