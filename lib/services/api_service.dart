import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../core/api_client.dart';
import '../core/auth_storage.dart';

/// Dashboard — barcha statistikalar
class DashboardApi {
  static Future<Map<String, dynamic>> getDashboard({String? date}) async {
    final q = date != null ? {'date': date} : null;
    return ApiClient.get('/dashboard', queryParams: q);
  }

  static Future<Map<String, dynamic>> getTopSellingProducts() async {
    return ApiClient.get('/dashboard/top-selling-products');
  }
}

/// Login
class AuthApi {
  static Future<Map<String, dynamic>> login(String email, String password, String companyId) async {
    return ApiClient.login(email, password, companyId);
  }

  static Future<void> logout() async {
    try {
      await ApiClient.post('/logout');
    } catch (_) {}
    await clearAuth();
  }
}

/// Mijozlar
class ContactsApi {
  static Future<Map<String, dynamic>> getCustomersList() async {
    return ApiClient.get('/contacts/customers-list');
  }

  static Future<Map<String, dynamic>> getCustomers({Map<String, dynamic>? body}) async {
    return ApiClient.post('/contacts/customers', body: body ?? {});
  }

  static Future<Map<String, dynamic>> storeCustomer(Map<String, dynamic> data) async {
    return ApiClient.post('/contacts/customers/store', body: data);
  }

  static Future<Map<String, dynamic>> getCustomer(int id) async {
    return ApiClient.get('/contacts/customers/$id');
  }

  static Future<Map<String, dynamic>> updateCustomer(int id, Map<String, dynamic> data) async {
    return ApiClient.post('/contacts/customers/$id', body: data);
  }

  static Future<void> deleteCustomer(int id) async {
    await ApiClient.delete('/contacts/customers/$id');
  }

  static Future<Map<String, dynamic>> getCustomerDebts(int id) async {
    return ApiClient.post('/contacts/customers/$id/debts', body: {});
  }

  static Future<Map<String, dynamic>> getCustomerOrders(int id, {Map<String, dynamic>? body}) async {
    return ApiClient.post('/contacts/customers/$id/orders', body: body ?? {});
  }

  static Future<Map<String, dynamic>> storeCustomerDebt(
    int id,
    Map<String, dynamic> data, {
    int? paymentTypeId,
  }) async {
    final body = Map<String, dynamic>.from(data);
    if (paymentTypeId != null) body['payment_type_id'] = paymentTypeId;
    return ApiClient.post('/contacts/customers/$id/debt/store', body: body);
  }

  static Future<Map<String, dynamic>> updateCustomerDebt(int debtId, Map<String, dynamic> data) async {
    return ApiClient.post('/contacts/customers/debt/$debtId', body: data);
  }

  static Future<void> deleteCustomerDebt(int debtId) async {
    await ApiClient.delete('/contacts/customers/debt/$debtId');
  }

  static Future<Map<String, dynamic>> getCustomerBalanceTransactions(int id) async {
    return ApiClient.post('/contacts/customers/$id/balance-transactions', body: {});
  }

  static Future<Map<String, dynamic>> updateCustomerBalance(
    int id, {
    required num amount,
    required String type, // add | subtract | set
    String description = '',
  }) async {
    return ApiClient.post('/contacts/customers/$id/balance', body: {
      'amount': amount,
      'type': type,
      'description': description,
    });
  }

  static Future<void> deleteCustomerBalanceTransaction(int transactionId) async {
    await ApiClient.delete('/contacts/customers/balance-transactions/$transactionId');
  }

  static Future<Map<String, dynamic>> getCustomerDueOrders(int id) async {
    return ApiClient.get('/contacts/customers/$id/due-orders');
  }

  static Future<Map<String, dynamic>> bulkDuePayment(int id, {required num amount}) async {
    return ApiClient.post('/contacts/customers/$id/bulk-due-payment', body: {'amount': amount});
  }

  static Future<Map<String, dynamic>> getCustomerDebtCount() async {
    return ApiClient.get('/contacts/customer-debt-count');
  }
}

