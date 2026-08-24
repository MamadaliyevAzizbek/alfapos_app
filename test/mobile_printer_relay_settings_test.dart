import 'package:alfapos_app/services/mobile_printer_relay_settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    MobilePrinterRelaySettings.enabled.value = true;
    await MobilePrinterRelaySettings.setEnabled(true);
    await MobilePrinterRelaySettings.setPort(MobilePrinterRelaySettings.defaultPort);
  });

  test('default relay enabled and port 9100', () async {
    expect(await MobilePrinterRelaySettings.isEnabled(), isTrue);
    expect(await MobilePrinterRelaySettings.getPort(), 9100);
  });

  test('port clamps to valid range', () async {
    await MobilePrinterRelaySettings.setPort(80);
    expect(await MobilePrinterRelaySettings.getPort(), 1024);
    await MobilePrinterRelaySettings.setPort(70000);
    expect(await MobilePrinterRelaySettings.getPort(), 65535);
  });

  test('settings persist', () async {
    await MobilePrinterRelaySettings.setEnabled(false);
    await MobilePrinterRelaySettings.setPort(9200);
    expect(await MobilePrinterRelaySettings.isEnabled(), isFalse);
    expect(await MobilePrinterRelaySettings.getPort(), 9200);
  });
}
