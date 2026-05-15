/// Chekdagi bir mahsulot qatori (saqlash va ko'rsatish uchun)
class TransactionProductRow {
  final String productName;
  final String quantityStr;
  final int price;
  final int sum;
  /// Mahsulot id (qaytarishda omborga qaytarish uchun)
  final String? productId;
  /// Ombordan olib tashlangan dona (qaytarishda qaytariladi)
  final int quantityDeducted;

  const TransactionProductRow({
    required this.productName,
    required this.quantityStr,
    required this.price,
    required this.sum,
    this.productId,
    this.quantityDeducted = 0,
  });

  Map<String, dynamic> toJson() => {
        'productName': productName,
        'quantityStr': quantityStr,
        'price': price,
        'sum': sum,
        'productId': productId,
        'quantityDeducted': quantityDeducted,
      };

  static TransactionProductRow fromJson(Map<String, dynamic> json) =>
      TransactionProductRow(
        productName: json['productName'] as String? ?? '',
        quantityStr: json['quantityStr'] as String? ?? '',
        price: json['price'] as int? ?? 0,
        sum: json['sum'] as int? ?? 0,
        productId: json['productId'] as String?,
        quantityDeducted: json['quantityDeducted'] as int? ?? 0,
      );
}

/// Bitta sotuv tranzaksiyasi (chek) yozuvi
class TransactionRecord {
  final String receiptId;
  final String dateTime; // ISO8601
  final int totalSum;
  final int discountUzs;
  /// Kelish narxi bo'yicha jami (sof foyda = totalSum - totalCostUzs)
  final int totalCostUzs;
  /// To'lov turlari bo'yicha allocated summalar (kalit: API payment id yoki eski naqd/karta/...)
  final Map<String, int> payments;
  /// To'lov turi id -> nomi (API dan; eski cheklar uchun null)
  final Map<String, String>? paymentLabels;
  /// Chekdagi mahsulotlar ro'yxati
  final List<TransactionProductRow> productRows;
  final String? description;
  final String? sellerName;
  final String? clientName;
  /// Mijoz id (qaytarishda qarzni qaytarish uchun)
  final String? clientId;

  const TransactionRecord({
    required this.receiptId,
    required this.dateTime,
    required this.totalSum,
    this.discountUzs = 0,
    this.totalCostUzs = 0,
    required this.payments,
    this.paymentLabels,
    this.productRows = const [],
    this.description,
    this.sellerName,
    this.clientName,
    this.clientId,
  });

  Map<String, dynamic> toJson() => {
        'receiptId': receiptId,
        'dateTime': dateTime,
        'totalSum': totalSum,
        'discountUzs': discountUzs,
        'totalCostUzs': totalCostUzs,
        'payments': payments,
        'paymentLabels': paymentLabels,
        'productRows': productRows.map((e) => e.toJson()).toList(),
        'description': description,
        'sellerName': sellerName,
        'clientName': clientName,
        'clientId': clientId,
      };

  static TransactionRecord fromJson(Map<String, dynamic> json) {
    final pay = json['payments'];
    final Map<String, int> payments = {};
    if (pay is Map) {
      pay.forEach((k, v) {
        if (k is String && v != null) payments[k] = (v is int) ? v : int.tryParse(v.toString()) ?? 0;
      });
    }
    final labels = json['paymentLabels'];
    Map<String, String>? paymentLabels;
    if (labels is Map) {
      paymentLabels = {};
      labels.forEach((k, v) {
        if (k is String && v != null) paymentLabels![k] = v.toString();
      });
    }
    final rows = json['productRows'];
    List<TransactionProductRow> productRows = [];
    if (rows is List) {
      for (final e in rows) {
        if (e is Map<String, dynamic>) productRows.add(TransactionProductRow.fromJson(e));
      }
    }
    return TransactionRecord(
      receiptId: json['receiptId'] as String,
      dateTime: json['dateTime'] as String,
      totalSum: json['totalSum'] as int,
      discountUzs: json['discountUzs'] as int? ?? 0,
      totalCostUzs: json['totalCostUzs'] as int? ?? 0,
      payments: payments,
      paymentLabels: paymentLabels,
      productRows: productRows,
      description: json['description'] as String?,
      sellerName: json['sellerName'] as String?,
      clientName: json['clientName'] as String?,
      clientId: json['clientId'] as String?,
    );
  }

  DateTime get date => DateTime.tryParse(dateTime) ?? DateTime(0);
}
