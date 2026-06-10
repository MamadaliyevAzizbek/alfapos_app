import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/seller_preferences.dart';
import '../providers/sales_session_provider.dart';
import '../utils/receipt_row_builder.dart';
import '../utils/receipt_store_title.dart';
import '../models/receipt_design_config.dart';
import '../services/receipt_design_storage.dart';
import '../widgets/receipt_widget.dart';
import 'hold_order_cart.dart';
import 'hold_orders_response.dart';

class _SaveCancelled implements Exception {
  const _SaveCancelled();
}

class HoldOrderExcelData {
  final List<int> bytes;
  final String fileName;
  final String receiptNumber;

  const HoldOrderExcelData({
    required this.bytes,
    required this.fileName,
    required this.receiptNumber,
  });
}

class HoldOrderExcelExportResult {
  final bool ok;
  final String message;
  final bool cancelled;

  const HoldOrderExcelExportResult._(this.ok, this.message, {this.cancelled = false});

  factory HoldOrderExcelExportResult.ok(String message) =>
      HoldOrderExcelExportResult._(true, message);

  factory HoldOrderExcelExportResult.fail(String message) =>
      HoldOrderExcelExportResult._(false, message);

  factory HoldOrderExcelExportResult.cancelled() =>
      const HoldOrderExcelExportResult._(false, '', cancelled: true);
}

/// Saqlangan buyurtma oldindan chekini Excel (.xls) formatida yuklab olish.
class HoldOrderPrecheckExcelExport {
  HoldOrderPrecheckExcelExport._();

  /// API va savat ma'lumotlaridan Excel fayl baytlarini tayyorlash.
  static Future<({HoldOrderExcelData? data, String? error})> buildHoldOrderExcel(
    Map<String, dynamic> hold,
  ) async {
    try {
      final resumeFuture = HoldOrderCart.fetchResumeForPrint(hold);
      final designFuture = ReceiptDesignStorage.load();
      final sellerNameFuture = getSellerName();
      final sellerPhoneFuture = getSellerPhone();

      final resume = await resumeFuture;
      if (resume == null || resume.items.isEmpty) {
        return (data: null, error: 'Savat bo\'sh yoki yuklanmadi');
      }

      final results = await Future.wait([
        designFuture,
        sellerNameFuture,
        sellerPhoneFuture,
      ]);
      final design = results[0] as ReceiptDesignConfig;
      final seller = results[1] as String;
      final sellerPhone = results[2] as String?;

      final raw = resume.items.fold<int>(0, (s, e) => s + e.total);
      final total = _resolveGrandTotal(raw, resume);
      final client = resume.customer;
      final receiptNumber = _receiptLabel(hold, resume) ?? 'chek';
      final branchName = SalesSessionProvider.instance.branchName.trim();
      final storeTitle = ReceiptStoreTitle.resolve(design: design, branchName: branchName);
      final productRows = ReceiptRowBuilder.fromCartItems(resume.items);
      final discount = ReceiptRowBuilder.totalDiscountUzs(
        items: resume.items,
        totalAfterDiscount: total,
      );

      final bytes = utf8.encode(_buildSpreadsheetXml(
        storeTitle: storeTitle,
        receiptNumber: receiptNumber,
        dateTime: DateTime.now(),
        sellerName: seller.isNotEmpty ? seller : 'Sotuvchi',
        sellerPhone: sellerPhone,
        clientName: client?.name,
        clientPhone: client?.phone,
        productRows: productRows,
        discount: discount,
        total: total,
      ));

      final safeName = receiptNumber.replaceAll(RegExp(r'[^\w\-]'), '_');
      return (
        data: HoldOrderExcelData(
          bytes: bytes,
          fileName: 'chek_$safeName.xls',
          receiptNumber: receiptNumber,
        ),
        error: null,
      );
    } catch (e) {
      return (data: null, error: e.toString());
    }
  }