/// Mahsulotlar
class ProductsApi {
  static MediaType _imageMediaTypeForPath(String path) {
    final l = path.toLowerCase();
    if (l.endsWith('.png')) return MediaType('image', 'png');
    if (l.endsWith('.webp')) return MediaType('image', 'webp');
    if (l.endsWith('.gif')) return MediaType('image', 'gif');
    if (l.endsWith('.heic') || l.endsWith('.heif')) return MediaType('image', 'jpeg');
    return MediaType('image', 'jpeg');
  }

  static Future<Map<String, dynamic>> getProducts({int? limit, int? offset, String? search}) async {
    final q = <String, String>{};
    if (limit != null) q['limit'] = limit.toString();
    if (offset != null) q['offset'] = offset.toString();
    if (search != null && search.isNotEmpty) q['search'] = search;
    return ApiClient.get('/products', queryParams: q.isEmpty ? null : q);
  }

  static Future<Map<String, dynamic>> getProductsList({Map<String, dynamic>? body}) async {
    return ApiClient.post('/products/list', body: body ?? {});
  }

  static Future<Map<String, dynamic>> getProduct(int id) async {
    return ApiClient.get('/products/$id');
  }

  /// GET /products/{id}/edit-data
  static Future<Map<String, dynamic>> getProductEditData(int id) async {
    return ApiClient.get('/products/$id/edit-data');
  }

  /// [localImagePath] bo‘lsa MOBILE_API_DOCS.md bo‘yicha `multipart/form-data`, `image` fayl.
  /// Aks holda JSON body (shu jumladan `image_base64` bo‘lishi mumkin).
  static Future<Map<String, dynamic>> createProduct(
    Map<String, dynamic> data, {
    String? localImagePath,
  }) async {
    if (localImagePath != null && localImagePath.isNotEmpty) {
      final f = File(localImagePath);
      if (await f.exists()) {
        final fields = <String, String>{};
        data.forEach((key, value) {
          if (value == null) return;
          if (key == 'image_base64') return;
          if (value is String) {
            fields[key] = value;
          } else if (value is num || value is bool) {
            fields[key] = value.toString();
          } else if (value is List || value is Map) {
            fields[key] = jsonEncode(value);
          } else {
            fields[key] = value.toString();
          }
        });
        final name = f.uri.pathSegments.isNotEmpty ? f.uri.pathSegments.last : 'image.jpg';
        final multipartFile = await http.MultipartFile.fromPath(
          'image',
          localImagePath,
          filename: name,
          contentType: _imageMediaTypeForPath(localImagePath),
        );
        return ApiClient.postMultipart('/products', fields: fields, file: multipartFile);
      }
    }
    return ApiClient.post('/products', body: data);
  }

  static Future<Map<String, dynamic>> updateProduct(
    int id,
    Map<String, dynamic> data, {
    String? localImagePath,
  }) async {
    if (localImagePath != null && localImagePath.isNotEmpty) {
      final f = File(localImagePath);
      if (await f.exists()) {
        final fields = <String, String>{};
        data.forEach((key, value) {
          if (value == null) return;
          if (key == 'image_base64') return;
          if (value is String) {
            fields[key] = value;
          } else if (value is num || value is bool) {
            fields[key] = value.toString();
          } else if (value is List || value is Map) {
            fields[key] = jsonEncode(value);
          } else {
            fields[key] = value.toString();
          }
        });
        final name = f.uri.pathSegments.isNotEmpty ? f.uri.pathSegments.last : 'image.jpg';
        final multipartFile = await http.MultipartFile.fromPath(
          'image',
          localImagePath,
          filename: name,
          contentType: _imageMediaTypeForPath(localImagePath),
        );
        return ApiClient.postMultipart('/products/$id/edit', fields: fields, file: multipartFile);
      }
    }
    return ApiClient.post('/products/$id/edit', body: data);
  }

  static Future<void> deleteProduct(int id) async {
    await ApiClient.delete('/products/$id');
  }

