import 'package:flutter/foundation.dart';

import '../core/api_sync_throttle.dart';

/// Tranzaksiyalar / sotish ro‘yxati — to‘lovdan keyin va tab ochilganda yangilash.
class SalesListRefresh {
  SalesListRefresh._();

  static const throttleKey = 'transactions_sales_list';

  /// Har bir muvaffaqiyatli sotuv / tahrir keyin oshadi.
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static void notifyChanged() {
    ApiSyncThrottle.invalidate(throttleKey);
    revision.value = revision.value + 1;
  }
}
