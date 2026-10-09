import 'package:flutter/gestures.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../balsm_app/kit.dart';
import '../balsm_app/tokens.dart';

/// Renders a release note's HTML as native widgets.
///
/// The HTML comes from a remote file, so this is an allow-list, not a browser:
/// paragraphs, headings, lists, line breaks, bold / italic / underline / code,
/// and `https` links. Anything else contributes its text only, and `script`,
/// `style`, images, frames and forms contribute nothing — no markup in the
/// manifest can run code, load a remote resource, or restyle the app.
class ReleaseNotesHtml extends StatefulWidget {
  const ReleaseNotesHtml({
    super.key,
    required this.html,
    required this.ar,
    required this.linkColor,
    this.small = false,
  });
  final String html;
  final bool ar;
  final Color linkColor;

  /// The description size under a note's title (`--pt-xs`).
  final bool small;

  @override
  State<ReleaseNotesHtml> createState() => _ReleaseNotesHtmlState();
}

enum _BlockKind { paragraph, heading, bullet, numbered }

class _Block {
  _Block(this.kind, this.spans, {this.depth = 0, this.number = 0});
  final _BlockKind kind;
  final List<InlineSpan> spans;
  final int depth;
  final int number;
}

class _ReleaseNotesHtmlState extends State<ReleaseNotesHtml> {
  static const _dropped = {
    'script', 'style', 'head', 'title', 'meta', 'link', 'img', 'picture', 'svg', 'video', 'audio', //
    'iframe', 'object', 'embed', 'form', 'input', 'button', 'select', 'textarea', 'template', 'noscript',
  };
  static const _headings = {'h1', 'h2', 'h3', 'h4', 'h5', 'h6'};
  static const _blocks = {'p', 'div', 'section', 'article', 'blockquote', 'ul', 'ol', 'li', ..._headings};

  final _recognizers = <TapGestureRecognizer>[];
  late List<_Block> _parsed;

  @override
  void initState() {
    super.initState();
    _parsed = _parse();
  }

  @override
  void didUpdateWidget(ReleaseNotesHtml old) {
    super.didUpdateWidget(old);
    if (old.html != widget.html || old.linkColor != widget.linkColor || old.small != widget.small) {
      _disposeRecognizers();
      _parsed = _parse();
    }
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  List<_Block> _parse() {
    final out = <_Block>[];
    var spans = <InlineSpan>[];
    var kind = _BlockKind.paragraph;
    var depth = 0;
    var number = 0;

    void flush() {
      // Collapsed whitespace can leave a block that is only spaces.
      final hasText = spans.any((s) => s is TextSpan && (s.text ?? '').trim().isNotEmpty);
      if (hasText) out.add(_Block(kind, spans, depth: depth, number: number));
      spans = <InlineSpan>[];
    }

    void walk(dom.Node node, TextStyle style, {String? href, List<int>? counters}) {
      if (node is dom.Text) {
        final text = node.text.replaceAll(RegExp(r'\s+'), ' ');
        if (text.isEmpty) return;
        TapGestureRecognizer? tap;
        if (href != null) {
          tap = TapGestureRecognizer()..onTap = () => launchUrl(Uri.parse(href), mode: LaunchMode.externalApplication);
          _recognizers.add(tap);
        }
        spans.add(TextSpan(text: text, style: style, recognizer: tap));
        return;
      }
      if (node is! dom.Element) return;
      final tag = node.localName ?? '';
      if (_dropped.contains(tag)) return;

      if (tag == 'br') {
        spans.add(TextSpan(text: '\n', style: style));
        return;
      }

      var next = style;
      var link = href;
      switch (tag) {
        case 'b' || 'strong':
          next = style.copyWith(fontWeight: FontWeight.w700);
        case 'i' || 'em':
          next = style.copyWith(fontStyle: FontStyle.italic);
        case 'u':
          next = style.copyWith(decoration: TextDecoration.underline);
        case 'code':
          next = style.copyWith(fontFamily: 'IBMPlexMono');
        case 'a':
          final raw = node.attributes['href']?.trim() ?? '';
          // Only https leaves the app; any other scheme renders as plain text.
          if (raw.startsWith('https://')) {
            link = raw;
            next = style.copyWith(color: widget.linkColor, decoration: TextDecoration.underline);
          }
      }

      if (!_blocks.contains(tag)) {
        for (final c in node.nodes) {
          walk(c, next, href: link, counters: counters);
        }
        return;
      }

      // A block: close whatever text preceded it, then render its own.
      flush();
      final outerKind = kind, outerDepth = depth, outerNumber = number;
      if (tag == 'ul' || tag == 'ol') {
        depth++;
        final own = tag == 'ol' ? <int>[0] : null;
        for (final c in node.nodes) {
          walk(c, next, href: link, counters: own);
        }
        flush();
        depth--;
      } else {
        if (tag == 'li') {
          if (counters != null) {
            counters[0]++;
            kind = _BlockKind.numbered;
            number = counters[0];
          } else {
            kind = _BlockKind.bullet;
          }
        } else if (_headings.contains(tag)) {
          kind = _BlockKind.heading;
          next = next.copyWith(fontWeight: FontWeight.w700, color: T.fg1);
        } else {
          kind = _BlockKind.paragraph;
        }
        for (final c in node.nodes) {
          walk(c, next, href: link);
        }
        flush();
      }
      kind = outerKind;
      depth = outerDepth;
      number = outerNumber;
    }

    final base = Typo.bodySm(ar: widget.ar).copyWith(color: T.fg2, height: 1.5, fontSize: widget.small ? FS.xs : null);
    final body = html_parser.parseFragment(widget.html);
    for (final n in body.nodes) {
      walk(n, base);
    }
    flush();
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < _parsed.length; i++) {
      final b = _parsed[i];
      final text = Text.rich(TextSpan(children: _trimmed(b.spans)));
      final isItem = b.kind == _BlockKind.bullet || b.kind == _BlockKind.numbered;
      final body = !isItem
          ? text
          : Padding(
              padding: EdgeInsetsDirectional.only(start: 16.0 * (b.depth - 1).clamp(0, 4)),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(
                  width: 20,
                  child: Text(
                    b.kind == _BlockKind.numbered ? '${b.number}.' : '•',
                    style: Typo.bodySm(ar: widget.ar).copyWith(color: T.fg3, height: 1.5),
                  ),
                ),
                Expanded(child: text),
              ]),
            );
      // Items sit close together; paragraphs and headings get air.
      final gap = i == 0
          ? 0.0
          : isItem
              ? 4.0
              : 10.0;
      children.add(Padding(padding: EdgeInsets.only(top: gap), child: body));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: children);
  }

  /// Drops the leading/trailing space that source indentation leaves behind.
  List<InlineSpan> _trimmed(List<InlineSpan> spans) {
    final out = [...spans];
    TextSpan retext(TextSpan t, String? text) => TextSpan(text: text, style: t.style, recognizer: t.recognizer);
    final first = out.first;
    if (first is TextSpan) out[0] = retext(first, first.text?.trimLeft());
    final last = out.last;
    if (last is TextSpan) out[out.length - 1] = retext(last, last.text?.trimRight());
    return out;
  }
}
