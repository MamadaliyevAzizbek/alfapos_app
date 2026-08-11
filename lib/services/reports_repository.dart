import 'api_service.dart';

/// Hisobot / tranzaksiya / chek — filtrli, keshga yozilmaydi.
/// Ekranlar ReportsApi ni to‘g‘ridan chaqirmaydi.
class ReportsRepository {
  ReportsRepository._();
  static final ReportsRepository instance = ReportsRepository._();

  static const paymentTypeLabels = {
    'naqd': 'Naqd',
    'karta': 'Karta',
    'uzcard': 'UzCard',
    'humo': 'HUMO',
    'payme': 'Payme',
    'qarz': 'Qarz',
  };

  Future<Map<String, dynamic>> getSales({required Map<String, dynamic> body}) {
    return ReportsApi.getSales(body: body);
  }

  Future<Map<String, dynamic>> getSalesSummary({required Map<String, dynamic> body}) {
    return ReportsApi.getSalesSummary(body: body);
  }

  Future<Map<String, dynamic>> getSalesFilter() => ReportsApi.getSalesFilter();

  Future<Map<String, dynamic>> getReceivingReport({required Map<String, dynamic> body}) {
    return ReportsApi.getReceivingReport(body: body);
  }

  Future<Map<String, dynamic>> getInvoiceDetails(int orderId) {
    return ReportsApi.getInvoiceDetails(orderId);
  }

  Future<Map<String, dynamic>> getSalesAllDetails({required Map<String, dynamic> body}) {
    return ReportsApi.getSalesAllDetails(body: body);
  }

  Future<Map<String, dynamic>> getOrderForPrint(int orderId) {
    return ReportsApi.getOrderForPrint(orderId);
  }

  static Map<String, dynamic> salesListBody({
    required String from,
    required String to,
    int rowLimit = 200,
    int rowOffset = 0,
    String columnKey = 'id',
    String columnSortedBy = 'DESC',
    String searchValue = '',
    dynamic employeeId,
  }) =>
      ReportsApi.salesListBody(
        from: from,
        to: to,
        rowLimit: rowLimit,
        rowOffset: rowOffset,
        columnKey: columnKey,
        columnSortedBy: columnSortedBy,
        searchValue: searchValue,
        employeeId: employeeId,
      );

  static Map<String, dynamic> salesSummaryBody({
    required String from,
    required String to,
    int rowLimit = 200,
    int rowOffset = 0,
    String columnKey = 'id',
    String columnSortedBy = 'DESC',
    String searchValue = '',
  }) =>
      ReportsApi.salesSummaryBody(
        from: from,
        to: to,
        rowLimit: rowLimit,
        rowOffset: rowOffset,
        columnKey: columnKey,
        columnSortedBy: columnSortedBy,
        searchValue: searchValue,
      );

  static Map<String, dynamic> salesAllDetailsBody({
    required String from,
    required String to,
    int rowLimit = 200,
    int rowOffset = 0,
    String columnKey = 'id',
    String columnSortedBy = 'DESC',
    String searchValue = '',
  }) =>
      ReportsApi.salesAllDetailsBody(
        from: from,
        to: to,
        rowLimit: rowLimit,
        rowOffset: rowOffset,
        columnKey: columnKey,
        columnSortedBy: columnSortedBy,
        searchValue: searchValue,
      );

  static Map<String, dynamic> receivingListBody({
    required String from,
    required String to,
    int rowLimit = 100,
  }) =>
      ReportsApi.receivingListBody(from: from, to: to, rowLimit: rowLimit);

  static List<Map<String, dynamic>> extractRows(Map<String, dynamic> res) {
    List<dynamic> rows = res['datarows'] as List<dynamic>? ?? res['data'] as List<dynamic>? ?? [];
    if (rows.isEmpty && res['data'] is Map) {
      final inner = res['data'] as Map;
      rows = inner['datarows'] as List<dynamic>? ?? inner['rows'] as List<dynamic>? ?? [];
    }
    if (rows.isEmpty) {
      final raw = res['rows'];
      if (raw is List) rows = raw;
    }
    return rows.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }
}
