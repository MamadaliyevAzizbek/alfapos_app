import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'mobile_printer_relay_settings.dart';
import 'printer_settings.dart';
import 'raw_printer_send.dart';
import 'thermal_print_result.dart';
import '../utils/label_lp_print.dart';

/// Desktop: telefon ESC/POS → kompyuter TCP → USB termal printer.
class MobilePrinterRelay {
  MobilePrinterRelay._();

  static ServerSocket? _server;
  static bool _running = false;
  static int? _activePort;

  static bool get isRunning => _running;
  static int? get activePort => _activePort;
  static String? lastError;

  /// Sozlamalar bo‘yicha relayni yoqish yoki o‘chirish.
  static Future<void> sync() async {
    if (!Platform.isWindows && !Platform.isMacOS) {
      await stop();
      return;
    }
    if (!await MobilePrinterRelaySettings.isEnabled()) {
      await stop();
      return;
    }
    final port = await MobilePrinterRelaySettings.getPort();
    if (_running && _activePort == port) return;
    await stop();
    try {
      _server = await ServerSocket.bind(InternetAddress.anyIPv4, port, shared: true);
      _activePort = port;
      _running = true;
      lastError = null;
      _server!.listen(
        _handleClient,
        onError: (Object e) {
          if (kDebugMode) {
            // ignore: avoid_print
            print('[MobilePrinterRelay] server error: $e');
          }
        },
        cancelOnError: false,
      );
      if (kDebugMode) {
        // ignore: avoid_print
        print('[MobilePrinterRelay] listening on 0.0.0.0:$port');
      }
    } catch (e) {
      _running = false;
      _activePort = null;
      lastError = '$e';
      if (kDebugMode) {
        // ignore: avoid_print
        print('[MobilePrinterRelay] bind failed ($port): $e');
      }
    }
  }

  static Future<void> stop() async {
    final server = _server;
    _server = null;
    _running = false;
    _activePort = null;
    if (server != null) {
      try {
        await server.close();
      } catch (_) {}
    }
  }

  static void _handleClient(Socket socket) {
    final buffer = <int>[];
    socket.listen(
      (data) => buffer.addAll(data),
      onDone: () async {
        try {
          if (buffer.isEmpty) return;
          await PrinterSettings.preload();
          final isTspl = _looksLikeTspl(buffer);
          final name = isTspl
              ? await PrinterSettings.barcodeLabelPrinterName()
              : await PrinterSettings.selectedPrinterName();
          if (name == null || name.trim().isEmpty) {
            if (kDebugMode) {
              // ignore: avoid_print
              print(
                isTspl
                    ? '[MobilePrinterRelay] shtrix kod printeri tanlanmagan, ${buffer.length} bayt rad etildi'
                    : '[MobilePrinterRelay] printer tanlanmagan, ${buffer.length} bayt rad etildi',
              );
            }
            return;
          }
          final result = await _forwardBytes(buffer, name.trim());
          if (kDebugMode && !result.ok) {
            // ignore: avoid_print
            print('[MobilePrinterRelay] chop etish xato: ${result.message}');
          }
        } catch (e) {
          if (kDebugMode) {
            // ignore: avoid_print
            print('[MobilePrinterRelay] client xato: $e');
          }
        } finally {
          try {
            await socket.close();
          } catch (_) {
            socket.destroy();
          }
        }
      },
      onError: (_) {
        socket.destroy();
      },
      cancelOnError: true,
    );
  }

  static Future<ThermalPrintResult> _forwardBytes(
    List<int> bytes,
    String printerName,
  ) async {
    if (_isPng(bytes)) {
      return _sendPngViaLp(bytes, printerName);
    }
    return RawPrinterSend.send(bytes, printerName: printerName);
  }

  static bool _isPng(List<int> bytes) =>
      bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47;

  /// Native TSPL yorliq (SIZE … / CLS) — chek ESC/POS emas.
  static bool _looksLikeTspl(List<int> bytes) {
    if (bytes.length < 8) return false;
    final head = String.fromCharCodes(
      bytes.take(96).map((b) => (b >= 32 && b < 127) || b == 10 || b == 13 ? b : 32),
    ).toUpperCase();
    return head.contains('SIZE ') && head.contains('CLS');
  }

  static Future<ThermalPrintResult> _sendPngViaLp(
    List<int> bytes,
    String printer,
  ) async {
    final png = Uint8List.fromList(bytes);
    if (LabelLpPrint.looksLikeLabel(png)) {
      return LabelLpPrint.printPng(png, printer);
    }

    final file = File(
      '${Directory.systemTemp.path}/alfapos_relay_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    await file.writeAsBytes(bytes);
    var result = await Process.run('lp', ['-d', printer, '-o', 'fit-to-page', file.path]);
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
