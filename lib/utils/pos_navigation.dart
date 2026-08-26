import 'package:flutter/foundation.dart';

/// Tranzaksiya/hisobotdan sotuv (savatcha) bo‘limiga o‘tish.
///
/// Callback o‘rniga [ValueNotifier] — DesktopShell/MainShell listener orqali
/// ishonchli tab almashtirish (callback overwrite muammosi yo‘q).
class PosNavigation {
  PosNavigation._();

  /// Har bir o‘sish = «Sotuv bo‘limiga o‘t» so‘rovi.
  static final ValueNotifier<int> openSalesRequest = ValueNotifier(0);

  /// Har bir o‘sish = «Tranzaksiyalar» so‘rovi.
  static final ValueNotifier<int> openTransactionsRequest = ValueNotifier(0);

  /// Eski API (ixtiyoriy qo‘shimcha).
  static VoidCallback? openSalesSection;
  static VoidCallback? openTransactionsSection;

  static void goToSales() {
    openSalesRequest.value++;
    openSalesSection?.call();
  }

  static void goToTransactions() {
    openTransactionsRequest.value++;
    openTransactionsSection?.call();
  }
}