  static Future<Map<String, dynamic>> getSupportingData() async {
    return ApiClient.get('/products/supporting-data');
  }
}

/// Kategoriyalar
class CategoriesApi {
  static Future<Map<String, dynamic>> getCategories() async {
    return ApiClient.get('/products/categories');
  }

  /// GET /products/categories/{id}
  static Future<Map<String, dynamic>> getCategory(int id) async {
    return ApiClient.get('/products/categories/$id');
  }

  static Future<Map<String, dynamic>> createCategory(String name) async {
    return ApiClient.post('/products/categories', body: {'name': name});
  }

  static Future<Map<String, dynamic>> updateCategory(int id, String name) async {
    return ApiClient.post('/products/categories/$id', body: {'name': name});
  }

  static Future<void> deleteCategory(int id) async {
    await ApiClient.delete('/products/categories/$id');
  }
}

/// Xarajatlar
class ExpensesApi {
  static Future<Map<String, dynamic>> getExpenses({String? from, String? to}) async {
    final q = <String, String>{};
    if (from != null) q['from'] = from;
    if (to != null) q['to'] = to;
    return ApiClient.get('/expenses', queryParams: q.isEmpty ? null : q);
  }

  static Future<Map<String, dynamic>> createExpense(Map<String, dynamic> data) async {
    return ApiClient.post('/expenses', body: data);
  }

  static Future<void> deleteExpense(int id) async {
    await ApiClient.delete('/expenses/$id');
  }
}

/// Sotuv (Savatcha) — Murod API: mahsulotlar, to'lov turlari, filiallar, chek yuborish
class SalesApi {
  static Future<Map<String, dynamic>> getSalesProducts({Map<String, dynamic>? body}) async {
    return ApiClient.post('/sales/products', body: body ?? {'rowLimit': 50, 'offset': 0, 'orderType': 'sales'});
  }

  static Future<Map<String, dynamic>> getPaymentTypes() async {
    return ApiClient.get('/sales/payment-types');
  }

  static Future<Map<String, dynamic>> getBranches() async {
    return ApiClient.get('/sales/branches');
  }

  static Future<Map<String, dynamic>> setBranch({required int branchID, String orderType = 'sales'}) async {
    return ApiClient.post('/sales/set-branch', body: {'branchID': branchID, 'orderType': orderType});
  }

  static Future<Map<String, dynamic>> storeSale(Map<String, dynamic> data) async {
    return ApiClient.post('/sales/store', body: data);
  }

  /// POST /sales/return-full-order — chekni to'liq qaytarish (web bilan bir xil).
  /// Request: { orderId: 12345, invoiceId: "POS10119" }
  static Future<Map<String, dynamic>> returnFullOrder({
    required int orderId,
    required String invoiceId,
  }) async {
    return ApiClient.post(
      '/sales/return-full-order',
      body: {
        'orderId': orderId,
        'invoiceId': invoiceId,
      },
    );
  }
}

/// Kirim (receives) — yetkazib beruvchidan mahsulot kirimi, hisobotda yig'iladi
class ReceivesApi {
  /// POST /receives/products — body: rowLimit (500), orderType: 'receiving'. Javob: products[], variants[].
  static Future<Map<String, dynamic>> getReceivesProducts({Map<String, dynamic>? body}) async {
    return ApiClient.post('/receives/products', body: body ?? {'rowLimit': 500, 'orderType': 'receiving'});
  }

  static Future<Map<String, dynamic>> storeReceive(Map<String, dynamic> data) async {
    return ApiClient.post('/receives/store', body: data);
  }

  static Future<Map<String, dynamic>> getPaymentTypes() async {
    return ApiClient.get('/receives/payment-types');
  }

  static Future<Map<String, dynamic>> getBranches() async {
    return ApiClient.get('/receives/branches');
  }
}

