import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:mywatchlist/generated/l10n.dart';

/// The custom element a spoiler becomes before rendering (MAL's `div.spoiler` or BBCode).
const String spoilerElement = 'mwl-spoiler';

RegExp _re(String p) => RegExp(p, caseSensitive: false, dotAll: true);

final _simple = <RegExp, String>{
  _re(r'\[b\](.*?)\[/b\]'): r'<b>$1</b>',
  _re(r'\[i\](.*?)\[/i\]'): r'<i>$1</i>',
  _re(r'\[u\](.*?)\[/u\]'): r'<u>$1</u>',
  _re(r'\[s\](.*?)\[/s\]'): r'<s>$1</s>',
  _re(r'\[center\](.*?)\[/center\]'): r'<div style="text-align:center">$1</div>',
  _re(r'\[right\](.*?)\[/right\]'): r'<div style="text-align:right">$1</div>',
  _re(r'\[color=[^\]]*\](.*?)\[/color\]'): r'$1',
  _re(r'\[size=[^\]]*\](.*?)\[/size\]'): r'$1',
};
final _quote = _re(r'\[quote(?:=([^\]]*))?\](.*?)\[/quote\]');
final _spoiler = _re(r'\[spoiler(?:=([^\]]*))?\](.*?)\[/spoiler\]');
final _urlNamed = _re(r'\[url=([^\]\s]+)\](.*?)\[/url\]');
final _urlBare = _re(r'\[url\]([^\[\s]+)\[/url\]');
final _img = _re(r'\[img(?:[^\]]*)\]([^\[\s]+)\[/img\]');

String _attr(String s) => const HtmlEscape(HtmlEscapeMode.attribute).convert(s);

bool _web(String url) {
  final u = Uri.tryParse(url);
  return u != null && (u.scheme == 'http' || u.scheme == 'https') && u.host.isNotEmpty;
}

/// Replaces MAL's BBCode tags in [input] with HTML. Innermost pairs first, repeated until
/// nothing changes, so nested tags of the same kind work. Link and image targets must be
/// http(s); anything else stays as typed.
String _tagsToHtml(String input) {
  var out = input;
  for (var pass = 0; pass < 8; pass++) {
    final before = out;
    for (final e in _simple.entries) {
      out = out.replaceAllMapped(e.key, (m) => e.value.replaceAll(r'$1', m.group(1)!));
    }
    out = out.replaceAllMapped(_img, (m) => _web(m[1]!) ? '<img src="${_attr(m[1]!)}">' : m[0]!);
    out = out.replaceAllMapped(_urlNamed, (m) => _web(m[1]!) ? '<a href="${_attr(m[1]!)}">${m[2]}</a>' : m[0]!);
    out = out.replaceAllMapped(_urlBare, (m) => _web(m[1]!) ? '<a href="${_attr(m[1]!)}">${m[1]}</a>' : m[0]!);
    out = out.replaceAllMapped(_quote, (m) => '<blockquote>${m[2]}</blockquote>');
    out = out.replaceAllMapped(_spoiler, (m) {
      final name = (m[1] ?? '').trim();
      return '<$spoilerElement${name.isEmpty ? '' : ' data-name="${_attr(name)}"'}>${m[2]}</$spoilerElement>';
    });
    if (out == before) break;
  }
  return out;
}

/// A message typed in the composer (plain text + MAL BBCode) as the HTML the bubbles render:
/// the text is escaped first, so only BBCode becomes markup; line breaks become `<br>`.
String bbcodeToHtml(String text) {
  final escaped = const HtmlEscape(HtmlEscapeMode.element).convert(text.replaceAll('\r\n', '\n'));
  return _tagsToHtml(escaped).replaceAll('\n', '<br>');
}

final Map<String, String> _normalized = {};

/// MAL's message HTML made ready for the renderer: MAL's spoiler block (`div.spoiler` with its
/// Show/Hide buttons and `span.spoiler_content`) becomes one `mwl-spoiler` element, the
/// lazy-loaded `img[data-src]` gets its `src`, `div.quotetext` becomes a `blockquote`, form
/// controls and scripts go, and BBCode MAL left as text is converted too. Cached by input.
String normalizeMalMessageHtml(String raw) {
  final hit = _normalized.remove(raw);
  if (hit != null) return _normalized[raw] = hit;
  final value = _normalize(raw);
  _normalized[raw] = value;
  if (_normalized.length > 200) _normalized.remove(_normalized.keys.first);
  return value;
}

