import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

/// Windows / macOS / Linux POS — mobil kamera ruxsati kerak emas.
bool get isDesktopNative {
  if (kIsWeb) return false;
  return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
}

/// Windows firewall va tarmoq yordam matni (login xatolarida).
String windowsNetworkHelpText({String? detail}) {
  final buf = StringBuffer()
    ..writeln('Windows tarmoq yordami:')
    ..writeln('1. «Boshqaruv paneli» → «Windows Defender Firewall» → «Ilova ruxsatlari»')
    ..writeln('2. «Alfapos» yoki «alfapos_app» uchun «Private» va «Public» tarmoqni yoqing')
    ..writeln('3. Antivirus / VPN / korporativ proksi vaqtincha o‘chirib sinab ko‘ring')
    ..writeln('4. Kompyuter vaqti to‘g‘ri ekanligini tekshiring (SSL uchun muhim)');
  if (detail != null && detail.trim().isNotEmpty) {
    buf.writeln('\nTexnik: $detail');
  }
  return buf.toString().trim();
}

/// Windows: mahsulot rasmi — fayl tanlash (kamera ishlamaydi).
String desktopImagePickHelpText() =>
    'Kompyuterdan rasm faylini tanlang (.jpg, .jpeg, .png). '
    'Agar oyna ochilmasa, antivirus yoki «Controlled folder access» Alfapos ilovasiga ruxsat bering.';

/// Windows: printer — tizim printeri o‘rnatilgan bo‘lishi kerak.
String desktopPrinterHelpText() =>
    'Printer «Sozlamalar» bo‘limida tanlanadi. Windows «Parametrlar» → «Bluetooth va qurilmalar» → '
    '«Printerni qo‘shish» orqali Xprinter / termal printerni o‘rnating, keyin Alfaposda tanlang.';
