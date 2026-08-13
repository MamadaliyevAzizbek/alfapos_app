import 'package:alfapos_app/core/api_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('404 HTML is treated as not found, not proxy noise for UI', () {
    final e = ApiException('Topilmadi', 404);
    expect(e.isNotFound, isTrue);
    expect(e.isNonJsonOrProxyNoise, isFalse);
  });

  test('legacy proxy HTML message is flagged as noise', () {
    final e = ApiException(
      'Tarmoq/proksi JSON o‘rniga boshqa javob qaytardi (kod 404). '
      'Antivirus «HTTPS scanning», VPN yoki Windows proksini o‘chirib qayta urinib ko‘ring.',
      404,
    );
    expect(e.isNotFound, isTrue);
    expect(e.isNonJsonOrProxyNoise, isTrue);
  });
}