String _normalize(String raw) {
  final fragment = html_parser.parseFragment(_tagsToHtml(raw));
  for (final e in fragment.querySelectorAll('script, style')) {
    e.remove();
  }
  for (final e in fragment.querySelectorAll('.spoiler').reversed) {
    final content = e.querySelector('.spoiler_content') ?? e;
    final button = e.querySelector('input.show_button');
    for (final input in content.querySelectorAll('input')) {
      input.remove();
    }
    var inner = content.innerHtml.trim();
    if (inner.startsWith('<br>')) inner = inner.substring(4).trimLeft();
    final spoiler = dom.Element.tag(spoilerElement)..innerHtml = inner;
    final shown = button?.attributes['data-showname'] ?? '';
    // MAL writes "Show <name>" for `[spoiler=name]`; its default label is not a name.
    final name = shown.toLowerCase().startsWith('show ') ? shown.substring(5).trim() : '';
    if (name.isNotEmpty && name.toLowerCase() != 'spoiler') spoiler.attributes['data-name'] = name;
    e.replaceWith(spoiler);
  }
  for (final e in fragment.querySelectorAll('input, button, form')) {
    e.remove();
  }
  for (final e in fragment.querySelectorAll('div.quotetext')) {
    final quote = dom.Element.tag('blockquote')..innerHtml = e.innerHtml;
    e.replaceWith(quote);
  }
  for (final img in fragment.querySelectorAll('img')) {
    final lazy = img.attributes['data-src'];
    if (lazy != null && lazy.isNotEmpty) img.attributes['src'] = lazy;
  }
  return fragment.nodes.map((n) => n is dom.Element ? n.outerHtml : (n is dom.Text ? const HtmlEscape(HtmlEscapeMode.element).convert(n.text) : '')).join();
}

/// Plain one-line preview of a message body (inbox row): BBCode becomes styled spans, a picture
/// a photo icon + "Photo", a spoiler its label only, a quote is skipped.
List<InlineSpan> malPreviewSpans(String text, {required TextStyle? style, Color? iconColor}) {
  final s = S.current;
  final spans = <InlineSpan>[];
  final tag = RegExp(r'\[(/?)(b|i|u|s|spoiler|url|img|quote|center|right|color|size)(=[^\]]*)?\]', caseSensitive: false);
  var bold = 0, italic = 0, underline = 0, strike = 0;
  var pos = 0;
  TextStyle current() {
    final decorations = <TextDecoration>[
      if (underline > 0) TextDecoration.underline,
      if (strike > 0) TextDecoration.lineThrough,
    ];
    return (style ?? const TextStyle()).copyWith(
      fontWeight: bold > 0 ? FontWeight.w700 : null,
      fontStyle: italic > 0 ? FontStyle.italic : null,
      decoration: decorations.isEmpty ? null : TextDecoration.combine(decorations),
    );
  }

  void addText(String t) {
    final flat = t.replaceAll(RegExp(r'\s+'), ' ');
    if (flat.isNotEmpty) spans.add(TextSpan(text: flat, style: current()));
  }

  int skipTo(String name, int from) {
    final close = RegExp('\\[/$name\\]', caseSensitive: false).firstMatch(text.substring(from));
    return close == null ? text.length : from + close.end;
  }

  while (pos < text.length) {
    final m = tag.allMatches(text, pos).firstOrNull;
    if (m == null) {
      addText(text.substring(pos));
      break;
    }
    if (m.start > pos) addText(text.substring(pos, m.start));
    final closing = m[1] == '/';
    final name = m[2]!.toLowerCase();
    pos = m.end;
    if (closing) {
      switch (name) {
        case 'b':
          if (bold > 0) bold--;
        case 'i':
          if (italic > 0) italic--;
        case 'u':
          if (underline > 0) underline--;
        case 's':
          if (strike > 0) strike--;
      }
      continue;
    }
    switch (name) {
      case 'b':
        bold++;
      case 'i':
        italic++;
      case 'u':
        underline++;
      case 's':
        strike++;
      case 'img':
        pos = skipTo('img', pos);
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Padding(
            padding: const EdgeInsetsDirectional.only(end: 3),
            child: Icon(Icons.photo_outlined, size: (style?.fontSize ?? 14) + 2, color: iconColor ?? style?.color),
          ),
        ));
        spans.add(TextSpan(text: '${s.Pmc_Photo} ', style: current()));
      case 'spoiler':
        pos = skipTo('spoiler', pos);
        spans.add(TextSpan(text: '${s.Pmc_Spoiler} ', style: current().copyWith(fontStyle: FontStyle.italic)));
      case 'quote':
        pos = skipTo('quote', pos);
    }
  }
  return spans;
}