/// Savdo hisoboti (tranzaksiyalar ro'yxati, invoice batafsil)
class ReportsApi {
  /// MOBILE_API_DOCS.md: reports/sales uchun tavsiya etilgan datatable body.
  static Map<String, dynamic> salesListBody({
    required String from,
    required String to,
    int rowLimit = 200,
    int rowOffset = 0,
    String columnKey = 'id',
    String columnSortedBy = 'DESC',
    String searchValue = '',
  }) {
    final startAt = '$from 00:00:00';
    final endAt = '$to 23:59:59';
    return {
      'rowLimit': rowLimit,
      'rowOffset': rowOffset,
      'columnKey': columnKey,
      'columnSortedBy': columnSortedBy,
      'searchValue': searchValue,
      'reqType': '',
      // Ba'zi backendlar filterdan tashqarida ham shu maydonlarni kutadi.
      'from': from,
      'to': to,
      'start_date': from,
      'end_date': to,
      'filtersData': [
        {
          'key': 'date_range',
          'value': [
            {
              'start': from,
              'end': to,
              'start_date': from,
              'end_date': to,
              'from': from,
              'to': to,
              'start_datetime': startAt,
              'end_datetime': endAt,
            },
          ],
        },
        {'key': 'date', 'value': {'from': from, 'to': to}},
        // Backend bilan amaliyotda eng barqaror format.
        {'key': 'start_date', 'value': from},
        {'key': 'end_date', 'value': to},
        {'key': 'from', 'value': from},
        {'key': 'to', 'value': to},
      ],
    };
  }

  /// /reports/sales/all-details uchun datatable body.
  static Map<String, dynamic> salesAllDetailsBody({
    required String from,
    required String to,
    int rowLimit = 200,
    int rowOffset = 0,
    String columnKey = 'id',
    String columnSortedBy = 'DESC',
    String searchValue = '',
  }) {
    final startAt = '$from 00:00:00';
    final endAt = '$to 23:59:59';
    return {
      'rowLimit': rowLimit,
      'rowOffset': rowOffset,
      'columnKey': columnKey,
      'columnSortedBy': columnSortedBy,
      'searchValue': searchValue,
      'reqType': '',
      'from': from,
      'to': to,
      'start_date': from,
      'end_date': to,
      'filtersData': [
        {
          'key': 'date_range',
          'value': [
            {
              'start': from,
              'end': to,
              'start_date': from,
              'end_date': to,
              'from': from,
              'to': to,
              'start_datetime': startAt,
              'end_datetime': endAt,
            },
          ],
        },
        {'key': 'date', 'value': {'from': from, 'to': to}},
        {'key': 'start_date', 'value': from},
        {'key': 'end_date', 'value': to},
        {'key': 'from', 'value': from},
        {'key': 'to', 'value': to},
      ],
    };
  }

  /// /reports/sales/summary uchun datatable body.
  static Map<String, dynamic> salesSummaryBody({
    required String from,
    required String to,
    int rowLimit = 200,
    int rowOffset = 0,
    String columnKey = 'id',
    String columnSortedBy = 'DESC',
    String searchValue = '',
  }) {
    return salesAllDetailsBody(
      from: from,
      to: to,
      rowLimit: rowLimit,
      rowOffset: rowOffset,
      columnKey: columnKey,
      columnSortedBy: columnSortedBy,
      searchValue: searchValue,
    );
  }

  static Future<Map<String, dynamic>> getSales({Map<String, dynamic>? body}) async {
    return ApiClient.post('/reports/sales', body: body ?? {});
  }

  static Future<Map<String, dynamic>> getSalesFilter() async {
    return ApiClient.get('/reports/sales/filter');
  }

  /// POST /reports/sales/all-details
  static Future<Map<String, dynamic>> getSalesAllDetails({Map<String, dynamic>? body}) async {
    return ApiClient.post('/reports/sales/all-details', body: body ?? {});
  }

  /// POST /reports/sales/summary
  static Future<Map<String, dynamic>> getSalesSummary({Map<String, dynamic>? body}) async {
    return ApiClient.post('/reports/sales/summary', body: body ?? {});
  }

  static Future<Map<String, dynamic>> getInvoiceDetails(int orderId) async {
    return ApiClient.post('/reports/sales/invoice-details/$orderId', body: {});
  }

