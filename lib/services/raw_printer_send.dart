import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'thermal_receipt_printer.dart';

/// ESC/POS baytlarini tizim printeriga RAW rejimda yuborish.
class RawPrinterSend {
  RawPrinterSend._();

  static Future<ThermalPrintResult> send(
    List<int> bytes, {
    required String printerName,
  }) async {
    if (printerName.trim().isEmpty) {
      return ThermalPrintResult.fail('Printer nomi tanlanmagan');
    }
    try {
      if (Platform.isWindows) {
        return _sendWindows(bytes, printerName.trim());
      }
      if (Platform.isMacOS) {
        return _sendMac(bytes, printerName.trim());
      }
      return ThermalPrintResult.fail('RAW chop etish faqat Windows/macOS');
    } catch (e, st) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('[RawPrinterSend] $e\n$st');
      }
      return ThermalPrintResult.fail('RAW chop etish: $e');
    }
  }

  static Future<ThermalPrintResult> _sendWindows(List<int> bytes, String printer) async {
    final file = File(
      '${Directory.systemTemp.path}\\alfapos_esc_${DateTime.now().millisecondsSinceEpoch}.bin',
    );
    await file.writeAsBytes(bytes);
    final b64 = base64Encode(bytes);
    final escapedPrinter = printer.replaceAll("'", "''");
    final ps = r'''
Add-Type -Language CSharp -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class AlfaPosRawPrint {
  [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)]
  public struct DOCINFO {
    [MarshalAs(UnmanagedType.LPWStr)] public string pDocName;
    [MarshalAs(UnmanagedType.LPWStr)] public string pOutputFile;
    [MarshalAs(UnmanagedType.LPWStr)] public string pDatatype;
  }
  [DllImport("winspool.drv", CharSet=CharSet.Unicode, SetLastError=true)]
  public static extern bool OpenPrinter(string p, out IntPtr h, IntPtr d);
  [DllImport("winspool.drv", SetLastError=true)]
  public static extern bool ClosePrinter(IntPtr h);
  [DllImport("winspool.drv", CharSet=CharSet.Unicode, SetLastError=true)]
  public static extern bool StartDocPrinter(IntPtr h, int lvl, ref DOCINFO di);
  [DllImport("winspool.drv", SetLastError=true)]
  public static extern bool EndDocPrinter(IntPtr h);
  [DllImport("winspool.drv", SetLastError=true)]
  public static extern bool StartPagePrinter(IntPtr h);
  [DllImport("winspool.drv", SetLastError=true)]
  public static extern bool EndPagePrinter(IntPtr h);
  [DllImport("winspool.drv", SetLastError=true)]
  public static extern bool WritePrinter(IntPtr h, byte[] b, int c, out int w);
  public static bool Send(string printer, byte[] data) {
    IntPtr h;
    if (!OpenPrinter(printer, out h, IntPtr.Zero)) return false;
    var di = new DOCINFO { pDocName = "AlfaPOS", pDatatype = "RAW" };
    if (!StartDocPrinter(h, 1, ref di)) { ClosePrinter(h); return false; }
    if (!StartPagePrinter(h)) { EndDocPrinter(h); ClosePrinter(h); return false; }
    int written;
  WritePrinter(h, data, data.Length, out written);
    EndPagePrinter(h);
    EndDocPrinter(h);
    ClosePrinter(h);
    return written > 0;
  }
}
"@
$bytes = [Convert]::FromBase64String('__B64__')
$ok = [AlfaPosRawPrint]::Send('__PRINTER__', $bytes)
if ($ok) { exit 0 } else { exit 1 }
'''
        .replaceAll('__B64__', b64)
        .replaceAll('__PRINTER__', escapedPrinter);

    final result = await Process.run(
      'powershell',
      ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', ps],
    );
    if (result.exitCode == 0) {
      return ThermalPrintResult.ok('Chek yuborildi ($printer)');
    }
    final err = '${result.stderr}'.trim();
    return ThermalPrintResult.fail(
      err.isEmpty ? 'Windows RAW chop etib bo\'lmadi. Printerni tekshiring.' : err,
    );
  }

  static Future<ThermalPrintResult> _sendMac(List<int> bytes, String printer) async {
    final file = File(
      '${Directory.systemTemp.path}/alfapos_esc_${DateTime.now().millisecondsSinceEpoch}.bin',
    );
    await file.writeAsBytes(bytes);
    var result = await Process.run('lp', ['-d', printer, '-o', 'raw', file.path]);
    if (result.exitCode == 0) {
      return ThermalPrintResult.ok('Chek yuborildi ($printer)');
    }
    result = await Process.run('lp', ['-d', printer, file.path]);
    if (result.exitCode == 0) {
      return ThermalPrintResult.ok('Chek yuborildi ($printer)');
    }
    return ThermalPrintResult.fail('lp xato: ${result.stderr}');
  }
}
