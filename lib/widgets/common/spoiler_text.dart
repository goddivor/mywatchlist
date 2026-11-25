import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';

/// A part of a text: plain, or a `[Spoiler]…[/Spoiler]` block.
typedef SpoilerPart = ({String text, bool spoiler});

final RegExp _spoilerRe = RegExp(r'\[spoiler(?:=[^\]]*)?\](.*?)\[/spoiler\]', caseSensitive: false, dotAll: true);

/// Splits [text] around its `[Spoiler]…[/Spoiler]` blocks (MAL's character and people
/// "about"), trimming the blank lines the markers leave. Empty parts are dropped.
List<SpoilerPart> splitSpoilers(String text) {
  final parts = <SpoilerPart>[];
  void add(String s, bool spoiler) {
    final t = s.trim();
    if (t.isNotEmpty) parts.add((text: t, spoiler: spoiler));
  }

  var at = 0;
  for (final m in _spoilerRe.allMatches(text)) {
    add(text.substring(at, m.start), false);
    add(m.group(1) ?? '', true);
    at = m.end;
  }
  add(text.substring(at), false);
  return parts;
}

/// Selectable text whose spoiler blocks stay hidden until tapped.
class SpoilerText extends StatelessWidget {
  const SpoilerText(this.text, {super.key, this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final parts = splitSpoilers(text);
    if (parts.length == 1 && !parts.first.spoiler) return SelectableText(parts.first.text, style: style);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final part in parts)
          part.spoiler
              ? _Spoiler(text: part.text, style: style)
              : Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: SelectableText(part.text, style: style),
                ),
      ],
    );
  }
}

class _Spoiler extends StatefulWidget {
  const _Spoiler({required this.text, this.style});

  final String text;
  final TextStyle? style;

  @override
  State<_Spoiler> createState() => _SpoilerState();
}

class _SpoilerState extends State<_Spoiler> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final name = S.current.Fc_Spoiler;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton.icon(
          style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: EdgeInsets.zero),
          onPressed: () => setState(() => _open = !_open),
          icon: Icon(_open ? Icons.visibility_off : Icons.visibility, size: 16),
          label: Text(_open ? S.current.Fc_Spoiler_Hide(name) : S.current.Fc_Spoiler_Show(name)),
        ),
        if (_open) SelectableText(widget.text, style: widget.style),
      ],
    );
  }
}
