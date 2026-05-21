import '../models/receipt_design_config.dart';
import 'thermal_receipt_line_wrap.dart';

/// Termal chek mahsulot qatori (Alfapos.pdf ko‘rinishi).
class ThermalReceiptProductLine {
  final String name;
  final String quantity;
  final String unitPrice;
  final String lineTotal;

  const ThermalReceiptProductLine({
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
  });
}

/// Termal chek to‘lov qatori.
class ThermalReceiptPaymentLine {
  final String method;
  final String amount;

  const ThermalReceiptPaymentLine({
    required this.method,
    required this.amount,
  });
}

/// Chop etish uchun chek ma’lumoti (Alfapos.pdf).
class ThermalReceiptPrintData {
  final String storeName;
  final DateTime dateTime;
  final String receiptNumber;
  final String sellerName;
  final String? sellerPhone;
  final String? clientName;
  final String? clientPhone;
  final String? clientAddress;
  final List<ThermalReceiptProductLine> products;
  final List<ThermalReceiptPaymentLine> payments;
  final String discountAmount;
  final String totalAmount;
  final bool isPrecheck;

  const ThermalReceiptPrintData({
    required this.storeName,
    required this.dateTime,
    required this.receiptNumber,
    required this.sellerName,
    this.sellerPhone,
    this.clientName,
    this.clientPhone,
    this.clientAddress,
    this.products = const [],
    this.payments = const [],
    this.discountAmount = '0',
    required this.totalAmount,
    this.isPrecheck = false,
  });
}

/// Alfapos.pdf — markaziy sarlavha, raqamlangan mahsulotlar, o‘ngga tekislangan summalar.
class ThermalReceiptFormatter {
  ThermalReceiptFormatter._();

  static const _itemSep = '--------------------------------';
  static const _tableHeaders = {'mahsulot', 'miqdor', 'narx', 'summa'};

  /// API matn qatorlari → struktura (HTML dan keyin yoki zaxira).
  static ThermalReceiptPrintData parseApiRawLines(List<String> raw) {
    if (raw.isEmpty) {
      return ThermalReceiptPrintData(
        storeName: 'Alfa market',
        dateTime: DateTime.now(),
        receiptNumber: '',
        sellerName: 'Sotuvchi',
        totalAmount: '0',
      );
    }

    var storeName = 'Alfa market';
    var dateTime = DateTime.now();
    var receiptNumber = '';
    var sellerName = '';
    String? sellerPhone;
    String? clientName;
    final products = <ThermalReceiptProductLine>[];
    final payments = <ThermalReceiptPaymentLine>[];
    var discount = '0';
    var total = '0';

    var i = 0;
    while (i < raw.length) {
      final line = raw[i].trim();
      if (line.isEmpty) {
        i++;
        continue;
      }

      if (_isTableHeaderBlock(raw, i)) {
        i += 4;
        continue;
      }

      if (_isProductBlock(raw, i)) {
        products.add(
          ThermalReceiptProductLine(
            name: raw[i].trim(),
            quantity: raw[i + 1].trim(),
            unitPrice: _withSom(raw[i + 2].trim()),
            lineTotal: _withSom(raw[i + 3].trim()),
          ),
        );
        i += 4;
        continue;
      }

      final lower = line.toLowerCase();
      if (products.isEmpty &&
          payments.isEmpty &&
          !lower.contains('chek') &&
          !lower.contains('sotuv') &&
          !_looksLikeDate(line) &&
          !line.contains(':') &&
          !_containsTableHeaderWords(lower) &&
          line.length <= 40) {
        storeName = line;
        i++;
        continue;
      }

      final combined = _tryParseCombinedHeaderLine(raw, i);
      if (combined != null) {
        products.add(combined.$1);
        i = combined.$2;
        continue;
      }

      final dt = _parseDateTime(line);
      if (dt != null) {
        dateTime = dt;
        i++;
        continue;
      }

      if (lower.startsWith('chek raqami')) {
        receiptNumber = _afterColon(line);
        i++;
        continue;
      }
      if (lower.startsWith('sotuvchi nomeri') || lower.startsWith('sotuvchi telefon')) {
        sellerPhone = _afterColon(line);
        i++;
        continue;
      }
      if (lower.startsWith('sotuvchi')) {
        sellerName = _afterColon(line);
        i++;
        continue;
      }
      if (lower.startsWith('mijoz') && !lower.contains('telefon')) {
        final v = _afterColon(line);
        if (v.isNotEmpty) clientName = v;
        i++;
        continue;
      }

      if (_isSkippableMeta(line)) {
        i++;
        continue;
      }

      if (lower.startsWith('chegirma')) {
        discount = _extractTrailingAmount(line) ?? _afterColon(line);
        if (discount.isEmpty && i + 1 < raw.length) {
          discount = raw[i + 1].trim();
          i++;
        }
        i++;
        continue;
      }

      if (lower.contains('umumiy summa')) {
        total = _extractTrailingAmount(line) ?? _afterColon(line);
        if (total.isEmpty && i + 1 < raw.length) {
          total = raw[i + 1].trim();
          i++;
        }
        i++;
        continue;
      }

      final payment = _parsePaymentLine(line);
      if (payment != null) {
        payments.add(payment);
        i++;
        continue;
      }

      i++;
    }

    if (sellerName.isEmpty) sellerName = 'Sotuvchi';

    return ThermalReceiptPrintData(
      storeName: storeName,
      dateTime: dateTime,
      receiptNumber: receiptNumber,
      sellerName: sellerName,
      sellerPhone: sellerPhone,
      clientName: clientName,
      products: products,
      payments: payments,
      discountAmount: discount,
      totalAmount: total.isEmpty ? '0' : total,
    );
  }

