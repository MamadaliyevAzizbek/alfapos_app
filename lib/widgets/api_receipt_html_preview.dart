import 'package:flutter/material.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

/// API `templateData.content` HTML — haqiqiy ko‘rinish (termal kenglik).
class ApiReceiptHtmlPreview extends StatelessWidget {
  final String html;
  final double width;

  static const _blockTags = {
    'div',
    'p',
    'table',
    'tbody',
    'thead',
    'tr',
    'ul',
    'ol',
    'li',
    'h1',
    'h2',
    'h3',
    'h4',
    'hr',
  };

  const ApiReceiptHtmlPreview({
    super.key,
    required this.html,
    this.width = 302,
  });

  @override
  Widget build(BuildContext context) {
    final raw = html.trim();
    if (raw.isEmpty) {
      return SizedBox(
        width: width,
        child: const Text('HTML bo‘sh', style: TextStyle(color: Colors.grey)),
      );
    }

    if (!raw.contains('<')) {
      return _paper(
        child: Text(
          raw,
          style: _bodyStyle,
        ),
      );
    }

    final doc = html_parser.parse(raw);
    final root = doc.body ?? doc.documentElement;
    final children = root == null ? <Widget>[] : _buildNodes(root.nodes);

    return _paper(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: children.isEmpty
            ? [Text(_stripTags(raw), style: _bodyStyle)]
            : children,
      ),
    );
  }

  Widget _paper({required Widget child}) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: child,
    );
  }

  static const _bodyStyle = TextStyle(
    fontSize: 13,
    color: Colors.black,
    height: 1.35,
    fontWeight: FontWeight.w500,
  );

  static const _boldStyle = TextStyle(
    fontSize: 13,
    color: Colors.black,
    height: 1.35,
    fontWeight: FontWeight.w700,
  );

  List<Widget> _buildNodes(List<dom.Node> nodes) {
    final out = <Widget>[];
    for (final n in nodes) {
      out.addAll(_buildNode(n));
    }
    return out;
  }

  List<Widget> _buildNode(dom.Node node) {
    if (node is dom.Text) {
      final t = _decode(node.text.replaceAll(RegExp(r'\s+'), ' ').trim());
      if (t.isEmpty) return [];
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 1),
          child: Text(t, style: _bodyStyle),
        ),
      ];
    }
    if (node is! dom.Element) return [];

    final tag = node.localName?.toLowerCase() ?? '';
    if (tag == 'style' || tag == 'script' || tag == 'head' || tag == 'meta') {
      return [];
    }
    if (tag == 'br') {
      return [const SizedBox(height: 6)];
    }
    if (tag == 'hr') {
      return [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 6),
          child: Divider(height: 1, color: Colors.black26),
        ),
      ];
    }
    if (tag == 'tr') {
      final cells = <String>[];
      for (final c in node.children) {
        final ct = c.localName?.toLowerCase();
        if (ct == 'td' || ct == 'th') {
          final t = _elementText(c).trim();
          if (t.isNotEmpty) cells.add(t);
        }
      }
      if (cells.isEmpty) return [];
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < cells.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    cells[i],
                    style: i == 0 ? _bodyStyle : _boldStyle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ];
    }
    if (tag == 'div') {
      if (_hasBlockChild(node)) return _buildNodes(node.nodes);
      final text = _elementText(node).trim();
      if (text.isEmpty) return [];
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Text(text, style: _bodyStyle),
        ),
      ];
    }
    if (tag == 'p' || tag == 'h1' || tag == 'h2' || tag == 'h3' || tag == 'h4') {
      final text = _elementText(node).trim();
      if (text.isEmpty) return [];
      final style = (tag == 'h1' || tag == 'h2' || tag == 'h3')
          ? _boldStyle.copyWith(fontSize: 14)
          : _bodyStyle;
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Text(text, style: style),
        ),
      ];
    }
    if (tag == 'strong' || tag == 'b') {
      final text = _elementText(node).trim();
      if (text.isEmpty) return [];
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 1),
          child: Text(text, style: _boldStyle),
        ),
      ];
    }
    if (tag == 'table') {
      return [
        ..._buildNodes(node.nodes),
        const SizedBox(height: 4),
      ];
    }
    return _buildNodes(node.nodes);
  }

  static String _elementText(dom.Element el) {
    final buf = StringBuffer();
    void collect(dom.Node n) {
      if (n is dom.Text) {
        buf.write(n.text);
      } else if (n is dom.Element) {
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

  static bool _hasBlockChild(dom.Element el) {
    for (final child in el.nodes) {
      if (child is! dom.Element) continue;
      final t = child.localName?.toLowerCase() ?? '';
      if (_blockTags.contains(t)) return true;
    }
    return false;
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
}
