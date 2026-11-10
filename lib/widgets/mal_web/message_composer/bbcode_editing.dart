import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';

/// The formats a MAL message offers in the composer, each one a MAL BBCode tag.
enum MalFormat {
  bold('b'),
  italic('i'),
  underline('u'),
  strike('s'),
  spoiler('spoiler'),
  link('url');

  const MalFormat(this.tag);

  final String tag;

  IconData get icon => switch (this) {
        MalFormat.bold => Icons.format_bold_rounded,
        MalFormat.italic => Icons.format_italic_rounded,
        MalFormat.underline => Icons.format_underlined_rounded,
        MalFormat.strike => Icons.format_strikethrough_rounded,
        MalFormat.spoiler => Icons.visibility_off_outlined,
        MalFormat.link => Icons.link_rounded,
      };

  String get label {
    final s = S.current;
    return switch (this) {
      MalFormat.bold => s.Pmc_Bold,
      MalFormat.italic => s.Pmc_Italic,
      MalFormat.underline => s.Pmc_Underline,
      MalFormat.strike => s.Pmc_Strike,
      MalFormat.spoiler => s.Pmc_Spoiler,
      MalFormat.link => s.Pmc_Link,
    };
  }
}

/// Wraps the selection of [value] in [format]'s tags. With a collapsed cursor the empty pair
/// is inserted and the cursor lands between the tags; with a selection the selection keeps the
/// wrapped text. A link needs [url] (`[url=URL]text[/url]`, or `[url=URL]URL[/url]` with no
/// selected text). An invalid selection (field never focused) appends at the end.
TextEditingValue applyMalFormat(TextEditingValue value, MalFormat format, {String? url}) {
  final text = value.text;
  var sel = value.selection;
  if (!sel.isValid) sel = TextSelection.collapsed(offset: text.length);
  final start = sel.start.clamp(0, text.length);
  final end = sel.end.clamp(0, text.length);
  var inner = text.substring(start, end);
  final String open;
  if (format == MalFormat.link) {
    final target = (url ?? '').trim();
    if (target.isEmpty) return value;
    open = '[url=$target]';
    if (inner.isEmpty) inner = target;
  } else {
    open = '[${format.tag}]';
  }
  final close = '[/${format.tag}]';
  final replaced = text.replaceRange(start, end, '$open$inner$close');
  final TextSelection selection;
  if (start == end && format != MalFormat.link) {
    selection = TextSelection.collapsed(offset: start + open.length);
  } else if (start == end) {
    selection = TextSelection.collapsed(offset: start + open.length + inner.length + close.length);
  } else {
    selection = TextSelection(baseOffset: start + open.length, extentOffset: start + open.length + inner.length);
  }
  return TextEditingValue(text: replaced, selection: selection);
}

/// Inserts `[img]URL[/img]` at the cursor of [value] (replacing a selection), on its own
/// line, the cursor after it.
TextEditingValue insertMalImage(TextEditingValue value, String url) {
  final text = value.text;
  var sel = value.selection;
  if (!sel.isValid) sel = TextSelection.collapsed(offset: text.length);
  final start = sel.start.clamp(0, text.length);
  final end = sel.end.clamp(0, text.length);
  final before = start > 0 && text[start - 1] != '\n' ? '\n' : '';
  final after = end < text.length && text[end] != '\n' ? '\n' : '';
  final tag = '$before[img]${url.trim()}[/img]$after';
  return TextEditingValue(
    text: text.replaceRange(start, end, tag),
    selection: TextSelection.collapsed(offset: start + tag.length),
  );
}

final RegExp _anyTag = RegExp(r'\[/?(b|i|u|s|spoiler|url|img|quote|center|right|color|size)(=[^\]]*)?\]', caseSensitive: false);

/// Whether [text] holds MAL BBCode the composer knows (the preview shows only then).
bool hasMalMarkup(String text) => _anyTag.hasMatch(text);

/// Whether [s] is an http(s) URL with a host.
bool isWebUrl(String s) {
  final uri = Uri.tryParse(s.trim());
  return uri != null && (uri.scheme == 'http' || uri.scheme == 'https') && uri.host.isNotEmpty;
}
