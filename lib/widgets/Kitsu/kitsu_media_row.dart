import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_catalog.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_media.dart';
import 'package:mywatchlist/services/api/MAL/mal_anime.dart' show Anime;
import 'package:mywatchlist/widgets/MAL/home/contentlistwidget.dart';
import 'package:mywatchlist/widgets/MAL/home/section_header.dart';
import 'package:mywatchlist/widgets/home/home_sections.dart';
import 'package:mywatchlist/widgets/loading/loadingcard.dart';

/// A horizontal row of Kitsu titles with its header: the cards of the home sections, fed by the
/// Kitsu catalogue.
///
/// A title Kitsu maps to no MyAnimeList page cannot open a detail screen, so only the mapped
/// ones are drawn (a row of 20 usually keeps 19 or 20). The answer is kept in memory for
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: title, onTap: onViewAll),
          HomeAsync<List<Anime>>(
            cacheKey: cacheKey,
            maxAge: maxAge,
            refresh: refresh,
            load: () async => [
              for (final m in await load())
                if (m.toAnime() != null) m.toAnime()!,
            ],
            loading: loadingCardList(
              containerHeight: cardHeight,
              height: cardHeight,
              width: cardWidth,
              itemCount: itemCount > 8 ? 8 : itemCount,
              listPadding: const EdgeInsets.all(8),
            ),
            builder: (context, items) {
              if (items.isEmpty) {
                return HomeMessage(icon: Icons.inbox_outlined, text: S.current.Hw_Empty_Items);
              }
              return ContentListWidget(
                category: isAnime ? 'anime' : 'manga',
                items: items,
                height: cardHeight,
                padding: const EdgeInsets.all(8),
                tileWidth: cardWidth,
                tileHeight: cardHeight,
              );
            },
          ),
        ],
      ),
    );
  }
}
