import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mywatchlist/constants/constants.dart' show TitleLang;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/MAL/detail/detail_data.dart';
import 'package:mywatchlist/screens/MAL/detail/header/countdown_chip.dart';
import 'package:mywatchlist/screens/MAL/detail/header/cover_card.dart';
import 'package:mywatchlist/screens/MAL/detail/header/header_background.dart';
import 'package:mywatchlist/screens/MAL/detail/header/header_meta.dart';

/// Expanded part of the app bar: faded cover background, title (two lines),
/// cover card with the meta column, and the next-episode countdown.
///
/// The height is a pure function of the data ([extentFor]) so the app bar
/// never measures the content and does not jump when a source answers.
class DetailHeader extends StatelessWidget {
  static const double toolbarHeight = 40.0;
  static const double tabBarHeight = 48.0;
  static const double _titleHeight = 62.0;
  static const double _gap = 10.0;
  static const double _countdownHeight = 38.0;

  final DetailData data;
  final String title;
  final TitleLang titleLang;
  final ValueChanged<TitleLang> onTitleLangChanged;
  final VoidCallback? onMoreInfo;

  const DetailHeader({
    super.key,
    required this.data,
    required this.title,
    required this.titleLang,
    required this.onTitleLangChanged,
    this.onMoreInfo,
  });

  /// Whether the header reserves the countdown row: an anime MAL says is
  /// airing, with the countdown preference on.
  static bool reservesCountdown(DetailData data, {required bool enabled}) =>
      enabled && data.isAnime && data.content?.status == 'currently_airing';

  /// Total height of the app bar when expanded (status bar, toolbar, header
  /// content, tab bar).
  static double extentFor(DetailData data, {required double topInset, required bool countdown}) =>
      topInset +
      toolbarHeight +
      _titleHeight +
      _gap +
      DetailCoverCard.height +
      _gap +
      (reservesCountdown(data, enabled: countdown) ? _countdownHeight : 0) +
      tabBarHeight;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final countdownOn = contentPref(context, (c) => c.showCountdownOnDetail);
    final reserve = reservesCountdown(data, enabled: countdownOn);
    final next = data.nextEpisode;
    final content = Padding(
      padding: EdgeInsets.only(top: topInset + toolbarHeight, bottom: tabBarHeight),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: SizedBox(
              height: _titleHeight,
              width: double.infinity,
              child: Center(child: _TitleText(title)),
            ),
          ),
          const SizedBox(height: _gap),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              height: DetailCoverCard.height,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    flex: 9,
                    child: DetailCoverCard(
                      data: data,
                      titleLang: titleLang,
                      onTitleLangChanged: onTitleLangChanged,
                      onMoreInfo: onMoreInfo,
                    ),
                  ),
                  Expanded(flex: 8, child: DetailHeaderMeta(data: data)),
                ],
              ),
            ),
          ),
          if (reserve)
            SizedBox(
              height: _countdownHeight + _gap,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: next == null ? null : CountdownChip(episode: next),
              ),
            ),
        ],
      ),
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        DetailHeaderBackground(url: data.coverUrl),
        if (data.hasContent) Material(color: Colors.transparent, child: content) else content,
      ],
    );
  }
}

/// Title in at most two lines, shrunk to fit; long press copies it.
class _TitleText extends StatelessWidget {
  final String text;

  const _TitleText(this.text);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: text.isEmpty || text == '?'
          ? null
          : () async {
              final messenger = ScaffoldMessenger.maybeOf(context);
              await Clipboard.setData(ClipboardData(text: text));
              messenger
                ?..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(content: Text(S.current.Dh_Title_Copied)));
            },
      child: AutoSizeText(
        text,
        maxLines: 2,
        minFontSize: 14,
        textAlign: TextAlign.center,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}
