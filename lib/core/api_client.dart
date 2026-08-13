import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'api_http.dart';
import 'auth_storage.dart';

class ApiException implements Exception {
  final int? statusCode;
  final String message;
  ApiException(this.message, [this.statusCode]);
  @override
  String toString() => message;

  bool get isNotFound => statusCode == 404;

  /// HTML/proksi shovqin — foydalanuvchiga VPN matnini ko‘rsatmaslik kerak.
  bool get isNonJsonOrProxyNoise {
    final m = message.toLowerCase();
    return m.contains('<!doctype') ||
        m.contains('<html') ||
        m.contains('https scanning') ||
        m.contains('proksi') ||
        m.contains('json o‘rniga') ||
        m.contains("json o'rniga");
  }
}

class ApiClient {
  static String get _base => ApiConfig.apiBaseUrl;

  static Future<Map<String, String>> _headers({
    bool jsonBody = true,
    bool withAuth = true,
    bool includeCompanyHeader = true,
  }) async {
    final token = withAuth ? await getToken() : null;
    final companyId = includeCompanyHeader ? await getCompanyId() : null;
    final headers = <String, String>{
      'Accept': 'application/json',
      // multipart so'rovlarida Content-Type ni http o‘rnatadi (boundary bilan)
      if (jsonBody) 'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      if (companyId != null && companyId.isNotEmpty) 'X-Company-Id': companyId,
    };
    return headers;
  }

