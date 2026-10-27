import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mywatchlist/cache/dub_info.dart';
import 'package:mywatchlist/generated/l10n.dart';

/// Glyphs of `assets/fonts/MyDubListIcons.ttf`: four styles, each with a "dubbed" and a
/// "partially dubbed" icon.
abstract final class DubIcons {
  static const String fontFamily = 'DubStatus';
  static const String _asset = 'assets/fonts/MyDubListIcons.ttf';

  static const List<List<IconData>> _styles = [
    [
      IconData(0xE900, fontFamily: fontFamily),
      IconData(0xE901, fontFamily: fontFamily),
    ],
    [
      IconData(0xE902, fontFamily: fontFamily),
      IconData(0xE903, fontFamily: fontFamily),
    ],
    [
      IconData(0xE904, fontFamily: fontFamily),
      IconData(0xE905, fontFamily: fontFamily),
    ],
    [
      IconData(0xE906, fontFamily: fontFamily),
      IconData(0xE907, fontFamily: fontFamily),
    ],
  ];

  static const int styleCount = 4;

  /// Fallback glyphs when the font file is not bundled in the app.
  static const IconData _fallbackDub = Icons.record_voice_over_rounded;
  static const IconData _fallbackPartial = Icons.record_voice_over_outlined;

  static bool _fontMissing = false;
  static Future<void>? _loading;

  /// Registers the font at runtime, so the icons work whether or not the pubspec declares
  /// the family. When the file is not part of the app bundle the Material fallback is used.
  static Future<void> ensureFont() {
    return _loading ??= () async {
      try {
        final loader = FontLoader(fontFamily)..addFont(rootBundle.load(_asset));
        await loader.load();
      } catch (_) {
        _fontMissing = true;
      }
    }();
  }

  static int clampStyle(int style) => style.clamp(0, styleCount - 1);

  static IconData dub(int style) =>
      _fontMissing ? _fallbackDub : _styles[clampStyle(style)][0];

  static IconData partial(int style) =>
      _fontMissing ? _fallbackPartial : _styles[clampStyle(style)][1];

  /// Side padding that centres each style's glyph in its pill (the glyphs are drawn off-centre).
  static EdgeInsets padding(int style) {
    if (_fontMissing) return const EdgeInsets.all(4);
    switch (clampStyle(style)) {
      case 1:
        return const EdgeInsets.fromLTRB(6, 4, 10, 3);
      case 2:
        return const EdgeInsets.fromLTRB(4, 4, 4, 3);
      default:
        return const EdgeInsets.fromLTRB(4, 4, 12, 3);
    }
  }
}

/// Translated name of a dub status, also the screen-reader label of its icon.
String dubStatusLabel(DubStatus status) => switch (status) {
      DubStatus.dubbed => S.current.Dub_Status_Full,
      DubStatus.partial => S.current.Dub_Status_Partial,
      DubStatus.none => '',
    };

/// One dub icon in the colour of the surrounding text (settings, legends).
class DubGlyph extends StatelessWidget {
  final DubStatus status;
  final int style;
  final double size;
  final Color? color;

  const DubGlyph({
    super.key,
    required this.status,
    required this.style,
    this.size = 24,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: DubIcons.ensureFont(),
      builder: (context, _) => Icon(
        status == DubStatus.partial ? DubIcons.partial(style) : DubIcons.dub(style),
        size: size,
        color: color,
      ),
    );
  }
}

/// The small dark pill shown over a cover for a dubbed title. Builds nothing unless the dub
/// icon is enabled and MyDubList lists [animeId]. Only this pill rebuilds when the data or the
/// style changes. The pill is a dark translucent scrim with a white glyph, as the other card
/// badges, so it stays readable on any cover in every theme.
class DubStatusBadge extends StatefulWidget {
  final int? animeId;
  final double radius;

  const DubStatusBadge({super.key, required this.animeId, this.radius = 6});

  @override
  State<DubStatusBadge> createState() => _DubStatusBadgeState();
}

class _DubStatusBadgeState extends State<DubStatusBadge> {
  @override
  void initState() {
    super.initState();
    DubInfo.instance.attach();
    unawaited(DubIcons.ensureFont());
  }

  @override
  Widget build(BuildContext context) {
    final info = DubInfo.instance;
    return ListenableBuilder(
      listenable: info,
      builder: (context, _) {
        final status = info.statusOf(widget.animeId);
        if (status == DubStatus.none) return const SizedBox.shrink();
        final style = info.iconStyle;
        return IgnorePointer(
          child: Semantics(
            label: dubStatusLabel(status),
            excludeSemantics: true,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0x99000000),
                borderRadius: BorderRadius.circular(widget.radius),
              ),
              child: Padding(
                padding: DubIcons.padding(style),
                child: Icon(
                  status == DubStatus.partial ? DubIcons.partial(style) : DubIcons.dub(style),
                  size: 14,
                  color: const Color(0xFFFFFFFF),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
