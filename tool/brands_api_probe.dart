// dart run tool/brands_api_probe.dart [email] [password] [companyId]
import 'dart:convert';
import 'dart:io';

import 'package:alfapos_app/core/api_config.dart';
import 'package:alfapos_app/utils/filter_options_parser.dart';

Future<void> main(List<String> args) async {
  final email = args.isNotEmpty ? args[0] : 'murod';
  final password = args.length > 1 ? args[1] : '';
  final companyId = args.length > 2 ? args[2] : '1';

  if (password.isEmpty) {
    stderr.writeln('Usage: dart run tool/brands_api_probe.dart email password [companyId]');
    exitCode = 1;
    return;
  }

  final base = ApiConfig.apiBaseUrl;
  final client = HttpClient();

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    String? token,
  }) async {
    final req = await client.postUrl(Uri.parse('$base$path'));
    req.headers.set('Content-Type', 'application/json');
    req.headers.set('Accept', 'application/json');
    req.headers.set('X-Company-Id', companyId);
    if (token != null) req.headers.set('Authorization', 'Bearer $token');
    if (body != null) req.write(jsonEncode(body));
    final res = await req.close();
    final text = await res.transform(utf8.decoder).join();
    stdout.writeln('\n=== POST $path (${res.statusCode}) ===');
    dynamic decoded;
    try {
      decoded = jsonDecode(text);
    } catch (_) {
      stdout.writeln(text.length > 800 ? '${text.substring(0, 800)}...' : text);
      return {};
    }
    if (decoded is List) {
      stdout.writeln('ROOT LIST len=${decoded.length}');
      if (decoded.isNotEmpty) stdout.writeln('first: ${decoded.first}');
      decoded = <String, dynamic>{'data': decoded};
    } else {
      final pretty = const JsonEncoder.withIndent('  ').convert(decoded);
      stdout.writeln(pretty.length > 4000 ? '${pretty.substring(0, 4000)}...' : pretty);
    }
    return decoded is Map<String, dynamic> ? decoded : Map<String, dynamic>.from(decoded as Map);
  }

  Future<Map<String, dynamic>> get(String path, {String? token}) async {
    final req = await client.getUrl(Uri.parse('$base$path'));
    req.headers.set('Accept', 'application/json');
    req.headers.set('X-Company-Id', companyId);
    if (token != null) req.headers.set('Authorization', 'Bearer $token');
    final res = await req.close();
    final text = await res.transform(utf8.decoder).join();
    stdout.writeln('\n=== GET $path (${res.statusCode}) ===');
    dynamic decoded;
    try {
      decoded = jsonDecode(text);
    } catch (_) {
      stdout.writeln(text.length > 800 ? '${text.substring(0, 800)}...' : text);
      return {};
    }
    if (decoded is List) {
      stdout.writeln('ROOT LIST len=${decoded.length}');
      if (decoded.isNotEmpty) stdout.writeln('first: ${decoded.first}');
      decoded = <String, dynamic>{'data': decoded};
    } else {
      final pretty = const JsonEncoder.withIndent('  ').convert(decoded);
      stdout.writeln(pretty.length > 4000 ? '${pretty.substring(0, 4000)}...' : pretty);
    }
    return decoded is Map<String, dynamic> ? decoded : Map<String, dynamic>.from(decoded as Map);
  }

  try {
    final loginRes = await post('/login', body: {
      'email': email,
      'password': password,
      'company_id': int.tryParse(companyId) ?? companyId,
    });
    final token = loginRes['token']?.toString() ??
        (loginRes['data'] is Map ? (loginRes['data'] as Map)['token']?.toString() : null);
    if (token == null || token.isEmpty) {
      stderr.writeln('Login failed — no token');
      exitCode = 1;
      return;
    }
    stdout.writeln('\nLogged in companyId=$companyId');

    final endpoints = <(String, Future<Map<String, dynamic>> Function())>[
      ('POST /products/brands/list {}', () => post('/products/brands/list', body: {}, token: token)),
      (
        'POST /products/brands/list datatable',
        () => post('/products/brands/list', body: {
          'rowLimit': 500,
          'rowOffset': 0,
          'columnKey': 'name',
          'columnSortedBy': 'asc',
        }, token: token),
      ),
      ('GET /products/brands', () => get('/products/brands', token: token)),
      ('GET /products/filter-options', () => get('/products/filter-options', token: token)),
      ('GET /products/supporting-data', () => get('/products/supporting-data', token: token)),
    ];

    for (final e in endpoints) {
      final res = await e.$2();
      final parsed = FilterOptionsParser.parseIdNameList(res, companyId: companyId);
      stdout.writeln('→ parseIdNameList count=${parsed.length}');
      if (parsed.isNotEmpty) {
        stdout.writeln('   sample: ${parsed.take(3).toList()}');
      }
      final parsedNoFilter = FilterOptionsParser.parseIdNameList(res);
      if (parsedNoFilter.length != parsed.length) {
        stdout.writeln('→ without company filter count=${parsedNoFilter.length}');
      }
    }
  } finally {
    client.close(force: true);
  }
}
