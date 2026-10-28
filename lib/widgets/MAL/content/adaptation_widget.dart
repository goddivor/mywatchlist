import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/MAL/contentdetailedscreen.dart';
import 'package:mywatchlist/services/api/MAL/mal_anime.dart';
import 'package:mywatchlist/services/api/MAL/scrapper/anime_detailed_html.dart';
import 'package:mywatchlist/widgets/common/app_image.dart';
import 'package:mywatchlist/widgets/user/list/list_query.dart' show mediaTypeLabel;

/// Adaptations of a title, laid out like DailyAL's tiles: a small card with
/// the picture faded behind a centred title and the media type under it.
/// No relation chip: the section title already says "Adaptations".
class AdaptationsWidget extends StatelessWidget {
  final List<AdaptNode> nodes;
  const AdaptationsWidget({super.key, required this.nodes});

  static const double tileWidth = 160;
  static const double tileHeight = 105;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: tileHeight,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 17.0),
        itemCount: nodes.length,
        itemBuilder: (context, index) => AdaptationTile(node: nodes[index]),
      ),
    );
  }
}

/// One adaptation: DailyAL's card (160 x 105, 12 dp corners).
class AdaptationTile extends StatelessWidget {
  final AdaptNode node;
  const AdaptationTile({super.key, required this.node});

  static final BorderRadius _radius = BorderRadius.circular(12);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = scheme.surfaceContainerLow;
    final kind = adaptationKindLabel(node);
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Material(
        color: background,
        borderRadius: _radius,
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: AdaptationsWidget.tileWidth,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // DailyAL fades the picture to 10 %; an alpha veil does the
              // same without a saveLayer per tile.
              if (node.image.isNotEmpty)
                AppImage(
                  url: node.image,
                  width: AdaptationsWidget.tileWidth,
                  height: AdaptationsWidget.tileHeight,
                  placeholderColor: background,
                  errorWidget: (_) => const SizedBox.shrink(),
                ),
              ColoredBox(color: background.withValues(alpha: 0.9)),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 18, 8, 18),
                child: Column(
                  children: [
                    Expanded(
                      child: Center(
                        child: Text(
                          node.animeTitle.name,
                          textAlign: TextAlign.center,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13, color: scheme.onSurface),
                        ),
                      ),
                    ),
                    if (kind.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        kind,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ],
                ),
              ),
              // On top, so the ripple shows over the veil.
              Material(
                type: MaterialType.transparency,
                child: InkWell(onTap: () => _open(context)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _open(BuildContext context) {
    final url = node.animeTitle.url;
    final id = adaptationId(url);
    if (id == null) return;
    gotoPage(
      context: context,
      newPage: ContentDetailedScreen(
        node: Anime(
          id: id,
          title: node.animeTitle.name,
          imageUrl: node.image,
          score: 0,
          members: 0,
        ),
        category: adaptationCategory(url),
      ),
    );
  }
}

/// MAL id in `https://myanimelist.net/anime/33/Name` or `/manga/2/Name`.
int? adaptationId(String url) {
  final match = RegExp(r'/(?:anime|manga)/(\d+)').firstMatch(url);
  return match != null ? int.tryParse(match.group(1)!) : null;
}

/// `manga` or `anime`, from the entry URL.
String adaptationCategory(String url) => url.contains('/manga/') ? 'manga' : 'anime';

/// Translated media type of an adaptation: MAL writes the relation as
/// "Adaptation (Light Novel)"; without the parentheses, the entry kind.
String adaptationKindLabel(AdaptNode node) {
  final match = RegExp(r'\(([^()]+)\)\s*$').firstMatch(node.relation.trim());
  final type = match?.group(1)?.trim();
  if (type != null && type.isNotEmpty) {
    return mediaTypeLabel(type.toLowerCase().replaceAll(RegExp(r'[\s-]+'), '_'));
  }
  if (node.animeTitle.url.isEmpty) return '';
  return adaptationCategory(node.animeTitle.url) == 'manga'
      ? S.current.UserList_Media_Manga
      : S.current.Anime_Caps;
}
