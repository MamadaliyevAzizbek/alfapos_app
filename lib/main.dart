import 'dart:io' show HttpOverrides, Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app.dart';
import 'core/api_http.dart';
import 'core/desktop_runtime.dart';
import 'services/receipt_design_storage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await ReceiptDesignStorage.load();
  } catch (_) {}
  if (!kIsWeb && isDesktopNative) {
    HttpOverrides.global = AlfaposHttpOverrides();
    // SSL zanjiri — faqat Windows (macOS da keraksiz HEAD so‘rovini olib tashlash)
    if (Platform.isWindows) {
      await ApiHttp.warmUp();
    }
  }
  if (!kIsWeb && Platform.isAndroid) {
    // Android 15+ edge-to-edge (SDK 35) — insetlar SafeArea / AppBar orqali
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
}
