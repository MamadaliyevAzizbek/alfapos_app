import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

import 'thermal_receipt_formatter.dart';

/// API `templateData.content` HTML → Alfapos.pdf ko‘rinishidagi chek.
class ApiReceiptHtmlParser {
  ApiReceiptHtmlParser._();

  static const _tableHeaders = {'mahsulot', 'miqdor', 'narx', 'summa'};

  /// HTML → chop etish qatorlari (PDF format).
  static List<String> toPrintLines(String html) {
    return ThermalReceiptFormatter.toPrintLines(toPrintData(html));
  }

  /// HTML → strukturali chek (keyin formatlash).
  static ThermalReceiptPrintData toPrintData(String html) {
    final rawHtml = html.trim();
    if (rawHtml.isEmpty) {
      return ThermalReceiptPrintData(
        storeName: 'Alfa market',
        dateTime: DateTime.now(),
        receiptNumber: '',
        sellerName: 'Sotuvchi',
        totalAmount: '0',
      );
    }

    if (!rawHtml.contains('<')) {
      return _printDataFromRaw(_normalizeLines(rawHtml.split(RegExp(r'\r?\n'))));
    }

    final doc = html_parser.parse(rawHtml);
    final body = doc.body ?? doc.documentElement;
    if (body == null) {
      return _printDataFromRaw(_normalizeLines(_stripTags(rawHtml).split('\n')));
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

    final metaLines = <String>[];
    final tableRows = _collectTableRows(body);

    void walkMeta(Node node, {required bool insideTable}) {
      if (node is Text) {
        if (insideTable) return;
        final t = _decode(node.text.replaceAll(RegExp(r'\s+'), ' ').trim());
        if (t.isNotEmpty) metaLines.add(t);
        return;
      }
      if (node is! Element) return;

      final tag = node.localName?.toLowerCase() ?? '';
      if (tag == 'style' || tag == 'script' || tag == 'head' || tag == 'meta') {
        return;
      }
      if (tag == 'table' || tag == 'tbody' || tag == 'thead' || tag == 'tfoot' || tag == 'tr') {
        return;
      }

      if (tag == 'p' || tag == 'h1' || tag == 'h2' || tag == 'h3' || tag == 'h4') {
        final block = _elementText(node).trim();
        if (block.isNotEmpty) metaLines.add(block);
        return;
      }

      if (tag == 'div') {
        if (_hasTableDescendant(node)) {
          for (final child in node.nodes) {
            walkMeta(child, insideTable: false);
          }
          return;
        }
        final block = _elementText(node).trim();
        if (block.isNotEmpty) metaLines.add(block);
        return;
      }

      for (final child in node.nodes) {
        walkMeta(child, insideTable: insideTable);
      }
    }

    walkMeta(body, insideTable: false);

    // Avval sarlavha (do'kon, sana, sotuvchi) — jadvaldan oldin
    for (final line in _normalizeLines(metaLines)) {
      if (_isLikelyStoreName(line)) {
        storeName = line;
        break;
      }
    }
    for (final line in _normalizeLines(metaLines)) {
      final lower = line.toLowerCase();
      final dt = _parseDateTime(line);
      if (dt != null) {
        dateTime = dt;
        continue;
      }
      if (lower.startsWith('chek raqami')) {
        receiptNumber = _afterColon(line);
        continue;
      }
      if (lower.startsWith('sotuvchi nomeri') || lower.startsWith('sotuvchi telefon')) {
        sellerPhone = _afterColon(line);
        continue;
      }
      if (lower.startsWith('sotuvchi')) {
        sellerName = _afterColon(line);
        continue;
      }
      if (lower.startsWith('mijoz') && !lower.contains('telefon')) {
        final v = _afterColon(line);
        if (v.isNotEmpty) clientName = v;
      }
    }

    // Jadval qatorlari (gorizontal yoki vertikal)
    final pendingVertical = <String>[];
    for (var ri = 0; ri < tableRows.length; ri++) {
      final cells = tableRows[ri];

      if (cells.length == 1 && _containsTableHeaderWords(cells[0].toLowerCase())) {
        var price = '';
        var total = '';
        var j = ri + 1;
        while (j < tableRows.length &&
            tableRows[j].length == 1 &&
            _looksNumeric(tableRows[j][0])) {
          if (price.isEmpty) {
            price = tableRows[j][0];
          } else {
            total = tableRows[j][0];
          }
          j++;
        }
        final tail = _stripLeadingTableHeaders(cells[0]);
        final nq = _splitNameAndQty(tail);
        if (nq != null) {
          products.add(
            ThermalReceiptProductLine(
              name: nq.$1,
              quantity: nq.$2,
              unitPrice: price.isNotEmpty ? price : total,
              lineTotal: total.isNotEmpty ? total : price,
            ),
          );
        }
        ri = j - 1;
        continue;
      }
      if (cells.length > 4 && _isHeaderCells(cells.sublist(0, 4))) {
        if (_flushVerticalProduct(pendingVertical, products)) {
          pendingVertical.clear();
        }
        final rest = cells.sublist(4);
        final product = _productFromFlexibleCells(rest);
        if (product != null) products.add(product);
        continue;
      }
      if (cells.length >= 4) {
        if (_isHeaderCells(cells)) continue;
        if (_flushVerticalProduct(pendingVertical, products)) {
          pendingVertical.clear();
        }
        products.add(_productFromCells(cells));
        continue;
      }
      if (cells.length == 3) {
        if (_isHeaderCells(cells)) continue;
        if (_flushVerticalProduct(pendingVertical, products)) {
          pendingVertical.clear();
        }
        products.add(
          ThermalReceiptProductLine(
            name: cells[0],
            quantity: cells[1],
            unitPrice: cells[1],
            lineTotal: cells[2],
          ),
        );
        continue;
      }
      if (cells.length == 2) {
        if (_flushVerticalProduct(pendingVertical, products)) {
          pendingVertical.clear();
        }
        final lower0 = cells[0].toLowerCase();
        final lower1 = cells[1].toLowerCase();
        if (lower0.contains('chegirma')) {
          discount = cells[1];
        } else if (lower0.contains('umumiy summa')) {
          total = cells[1];
        } else if (_looksNumeric(cells[1])) {
          payments.add(ThermalReceiptPaymentLine(method: cells[0], amount: cells[1]));
        } else {
          metaLines.add('${cells[0]}  ${cells[1]}');
        }
        continue;
      }
      if (cells.length == 1) {
        pendingVertical.add(cells[0]);
        if (pendingVertical.length >= 4) {
          if (!_isHeaderCells(pendingVertical)) {
            products.add(_productFromCells(pendingVertical.sublist(0, 4)));
          }
          pendingVertical.clear();
        }
      }
    }
    if (pendingVertical.length >= 4 && !_isHeaderCells(pendingVertical)) {
      products.add(_productFromCells(pendingVertical.sublist(0, 4)));
    }

    _parseMetaProductLines(_normalizeLines(metaLines), products);

    if (sellerName.isEmpty) sellerName = 'Sotuvchi';
    if (total == '0' && products.isNotEmpty) {
      total = products.last.lineTotal;
    }

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
      totalAmount: total,
    );
  }

