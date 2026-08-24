import 'dart:async';
import 'dart:io' show HttpOverrides, Platform;

import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'core/api_http.dart';
import 'core/desktop_runtime.dart';
import 'services/mobile_printer_relay.dart';
import 'services/mobile_printer_relay_settings.dart';
import 'services/network_printer_settings.dart';
import 'services/printer_settings.dart';
import 'services/receipt_design_storage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final isMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  // Desktop: chek dizayni kerak. Mobil: runApp dan keyin fon rejimida.
  if (!isMobile) {
    try {
      await ReceiptDesignStorage.load();
    } catch (_) {}
  }

  if (!kIsWeb && isDesktopNative) {
    HttpOverrides.global = AlfaposHttpOverrides();
    if (Platform.isWindows) {
      await ApiHttp.warmUp();
    }
    if (Platform.isWindows || Platform.isMacOS) {
      await PrinterSettings.preload();
      await MobilePrinterRelaySettings.load();
      await MobilePrinterRelay.sync();
    }
  }

  if (!kIsWeb && Platform.isAndroid) {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const AlfaposApp());

  if (isMobile) {
    unawaited(NetworkPrinterSettings.load());
    unawaited(_warmMobileCaches());
  }

  _scheduleUnattendedMobilePrintSelfTest();
}

Future<void> _warmMobileCaches() async {
  try {
    await ReceiptDesignStorage.load();
  } catch (_) {}
}

Future<void> _scheduleUnattendedMobilePrintSelfTest() async {
  if (kIsWeb || !Platform.isIOS) return;
  const runTest = bool.fromEnvironment('AUTO_TEST_PRINT');
  if (!runTest) return;
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    await Future<void>.delayed(const Duration(seconds: 8));
    try {
      const hostEnv = String.fromEnvironment('ALFAPOS_PRINTER_HOST');
      if (hostEnv.trim().isNotEmpty && NetworkPrinterSettings.isValidHost(hostEnv)) {
        await NetworkPrinterSettings.setEnabled(true);
        await NetworkPrinterSettings.setHost(hostEnv.trim());
        await NetworkPrinterSettings.setPort(NetworkPrinterSettings.defaultPort);
        await NetworkPrinterSettings.setMode(NetworkPrinterMode.computerRelay);
      }
      await NetworkPrinterSettings.load();
      await PrinterSettings.preload();
      final result = await PrinterSettings.testPrint();
      if (kDebugMode) {
        // ignore: avoid_print
        print('[AutoTestPrint] ${result.ok ? "OK" : "FAIL"}: ${result.message}');
      }
    } catch (e, st) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('[AutoTestPrint] error: $e\n$st');
      }
    }
  });
}
