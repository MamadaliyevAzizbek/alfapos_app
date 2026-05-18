// Desktop login API tekshiruvi: dart run tool/login_api_probe.dart
import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> args) async {
  final email = args.isNotEmpty ? args[0] : 'murod';
  final password = args.length > 1 ? args[1] : 'wrong';
  final companyId = args.length > 2 ? int.tryParse(args[2]) ?? 1 : 1;

  final uri = Uri.parse('https://app.alfapos.uz/api/v1/login');
  final body = jsonEncode({
    'email': email,
    'password': password,
    'company_id': companyId,
  });

  stdout.writeln('POST $uri');
  stdout.writeln('Body: $body');

  final client = HttpClient();
  client.connectionTimeout = const Duration(seconds: 30);

  try {
    final req = await client.postUrl(uri);
    req.headers.set('Content-Type', 'application/json');
    req.headers.set('Accept', 'application/json');
    req.write(body);
    final res = await req.close();
    final text = await res.transform(utf8.decoder).join();
    stdout.writeln('Status: ${res.statusCode}');
    stdout.writeln('Response: $text');
  } catch (e, st) {
    stderr.writeln('XATO: $e');
    stderr.writeln(st);
    exitCode = 1;
  } finally {
    client.close(force: true);
  }
}
