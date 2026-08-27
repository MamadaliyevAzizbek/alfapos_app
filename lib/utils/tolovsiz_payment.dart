/// To'lovsiz to'lov — balans + qarz avtomatik taqsimot (TOLOVSIZ_PAYMENT_API.md).
class TolovsizPreview {
  final double balancePart;
  final double creditPart;
  const TolovsizPreview(this.balancePart, this.creditPart);
}

class TolovsizReturnPreview {
  final double debtPart;
  final double balanceRefundPart;
  const TolovsizReturnPreview(this.debtPart, this.balanceRefundPart);
}

class TolovsizPayment {
  TolovsizPayment._();

  static bool isEnabled(dynamic salesTolovsizPaymentEnabled) {
    if (salesTolovsizPaymentEnabled == null) return false;
    if (salesTolovsizPaymentEnabled is bool) return salesTolovsizPaymentEnabled;
    if (salesTolovsizPaymentEnabled is int) return salesTolovsizPaymentEnabled == 1;
    if (salesTolovsizPaymentEnabled is num) {
      return salesTolovsizPaymentEnabled.toInt() == 1;
    }
    final s = salesTolovsizPaymentEnabled.toString().trim().toLowerCase();
    return s == '1' || s == 'true' || s == 'yes';
  }

  /// GET /support/sales-settings javobidan to'lovsiz yoqilgan-yo'qligini o'qish.
  static bool parseEnabledFromSettingsResponse(Map<String, dynamic> res) {
    const keys = [
      'salesTolovsizPaymentEnabled',
      'sales_tolovsiz_payment_enabled',
    ];
    for (final k in keys) {
      if (res.containsKey(k)) return isEnabled(res[k]);
    }
    final data = res['data'];
    if (data is Map) {
      final m = Map<String, dynamic>.from(data);
      for (final k in keys) {
        if (m.containsKey(k)) return isEnabled(m[k]);
      }
    }
    final settings = res['settings'];
    if (settings is Map) {
      final m = Map<String, dynamic>.from(settings);
      for (final k in keys) {
        if (m.containsKey(k)) return isEnabled(m[k]);
      }
    }
    return false;
  }

  static bool isContext({
    required bool featureEnabled,
    required int? customerId,
  }) =>
      featureEnabled && customerId != null && customerId > 0;

  static bool isPaymentType(Map<String, dynamic> e) {
    final type = (e['type'] ?? e['payment_type'] ?? '').toString().toLowerCase();
    if (type == 'tolovsiz') return true;
    final name = (e['name'] ?? e['title'] ?? e['payment_method'] ?? '')
        .toString()
        .toLowerCase();
    final compact = name.replaceAll(RegExp(r"[\s'’`\-_]"), '');
    return compact.contains('tolovsiz') || name.contains("to'lovsiz");
  }

  static bool isHiddenInSales(Map<String, dynamic> e) {
    final v = e['hide_in_sales'] ?? e['hideInSales'];
    if (v is int) return v == 1;
    if (v is bool) return v;
    return v?.toString() == '1';
  }

  /// Sotuv: avval balans, qolgani qarz.
  static TolovsizPreview previewSale({
    required double remaining,
    required double customerBalance,
    double alreadyUsedBalance = 0,
  }) {
    if (remaining <= 0) return const TolovsizPreview(0, 0);
    final avail = (customerBalance - alreadyUsedBalance).clamp(0.0, double.infinity).toDouble();
    final balancePart = avail < remaining ? avail : remaining;
    final creditPart = (remaining - balancePart).clamp(0.0, double.infinity).toDouble();
    return TolovsizPreview(balancePart, creditPart);
  }

  /// Qaytarish: avval qarz, qolgani balansga (TOLOVSIZ_SALES_RETURNS_API.md §9).
  static TolovsizReturnPreview previewReturn({
    required double returnAbs,
    required double customerDueAmount,
    double otherRefundsAbs = 0,
  }) {
    if (returnAbs <= 0) return const TolovsizReturnPreview(0, 0);
    final remaining = (returnAbs - otherRefundsAbs).clamp(0.0, double.infinity).toDouble();
    if (remaining <= 0) return const TolovsizReturnPreview(0, 0);
    final debtPart = remaining < customerDueAmount ? remaining : customerDueAmount;
    final balanceRefundPart = (remaining - debtPart).clamp(0.0, double.infinity).toDouble();
    return TolovsizReturnPreview(debtPart, balanceRefundPart);
  }

  static bool usesTolovsizInAllocated(
    Map<String, num> allocated,
    bool Function(String paymentId) isTolovsizById,
  ) {
    for (final e in allocated.entries) {
      if (isTolovsizById(e.key) && e.value > 0) return true;
    }
    return false;
  }

  static bool debtLimitOk({
    required double currentDebt,
    required int? debtLimit,
    required double creditPart,
  }) {
    if (debtLimit == null || debtLimit <= 0) return true;
    return (currentDebt + creditPart) <= debtLimit;
  }

  static bool isBlacklisted(int? debtLimit) => debtLimit == -1;

  static String paymentTimeNow() {
    final now = DateTime.now();
    final y = now.year;
    final mo = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    final h = now.hour.toString().padLeft(2, '0');
    final mi = now.minute.toString().padLeft(2, '0');
    return '$y-$mo-$d $h:$mi';
  }

  static Map<String, dynamic> buildStorePaymentRow({
    required int paymentTypeId,
    required String paymentName,
    required num amount,
    required bool isReturn,
  }) {
    final paid = isReturn ? -amount.abs() : amount.abs();
    return {
      'paid': paid.toStringAsFixed(3),
      'paymentID': paymentTypeId,
      'paymentName': paymentName,
      'paymentType': 'tolovsiz',
      'PaymentTime': paymentTimeNow(),
      'options': <String, dynamic>{},
      'is_active': 1,
      'exchange': 0,
    };
  }
}
