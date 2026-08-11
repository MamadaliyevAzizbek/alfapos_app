import 'package:flutter/foundation.dart';

import '../services/reports_repository.dart';

/// Eski to‘lov yorliqlari — yangi kod [ReportsRepository.paymentTypeLabels] ishlatsin.
const Map<String, String> paymentTypeLabels = ReportsRepository.paymentTypeLabels;

/// Lokal tranzaksiya ro‘yxati yo‘q — hisobotlar [ReportsRepository] orqali.
class TransactionsProvider extends ChangeNotifier {
  TransactionsProvider._();
  static final TransactionsProvider _instance = TransactionsProvider._();
  static TransactionsProvider get instance => _instance;

  void resetForAccountChange() {
    notifyListeners();
  }
}