  /// MOBILE_INVOICE_AND_RECEIPT_API: chekni HTML/print ko'rinishida — templateData.content (termal), largeInvoiceView (A4).
  static Future<Map<String, dynamic>> getOrderForPrint(int orderId) async {
    return ApiClient.get('/reports/sales/order/$orderId');
  }

  /// Chekni qaytarish — avval POST /sales/return (body: order_id), 404 bo'lsa POST /reports/sales/return/{id}.
  static Future<Map<String, dynamic>> returnSale(int orderId) async {
    try {
      return await ApiClient.post('/sales/return', body: {'order_id': orderId});
    } on ApiException catch (e) {
      if (e.statusCode == 404) {
        return ApiClient.post('/reports/sales/return/$orderId', body: {});
      }
      rethrow;
    }
  }
}

/// To'lov hisobotlari (MOBILE_API_DOCS.md)
class ReportsPaymentApi {
  /// POST /reports/payment
  static Future<Map<String, dynamic>> getPayments({Map<String, dynamic>? body}) async {
    return ApiClient.post('/reports/payment', body: body ?? {});
  }

  /// GET /reports/payment/filter
  static Future<Map<String, dynamic>> getPaymentFilter() async {
    return ApiClient.get('/reports/payment/filter');
  }

  /// POST /reports/payment/summary
  static Future<Map<String, dynamic>> getPaymentSummary({Map<String, dynamic>? body}) async {
    return ApiClient.post('/reports/payment/summary', body: body ?? {});
  }

  /// GET /reports/payment/summary/filter
  static Future<Map<String, dynamic>> getPaymentSummaryFilter() async {
    return ApiClient.get('/reports/payment/summary/filter');
  }

  /// GET /reports/payment/order/{id}
  static Future<Map<String, dynamic>> getPaymentOrder(int orderId) async {
    return ApiClient.get('/reports/payment/order/$orderId');
  }
}

/// Xarajat kategoriyalari (MOBILE_API_DOCS.md)
class ExpenseCategoriesApi {
  /// GET /support/expense-categories/expense-categories
  static Future<Map<String, dynamic>> getExpenseCategories() async {
    return ApiClient.get('/support/expense-categories/expense-categories');
  }

  /// POST /support/expense-categories/expense-categories/list
  static Future<Map<String, dynamic>> listExpenseCategories({Map<String, dynamic>? body}) async {
    return ApiClient.post(
      '/support/expense-categories/expense-categories/list',
      body: body ??
          {
            'columnKey': 'id',
            'columnSortedBy': 'DESC',
            'rowOffset': 0,
            'rowLimit': 50,
            'searchValue': '',
            'reqType': '',
            'filtersData': [],
          },
    );
  }

  /// POST /support/expense-categories/expense-categories
  static Future<Map<String, dynamic>> createExpenseCategory(Map<String, dynamic> data) async {
    return ApiClient.post('/support/expense-categories/expense-categories', body: data);
  }

  /// POST /support/expense-categories/expense-categories/{id}
  static Future<Map<String, dynamic>> updateExpenseCategory(int id, Map<String, dynamic> data) async {
    return ApiClient.post('/support/expense-categories/expense-categories/$id', body: data);
  }

  /// GET /support/expense-categories/expense-categories/{id}
  static Future<Map<String, dynamic>> getExpenseCategory(int id) async {
    return ApiClient.get('/support/expense-categories/expense-categories/$id');
  }

  /// DELETE /support/expense-categories/expense-categories/{id}
  static Future<void> deleteExpenseCategory(int id) async {
    await ApiClient.delete('/support/expense-categories/expense-categories/$id');
  }
}

/// Daromad kategoriyalari (MOBILE_API_DOCS.md)
class IncomeCategoriesApi {
  static Future<Map<String, dynamic>> getIncomeCategories() async {
    return ApiClient.get('/support/income-categories/income-categories');
  }

