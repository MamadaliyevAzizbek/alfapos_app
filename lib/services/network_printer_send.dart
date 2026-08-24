import 'dart:async';
import 'dart:io';

import 'thermal_print_result.dart';

/// ESC/POS baytlarini WiFi printerga TCP orqali yuborish (port 9100).
class NetworkPrinterSend {
  NetworkPrinterSend._();

  static const Duration defaultTimeout = Duration(seconds: 8);

  static Future<ThermalPrintResult> send(
    List<int> bytes, {
    required String host,
    required int port,
    Duration timeout = defaultTimeout,
  }) async {
    final h = host.trim();
    if (h.isEmpty) {
      return ThermalPrintResult.fail('Printer IP manzili kiritilmagan');
    }
    if (bytes.isEmpty) {
      return ThermalPrintResult.fail('Yuboriladigan ma\'lumot bo\'sh');
    }

    Socket? socket;
    try {
      socket = await Socket.connect(h, port, timeout: timeout);
      socket.add(bytes);
      await socket.flush();
      await socket.close();
      return ThermalPrintResult.ok('Chek yuborildi ($h:$port)');
    } on SocketException catch (e) {
      return ThermalPrintResult.fail(_friendlySocketError(e, h, port));
    } on TimeoutException {
      return ThermalPrintResult.fail(
        'Printer javob bermadi ($h:$port). WiFi va IP ni tekshiring.',
      );
    } catch (e) {
      return ThermalPrintResult.fail('Printerga yuborib bo\'lmadi: $e');
    } finally {
      socket?.destroy();
    }
  }

  /// Ulanishni tekshirish — qisqa TCP handshake.
  static Future<ThermalPrintResult> testConnection({
    required String host,
    required int port,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final h = host.trim();
    if (h.isEmpty) {
      return ThermalPrintResult.fail('IP manzil kiritilmagan');
    }

    Socket? socket;
    try {
      socket = await Socket.connect(h, port, timeout: timeout);
      await socket.close();
      return ThermalPrintResult.ok('Printerga ulandi ($h:$port)');
    } on SocketException catch (e) {
      return ThermalPrintResult.fail(_friendlySocketError(e, h, port));
    } on TimeoutException {
      return ThermalPrintResult.fail(
        'Ulanish vaqti tugadi. Telefon va printer bir xil WiFi da ekanini tekshiring.',
      );
    } catch (e) {
      return ThermalPrintResult.fail('Ulanib bo\'lmadi: $e');
    } finally {
      socket?.destroy();
    }
  }

  static String _friendlySocketError(SocketException e, String host, int port) {
    final msg = e.message.toLowerCase();
    if (msg.contains('network is unreachable') ||
        msg.contains('no route to host') ||
        msg.contains('host is down')) {
      return 'Printer topilmadi ($host:$port). '
          'Telefon va printer bir xil WiFi tarmog‘ida ekanini tekshiring.';
    }
    if (msg.contains('connection refused')) {
      return 'Printer porti yopiq ($host:$port). '
          'Port odatda 9100 bo‘ladi — printer sozlamalarini tekshiring.';
    }
    if (msg.contains('connection timed out')) {
      return 'Ulanish vaqti tugadi ($host:$port). IP manzil to‘g‘riligini tekshiring.';
    }
    return 'Printerga ulanib bo\'lmadi ($host:$port): ${e.message}';
  }
}
