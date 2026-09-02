import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../models/barcode_label_config.dart';
import '../models/product.dart';
import 'barcode_label_tspl_builder.dart';
import 'network_printer_send.dart';
import 'network_printer_settings.dart';
import 'printer_settings.dart';
import 'raw_printer_send.dart';
import 'thermal_print_result.dart';

/// Shtrix kod yorlig‘ini printerga yuborish (native TSPL — tez, aniq).
class BarcodeLabelPrinter {
  BarcodeLabelPrinter._();

  static bool get _supportsNetworkPrint =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// Faqat bazadagi shtrix kod (SKU / PLU o‘rniga yorliq chiqarilmaydi).
  static String? resolvePrintCode(Product product) {
    final barcode = product.barcode?.trim();
    if (barcode != null && barcode.isNotEmpty) return barcode;
    final extra = product.additionalBarcodes;
    if (extra != null) {
      for (final raw in extra) {
        final code = raw.trim();
        if (code.isNotEmpty) return code;
      }
    }
    return null;
  }

  static Future<ThermalPrintResult> printLabels(
    Product product,
    BarcodeLabelConfig config,
  ) async {
    final code = resolvePrintCode(product);
    if (code == null) {
      return ThermalPrintResult.fail('Mahsulotda shtrix kod yo\'q');
    }

    final cfg = config.normalized();

    if (cfg.template == BarcodeLabelTemplate.shopName && cfg.shopName.isEmpty) {
      return ThermalPrintResult.fail('Do‘kon nomini kiriting');
    }

    final tspl = await BarcodeLabelTsplBuilder.buildNative(
      product: product,
      barcode: code,
      config: cfg,
    );

    final result = await _sendTspl(tspl);
    if (!result.ok) return result;

    final n = cfg.copies;
    return ThermalPrintResult.ok(
      n == 1 ? 'Yorliq chop etildi' : '$n ta yorliq chop etildi',
    );
  }

  /// Bir nechta mahsulot yorliqlarini ketma-ket bitta buyruqda yuborish.
  static Future<ThermalPrintResult> printQueue(
    List<({Product product, BarcodeLabelConfig config})> jobs,
  ) async {
    if (jobs.isEmpty) {
      return ThermalPrintResult.fail('Chop etish uchun mahsulot yo‘q');
    }

    final out = BytesBuilder(copy: false);
    var totalCopies = 0;
    for (final job in jobs) {
      final code = resolvePrintCode(job.product);
      if (code == null) {
        return ThermalPrintResult.fail(
          '«${job.product.name}» da shtrix kod yo‘q',
        );
      }
      final cfg = job.config.normalized();
      if (cfg.template == BarcodeLabelTemplate.shopName && cfg.shopName.isEmpty) {
        return ThermalPrintResult.fail(
          '«${job.product.name}» uchun do‘kon nomini kiriting',
        );
      }
      out.add(
        await BarcodeLabelTsplBuilder.buildNative(
          product: job.product,
          barcode: code,
          config: cfg,
        ),
      );
      totalCopies += cfg.copies;
    }

    final result = await _sendTspl(out.toBytes());
    if (!result.ok) return result;
    return ThermalPrintResult.ok(
      totalCopies == 1
          ? 'Yorliq chop etildi'
          : '$totalCopies ta yorliq chop etildi',
    );
  }

  static Future<ThermalPrintResult> _sendTspl(Uint8List tspl) async {
    if (_supportsNetworkPrint && await NetworkPrinterSettings.isConfigured()) {
      final endpoint = await NetworkPrinterSettings.activeEndpoint();
      if (endpoint == null) {
        return ThermalPrintResult.fail(
          'WiFi printer sozlanmagan. Menyu → Printer sozlamalari.',
        );
      }
      return NetworkPrinterSend.send(
        tspl,
        host: endpoint.host,
        port: endpoint.port,
        waitForRelayAck:
            await NetworkPrinterSettings.usesComputerRelay(),
      );
    }

    if (Platform.isMacOS || Platform.isWindows) {
      final printer = await PrinterSettings.barcodeLabelPrinterName();
      if (printer == null || printer.isEmpty) {
        return ThermalPrintResult.fail(
          'Shtrix kod printeri sozlanmagan. '
          'Sozlamalar → Termal printer → Shtrix kod printerini tanlang.',
        );
      }
      return RawPrinterSend.send(tspl, printerName: printer);
    }

    return ThermalPrintResult.fail(
      'Shtrix kod printeri sozlanmagan. '
      'Sozlamalar → Termal printer → Shtrix kod printerini tanlang.',
    );
  }
}
