import 'package:alfapos_app/services/network_printer_settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await NetworkPrinterSettings.setEnabled(false);
    await NetworkPrinterSettings.setHost(null);
    await NetworkPrinterSettings.setPort(NetworkPrinterSettings.defaultPort);
  });

  test('default port is 9100', () async {
    expect(await NetworkPrinterSettings.getPort(), 9100);
  });

  test('host validation accepts ipv4 and hostname', () {
    expect(NetworkPrinterSettings.isValidHost('192.168.1.100'), isTrue);
    expect(NetworkPrinterSettings.isValidHost('xprinter.local'), isTrue);
    expect(NetworkPrinterSettings.isValidHost(''), isFalse);
    expect(NetworkPrinterSettings.isValidHost('999.999.1.1'), isFalse);
  });

  test('settings persist', () async {
    await NetworkPrinterSettings.setEnabled(true);
    await NetworkPrinterSettings.setHost('192.168.0.55');
    await NetworkPrinterSettings.setPort(9100);
    expect(await NetworkPrinterSettings.isConfigured(), isTrue);
    expect(await NetworkPrinterSettings.getHost(), '192.168.0.55');
    expect(await NetworkPrinterSettings.getPort(), 9100);
  });

  test('port clamps to valid range', () async {
    await NetworkPrinterSettings.setPort(0);
    expect(await NetworkPrinterSettings.getPort(), 1);
    await NetworkPrinterSettings.setPort(99999);
    expect(await NetworkPrinterSettings.getPort(), 65535);
  });
}