  /// Matn qatorlari (HTML bo‘lmaganda) — xuddi PDF formatiga o‘tkazish.
  static ThermalReceiptPrintData _printDataFromRaw(List<String> raw) {
    return ThermalReceiptFormatter.parseApiRawLines(raw);
  }

  static List<List<String>> _collectTableRows(Element root) {
    final rows = <List<String>>[];
    for (final tr in root.querySelectorAll('tr')) {
      final cells = _rowCells(tr);
      if (cells.isNotEmpty) rows.add(cells);
    }
    return rows;
  }

  static List<String> _rowCells(Element tr) {
    final cells = <String>[];
    for (final child in tr.children) {
      final ct = child.localName?.toLowerCase();
      if (ct == 'td' || ct == 'th') {
        final t = _elementText(child).trim();
        if (t.isNotEmpty) cells.add(t);
      }
    }
    return cells;
  }

  static bool _isHeaderCells(List<String> cells) {
    final lower = cells.map((c) => c.trim().toLowerCase()).where((c) => c.isNotEmpty).toList();
    if (lower.length < 2) return false;
    final headerHits = lower.where(_tableHeaders.contains).length;
    return headerHits >= 2 && headerHits == lower.length;
  }

  static bool _isLikelyStoreName(String line) {
    final lower = line.toLowerCase();
    if (_containsTableHeaderWords(lower)) return false;
    if (lower.contains('chek') || lower.contains('sotuv') || lower.contains('mijoz')) {
      return false;
    }
    if (_looksLikeDate(line) || line.contains(':')) return false;
    if (line.length > 40) return false;
    return true;
  }

  static bool _containsTableHeaderWords(String lower) {
    for (final h in _tableHeaders) {
      if (lower.contains(h)) return true;
    }
    return false;
  }