  /// API HTML parser chiqishi → PDF ko‘rinishidagi qatorlar.
  static List<String> fromApiRawLines(List<String> raw) {
    return toPrintLines(parseApiRawLines(raw));
  }

  static List<String> toPrintLines(
    ThermalReceiptPrintData d, {
    ReceiptDesignConfig config = ReceiptDesignConfig.defaults,
  }) {
    final lines = <String>[];
    final sep = config.itemSeparator;
    String som(String amount) => _withSom(amount, suffix: config.currencySuffix);

    void center(String s) => lines.add('^${s.trim()}');
    void left(String s) {
      for (final part in ThermalReceiptLineWrap.wrapLine(s)) {
        lines.add(part);
      }
    }

    final title = config.titleForBranch(d.storeName);
    center(title);
    if (config.showDateTime) {
      center(_fmtDateTime(d.dateTime));
    }
    lines.add('');

    if (d.isPrecheck) {
      center(config.precheckBanner);
      lines.add('');
      left("${config.receiptNumberLabel}: to'lov oldin");
    } else if (d.receiptNumber.isNotEmpty) {
      left('${config.receiptNumberLabel}: ${d.receiptNumber}');
    }
    left('${config.sellerLabel}: ${d.sellerName}');
    if (config.showSellerPhone &&
        d.sellerPhone != null &&
        d.sellerPhone!.trim().isNotEmpty) {
      left('${config.sellerPhoneLabel}: ${d.sellerPhone!.trim()}');
    }
    if (config.showClientLine &&
        d.clientName != null &&
        d.clientName!.trim().isNotEmpty) {
      left('${config.clientLabel}: ${d.clientName!.trim()}');
    }
    if (config.showClientPhone &&
        d.clientPhone != null &&
        d.clientPhone!.trim().isNotEmpty) {
      left('${config.clientPhoneLabel}: ${d.clientPhone!.trim()}');
    }
    if (config.showClientAddress &&
        d.clientAddress != null &&
        d.clientAddress!.trim().isNotEmpty) {
      left('${config.clientAddressLabel}: ${d.clientAddress!.trim()}');
    }
    lines.add('');

    var n = 0;
    for (final p in d.products) {
      n++;
      if (config.numberedProducts) {
        left('$n) ${p.name}');
      } else {
        left(p.name);
      }
      final sumPart = p.lineTotal.contains('so\'m') || p.lineTotal.contains('sum')
          ? p.lineTotal
          : som(p.lineTotal);
      final qtyPart = _productQtyLine(p, suffix: config.currencySuffix);
      lines.add(
        ThermalReceiptLineWrap.formatTwoColumns(qtyPart, sumPart, rightWidth: 16),
      );
      if (config.showItemSeparator) {
        lines.add(sep);
      }
    }

    if (!d.isPrecheck) {
      for (final pay in d.payments) {
        lines.add(
          ThermalReceiptLineWrap.formatTwoColumns(
            pay.method,
            som(pay.amount),
            rightWidth: 16,
          ),
        );
      }
    }

    lines.add(
      ThermalReceiptLineWrap.formatTwoColumns(
        config.discountLabel,
        som(d.discountAmount),
        rightWidth: 16,
      ),
    );
    if (config.showItemSeparator) {
      lines.add(sep);
    }
    lines.add(
      ThermalReceiptLineWrap.formatTwoColumns(
        config.totalLabel,
        som(d.totalAmount),
        rightWidth: 16,
      ),
    );

    if (config.showFooter && config.footerText.trim().isNotEmpty) {
      lines.add('');
      center(config.footerText.trim());
    }

    if (d.isPrecheck) {
      lines.add('');
      left("To'lov hali amalga oshirilmagan");
    }

    return ThermalReceiptLineWrap.wrapAll(lines);
  }