  /// Native save panel ochilishidan oldin modal oynalar yopilgan bo‘lishi kerak.
  static Future<void> pauseForNativeSaveDialog() async {
    await WidgetsBinding.instance.endOfFrame;
    await Future<void>.delayed(const Duration(milliseconds: 150));
  }

  /// Desktop: foydalanuvchi saqlash joyini tanlaydi, fayl shu yerga yoziladi.
  static Future<HoldOrderExcelExportResult> saveToDesktop(HoldOrderExcelData data) async {
    try {
      final savedPath = await _pickAndSaveDesktopExcelFile(
        bytes: data.bytes,
        fileName: data.fileName,
      );
      return HoldOrderExcelExportResult.ok('Chek saqlandi: $savedPath');
    } on _SaveCancelled {
      return HoldOrderExcelExportResult.cancelled();
    } catch (e) {
      return HoldOrderExcelExportResult.fail('Fayl saqlanmadi: $e');
    }
  }

  /// Mobil: vaqtinchalik fayl orqali ulashish.
  static Future<HoldOrderExcelExportResult> shareHoldOrderExcel(HoldOrderExcelData data) async {
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/${data.fileName}');
      await file.writeAsBytes(data.bytes, flush: true);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/vnd.ms-excel')],
        subject: 'Chek ${data.receiptNumber}',
      );
      return HoldOrderExcelExportResult.ok('Chek ulashish ochildi');
    } catch (e) {
      return HoldOrderExcelExportResult.fail('Ulashish xatosi: $e');
    }
  }

  static Future<HoldOrderExcelExportResult> exportHoldOrder(
    Map<String, dynamic> hold,
  ) async {
    final built = await buildHoldOrderExcel(hold);
    if (built.error != null) {
      return HoldOrderExcelExportResult.fail(built.error!);
    }
    final data = built.data!;

    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      return saveToDesktop(data);
    }
    return shareHoldOrderExcel(data);
  }

  /// Desktop: saveFile faqat yo‘l qaytaradi — baytlarni alohida yozamiz.
  @visibleForTesting
  static Future<void> saveBytesToPath({
    required List<int> bytes,
    required String selectedPath,
  }) async {
    final target = _normalizeSavePath(selectedPath);
    final file = File(target);
    final parent = file.parent;
    if (!await parent.exists()) {
      await parent.create(recursive: true);
    }
    await file.writeAsBytes(bytes, flush: true);
    if (!await file.exists() || await file.length() == 0) {
      throw StateError('Fayl yozilmadi: $target');
    }
  }

  static Future<String?> _downloadsDirectory() async {
    try {
      final dir = await getDownloadsDirectory();
      return dir?.path;
    } catch (_) {
      return null;
    }
  }

  static Future<String> _pickAndSaveDesktopExcelFile({
    required List<int> bytes,
    required String fileName,
  }) async {
    final initialDirectory = await _downloadsDirectory();
    String? path;
    try {
      path = await FilePicker.platform.saveFile(
        dialogTitle: 'Chekni qayerga saqlash',
        fileName: fileName,
        initialDirectory: initialDirectory,
        type: FileType.any,
        lockParentWindow: false,
      );
    } catch (e) {
      throw StateError('Saqlash oynasi ochilmadi: $e');
    }
    if (path == null || path.trim().isEmpty) {
      throw const _SaveCancelled();
    }

    final target = _normalizeSavePath(path.trim());
    await saveBytesToPath(bytes: bytes, selectedPath: target);
    return target;
  }

  /// Asosiy ekran kontekstida: tayyorlash + saqlash (modal oynalarsiz).
  static Future<HoldOrderExcelExportResult> exportHoldOrderFromApp(
    Map<String, dynamic> hold, {
    Future<void> Function()? onPrepared,
  }) async {
    final built = await buildHoldOrderExcel(hold);
    if (built.error != null) {
      return HoldOrderExcelExportResult.fail(built.error!);
    }
    final data = built.data!;

    await onPrepared?.call();
    await pauseForNativeSaveDialog();

    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      return saveToDesktop(data);
    }
    return shareHoldOrderExcel(data);
  }

  @visibleForTesting
  static String normalizeSavePathForTest(String selectedPath, {String extension = '.xls'}) =>
      _normalizeSavePath(selectedPath, extension: extension);

  static String _normalizeSavePath(String selectedPath, {String extension = '.xls'}) {
    var target = selectedPath.trim();
    if (target.isEmpty) return target;

    final ext = extension.toLowerCase();
    if (!target.toLowerCase().endsWith(ext)) {
      target = '$target$extension';
    }
    return target;
  }

  static int _resolveGrandTotal(int raw, HoldOrderResume resume) {
    final fromApi = resume.grandTotal;
    if (fromApi != null && fromApi > 0) return fromApi;
    final pct = resume.discountPercent;
    if (pct != null && pct != 0) {
      return (raw * (100 + pct) / 100).round();
    }
    return raw;
  }

  static String? _receiptLabel(Map<String, dynamic> hold, HoldOrderResume resume) {
    final inv = HoldOrdersResponse.resolveInvoiceId(hold) ?? resume.invoiceId;
    if (inv != null && inv.isNotEmpty) {
      final s = inv.trim();
      return s.toUpperCase().startsWith('POS') ? s : 'POS$s';
    }
    final id = HoldOrdersResponse.resolveOrderId(hold) ?? resume.orderId;
    if (id != null && id > 0) return 'POS$id';
    return null;
  }

  @visibleForTesting
  static String buildSpreadsheetXmlForTest({
    required String storeTitle,
    required String receiptNumber,
    required List<ReceiptRow> productRows,
    int discount = 0,
    int total = 0,
  }) {
    return _buildSpreadsheetXml(
      storeTitle: storeTitle,
      receiptNumber: receiptNumber,
      dateTime: DateTime(2026, 5, 28, 9, 39),
      sellerName: 'Sotuvchi',
      productRows: productRows,
      discount: discount,
      total: total,
    );
  }

  static String _buildSpreadsheetXml({
    required String storeTitle,
    required String receiptNumber,
    required DateTime dateTime,
    required String sellerName,
    String? sellerPhone,
    String? clientName,
    String? clientPhone,
    required List<ReceiptRow> productRows,
    required int discount,
    required int total,
  }) {
    final rows = <List<String>>[
      [storeTitle],
      ['Oldindan chek'],
      ['Chek raqami', receiptNumber],
      ['Sana', _fmtDateTime(dateTime)],
      ['Sotuvchi', sellerName],
      if (sellerPhone != null && sellerPhone.trim().isNotEmpty) ['Telefon', sellerPhone.trim()],
      if (clientName != null && clientName.trim().isNotEmpty) ['Mijoz', clientName.trim()],
      if (clientPhone != null && clientPhone.trim().isNotEmpty) ['Mijoz tel.', clientPhone.trim()],
      const [],
      const ['Mahsulot', 'Miqdor', 'Narx', 'Summa'],
      ...productRows.map(
        (r) => [
          r.productName,
          r.quantityStr,
          _fmt(r.price),
          _fmt(r.sum),
        ],
      ),
      const [],
      if (discount > 0) ['Chegirma', _fmt(discount)],
      ['Jami', _fmt(total)],
    ];

    final buffer = StringBuffer()
      ..writeln('<?xml version="1.0"?>')
      ..writeln('<?mso-application progid="Excel.Sheet"?>')
      ..writeln(
        '<Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet" '
        'xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet">',
      )
      ..writeln('<Worksheet ss:Name="Chek">')
      ..writeln('<Table>');

    for (final row in rows) {
      buffer.writeln('<Row>');
      for (final cell in row) {
        buffer.writeln(
          '<Cell><Data ss:Type="String">${_xmlEscape(cell)}</Data></Cell>',
        );
      }
      buffer.writeln('</Row>');
    }

    buffer
      ..writeln('</Table>')
      ..writeln('</Worksheet>')
      ..writeln('</Workbook>');

    return buffer.toString();
  }

  static String _fmt(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  static String _fmtDateTime(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $h:$min';
  }

  static String _xmlEscape(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}
