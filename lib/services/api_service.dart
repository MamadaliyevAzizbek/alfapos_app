import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../core/api_client.dart';
import '../core/auth_storage.dart';
import '../core/session_reset.dart';
import '../models/product.dart';
import '../utils/product_web_store_body.dart';
import '../utils/sale_store_response.dart';

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
    await resetAppSessionForAccountChange();
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

  /// POST /contacts/suppliers — kirim uchun yetkazib beruvchilar.
  static Future<Map<String, dynamic>> getSuppliers({Map<String, dynamic>? body}) async {
    return ApiClient.post('/contacts/suppliers', body: body ?? {
      'rowLimit': 5000,
      'rowOffset': 0,
      'columnKey': 'id',
      'columnSortedBy': 'DESC',
    });
  }

  static Future<Map<String, dynamic>> storeSupplier(Map<String, dynamic> data) async {
    return ApiClient.post('/contacts/suppliers/store', body: data);
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

  /// GET /contacts/payment-list — umumiy to'lash uchun (web BulkDuePayment).
  static Future<Map<String, dynamic>> getPaymentList() async {
    return ApiClient.get('/contacts/payment-list');
  }

  /// POST bulk-due-payment — [paymentMethod]: payment_types.id yoki "customer_balance".
  static Future<Map<String, dynamic>> bulkDuePayment(
    int id, {
    required num amount,
    required Object paymentMethod,
  }) async {
    return ApiClient.post('/contacts/customers/$id/bulk-due-payment', body: {
      'amount': amount,
      'payment_method': paymentMethod,
    });
  }

  static Future<Map<String, dynamic>> deleteBulkDuePayment(
    int customerId, {
    required String bulkGroupId,
  }) async {
    return ApiClient.post(
      '/contacts/customers/$customerId/bulk-due-payment/delete',
      body: {'bulk_group_id': bulkGroupId},
    );
  }

  static Future<Map<String, dynamic>> deleteOrderDuePayment(
    int customerId, {
    required int paymentId,
  }) async {
    return ApiClient.post(
      '/contacts/customers/$customerId/order-due-payment/delete/$paymentId',
      body: {},
    );
  }

  static Future<Map<String, dynamic>> getCustomerDebtCount() async {
    return ApiClient.get('/contacts/customer-debt-count');
  }

  static Future<Map<String, dynamic>> getCustomerFormOptions() async {
    return ApiClient.get('/contacts/customers/form-options');
  }

  static Future<Map<String, dynamic>> getCustomerGroups() async {
    return ApiClient.get('/contacts/customer-groups');
  }

  static Future<Map<String, dynamic>> getGroupsShort() async {
    return ApiClient.get('/contacts/groups');
  }

  static Future<Map<String, dynamic>> postGroupsList({
    int rowLimit = 200,
    int rowOffset = 0,
    String? reqType,
  }) async {
    final body = <String, dynamic>{
      'rowLimit': rowLimit,
      'rowOffset': rowOffset,
    };
    if (reqType != null && reqType.isNotEmpty) body['reqType'] = reqType;
    return ApiClient.post('/contacts/groups-list', body: body);
  }

  static Future<Map<String, dynamic>> getCustomerGroup(int id) async {
    return ApiClient.get('/contacts/groups/$id');
  }

  static Future<Map<String, dynamic>> storeCustomerGroup({
    required String title,
    required num discount,
    bool isDefault = false,
  }) async {
    return ApiClient.post('/contacts/groups/store', body: {
      'title': title,
      'discount': discount,
      'is_default': isDefault ? 1 : 0,
    });
  }

  static Future<Map<String, dynamic>> updateCustomerGroup(
    int id, {
    required String title,
    required num discount,
    bool isDefault = false,
  }) async {
    return ApiClient.post('/contacts/groups/$id', body: {
      'title': title,
      'discount': discount,
      'is_default': isDefault ? 1 : 0,
    });
  }

  static Future<Map<String, dynamic>> deleteCustomerGroup(int id) async {
    return ApiClient.delete('/contacts/groups/$id');
  }

  static Future<Map<String, dynamic>> saveOrderDuePayment(Map<String, dynamic> body) async {
    return ApiClient.post('/contacts/customers/save-order-due-payment', body: body);
  }

  static Future<Map<String, dynamic>> sendTelegramReceipt(Map<String, dynamic> body) async {
    return ApiClient.post('/contacts/customers/send-telegram-receipt', body: body);
  }

  static Future<Map<String, dynamic>> sendTelegramDebtBalance(int customerId) async {
    return ApiClient.post('/contacts/customers/$customerId/send-telegram-debt-balance', body: {});
  }

  static Future<Map<String, dynamic>> setAutoTelegramCustomerReceipt(int customerId, bool enabled) async {
    return ApiClient.post('/contacts/customers/$customerId/auto-telegram-customer-receipt', body: {
      'auto_telegram_customer_receipt': enabled ? 1 : 0,
    });
  }

  static Future<Map<String, dynamic>> getWordDocuments(int customerId) async {
    return ApiClient.get('/contacts/customers/$customerId/word-documents');
  }

  static Future<Map<String, dynamic>> addToBlacklist(int customerId) async {
    return ApiClient.post('/contacts/customers/blacklist/add', body: {'customer_id': customerId});
  }

  static Future<Map<String, dynamic>> removeFromBlacklist(int customerId) async {
    return ApiClient.post('/contacts/customers/blacklist/remove/$customerId', body: {});
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

  /// Laravel multipart: massivlar `key[0]`, `key[1]` ko'rinishida (jsonEncode emas).
  static Map<String, String> dataToMultipartFields(Map<String, dynamic> data) {
    final fields = <String, String>{};

    data.forEach((key, value) {
      if (value == null) return;
      if (key == 'image_base64') return;
      if (value is String) {
        fields[key] = value;
      } else if (value is num || value is bool) {
        fields[key] = value.toString();
      } else if (value is List) {
        for (var i = 0; i < value.length; i++) {
          final item = value[i];
          if (item == null) continue;
          if (item is Map) {
            final m = Map<String, dynamic>.from(item as Map);
            m.forEach((subKey, subVal) {
              if (subVal == null) return;
              if (subVal is List || subVal is Map) {
                fields['$key[$i][$subKey]'] = jsonEncode(subVal);
                return;
              }
              final str = subVal is String ? subVal.trim() : subVal.toString();
              if (str.isNotEmpty) fields['$key[$i][$subKey]'] = str;
            });
            continue;
          }
          final str = item is String ? item.trim() : item.toString();
          if (str.isEmpty) continue;
          fields['$key[$i]'] = str;
        }
      } else if (value is Map) {
        fields[key] = jsonEncode(value);
      } else {
        fields[key] = value.toString();
      }
    });
    return fields;
  }

  static Future<String?> _readImageBase64(String localImagePath) async {
    final f = File(localImagePath);
    if (!await f.exists()) return null;
    final bytes = await f.readAsBytes();
    if (bytes.isEmpty) return null;
    if (bytes.length > 6 * 1024 * 1024) {
      throw ApiException('Rasm hajmi juda katta (6 MB dan oshmasligi kerak)', 400);
    }
    return base64Encode(bytes);
  }

  static String _imageDataUri(String localImagePath, String base64) {
    final l = localImagePath.toLowerCase();
    final mime = l.endsWith('.png')
        ? 'image/png'
        : l.endsWith('.webp')
            ? 'image/webp'
            : 'image/jpeg';
    return 'data:$mime;base64,$base64';
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
  /// Yangi mahsulot va tahrirlashda rasm — bir xil multipart (`image` fayl).
  static int? _variantIdFromData(Map<String, dynamic> data) {
    final direct = data['variantID'] ?? data['variant_id'];
    if (direct is int && direct > 0) return direct;
    if (direct != null) {
      final n = int.tryParse(direct.toString());
      if (n != null && n > 0) return n;
    }
    final vd = data['variantDetails'];
    if (vd is List && vd.isNotEmpty && vd.first is Map) {
      final id = (vd.first as Map)['id'];
      if (id is int && id > 0) return id;
      final n = int.tryParse(id?.toString() ?? '');
      if (n != null && n > 0) return n;
    }
    return null;
  }

  static bool _isPlaceholderImagePath(String? raw) {
    if (raw == null || raw.trim().isEmpty) return true;
    final l = raw.toLowerCase();
    return l.contains('non.jpg') ||
        l.contains('no_image') ||
        l.contains('no-image') ||
        l.contains('placeholder');
  }

  static bool _responseHasProductImage(Map<String, dynamic> res) {
    final data = res['data'] ?? res['product'];
    if (data is Map) {
      final img = Product.imageUrlFromApiMap(Map<String, dynamic>.from(data));
      if (!_isPlaceholderImagePath(img)) return true;
    }
    final top = Product.imageUrlFromApiMap(res);
    return !_isPlaceholderImagePath(top);
  }

  static bool _isProductStorePath(String path) =>
      path == '/products/store' || path.endsWith('/products/store');

  static int? _productIdFromResponse(Map<String, dynamic> res) {
    final data = res['data'] ?? res['product'];
    if (data is Map) {
      final id = data['id'] ?? data['productID'] ?? data['product_id'];
      if (id is int && id > 0) return id;
      final n = int.tryParse(id?.toString() ?? '');
      if (n != null && n > 0) return n;
    }
    final id = res['id'] ?? res['productID'];
    if (id is int && id > 0) return id;
    return int.tryParse(id?.toString() ?? '');
  }

  static Future<Map<String, dynamic>> _postMultipartWithImageField(
    String path,
    Map<String, dynamic> data,
    String localImagePath,
    String fieldName,
  ) async {
    final fields = dataToMultipartFields(data);
    final file = File(localImagePath);
    final name = file.uri.pathSegments.isNotEmpty ? file.uri.pathSegments.last : 'image.jpg';
    final contentType = _imageMediaTypeForPath(localImagePath);
    final multipartFile = await http.MultipartFile.fromPath(
      fieldName,
      localImagePath,
      filename: name,
      contentType: contentType,
    );
    return ApiClient.postMultipart(path, fields: fields, file: multipartFile);
  }

  /// `/products/store` ga faqat bir marta POST — keyin rasm uchun `/products/{id}/edit`.
  static String? _switchStorePathToEditAfterCreate(String path, Map<String, dynamic> res) {
    if (!_isProductStorePath(path)) return null;
    final id = _productIdFromResponse(res);
    if (id == null || id <= 0) return null;
    return '/products/$id/edit';
  }

  /// Avval JSON base64 (`image`), keyin multipart — server `public/uploads/products/`.
  static Future<Map<String, dynamic>> _postProductWithImageFallback(
    String path,
    Map<String, dynamic> data,
    String localImagePath,
  ) async {
    final f = File(localImagePath);
    if (!await f.exists()) {
      return ApiClient.post(path, body: data);
    }

    final b64 = await _readImageBase64(localImagePath);
    if (b64 == null) {
      throw ApiException('Rasm fayli o\'qilmadi', 400);
    }
    final dataUri = _imageDataUri(localImagePath, b64);

    ApiException? lastError;
    Map<String, dynamic>? lastOk;
    var effectivePath = path;
    var storeCreateDone = false;

    final jsonBodies = <Map<String, dynamic>>[
      {...data, 'image': dataUri, 'image_base64': b64},
      {...data, 'image': dataUri},
      {...data, 'image_base64': b64},
      {...data, 'productImage': dataUri},
    ];
    for (final body in jsonBodies) {
      if (storeCreateDone && _isProductStorePath(effectivePath)) break;
      try {
        final res = await ApiClient.post(effectivePath, body: body);
        if (_responseHasProductImage(res)) return res;
        lastOk = res;
        if (_isProductStorePath(effectivePath)) {
          storeCreateDone = true;
          final editPath = _switchStorePathToEditAfterCreate(effectivePath, res);
          if (editPath != null) {
            effectivePath = editPath;
          } else {
            break;
          }
        }
      } on ApiException catch (e) {
        lastError = e;
      }
    }

    final multipartFields = <String>['image', 'productImage', 'product_image'];
    final variantId = _variantIdFromData(data);
    if (variantId != null) {
      multipartFields.addAll(['variant_image', 'variantDetails[0][image]']);
    }
    for (final field in multipartFields) {
      if (storeCreateDone && _isProductStorePath(effectivePath)) break;
      try {
        final res = await _postMultipartWithImageField(effectivePath, data, localImagePath, field);
        if (_responseHasProductImage(res)) return res;
        lastOk = res;
        if (_isProductStorePath(effectivePath)) {
          storeCreateDone = true;
          final editPath = _switchStorePathToEditAfterCreate(effectivePath, res);
          if (editPath != null) {
            effectivePath = editPath;
          } else {
            break;
          }
        }
      } on ApiException catch (e) {
        lastError = e;
      }
    }

    if (lastOk != null) return lastOk;
    throw lastError ?? ApiException('Rasm yuborilmadi', 500);
  }

  /// Yangi mahsulot — web bilan bir xil (`wholesalePrice`, pachka maydonlari).
  static Future<Map<String, dynamic>> storeProduct(
    Map<String, dynamic> data, {
    String? localImagePath,
    Product? imageHintProduct,
  }) async {
    if (localImagePath == null || localImagePath.isEmpty) {
      return ApiClient.post('/products/store', body: data);
    }

    var res = await _postProductWithImageFallback('/products/store', data, localImagePath);
    if (_responseHasProductImage(res)) return res;

    final id = _productIdFromResponse(res);
    if (id == null) return res;

    final patch = Map<String, dynamic>.from(data);
    if (imageHintProduct != null) {
      try {
        final fresh = await getProduct(id);
        final raw = fresh['data'] ?? fresh['product'] ?? fresh;
        if (raw is Map) {
          final parsed = Product.fromApiJson(Map<String, dynamic>.from(raw));
          final vid = parsed.variantId;
          if (vid != null && vid > 0) {
            patch['variantID'] = vid;
            patch['variantDetails'] = [
              ProductWebStoreBody.variantDetailEntry(vid, imageHintProduct),
            ];
          }
        }
      } catch (_) {}
    }

    try {
      res = await _postProductWithImageFallback(
        '/products/$id/edit',
        patch,
        localImagePath,
      );
    } catch (_) {}
    return res;
  }

  /// Eski V1 — cheklangan maydonlar; faqat fallback.
  static Future<Map<String, dynamic>> createProduct(
    Map<String, dynamic> data, {
    String? localImagePath,
    Product? imageHintProduct,
  }) async =>
      storeProduct(data, localImagePath: localImagePath, imageHintProduct: imageHintProduct);

  static Future<Map<String, dynamic>> updateProduct(
    int id,
    Map<String, dynamic> data, {
    String? localImagePath,
  }) async {
    if (localImagePath != null && localImagePath.isNotEmpty) {
      return _postProductWithImageFallback('/products/$id/edit', data, localImagePath);
    }
    return ApiClient.post('/products/$id/edit', body: data);
  }

  static Future<void> deleteProduct(int id) async {
    await ApiClient.delete('/products/$id');
  }

  static Future<Map<String, dynamic>> getSupportingData() async {
    return ApiClient.get('/products/supporting-data');
  }

  static Map<String, dynamic> get _referenceListBody => {
        'rowLimit': 500,
        'rowOffset': 0,
        'columnKey': 'name',
        'columnSortedBy': 'asc',
      };

  static Future<Map<String, dynamic>> postCategoriesList() async {
    return ApiClient.post('/products/categories/list', body: _referenceListBody);
  }

  static Future<Map<String, dynamic>> postBrandsList() async {
    return ApiClient.post('/products/brands/list', body: _referenceListBody);
  }

  static Future<Map<String, dynamic>> getBrands() async {
    return ApiClient.get('/products/brands');
  }

  static Future<Map<String, dynamic>> getFilterOptions() async {
    return ApiClient.get('/products/filter-options');
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

/// Kassaga kirim (tezkor kirim forma)
class IncomesApi {
  static Future<Map<String, dynamic>> getIncomes({String? from, String? to}) async {
    final q = <String, String>{};
    if (from != null) q['from'] = from;
    if (to != null) q['to'] = to;
    return ApiClient.get('/incomes', queryParams: q.isEmpty ? null : q);
  }

  static Future<Map<String, dynamic>> createIncome(Map<String, dynamic> data) async {
    return ApiClient.post('/incomes', body: data);
  }
}

/// Sotuv (Savatcha) — MOBILE_SALES_API_UZ.md
class SalesApi {
  static Future<Map<String, dynamic>> getSalesProducts({Map<String, dynamic>? body}) async {
    return ApiClient.post('/sales/products', body: body ?? {'rowLimit': 40, 'offset': 0, 'orderType': 'sales'});
  }

  static Future<Map<String, dynamic>> barcodeSearch({
    required String searchValue,
    required int branchId,
    String orderType = 'sales',
  }) async {
    return ApiClient.post('/sales/barcode-search', body: {
      'searchValueForBarCode': searchValue,
      'orderType': orderType,
      'branchId': branchId,
    });
  }

  static Future<Map<String, dynamic>> searchCustomers({
    required String searchValue,
    String orderType = 'sales',
  }) async {
    return ApiClient.post('/sales/customers', body: {
      'orderType': orderType,
      'customerSearchValue': searchValue,
    });
  }

  static Future<Map<String, dynamic>> getPaymentTypes() async {
    return ApiClient.get('/sales/payment-types');
  }

  /// GET /support/sales-settings — salesTolovsizPaymentEnabled va boshqa sozlamalar.
  static Future<Map<String, dynamic>> getSalesSettings() async {
    return ApiClient.get('/support/sales-settings');
  }

  static Future<Map<String, dynamic>> getBranches() async {
    return ApiClient.get('/sales/branches');
  }

  static Future<Map<String, dynamic>> getCurrencies() async {
    return ApiClient.get('/sales/currencies');
  }

  static Future<Map<String, dynamic>> setBranch({required int branchID, String orderType = 'sales'}) async {
    return ApiClient.post('/sales/set-branch', body: {'branchID': branchID, 'orderType': orderType});
  }

  static Future<Map<String, dynamic>> getCashRegisters() async {
    return ApiClient.get('/sales/cash-registers');
  }

  static Future<Map<String, dynamic>> getCashRegisterBalance(int id) async {
    return ApiClient.get('/sales/cash-registers/$id/balance');
  }

  static Future<Map<String, dynamic>> openCloseCashRegister(Map<String, dynamic> body) async {
    return ApiClient.post('/sales/cash-registers/open-close', body: body);
  }

  static Future<Map<String, dynamic>> getRegisterExpectedAmount(int cashRegisterId) async {
    return ApiClient.get('/sales/register-amount/$cashRegisterId');
  }

  static Future<Map<String, dynamic>> getShiftInfo(int logId) async {
    return ApiClient.get('/sales/cash-register-shifts/$logId/info');
  }

  static Future<Map<String, dynamic>> getShiftAnalytics(int logId) async {
    return ApiClient.get('/sales/cash-register-shifts/$logId/analytics');
  }

  static Future<Map<String, dynamic>> closeShift(Map<String, dynamic> body) async {
    return ApiClient.post('/sales/cash-register-shifts/close', body: body);
  }

  /// Barcha pauza (hold) buyurtmalar — filtrlash klientda (API kassa id qaytarmasligi mumkin).
  static Future<Map<String, dynamic>> getHoldOrders() async {
    return ApiClient.get('/sales/hold-orders');
  }

  static Future<Map<String, dynamic>> updateHoldStatus(Map<String, dynamic> body) async {
    return ApiClient.post('/sales/hold-orders/update-status', body: body);
  }

  static bool _doneStoreSaleInFlight = false;

  static Future<Map<String, dynamic>> storeSale(Map<String, dynamic> data) async {
    final isDone = data['status']?.toString() == 'done';
    if (isDone) {
      if (_doneStoreSaleInFlight) {
        throw ApiException(
          'Sotuv allaqachon yuborilmoqda. Biroz kuting.',
          429,
        );
      }
      _doneStoreSaleInFlight = true;
    }
    try {
      final res = await ApiClient.post('/sales/store', body: data);
      SaleStoreResponse.ensureCreated(res);
      return res;
    } finally {
      if (isDone) _doneStoreSaleInFlight = false;
    }
  }

  static Future<Map<String, dynamic>> sendTelegramReceipt({
    required int customerId,
    required int orderId,
    required String invoiceId,
  }) async {
    return ApiClient.post('/sales/send-telegram-receipt', body: {
      'id': customerId,
      'orderId': orderId,
      'invoiceId': invoiceId,
    });
  }

  static Future<Map<String, dynamic>> sendTelegramDailySummary() async {
    return ApiClient.post('/sales/send-telegram-daily-summary', body: {});
  }

  static Future<Map<String, dynamic>> getVariantQuantity(int variantId, {required int branchId}) async {
    return ApiClient.get('/sales/variant-available-quantity/$variantId?branchId=$branchId');
  }

  static Future<Map<String, dynamic>> cancelSale(int orderId) async {
    return ApiClient.post('/sales/cancel', body: {'orderID': orderId});
  }

  static Future<Map<String, dynamic>> continueSale(int orderId) async {
    return ApiClient.post('/sales/continue-sale', body: {'orderID': orderId});
  }

  /// POST /sales/returns-type-set — server qaytarish rejimini yoqish.
  static Future<Map<String, dynamic>> setReturnsType({String salesOrReturnType = 'returns'}) async {
    return ApiClient.post('/sales/returns-type-set', body: {
      'salesOrReturnType': salesOrReturnType,
    });
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

  /// POST /receives/barcode-search
  static Future<Map<String, dynamic>> barcodeSearch({
    required String searchValue,
    int? branchId,
    String orderType = 'receiving',
  }) async {
    return ApiClient.post('/receives/barcode-search', body: {
      'searchValueForBarCode': searchValue,
      'orderType': orderType,
      if (branchId != null) 'branchId': branchId,
    });
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

  static Future<Map<String, dynamic>> getCurrencies() async {
    return ApiClient.get('/receives/currencies');
  }

  static Future<Map<String, dynamic>> setBranch({required int branchId, String orderType = 'receiving'}) async {
    return ApiClient.post('/receives/set-branch', body: {
      'branchID': branchId,
      'orderType': orderType,
    });
  }

  static Future<Map<String, dynamic>> getEditableOrder(int orderId, {String orderType = 'receiving'}) async {
    return ApiClient.get('/receives/editable-order/$orderId?orderType=$orderType');
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

  /// POST /reports/receiving — kirim tarixi.
  static Future<Map<String, dynamic>> getReceivingReport({Map<String, dynamic>? body}) async {
    return ApiClient.post('/reports/receiving', body: body ?? {});
  }

  static Future<Map<String, dynamic>> getReceivingFilter() async {
    return ApiClient.get('/reports/receiving/filter');
  }

  static Map<String, dynamic> receivingListBody({
    required String from,
    required String to,
    int rowLimit = 20,
    int rowOffset = 0,
  }) {
    return {
      'rowLimit': rowLimit,
      'rowOffset': rowOffset,
      'columnKey': 'date',
      'columnSortedBy': 'DESC',
      'filtersData': [
        {
          'filterKey': 'date_range',
          'value': [
            {'start': from, 'end': to},
          ],
        },
      ],
    };
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

/// Kompaniya branding (logo, theme)
class BrandingApi {
  /// GET /support/branding — joriy kompaniya (auth kerak)
  static Future<Map<String, dynamic>> getBranding() async {
    return ApiClient.get('/support/branding');
  }

  static String? logoUrlFromResponse(Map<String, dynamic> response) {
    final data = response['data'];
    if (data is! Map) return null;
    final url = data['app_logo_url'];
    if (url is String && url.trim().isNotEmpty) return url.trim();
    return null;
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
