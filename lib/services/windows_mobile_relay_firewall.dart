import 'dart:io';

import 'package:flutter/foundation.dart';

/// Windows: telefon → Mobil relay uchun inbound TCP 9100 firewall qoidasi.
class WindowsMobileRelayFirewall {
  WindowsMobileRelayFirewall._();

  /// Admin PowerShell orqali firewall skriptini ishga tushirish.
  /// Foydalanuvchi UAC so‘rovini tasdiqlashi kerak.
  static Future<({bool ok, String message})> openInboundRelay({
    int port = 9100,
  }) async {
    if (!Platform.isWindows) {
      return (ok: false, message: 'Faqat Windows uchun');
    }

    final exePath = Platform.resolvedExecutable;
    final script = _resolveFirewallScript();
    if (script == null) {
      return (
        ok: false,
        message:
            'Firewall skripti topilmadi. Setup orqali qayta o‘rnating '
            '(firewall belgisini yoqing) yoki allow_alfapos_firewall.ps1 ni '
            'Administrator sifatida ishga tushiring.',
      );
    }

    try {
      final scriptPath = script.path.replaceAll("'", "''");
      final exeEscaped = exePath.replaceAll("'", "''");
      final argList =
          "'-NoProfile','-ExecutionPolicy','Bypass','-File','$scriptPath',"
          "'-ExePath','$exeEscaped','-RelayPort','$port'";
      final result = await Process.run(
        'powershell',
        [
          '-NoProfile',
          '-ExecutionPolicy',
          'Bypass',
          '-Command',
          'Start-Process -FilePath powershell -Verb RunAs -Wait '
              '-ArgumentList @($argList)',
        ],
      );
      if (result.exitCode == 0) {
        return (
          ok: true,
          message:
              'Firewall so‘rovi yuborildi. UAC da «Ha» bosing. '
              'Keyin telefonda yana «Ulanishni tekshirish»ni bosing.',
        );
      }
      final err = '${result.stderr}${result.stdout}'.trim();
      return (
        ok: false,
        message: err.isEmpty
            ? 'Firewall ochilmadi (kod ${result.exitCode}). Administrator huquqi kerak.'
            : err,
      );
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('[WindowsMobileRelayFirewall] $e');
      }
      return (ok: false, message: 'Firewall: $e');
    }
  }

  static File? _resolveFirewallScript() {
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final sep = Platform.pathSeparator;
    final candidates = <String>[
      '$exeDir${sep}allow_alfapos_firewall.ps1',
      '${Directory.current.path}${sep}windows${sep}scripts${sep}allow_alfapos_firewall.ps1',
      '${Directory.current.path}${sep}allow_alfapos_firewall.ps1',
    ];
    for (final p in candidates) {
      final f = File(p);
      if (f.existsSync()) return f;
    }
    return null;
  }
}
