import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_catalog.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_media.dart';
import 'package:mywatchlist/widgets/Kitsu/kitsu_media_tile.dart';
import 'package:mywatchlist/widgets/MAL/home/section_header.dart';
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
            child: KitsuMediaTile(
              key: ValueKey('${items[i].category}:${items[i].id}'),
              media: items[i],
            ),
          ),
        ),
      );

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