  static Future<Map<String, dynamic>> listIncomeCategories({Map<String, dynamic>? body}) async {
    return ApiClient.post(
      '/support/income-categories/income-categories/list',
      body: body ??
          {
            'columnKey': 'id',
            'columnSortedBy': 'DESC',
            'rowOffset': 0,
            'rowLimit': 50,
            'searchValue': '',
            'reqType': '',
            'filtersData': [],
          },
    );
  }

  static Future<Map<String, dynamic>> createIncomeCategory(Map<String, dynamic> data) async {
    return ApiClient.post('/support/income-categories/income-categories', body: data);
  }

  static Future<Map<String, dynamic>> updateIncomeCategory(int id, Map<String, dynamic> data) async {
    return ApiClient.post('/support/income-categories/income-categories/$id', body: data);
  }

  static Future<Map<String, dynamic>> getIncomeCategory(int id) async {
    return ApiClient.get('/support/income-categories/income-categories/$id');
  }

  static Future<void> deleteIncomeCategory(int id) async {
    await ApiClient.delete('/support/income-categories/income-categories/$id');
  }
}

/// Valyutalar (MOBILE_API_DOCS.md)
class CurrenciesApi {
  /// POST /support/currencies/list
  static Future<Map<String, dynamic>> listCurrencies({Map<String, dynamic>? body}) async {
    return ApiClient.post(
      '/support/currencies/list',
      body: body ??
          {
            'columnKey': 'id',
            'columnSortedBy': 'DESC',
            'rowOffset': 0,
            'rowLimit': 50,
            'searchValue': '',
            'reqType': '',
            'filtersData': [],
          },
    );
  }

  /// GET /support/currencies
  static Future<Map<String, dynamic>> getCurrencies() async {
    return ApiClient.get('/support/currencies');
  }

  /// GET /support/currencies/primary-purchase
  static Future<Map<String, dynamic>> getPrimaryPurchaseCurrency() async {
    return ApiClient.get('/support/currencies/primary-purchase');
  }

  /// GET /support/currencies/primary-sales
  static Future<Map<String, dynamic>> getPrimarySalesCurrency() async {
    return ApiClient.get('/support/currencies/primary-sales');
  }

  /// POST /support/currencies
  static Future<Map<String, dynamic>> createCurrency(Map<String, dynamic> data) async {
    return ApiClient.post('/support/currencies', body: data);
  }

  /// GET /support/currencies/{id}
  static Future<Map<String, dynamic>> getCurrency(int id) async {
    return ApiClient.get('/support/currencies/$id');
  }

  /// POST /support/currencies/{id}
  static Future<Map<String, dynamic>> updateCurrency(int id, Map<String, dynamic> data) async {
    return ApiClient.post('/support/currencies/$id', body: data);
  }

  /// DELETE /support/currencies/{id}
  static Future<void> deleteCurrency(int id) async {
    await ApiClient.delete('/support/currencies/$id');
  }

  /// POST /support/currencies/{id}/exchange-rate
  static Future<Map<String, dynamic>> updateExchangeRate(int id, num exchangeRate) async {
    return ApiClient.post('/support/currencies/$id/exchange-rate', body: {'exchange_rate': exchangeRate});
  }

  /// POST /support/currencies/primary
  static Future<Map<String, dynamic>> setPrimaryCurrencies({
    required int primaryPurchaseCurrency,
    required int primarySalesCurrency,
  }) async {
    return ApiClient.post(
      '/support/currencies/primary',
      body: {
        'primary_purchase_currency': primaryPurchaseCurrency,
        'primary_sales_currency': primarySalesCurrency,
      },
    );
  }
}

/// User profil
class UserApi {
  static Future<Map<String, dynamic>> getUser() async {
    return ApiClient.get('/user');
  }

  static Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data) async {
    return ApiClient.post('/user/profile', body: data);
  }

  static Future<void> changePassword(String password, String passwordConfirmation) async {
    await ApiClient.post('/user/password', body: {
      'password': password,
      'password_confirmation': passwordConfirmation,
    });
  }
}
