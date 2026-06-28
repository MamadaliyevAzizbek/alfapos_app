import 'dart:io';

import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/receipt_design_config.dart';
import '../utils/api_receipt_html_parser.dart';
import '../utils/thermal_bitmap.dart';
import 'api_service.dart';
import '../utils/thermal_receipt_formatter.dart';
import 'escpos_receipt_builder.dart';
import 'printer_settings.dart';
import 'receipt_design_storage.dart';
import 'raw_printer_send.dart';

/// Termal printer (Xprinter 80mm va h.k.) orqali chek chop etish.
class ThermalReceiptPrinter {
  ThermalReceiptPrinter._();

  static const _prefsPrinterKey = 'thermal_printer_name_v1';
  static String? _cachedPrinterName;

  static Future<String?> savedPrinterName() async {
    final cached = _cachedPrinterName?.trim();
    if (cached != null && cached.isNotEmpty) return cached;
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_prefsPrinterKey)?.trim();
    if (s == null || s.isEmpty) return null;
    _cachedPrinterName = s;
    return s;
  }

  static Future<void> clearSavedPrinter() async {
    _cachedPrinterName = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsPrinterKey);
  }

  static final _xprinterNamePatterns = [
    'xprinter',
    'xp-80',
    'xp80',
    '80c',
    'xp-58',
    'thermal',
  ];

  /// Mahalliy chek (dastur yig‘adi) — ESC/POS printerga yuborish.
  static Future<ThermalPrintResult> printLocalReceipt(
    List<String> lines, {
    bool directOnly = false,
    bool? openCashDrawer,
    ReceiptDesignConfig? design,
  }) async {
    if (lines.isEmpty) {
      return ThermalPrintResult.fail('Chek matni bo\'sh');
    }
    if (!Platform.isWindows && !Platform.isMacOS) {
      return ThermalPrintResult.fail(
        'Termal chop etish faqat Windows yoki macOS desktop ilovasida',
      );
    }
    return _printEscPosLines(
      lines,
      directOnly: directOnly,
      openCashDrawer: openCashDrawer,
      design: design,
    );
  }

  /// Sotuv / oldindan chek — faqat mahalliy qatorlar (server API ishlatilmaydi).
  static Future<ThermalPrintResult> printSaleReceipt({
    required List<String> localLines,
    bool directOnly = false,
    bool? openCashDrawer,
  }) =>
      printLocalReceipt(
        localLines,
        directOnly: directOnly,
        openCashDrawer: openCashDrawer,
      );

  /// Eski API HTML chek (faqat maxsus holatlar / debug; sotuvda ishlatilmaydi).
  static Future<ThermalPrintResult> printFromApiOrder(
    int orderId, {
    bool directOnly = false,
  }) async {
    try {
      final res = await ReportsApi.getOrderForPrint(orderId);
      final html = _extractThermalHtml(res);
      if (html == null || html.trim().isEmpty) {
        return ThermalPrintResult.fail('API termal chek HTML topilmadi');
      }

      final lines = ApiReceiptHtmlParser.toPrintLines(html);
      if (lines.isEmpty) {
        return ThermalPrintResult.fail('API chek matni bo\'sh');
      }

      if (Platform.isWindows || Platform.isMacOS) {
        final esc = await _printEscPosLines(lines, directOnly: directOnly);
        if (esc.ok) return esc;
      }

      return ThermalPrintResult.fail('Chek chop etib bo\'lmadi');
    } catch (e, st) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('[ThermalReceiptPrinter] API chek: $e\n$st');
      }
      return ThermalPrintResult.fail('API chek: $e');
    }
  }

  /// Chek chop etishdan oldin keshni tayyorlash.
  static Future<void> warmup() async {
    await Future.wait([
      ReceiptDesignStorage.load(),
      EscPosReceiptBuilder.warmup(),
      savedPrinterName(),
    ]);
  }

  static Future<ThermalPrintResult> _printEscPosLines(
    List<String> lines, {
    bool directOnly = false,
    bool? openCashDrawer,
    ReceiptDesignConfig? design,
  }) async {
    final totalSw = Stopwatch()..start();
    final bytes = await _buildEscPosBytes(
      lines,
      openCashDrawer: openCashDrawer,
      design: design,
    );
    final buildMs = totalSw.elapsedMilliseconds;
    final printer =
        await savedPrinterName() ?? await _resolveSystemPrinterName();
    if (printer == null || printer.isEmpty) {
      return ThermalPrintResult.fail(
        directOnly
            ? 'Printer tanlanmagan. Sozlamalar → printerni tanlang.'
            : 'Printer topilmadi',
      );
    }
    final result = await RawPrinterSend.send(bytes, printerName: printer);
    if (result.ok) {
      await rememberPrinterName(printer);
    }
    if (kDebugMode) {
      // ignore: avoid_print
      print(
        '[PrintPerf] printLocalReceipt build=${buildMs}ms send=${totalSw.elapsedMilliseconds - buildMs}ms total=${totalSw.elapsedMilliseconds}ms',
      );
    }
    return result;
  }

  /// Mahalliy widget skrinshoti (oldindan chek va h.k.).
  static Future<ThermalPrintResult> printPngBytes(
    Uint8List pngBytes, {
    bool directOnly = false,
  }) async {
    try {
      final bitmap = prepareThermalBitmap(pngBytes);

      if (Platform.isMacOS) {
        final lp = await _directPrintPngViaLp(bitmap);
        if (lp != null) return lp;
      }

      final pdfBytes = await _pngToRoll80Pdf(bitmap);
      final direct = await _directPrintPdf(pdfBytes);
      if (direct != null) return direct;

      if (directOnly) {
        return ThermalPrintResult.fail(
          'Printer topilmadi yoki chop etib bo\'lmadi. Sozlamalar → printerni tanlang.',
        );
      }

      await Printing.layoutPdf(
        onLayout: (_) async => pdfBytes,
        format: PdfPageFormat.roll80,
        name: 'AlfaPos chek',
      );
      return ThermalPrintResult.ok('Chop etish oynasi ochildi — printerni tanlang');
    } catch (e, st) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('[ThermalReceiptPrinter] $e\n$st');
      }
      return ThermalPrintResult.fail('Chop etib bo\'lmadi: $e');
    }
  }

  static Future<Uint8List> _pngToRoll80Pdf(Uint8List pngBytes) async {
    final doc = pw.Document();
    final image = pw.MemoryImage(pngBytes);
    final decoded = img.decodeImage(pngBytes);

    const marginH = 1 * PdfPageFormat.mm;
    const marginTop = 1 * PdfPageFormat.mm;
    const marginBottom = 2 * PdfPageFormat.mm;
    final rollWidth = PdfPageFormat.roll80.width;

    var pageHeight = PdfPageFormat.roll80.height;
    double imageWidthPt = rollWidth - marginH * 2;
    double imageHeightPt = pageHeight;

    if (decoded != null && decoded.width > 0 && decoded.height > 0) {
      imageWidthPt = rollWidth - marginH * 2;
      imageHeightPt = imageWidthPt * decoded.height / decoded.width;
      pageHeight = imageHeightPt + marginTop + marginBottom;
      pageHeight = pageHeight.clamp(40 * PdfPageFormat.mm, 1200 * PdfPageFormat.mm);
    }

    final format = PdfPageFormat(
      rollWidth,
      pageHeight,
      marginLeft: marginH,
      marginRight: marginH,
      marginTop: marginTop,
      marginBottom: marginBottom,
    );

    doc.addPage(
      pw.Page(
        pageFormat: format,
        build: (ctx) {
          return pw.SizedBox(
            width: imageWidthPt,
            height: imageHeightPt,
            child: pw.Image(
              image,
              width: imageWidthPt,
              height: imageHeightPt,
              fit: pw.BoxFit.fill,
            ),
          );
        },
      ),
    );
    return doc.save();
  }

  static Future<ThermalPrintResult?> _directPrintPngViaLp(Uint8List pngBytes) async {
    final printer = await _resolveSystemPrinterName();
    if (printer == null) return null;

    final file = File(
      '${Directory.systemTemp.path}/alfapos_receipt_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    await file.writeAsBytes(pngBytes);

    final result = await Process.run('lp', [
      '-d',
      printer,
      '-o',
      'fit-to-page',
      file.path,
    ]);

    if (result.exitCode == 0) {
      await rememberPrinterName(printer);
      return ThermalPrintResult.ok('Chek yuborildi ($printer)');
    }

    final retry = await Process.run('lp', ['-d', printer, file.path]);
    if (retry.exitCode == 0) {
      await rememberPrinterName(printer);
      return ThermalPrintResult.ok('Chek yuborildi ($printer)');
    }
    return null;
  }

  static Future<ThermalPrintResult?> _directPrintPdf(Uint8List pdfBytes) async {
    final printer = await _resolvePrinter();
    if (printer == null) return null;
    final ok = await Printing.directPrintPdf(
      printer: printer,
      onLayout: (_) async => pdfBytes,
      format: PdfPageFormat.roll80,
    );
    if (ok) {
      return ThermalPrintResult.ok('Chek printerga yuborildi (${printer.name})');
    }
    return null;
  }

  static Future<List<String>> discoverPrinterNames() async {
    final names = <String>{};
    try {
      for (final p in await Printing.listPrinters()) {
        if (p.name.trim().isNotEmpty) names.add(p.name.trim());
      }
    } catch (_) {}

    final system = await _listSystemPrinterNames();
    names.addAll(system);
    final list = names.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  static Future<List<String>> _listSystemPrinterNames() async {
    final names = <String>[];
    if (Platform.isMacOS) {
      final result = await Process.run('lpstat', ['-p']);
      if (result.exitCode == 0) {
        for (final line in result.stdout.toString().split('\n')) {
          final match = RegExp(r'^printer\s+(\S+)', caseSensitive: false).firstMatch(line);
          if (match != null) names.add(match.group(1)!);
        }
      }
    }
    if (Platform.isWindows) {
      final result = await Process.run(
        'powershell',
        ['-NoProfile', '-Command', 'Get-Printer | Select-Object -ExpandProperty Name'],
      );
      if (result.exitCode == 0) {
        for (final line in result.stdout.toString().split('\n')) {
          final n = line.trim();
          if (n.isNotEmpty) names.add(n);
        }
      }
    }
    return names;
  }

  static Future<List<int>> _buildEscPosBytes(
    List<String> lines, {
    bool? openCashDrawer,
    ReceiptDesignConfig? design,
  }) async {
    final settings = await Future.wait([
      design != null ? Future.value(design) : ReceiptDesignStorage.load(),
      openCashDrawer != null
          ? Future<bool>.value(openCashDrawer)
          : PrinterSettings.isCashDrawerOpenOnPrintEnabled(),
      PrinterSettings.cashDrawerPin(),
      PrinterSettings.selectedPrinterName(),
    ]);
    final resolvedDesign = settings[0] as ReceiptDesignConfig;
    final drawerEnabled = settings[1] as bool;
    final drawerPin = settings[2] as CashDrawerPin;
    final printerName = settings[3] as String?;
    final posPin =
        drawerPin == CashDrawerPin.pin5 ? PosDrawer.pin5 : PosDrawer.pin2;

    return EscPosReceiptBuilder.buildReceipt(
      lines: lines,
      design: resolvedDesign,
      openCashDrawer: drawerEnabled,
      cashDrawerPin: posPin,
      compactRestaurant: ThermalReceiptFormatter.hasRestaurantQueueLine(lines),
      printerName: printerName,
    );
  }

  static Future<ThermalPrintResult> printTestReceipt() async {
    return _printEscPosLines(
      [
        '^AlfaPOS',
        'Printer testi',
        'Do\'kon — O\'zbekiston noni',
        'Jami: 125 000 so\'m',
        DateTime.now().toString().substring(0, 19),
      ],
      directOnly: true,
      openCashDrawer: false,
    );
  }

  static Future<Printer?> _resolvePrinter() async {
    final printers = await Printing.listPrinters();
    if (printers.isEmpty) return null;

    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsPrinterKey)?.trim();
    if (saved != null && saved.isNotEmpty) {
      for (final p in printers) {
        if (p.name == saved) return p;
      }
    }

    for (final pattern in _xprinterNamePatterns) {
      for (final p in printers) {
        if (p.name.toLowerCase().contains(pattern)) return p;
      }
    }

    return printers.first;
  }

  static Future<void> rememberPrinterName(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    if (_cachedPrinterName == trimmed) return;
    _cachedPrinterName = trimmed;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsPrinterKey, trimmed);
  }

  /// API javobidan termal chek HTML (sozlamalar ko‘rinishi uchun ham).
  static ThermalHtmlExtract? thermalHtmlFromOrderResponse(Map<String, dynamic> res) {
    final template = res['templateData'];
    if (template is Map) {
      final content = template['content'];
      if (content != null && content.toString().trim().isNotEmpty) {
        return ThermalHtmlExtract(
          html: content.toString(),
          source: 'templateData.content',
        );
      }
    }
    final large = res['largeInvoiceView'];
    if (large != null && large.toString().trim().isNotEmpty) {
      return ThermalHtmlExtract(
        html: large.toString(),
        source: 'largeInvoiceView',
      );
    }
    return null;
  }

  static String? _extractThermalHtml(Map<String, dynamic> res) {
    return thermalHtmlFromOrderResponse(res)?.html;
  }

  static Future<String?> _resolveSystemPrinterName() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsPrinterKey);
    if (saved != null && saved.trim().isNotEmpty) return saved.trim();

    if (Platform.isMacOS) {
      final result = await Process.run('lpstat', ['-p']);
      if (result.exitCode != 0) return null;
      final lines = result.stdout.toString().split('\n');
      for (final line in lines) {
        final lower = line.toLowerCase();
        if (!_lineMatchesPrinter(lower)) continue;
        final match = RegExp(r'^printer\s+(\S+)', caseSensitive: false).firstMatch(line);
        if (match != null) return match.group(1);
      }
    }

    if (Platform.isWindows) {
      final result = await Process.run(
        'powershell',
        ['-NoProfile', '-Command', 'Get-Printer | Select-Object -ExpandProperty Name'],
      );
      if (result.exitCode != 0) return null;
      for (final line in result.stdout.toString().split('\n')) {
        final name = line.trim();
        if (name.isEmpty) continue;
        if (_lineMatchesPrinter(name.toLowerCase())) return name;
      }
    }
    return null;
  }

  static bool _lineMatchesPrinter(String lower) {
    for (final p in _xprinterNamePatterns) {
      if (lower.contains(p)) return true;
    }
    return false;
  }

  static int? orderIdFromStoreResponse(Map<String, dynamic>? res) {
    if (res == null) return null;
    final maps = <Map<String, dynamic>>[res];
    final data = res['data'];
    if (data is Map) maps.add(Map<String, dynamic>.from(data));
    final order = res['order'];
    if (order is Map) maps.add(Map<String, dynamic>.from(order));

    const orderKeys = ['order_id', 'orderId', 'orderID'];
    for (final map in maps) {
      for (final k in orderKeys) {
        final v = map[k];
        if (v == null) continue;
        final n = v is int ? v : int.tryParse(v.toString());
        if (n != null && n > 0) return n;
      }
    }

    for (final map in maps) {
      final v = map['id'];
      if (v == null) continue;
      final n = v is int ? v : int.tryParse(v.toString());
      if (n != null && n > 0) return n;
    }
    return null;
  }

  static Future<int?> resolveOrderId({
    required String receiptId,
    int? storeOrderId,
  }) async {
    if (storeOrderId != null && storeOrderId > 0) return storeOrderId;

    final trimmed = receiptId.trim();
    final numericOnly = int.tryParse(trimmed);
    if (numericOnly != null && numericOnly > 0) return numericOnly;

    try {
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final res = await ReportsApi.getSales(
        body: ReportsApi.salesListBody(
          from: today,
          to: today,
          rowLimit: 24,
          rowOffset: 0,
          columnKey: 'id',
          columnSortedBy: 'DESC',
        ),
      );
      final rows = res['datarows'] as List<dynamic>? ?? res['data'] as List<dynamic>? ?? [];
      final targets = {
        trimmed.toLowerCase(),
        trimmed.replaceFirst(RegExp(r'^pos', caseSensitive: false), '').toLowerCase(),
        if (!trimmed.toLowerCase().startsWith('pos')) 'pos${trimmed.toLowerCase()}',
      };
      for (final r in rows) {
        if (r is! Map) continue;
        final m = Map<String, dynamic>.from(r);
        final inv = (m['invoice_id'] ?? m['invoiceId'] ?? '').toString().trim().toLowerCase();
        if (inv.isEmpty || inv.contains('umumiy')) continue;
        if (targets.contains(inv)) {
          final id = m['id'] ?? m['order_id'];
          final n = id is int ? id : int.tryParse(id?.toString() ?? '');
          if (n != null && n > 0) return n;
        }
      }
    } catch (_) {}
    return null;
  }
}

class ThermalHtmlExtract {
  final String html;
  final String source;

  const ThermalHtmlExtract({required this.html, required this.source});
}

class ThermalPrintResult {
  final bool ok;
  final String message;

  const ThermalPrintResult._(this.ok, this.message);

  factory ThermalPrintResult.ok(String message) => ThermalPrintResult._(true, message);
  factory ThermalPrintResult.fail(String message) => ThermalPrintResult._(false, message);
}