  static bool _isTableHeaderBlock(List<String> raw, int i) {
    if (i + 3 >= raw.length) return false;
    final keys = [raw[i], raw[i + 1], raw[i + 2], raw[i + 3]]
        .map((s) => s.trim().toLowerCase())
        .toList();
    return _tableHeaders.contains(keys[0]) &&
        _tableHeaders.contains(keys[1]) &&
        _tableHeaders.contains(keys[2]) &&
        _tableHeaders.contains(keys[3]);
  }

  static bool _isProductBlock(List<String> raw, int i) {
    if (i + 3 >= raw.length) return false;
    if (_isTableHeaderBlock(raw, i)) return false;
    final name = raw[i].trim();
    if (name.isEmpty) return false;
    final headerWords = _tableHeaders;
    if (headerWords.contains(name.toLowerCase())) return false;
    final qty = raw[i + 1].trim();
    final price = raw[i + 2].trim();
    final sum = raw[i + 3].trim();
    if (!_looksNumeric(price) || !_looksNumeric(sum)) return false;
    return qty.isNotEmpty;
  }

  static bool _containsTableHeaderWords(String lower) {
    for (final h in _tableHeaders) {
      if (lower.contains(h)) return true;
    }
    return false;
  }

  /// «Mahsulot Miqdor Narx Summa sprite 4шт» + 2,000 + 8,000
  static (ThermalReceiptProductLine, int)? _tryParseCombinedHeaderLine(
    List<String> raw,
    int i,
  ) {
    final line = raw[i].trim();
    final lower = line.toLowerCase();
    if (!_containsTableHeaderWords(lower) || !lower.contains('summa')) return null;

    var t = line;
    for (final h in ['Mahsulot', 'Miqdor', 'Narx', 'Summa']) {
      t = t.replaceFirst(RegExp('^$h\\s*', caseSensitive: false), '').trim();
    }
    if (t.isEmpty) return null;

    var price = '';
    var total = '';
    var j = i + 1;
    while (j < raw.length && _looksNumeric(raw[j])) {
      if (price.isEmpty) {
        price = raw[j].trim();
      } else if (total.isEmpty) {
        total = raw[j].trim();
      } else {
        break;
      }
      j++;
    }

    final parts = t.split(RegExp(r'\s+'));
    if (parts.isEmpty) return null;
    String name;
    String qty;
    if (parts.length >= 2) {
      qty = parts.last;
      name = parts.sublist(0, parts.length - 1).join(' ');
    } else {
      name = t;
      qty = '1';
    }

    return (
      ThermalReceiptProductLine(
        name: name,
        quantity: qty,
        unitPrice: price.isNotEmpty ? price : total,
        lineTotal: total.isNotEmpty ? total : price,
      ),
      j,
    );
  }

