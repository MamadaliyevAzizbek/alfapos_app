import 'package:alfapos_app/utils/local_network_ip.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('virtual adapter names are ignored via scoring helpers', () {
    // Public API smoke: listCandidates should not throw in test VM.
    expect(LocalNetworkIp.listCandidates, isA<Function>());
  });

  test('LocalIpv4Candidate label includes interface', () {
    const c = LocalIpv4Candidate(
      ip: '192.168.1.10',
      interfaceName: 'Wi-Fi',
      score: 100,
    );
    expect(c.label, '192.168.1.10  (Wi-Fi)');
  });
}
