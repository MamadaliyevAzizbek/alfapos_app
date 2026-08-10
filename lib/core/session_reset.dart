import 'package:shared_preferences/shared_preferences.dart';

import '../providers/cart_provider.dart';
import '../providers/cash_register_shift_provider.dart';
import '../providers/categories_provider.dart';
import '../providers/clients_provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/expenses_provider.dart';
import '../providers/products_provider.dart';
import '../providers/receive_session_provider.dart';
import '../providers/sales_session_provider.dart';
import '../providers/transactions_provider.dart';
import '../services/hold_order_register_tags_storage.dart';
import 'api_http.dart';
import 'api_sync_throttle.dart';
import 'auth_storage.dart';
import 'seller_preferences.dart';
import '../widgets/throttled_refresh_indicator.dart';

const String _keyLoginCompanyId = 'alfapos_login_companyId';
const String _keyLoginLogin = 'alfapos_login_login';
const String _keyLoginPassword = 'alfapos_login_password';

/// Logout yoki boshqa hisob bilan login — eski xodim ma'lumotlari qolmasin.
Future<void> resetAppSessionForAccountChange({
  bool clearSavedLoginForm = false,
}) async {
  ApiHttp.resetClient();
  ApiSyncThrottle.clearAll();
  PullRefreshGuard.reset();

  CartProvider.instance.clear();
  CashRegisterShiftProvider.instance.resetForAccountChange();
  ClientsProvider.instance.resetForAccountChange();
  DashboardProvider.instance.resetForAccountChange();
  ExpensesProvider.instance.resetForAccountChange();
  ProductsProvider.instance.resetForAccountChange();
  ReceiveSessionProvider.instance.resetForAccountChange();
  SalesSessionProvider.instance.resetForAccountChange();
  TransactionsProvider.instance.resetForAccountChange();
  await CategoriesProvider.instance.resetForAccountChange();

  await clearUserProfileCache();
  await _clearSalesSessionDiskCache();
  await HoldOrderRegisterTagsStorage.clear();

  if (clearSavedLoginForm) {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyLoginCompanyId);
    await prefs.remove(_keyLoginLogin);
    await prefs.remove(_keyLoginPassword);
  }
}

Future<void> _clearSalesSessionDiskCache() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(await companyStorageKey('alfapos_sales_products_v1'));
  await prefs.remove(await companyStorageKey('alfapos_sales_meta_v1'));
}