  static bool _looksNumeric(String s) {
    final t = s.replaceAll(RegExp(r'[^\d,.]'), '');
    return t.isNotEmpty && RegExp(r'\d').hasMatch(t);
  }

  static bool _looksLikeDate(String s) {
    return RegExp(r'\d{4}-\d{2}-\d{2}').hasMatch(s);
  }

  static DateTime? _parseDateTime(String line) {
    final m = RegExp(
      r'(\d{4})-(\d{2})-(\d{2})\s*[-|]\s*(\d{1,2}):(\d{2})(?::(\d{2}))?',
    ).firstMatch(line);
    if (m == null) return null;
    return DateTime(
      int.parse(m.group(1)!),
      int.parse(m.group(2)!),
      int.parse(m.group(3)!),
      int.parse(m.group(4)!),
      int.parse(m.group(5)!),
      m.group(6) != null ? int.parse(m.group(6)!) : 0,
    );
  }

  static String _fmtDateTime(DateTime d) {
    final date =
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final time =
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}:${d.second.toString().padLeft(2, '0')}';
    return '$date | $time';
  }

  static String _afterColon(String line) {
    final idx = line.indexOf(':');
    if (idx < 0) return line.trim();
    return line.substring(idx + 1).trim();
  }

  static bool _isSkippableMeta(String line) {
    final lower = line.toLowerCase();
    if (lower.startsWith('mijoz telefon') && _afterColon(line).isEmpty) return true;
    if (lower.startsWith('manzil') && _afterColon(line).isEmpty) return true;
    if (lower.startsWith('izoh') && _afterColon(line).isEmpty) return true;
    if (lower.startsWith('qarz muddat') && _afterColon(line).isEmpty) return true;
    return false;
  }

  static ThermalReceiptPaymentLine? _parsePaymentLine(String line) {
    final lower = line.toLowerCase();
    if (lower.startsWith('chegirma') || lower.contains('umumiy summa')) return null;
    final amount = _extractTrailingAmount(line);
    if (amount == null) return null;
    var method = line.substring(0, line.lastIndexOf(amount)).trim();
    method = method.replaceAll(RegExp(r'\s+\d{4}-\d{2}-\d{2}.*$'), '').trim();
    if (method.isEmpty) return null;
    return ThermalReceiptPaymentLine(method: method, amount: amount);
  }

  static String? _extractTrailingAmount(String line) {
    final m = RegExp(r'([\d][\d\s,.]*)\s*$').firstMatch(line.trim());
    return m?.group(1)?.trim();
  }

  static String _withSom(String amount, {String suffix = "so'm"}) {
    final t = amount.trim();
    final suf = suffix.trim().isEmpty ? "so'm" : suffix.trim();
    if (t.isEmpty) return '0 $suf';
    final lower = t.toLowerCase();
    if (lower.contains("so'm") || lower.contains('sum') || lower.endsWith(suf.toLowerCase())) {
      return t;
    }
    return '$t $suf';
  }

  static String _productQtyLine(ThermalReceiptProductLine p, {String suffix = "so'm"}) {
    final qty = p.quantity.trim();
    final price = p.unitPrice.replaceAll(RegExp(r"\s*so'm\.?\s*$", caseSensitive: false), '').trim();
    final total = p.lineTotal.replaceAll(RegExp(r"\s*so'm\.?\s*$", caseSensitive: false), '').trim();
    final suf = suffix.trim().isEmpty ? "so'm" : suffix.trim();
    if (qty.contains('x') || qty.contains('×')) {
      return '${qty.replaceAll('×', 'x')} $suf.';
    }
    if (price.isNotEmpty && price != total && _looksNumeric(price)) {
      return '$qty x $price $suf.';
    }
    if (price.isNotEmpty && price == qty && _looksNumeric(total)) {
      return '$qty x $total $suf.';
    }
    return '$qty x $price $suf.';
  }
}
