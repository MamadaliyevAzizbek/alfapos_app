import 'dart:io' show HttpOverrides;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app.dart';
import 'core/api_http.dart';
import 'core/desktop_runtime.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb && isDesktopNative) {
    HttpOverrides.global = AlfaposHttpOverrides();
    // Windows: SSL/proksi zanjirini login oldidan tayyorlash
    await ApiHttp.warmUp();
  }
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const AlfaposApp());
}
