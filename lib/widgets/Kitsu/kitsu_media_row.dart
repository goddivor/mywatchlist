import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_catalog.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_media.dart';
import 'package:mywatchlist/widgets/Kitsu/kitsu_media_tile.dart';
import 'package:mywatchlist/widgets/MAL/home/section_header.dart';
import 'package:mywatchlist/widgets/common/app_colors.dart';
import 'package:mywatchlist/widgets/home/home_sections.dart';
import 'package:mywatchlist/widgets/loading/loadingcard.dart';

/// A horizontal row of Kitsu titles with its header: the cards of the home sections, fed by the
/// Kitsu catalogue.
///
/// Every title is drawn, mapped to MyAnimeList or not: Kitsu is its own app, and a tap opens the
/// title through the Kitsu tile. The answer is kept in memory for
/// [maxAge] like the other home sections (cleared by a pull to refresh through [refresh]).
class KitsuMediaRow extends StatelessWidget {
  final String cacheKey;
  final String title;
  final bool isAnime;
  final Future<List<KitsuMedia>> Function() load;
  final double cardWidth;
  final double cardHeight;
  final int itemCount;
  final Duration maxAge;
  final int refresh;

  /// Opens the full list ("View all"); null shows a plain title.
  final VoidCallback? onViewAll;

  /// Draws nothing, header included, when the row is empty or fails (a bonus row such as "popular
  /// with people you follow": it appears only when there is something to show).
  final bool hideWhenEmpty;

  const KitsuMediaRow({
    super.key,
    required this.cacheKey,
    required this.title,
    required this.isAnime,
    required this.load,
    required this.cardWidth,
    required this.cardHeight,
    this.itemCount = 15,
    this.maxAge = const Duration(hours: 2),
    this.refresh = 0,
    this.onViewAll,
    this.hideWhenEmpty = false,
  });

  /// A row of the catalogue search [query].
  factory KitsuMediaRow.query({
    Key? key,
    required String title,
    required KitsuMediaQuery query,
    required double cardWidth,
    required double cardHeight,
    int itemCount = 15,
    Duration maxAge = const Duration(hours: 2),
    int refresh = 0,
    VoidCallback? onViewAll,
  }) =>
      KitsuMediaRow(
        key: key,
        cacheKey: 'kitsu:${query.key}:$itemCount',
        title: title,
        isAnime: query.isAnime,
        load: () async =>
            (await KitsuCatalog.instance.page(query, limit: itemCount)).items,
        cardWidth: cardWidth,
        cardHeight: cardHeight,
        itemCount: itemCount,
        maxAge: maxAge,
        refresh: refresh,
        onViewAll: onViewAll,
      );

  /// The horizontal strip of Kitsu tiles shared by every row of the Kitsu home.
  static Widget cards({required List<KitsuMedia> items, required double cardWidth}) => SizedBox(
        height: cardWidth * 1.5 + KitsuMediaTile.textHeight + 8,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
          itemCount: items.length,
          separatorBuilder: (context, index) => const SizedBox(width: 10),
          itemBuilder: (context, i) => SizedBox(
            width: cardWidth,
            child: tile(items[i]),
          ),
        ),
      );

  /// A Kitsu tile with the community score as Kitsu writes it ("88%", small, in the corner)
  /// instead of a score out of 10.
  static Widget tile(KitsuMedia media) {
    final score = media.meanScore;
    final plain = KitsuMedia(
      id: media.id,
      isAnime: media.isAnime,
      title: media.title,
      otherTitles: media.otherTitles,
      posterUrl: media.posterUrl,
      largePosterUrl: media.largePosterUrl,
      subtype: media.subtype,
      releaseState: media.releaseState,
      userCount: media.userCount,
      popularityRank: media.popularityRank,
      ratingRank: media.ratingRank,
      total: media.total,
      totalVolumes: media.totalVolumes,
      startDate: media.startDate,
      endDate: media.endDate,
      synopsis: media.synopsis,
      malId: media.malId,
    );
    final key = ValueKey('${media.category}:${media.id}');
    if (score == null) return KitsuMediaTile(key: key, media: plain);
    return Stack(
      key: key,
      children: [
        Positioned.fill(child: KitsuMediaTile(media: plain)),
        PositionedDirectional(top: 6, end: 6, child: KitsuPercentBadge(percent: score * 10)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final header = SectionHeader(title: title, onTap: onViewAll);
    Widget section(Widget body) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [header, body],
          ),
        );
    final loading = loadingCardList(
      containerHeight: cardHeight,
      height: cardHeight,
      width: cardWidth,
      itemCount: itemCount > 8 ? 8 : itemCount,
      listPadding: const EdgeInsets.all(8),
    );
    Widget cards(List<KitsuMedia> items) => KitsuMediaRow.cards(items: items, cardWidth: cardWidth);
    Future<List<KitsuMedia>> loadCards() => load();

    if (hideWhenEmpty) {
      return HomeAsync<List<KitsuMedia>>(
        cacheKey: cacheKey,
        maxAge: maxAge,
        refresh: refresh,
        load: () async {
          try {
            return await loadCards();
          } catch (_) {
            return const <KitsuMedia>[];
          }
        },
        loading: section(loading),
        builder: (context, items) => items.isEmpty ? const SizedBox.shrink() : section(cards(items)),
      );
    }
    return section(HomeAsync<List<KitsuMedia>>(
      cacheKey: cacheKey,
      maxAge: maxAge,
      refresh: refresh,
      load: loadCards,
      loading: loading,
      builder: (context, items) => items.isEmpty
          ? HomeMessage(icon: Icons.inbox_outlined, text: S.current.Hw_Empty_Items)
          : cards(items),
    ));
  }
}

/// Kitsu's community score on a poster: "88%" on the picture scrim.
class KitsuPercentBadge extends StatelessWidget {
  final double percent;

  const KitsuPercentBadge({super.key, required this.percent});

  @override
  Widget build(BuildContext context) {
    final tokens = AppColors.of(context);
    final text = '${percent.round()}%';
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.imageScrim.withValues(alpha: AppColors.imageScrimOpacity),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          child: Text(
            text,
            semanticsLabel: S.current.Kr_Community_Score(text),
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: tokens.onImageScrim, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}
