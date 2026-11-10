import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/MAL/contentdetailedscreen.dart';
import 'package:mywatchlist/services/api/MAL/mal_anime.dart';
import 'package:mywatchlist/services/api/MAL/scrapper/anime_detailed_html.dart';
import 'package:mywatchlist/widgets/common/app_image.dart';
import 'package:mywatchlist/widgets/user/list/list_query.dart' show mediaTypeLabel;

/// Adaptations of a title: a horizontal row of cards with the cover on the left, a relation
/// badge, the title and the media type, and a chevron (MWL's own look, the owner's choice over
/// DailyAL's faded tiles).
class AdaptationsWidget extends StatelessWidget {
  final List<AdaptNode> nodes;
  const AdaptationsWidget({super.key, required this.nodes});

  static const double tileWidth = 280;
  static const double tileHeight = 130;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: tileHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 17.0),
        itemCount: nodes.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) => AdaptationTile(node: nodes[index]),
      ),
    );
  }
}

/// One adaptation: cover, relation badge, title, media type and a chevron.
class AdaptationTile extends StatelessWidget {
  final AdaptNode node;
  const AdaptationTile({super.key, required this.node});

  static final BorderRadius _radius = BorderRadius.circular(14);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final kind = adaptationKindLabel(node);
    final relation = adaptationRelationLabel(node);
    return SizedBox(
      width: AdaptationsWidget.tileWidth,
      child: Material(
        color: scheme.surfaceContainerLow,
        borderRadius: _radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _open(context),
          child: Row(
            children: [
              AppImage(
                url: node.image,
                width: 90,
                height: AdaptationsWidget.tileHeight,
                placeholderColor: scheme.surfaceContainerHighest,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (relation.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: scheme.primaryContainer,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            relation,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: scheme.onPrimaryContainer,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      Expanded(
                        child: Text(
                          node.animeTitle.name,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600, height: 1.3),
                        ),
                      ),
                      if (kind.isNotEmpty)
                        Text(
                          kind,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant, fontSize: 12),
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
                ),
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

/// The relation MAL writes before the parentheses ("Adaptation (Manga)" gives "Adaptation").
String adaptationRelationLabel(AdaptNode node) =>
    node.relation.replaceAll(RegExp(r'\([^()]*\)\s*$'), '').trim();
