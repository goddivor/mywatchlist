import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/MAL/mal_anime.dart';
import 'package:mywatchlist/user/preferences/preferences.dart';
import 'package:mywatchlist/widgets/common/translator.dart';

const _collapsedHeight = 220.0;
const _ease = Cubic(0.23, 1, 0.32, 1);

/// Synopsis, genres and background of a detail page. Long texts start collapsed
/// behind a fade; the synopsis can be translated into the app language
/// ([TranslatorWidget]), automatically when `autoTranslateSynopsis` is on.
/// Without a [synopsis] the widget is the page's loading placeholder.
class SysonpsisWidget extends StatefulWidget {
  final String? synopsis;
  final List<Genre>? genres;
  final String? background;
  final String category;
  final double horizPadding;
  final int characterLimit;
  final bool expanded;

  const SysonpsisWidget({
    super.key,
    this.synopsis,
    this.genres,
    this.category = "anime",
    this.background,
    this.expanded = false,
    this.characterLimit = 300,
    this.horizPadding = 15.0,
  });

  @override
  State<SysonpsisWidget> createState() => _SysonpsisWidgetState();
}

class _SysonpsisWidgetState extends State<SysonpsisWidget>
    with AutomaticKeepAliveClientMixin {
  late bool _expanded;
  late bool _showExpand;

  bool get _hasBackground => !nullOrEmpty(widget.background);

  @override
  void initState() {
    super.initState();
    final synopsis = widget.synopsis ?? '';
    _showExpand = synopsis.length > widget.characterLimit || _hasBackground;
    _expanded = widget.expanded || !_showExpand;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final scheme = Theme.of(context).colorScheme;
    final padded = Padding(
      padding: EdgeInsets.symmetric(horizontal: widget.horizPadding),
      child: widget.synopsis == null ? loadingText(context) : _content(context),
    );
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: _ease,
            alignment: Alignment.topCenter,
            child: CustomPaint(
              foregroundPainter: _FadePainter(
                color: Theme.of(context).scaffoldBackgroundColor,
                start: _expanded ? 50 : 0,
                end: _expanded ? 50 : 255,
              ),
              child: _expanded
                  ? padded
                  : SizedBox(
                      height: _collapsedHeight,
                      width: double.infinity,
                      child: OverflowBox(
                        alignment: Alignment.topCenter,
                        minHeight: 0,
                        maxHeight: 4000,
                        child: padded,
                      ),
                    ),
            ),
          ),
        ),
        if (_showExpand)
          Center(
            child: SizedBox(
              height: 40,
              child: IconButton(
                tooltip: _expanded
                    ? S.current.Synopsis_Collapse
                    : S.current.Synopsis_Expand,
                onPressed: () => setState(() => _expanded = !_expanded),
                padding: EdgeInsets.zero,
                color: scheme.onSurfaceVariant,
                icon: Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  size: 24,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _content(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 14);
    final synopsis = widget.synopsis!.trim();
    final autoTranslate = context.select<PreferencesBloc?, bool>((bloc) =>
        (bloc?.state ?? Preferences.current).general.autoTranslateSynopsis);
    return Padding(
      padding: const EdgeInsets.fromLTRB(5, 5, 5, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: genresWidget(widget.genres ?? [], widget.category, context),
          ),
          const SizedBox(height: 5),
          if (synopsis.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                S.current.Synopsis_Empty,
                style: textStyle?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            TranslatorWidget(
              content: synopsis,
              autoTranslate: autoTranslate,
              reversed: true,
              translateLabel: S.current.Translate_Synopsis2,
              originalLabel: S.current.Show_Original,
              builder: (_, text) => SizedBox(
                width: double.infinity,
                child: Text(text, textAlign: TextAlign.justify, style: textStyle),
              ),
            ),
          if (_hasBackground) ...[
            const SizedBox(height: 14),
            Text(
              S.current.Background,
              style: textStyle?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 5),
            SizedBox(
              width: double.infinity,
              child: Text(
                widget.background!,
                textAlign: TextAlign.justify,
                style: textStyle,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}

class _FadePainter extends CustomPainter {
  final Color color;
  final int start;
  final int end;

  const _FadePainter({required this.color, required this.start, required this.end});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [color.withValues(alpha: start / 255), color.withValues(alpha: end / 255)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(rect);
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(_FadePainter old) =>
      old.color != color || old.start != start || old.end != end;
}