  /// Login — token siz so'rov
  static Future<Map<String, dynamic>> login(String email, String password, String companyId) async {
    final uri = Uri.parse('$_base/login');
    final cid = int.tryParse(companyId.trim());
    final payload = {
      'email': email.trim(),
      'password': password,
      'company_id': cid ?? companyId.trim(),
    };
    ApiHttp.debugLog('POST $uri body=${payload.keys} company_id=${payload['company_id']}');
    try {
      final response = await ApiHttp.post(
        uri,
        headers: await _headers(withAuth: false, includeCompanyHeader: false),
        body: jsonEncode(payload),
      );
      ApiHttp.debugLog('login status=${response.statusCode} len=${response.body.length}');
      return _handleResponse(response);
    } on SocketException catch (e) {
      ApiHttp.debugLog('SocketException: $e');
      rethrow;
    } on HandshakeException catch (e) {
      ApiHttp.debugLog('HandshakeException: $e');
      rethrow;
    } on http.ClientException catch (e) {
      ApiHttp.debugLog('ClientException: $e');
      rethrow;
    } on TimeoutException catch (e) {
      ApiHttp.debugLog('TimeoutException: $e');
      rethrow;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[ApiClient.login] $e\n$st');
      }
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> get(String path, {Map<String, String>? queryParams}) async {
    final h = await _headers();
    var uri = Uri.parse('$_base$path');
    if (queryParams != null && queryParams.isNotEmpty) {
      uri = uri.replace(queryParameters: queryParams);
    }
    final response = await ApiHttp.get(uri, headers: h);
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> post(String path, {Map<String, dynamic>? body}) async {
    final uri = Uri.parse('$_base$path');
    final response = await ApiHttp.post(
      uri,
      headers: await _headers(),
      body: body != null ? jsonEncode(body) : null,
    );
    return _handleResponse(response);
  }

  /// MOBILE_API_DOCS.md: mahsulot yaratishda rasm `image` maydoni bilan multipart.
  /// Boshqa maydonlar matn sifatida (sonlar ham string) yuboriladi.
  static Future<Map<String, dynamic>> postMultipart(
    String path, {
    required Map<String, String> fields,
    http.MultipartFile? file,
  }) async {
    final uri = Uri.parse('$_base$path');
    final req = http.MultipartRequest('POST', uri);
    req.headers.addAll(await _headers(jsonBody: false));
    fields.forEach((k, v) {
      req.fields[k] = v;
    });
    if (file != null) req.files.add(file);
    final streamed = await ApiHttp.send(req);
    final response = await http.Response.fromStream(streamed);
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> delete(String path) async {
    final uri = Uri.parse('$_base$path');
    final response = await ApiHttp.delete(uri, headers: await _headers());
    return _handleResponse(response);
  }

  /// JSON o‘qish: BOM va oldidagi PHP/proksi chiqindisini kesib urinish.
  static dynamic _decodeJsonBody(String raw) {
    var body = raw.trim();
    if (body.startsWith('\uFEFF')) {
      body = body.substring(1).trim();
    }
    try {
      return jsonDecode(body);
    } catch (_) {
      final obj = body.indexOf('{');
      final arr = body.indexOf('[');
      var start = -1;
      if (obj >= 0 && arr >= 0) {
        start = obj < arr ? obj : arr;
      } else {
        start = obj >= 0 ? obj : arr;
      }
      if (start > 0) {
        return jsonDecode(body.substring(start));
      }
      rethrow;
    }
  }

  static String _bodyPreview(String body, {int max = 120}) {
    final oneLine = body.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (oneLine.length <= max) return oneLine;
    return '${oneLine.substring(0, max)}…';
  }

  static Future<Map<String, dynamic>> _handleResponse(http.Response response) async {
    dynamic decoded;
    if (response.body.isNotEmpty) {
      try {
        decoded = _decodeJsonBody(response.body);
      } catch (e) {
        final body = response.body.trim().toLowerCase();
        final preview = _bodyPreview(response.body);
        if (body.startsWith('<') ||
            body.contains('<!doctype') ||
            body.contains('<html') ||
            body.contains('access denied') ||
            body.contains('proxy')) {
          if (response.statusCode == 404) {
            throw ApiException('Topilmadi', 404);
          }
          throw ApiException(
            'Tarmoq/proksi JSON o‘rniga boshqa javob qaytardi (kod ${response.statusCode}). '
            'Antivirus «HTTPS scanning», VPN yoki Windows proksini o‘chirib qayta urinib ko‘ring.\n'
            'Javob: $preview',
            response.statusCode,
          );
        }
        throw ApiException(
          'Server noto‘g‘ri javob qaytardi (kod ${response.statusCode}). '
          'Antivirus / proksi / VPN ni tekshiring.\n'
          'Javob: $preview',
          response.statusCode,
        );
      }
      // Backend ba'zan root da massiv qaytaradi (masalan GET /products/categories, top-selling-products)
      if (decoded is List) {
        decoded = <String, dynamic>{'data': decoded};
      } else if (decoded is! Map<String, dynamic>) {
        decoded = <String, dynamic>{};
      }
    } else {
      decoded = <String, dynamic>{};
    }
    final map = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final success = map['success'];
      if (success == false ||
          success == 0 ||
          (success is String && success.toString().toLowerCase().trim() == 'false')) {
        final msg = map['message'] as String? ?? 'So\'rov bajarilmadi';
        // Ba'zi backendlar `success:false` bilan ham muvaffaqiyat xabarini qaytaradi (rasm upload).
        if (_isSuccessLikeMessage(msg)) {
          return map;
        }
        throw ApiException(msg, response.statusCode);
      }
      return map;
    }

    String message = map['message'] as String? ??
        map['error'] as String? ??
        'Xatolik: ${response.statusCode}';

    // Laravel validation (422): errors ob'ektidan maydon xabarlarini birlashtirish
    final errors = map['errors'];
    if (errors is Map<String, dynamic>) {
      final parts = <String>[];
      for (final entry in errors.entries) {
        final key = entry.key;
        final val = entry.value;
        if (val is List && val.isNotEmpty) {
          parts.add('$key: ${val.first}');
        } else if (val != null) {
          parts.add('$key: $val');
        }
      }
      if (parts.isNotEmpty) {
        message = parts.join('\n');
      }
    }

    // Laravel throttle (429) — inglizcha matnni tushunarli qilish.
    if (response.statusCode == 429 || _isTooManyAttemptsMessage(message)) {
      message =
          'Juda ko\'p so\'rov yuborildi. 30–60 soniya kutib, qayta urinib ko\'ring.';
    }

    throw ApiException(message, response.statusCode);
  }

  static bool _isTooManyAttemptsMessage(String message) {
    final m = message.toLowerCase();
    return m.contains('too many attempts') ||
        m.contains('too many requests') ||
        m.contains('rate limit') ||
        m.contains('throttle');
  }

  /// Backend ba'zan `success:false` + muvaffaqiyat matni yuboradi — saqlash muvaffaqiyatli deb qabul qilinadi.
  static bool isSuccessLikeMessage(String message) => _isSuccessLikeMessage(message);

  static bool _isSuccessLikeMessage(String message) {
    final m = message.toLowerCase().trim();
    if (m.isEmpty) return false;
    const keys = [
      'muvaffaqiyat',
      'saqlandi',
      'yangilandi',
      "qo'shildi",
      'successfully',
      'success',
      'updated',
      'created',
      'saved',
    ];
    for (final k in keys) {
      if (m.contains(k)) return true;
    }
    return false;
  }
}
