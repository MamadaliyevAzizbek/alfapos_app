import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

/// API `templateData.content` HTML → termal chek matn qatorlari.
class ApiReceiptHtmlParser {
  ApiReceiptHtmlParser._();

  /// HTML teglarini olib tashlab, chekda ko'rinadigan qatorlarni qaytaradi.
  static List<String> toPrintLines(String html) {
    final raw = html.trim();
    if (raw.isEmpty) return [];

    if (!raw.contains('<')) {
      return _normalizeLines(raw.split(RegExp(r'\r?\n')));
    }

    final doc = html_parser.parse(raw);
    final body = doc.body ?? doc.documentElement;
    if (body == null) return _normalizeLines(_stripTags(raw).split('\n'));

    final lines = <String>[];
    _walk(body, lines, inTable: false);
    return _normalizeLines(lines);
  }

  static void _walk(Node node, List<String> lines, {required bool inTable}) {
    if (node is Text) {
      final t = _decode(node.text.replaceAll(RegExp(r'\s+'), ' ').trim());
      if (t.isNotEmpty) {
        if (inTable && lines.isNotEmpty) {
          final last = lines.last;
          if (!last.contains(t)) {
            lines[lines.length - 1] = '$last  $t';
          }
        } else {
          lines.add(t);
        }
      }
      return;
    }

    if (node is! Element) return;

    final tag = node.localName?.toLowerCase() ?? '';

    if (tag == 'style' || tag == 'script' || tag == 'head') return;

    if (tag == 'br') {
      lines.add('');
      return;
    }

    if (tag == 'tr') {
      final cells = <String>[];
      for (final child in node.children) {
        if (child.localName?.toLowerCase() == 'td' || child.localName?.toLowerCase() == 'th') {
          final cellText = _elementText(child).trim();
          if (cellText.isNotEmpty) cells.add(cellText);
        }
      }
      if (cells.isNotEmpty) {
        lines.add(cells.join('  '));
      }
      return;
    }

    if (tag == 'p' || tag == 'div' || tag == 'h1' || tag == 'h2' || tag == 'h3') {
      final block = _elementText(node).trim();
      if (block.isNotEmpty) lines.add(block);
      if (tag == 'div' || tag == 'p') {
        for (final child in node.nodes) {
          _walk(child, lines, inTable: false);
        }
      }
      return;
    }

    final tableMode = tag == 'table' || tag == 'tbody' || inTable;
    for (final child in node.nodes) {
      _walk(child, lines, inTable: tableMode);
    }

    if (tag == 'table') {
      lines.add('');
    }
  }

  static String _elementText(Element el) {
    final buf = StringBuffer();
    void collect(Node n) {
      if (n is Text) {
        buf.write(n.text);
      } else if (n is Element) {
        final t = n.localName?.toLowerCase();
        if (t == 'br') buf.write('\n');
        for (final c in n.nodes) collect(c);
      }
    }
    for (final n in el.nodes) collect(n);
    return _decode(buf.toString());
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
    for (final line in lines) {
      final t = line.trim();
      if (t.isEmpty) {
        if (out.isEmpty || out.last.isEmpty) continue;
        out.add('');
        continue;
      }
      out.add(t);
    }
    while (out.isNotEmpty && out.last.isEmpty) {
      out.removeLast();
    }
    return out;
  }
}
