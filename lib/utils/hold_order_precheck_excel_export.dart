import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/seller_preferences.dart';
import '../models/cart_item.dart';
import '../models/product.dart';
import '../providers/sales_session_provider.dart';
import '../utils/receipt_store_title.dart';
import '../models/receipt_design_config.dart';
import '../services/receipt_design_storage.dart';
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
      final description = _holdDescription(hold);

      final bytes = utf8.encode(_buildSpreadsheetXml(
        storeTitle: storeTitle,
        receiptNumber: receiptNumber,
        dateTime: DateTime.now(),
        sellerName: seller.isNotEmpty ? seller : 'Sotuvchi',
        sellerPhone: sellerPhone,
        clientName: client?.name,
        clientPhone: client?.phone,
        clientAddress: client?.address,
        description: description,
        branchName: branchName,
        items: resume.items,
        total: total,
      ));

      final safeName = receiptNumber.replaceAll(RegExp(r'[^\w\-]'), '_');
      return (
        data: HoldOrderExcelData(
          bytes: bytes,
          fileName: 'nakladnoy_$safeName.xls',
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
        dialogTitle: 'Nakladnoyni qayerga saqlash',
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

  static String? _holdDescription(Map<String, dynamic> hold) {
    for (final key in ['description', 'comment', 'note', 'izoh', 'remarks']) {
      final v = hold[key]?.toString().trim();
      if (v != null && v.isNotEmpty) return v;
    }
    return null;
  }

  @visibleForTesting
  static String buildSpreadsheetXmlForTest({
    required String storeTitle,
    required String receiptNumber,
    required List<CartItem> items,
    int total = 0,
  }) {
    return _buildSpreadsheetXml(
      storeTitle: storeTitle,
      receiptNumber: receiptNumber,
      dateTime: DateTime(2026, 6, 12),
      sellerName: 'Murod Qodirov',
      items: items,
      total: total,
      branchName: 'Asosiy filial',
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
    String? clientAddress,
    String? description,
    String? branchName,
    required List<CartItem> items,
    required int total,
  }) {
    const tableHeaders = [
      '№',
      'Mahsulot kodi',
      'Nomi',
      "O'lchov birligi",
      'Miqdor',
      'Narx',
      'Summa',
    ];

    final productLines = <List<String>>[];
    for (var i = 0; i < items.length; i++) {
      productLines.add(_productLineCells(items[i], i + 1));
    }

    final buffer = StringBuffer()
      ..writeln('<?xml version="1.0"?>')
      ..writeln('<?mso-application progid="Excel.Sheet"?>')
      ..writeln(
        '<Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet" '
        'xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet">',
      )
      ..writeln(_stylesXml())
      ..writeln('<Worksheet ss:Name="Nakladnoy">')
      ..writeln('<Table>')
      ..writeln(_columnsXml());

    _writeRow(buffer, ['Nakladnoy № $receiptNumber, ${_fmtDate(dateTime)}'], styleId: 'Title');
    _writeRow(buffer, const []);
    _writeRow(buffer, ["Do'kon:", _dash(storeTitle)]);
    _writeRow(buffer, ['Sotuvchi:', _dash(sellerName)]);
    _writeRow(buffer, ['Tel.:', _dash(sellerPhone)]);
    _writeRow(buffer, ['Mijoz:', _dash(clientName)]);
    _writeRow(buffer, ['Tel.:', _dash(clientPhone)]);
    _writeRow(buffer, ['Manzil:', _dash(clientAddress)]);
    _writeRow(buffer, ['Izoh:', _dash(description)]);
    _writeRow(buffer, const []);
    _writeRow(buffer, tableHeaders, styleId: 'TableHead');
    for (final line in productLines) {
      _writeRow(buffer, line, styleId: 'TableCell');
    }
    _writeRow(
      buffer,
      ['${items.length}', '', '', '', '', '', _fmtComma(total)],
      styleId: 'TableCell',
    );
    _writeRow(buffer, ['', '', '', '', '', 'Jami:', _fmtComma(total)], styleId: 'Total');
    _writeRow(buffer, const []);
    _writeRow(
      buffer,
      [
        'Ombordan:',
        _dash((branchName != null && branchName.trim().isNotEmpty) ? branchName.trim() : storeTitle),
        'Qabul qildi:',
        '',
      ],
    );
    _writeRow(buffer, ['Izoh', _dash(description)]);

    buffer
      ..writeln('</Table>')
      ..writeln('</Worksheet>')
      ..writeln('</Workbook>');

    return buffer.toString();
  }

  static List<String> _productLineCells(CartItem item, int index) {
    final p = item.product;
    final code = (p.sku ?? p.barcode ?? '').trim();
    final unit = _excelUnitLabel(item);
    final qty = item.quantity == item.quantity.roundToDouble()
        ? '${item.quantity.round()}'
        : item.quantity.toString();
    return [
      '$index',
      code.isEmpty ? '—' : code,
      p.name,
      unit,
      qty,
      _fmtComma(item.unitPriceDisplay),
      _fmtComma(item.total),
    ];
  }

  static String _excelUnitLabel(CartItem item) {
    if (item.sellByPack) return 'pachka';
    final short = Product.unitDisplayShort(item.product.unit);
    if (short == 'sht') return 'шт';
    return short;
  }

  static String _columnsXml() {
    const widths = [28, 72, 140, 56, 48, 64, 72];
    return widths.map((w) => '<Column ss:Width="$w"/>').join('\n');
  }

  static String _stylesXml() {
    const border = '''
<Border ss:Position="Bottom" ss:LineStyle="Continuous" ss:Weight="1"/>
<Border ss:Position="Left" ss:LineStyle="Continuous" ss:Weight="1"/>
<Border ss:Position="Right" ss:LineStyle="Continuous" ss:Weight="1"/>
<Border ss:Position="Top" ss:LineStyle="Continuous" ss:Weight="1"/>''';
    return '''
<Styles>
  <Style ss:ID="Title">
    <Font ss:Bold="1" ss:Size="12"/>
  </Style>
  <Style ss:ID="TableHead">
    <Font ss:Bold="1"/>
    <Interior ss:Color="#F2F2F2" ss:Pattern="Solid"/>
    <Borders>$border</Borders>
  </Style>
  <Style ss:ID="TableCell">
    <Borders>$border</Borders>
  </Style>
  <Style ss:ID="Total">
    <Font ss:Bold="1"/>
    <Borders>$border</Borders>
  </Style>
</Styles>''';
  }

  static void _writeRow(
    StringBuffer buffer,
    List<String> cells, {
    String? styleId,
  }) {
    buffer.writeln('<Row>');
    for (final cell in cells) {
      final style = styleId == null ? '' : ' ss:StyleID="$styleId"';
      buffer.writeln(
        '<Cell$style><Data ss:Type="String">${_xmlEscape(cell)}</Data></Cell>',
      );
    }
    buffer.writeln('</Row>');
  }

  static String _dash(String? value) {
    final v = value?.trim();
    if (v == null || v.isEmpty) return '—';
    return v;
  }

  static String _fmtComma(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  static String _fmtDate(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year.toString();
    return '$d.$m.$y';
  }

  static String _xmlEscape(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}
