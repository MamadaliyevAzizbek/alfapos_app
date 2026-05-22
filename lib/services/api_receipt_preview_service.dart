import '../utils/api_receipt_html_parser.dart';
import 'api_service.dart';
import 'thermal_receipt_printer.dart';

/// Sozlamalar: API dan kelgan chekni ko‘rsatish uchun ma’lumot.
class ApiReceiptPreviewData {
  final int orderId;
  final String? invoiceId;
  final String html;
  final String htmlSource;
  final List<String> printLines;

  const ApiReceiptPreviewData({
    required this.orderId,
    this.invoiceId,
    required this.html,
    required this.htmlSource,
    required this.printLines,
  });
}

class ApiReceiptPreviewService {
  ApiReceiptPreviewService._();

  /// Oxirgi sotuv (bugun) order id.
  static Future<int?> latestSaleOrderId() async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final res = await ReportsApi.getSales(
      body: ReportsApi.salesListBody(
        from: today,
        to: today,
        rowLimit: 30,
        rowOffset: 0,
        columnKey: 'id',
        columnSortedBy: 'DESC',
      ),
    );
    final rows = res['datarows'] as List<dynamic>? ?? res['data'] as List<dynamic>? ?? [];
    for (final r in rows) {
      if (r is! Map) continue;
      final m = Map<String, dynamic>.from(r);
      final inv = (m['invoice_id'] ?? m['invoiceId'] ?? '').toString().trim().toLowerCase();
      if (inv.contains('umumiy') || inv.contains('grand')) continue;
      final id = m['id'] ?? m['order_id'];
      final n = id is int ? id : int.tryParse(id?.toString() ?? '');
      if (n != null && n > 0) return n;
    }
    return null;
  }

  static Future<ApiReceiptPreviewData> loadForOrder(int orderId) async {
    final res = await ReportsApi.getOrderForPrint(orderId);
    final extracted = ThermalReceiptPrinter.thermalHtmlFromOrderResponse(res);
    if (extracted == null || extracted.html.trim().isEmpty) {
      throw Exception('API termal chek HTML topilmadi (order $orderId)');
    }
    final lines = ApiReceiptHtmlParser.toPrintLines(extracted.html);
    final invoiceId = res['invoiceId']?.toString();
    return ApiReceiptPreviewData(
      orderId: orderId,
      invoiceId: invoiceId,
      html: extracted.html,
      htmlSource: extracted.source,
      printLines: lines,
    );
  }
}