  /// Bir qatorda «Mahsulot Miqdor Narx Summa sprite 4шт» + keyingi narx qatorlari.
  static void _parseMetaProductLines(
    List<String> meta,
    List<ThermalReceiptProductLine> products,
  ) {
    for (var i = 0; i < meta.length; i++) {
      final line = meta[i];
      if (!_containsTableHeaderWords(line.toLowerCase())) continue;
      final tail = _stripLeadingTableHeaders(line);
      if (tail.isEmpty) continue;

      var price = '';
      var total = '';
      var j = i + 1;
      while (j < meta.length && _looksNumeric(meta[j])) {
        if (price.isEmpty) {
          price = meta[j];
        } else if (total.isEmpty) {
          total = meta[j];
        } else {
          break;
        }
        j++;
      }

      final nq = _splitNameAndQty(tail);
      if (nq == null) continue;
      if (products.any((p) => p.name == nq.$1)) continue;

      products.add(
        ThermalReceiptProductLine(
          name: nq.$1,
          quantity: nq.$2,
          unitPrice: price.isNotEmpty ? price : total,
          lineTotal: total.isNotEmpty ? total : price,
        ),
      );
    }
  }

  static String _stripLeadingTableHeaders(String line) {
    var t = line.trim();
    const ordered = ['Mahsulot', 'Miqdor', 'Narx', 'Summa'];
    for (final h in ordered) {
      final re = RegExp('^$h\\s*', caseSensitive: false);
      t = t.replaceFirst(re, '').trim();
    }
    return t;
  }

  static (String, String)? _splitNameAndQty(String tail) {
    final t = tail.trim();
    if (t.isEmpty) return null;
    final m = RegExp(
      r'^(.+?)\s+(\d+[\.,]?\d*\s*(?:шт|sh|dona|kg|g|l|ml|pachka)|\d+\s*x\s*[\d,.]+)$',
      caseSensitive: false,
    ).firstMatch(t);
    if (m != null) {
      return (m.group(1)!.trim(), m.group(2)!.trim());
    }
    final parts = t.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return (parts.sublist(0, parts.length - 1).join(' '), parts.last);
    }
    return (t, '1');
  }

  static ThermalReceiptProductLine? _productFromFlexibleCells(List<String> cells) {
    if (cells.isEmpty) return null;
    if (cells.length >= 4) return _productFromCells(cells);
    if (cells.length == 3) {
      return ThermalReceiptProductLine(
        name: cells[0],
        quantity: cells[1],
        unitPrice: cells[1],
        lineTotal: cells[2],
      );
    }
    if (cells.length == 2) {
      return ThermalReceiptProductLine(
        name: cells[0],
        quantity: cells[1],
        unitPrice: cells[1],
        lineTotal: cells[1],
      );
    }
    return ThermalReceiptProductLine(
      name: cells[0],
      quantity: '1',
      unitPrice: '0',
      lineTotal: '0',
    );
  }

  static ThermalReceiptProductLine _productFromCells(List<String> cells) {
    if (cells.length >= 4) {
      return ThermalReceiptProductLine(
        name: cells[0],
        quantity: cells[1],
        unitPrice: cells[2],
        lineTotal: cells[3],
      );
    }
    return ThermalReceiptProductLine(
      name: cells[0],
      quantity: cells.length > 1 ? cells[1] : '1',
      unitPrice: cells.length > 2 ? cells[2] : '0',
      lineTotal: cells.length > 3 ? cells[3] : cells.last,
    );
  }

  static bool _flushVerticalProduct(List<String> buf, List<ThermalReceiptProductLine> out) {
    if (buf.length >= 4 && !_isHeaderCells(buf)) {
      out.add(_productFromCells(buf.sublist(0, 4)));
      return true;
    }
    return false;
  }

  static bool _hasTableDescendant(Element el) {
    for (final d in el.querySelectorAll('table')) {
      if (d != null) return true;
    }
    return false;
  }

  static String _elementText(Element el) {
    final buf = StringBuffer();
    void collect(Node n) {
      if (n is Text) {
        buf.write(n.text);
      } else if (n is Element) {
        if (n.localName?.toLowerCase() == 'br') buf.write(' ');
        for (final c in n.nodes) collect(c);
      }
    }
    for (final n in el.nodes) collect(n);
    return _decode(buf.toString().replaceAll(RegExp(r'\s+'), ' ').trim());
  }

  static String _stripTags(String html) {
    return html.replaceAll(RegExp(r'<[^>]*>'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static String _decode(String s) {
    return s
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'");
  }

  static List<String> _normalizeLines(List<String> lines) {
    final out = <String>[];
    String? prev;
    for (final line in lines) {
      final t = line.trim();
      if (t.isEmpty) continue;
      if (prev == t) continue;
      out.add(t);
      prev = t;
    }
    return out;
  }

  static bool _looksLikeDate(String s) => RegExp(r'\d{4}-\d{2}-\d{2}').hasMatch(s);

  static bool _looksNumeric(String s) {
    final t = s.replaceAll(RegExp(r'[^\d,.]'), '');
    return t.isNotEmpty && RegExp(r'\d').hasMatch(t);
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
}
