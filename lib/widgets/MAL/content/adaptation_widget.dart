import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/screens/MAL/contentdetailedscreen.dart';
import 'package:mywatchlist/services/api/MAL/mal_anime.dart';
import 'package:mywatchlist/services/api/MAL/scrapper/anime_detailed_html.dart';
import 'package:mywatchlist/widgets/common/avatar_widget.dart';

class AdaptationsWidget extends StatelessWidget {
  final List<AdaptNode> nodes;
  const AdaptationsWidget({super.key, required this.nodes});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 130,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 17.0),
        itemCount: nodes.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) => _buildCard(context, nodes[index]),
      ),
    );
  }

  Widget _buildCard(BuildContext context, AdaptNode node) {
    final theme = Theme.of(context);
    final relation = _parseRelation(node.relation);

    return SizedBox(
      width: 280,
      child: Material(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _navigateToContent(context, node, relation),
          borderRadius: BorderRadius.circular(14),
          child: Row(
            children: [
              // Cover image
              AvatarWidget(
                height: 130,
                width: 90,
                url: node.image,
                userRoundBorderforLoading: false,
                radius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  bottomLeft: Radius.circular(14),
                ),
              ),
              // Info section
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Relation badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          relation.type,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Title
                      Expanded(
                        child: Text(
                          node.animeTitle.name,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            height: 1.3,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Media type (e.g., "Manga", "Light Novel")
                      if (relation.mediaType != null)
                        Text(
                          relation.mediaType!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              // Arrow icon
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToContent(BuildContext context, AdaptNode node, _RelationInfo relation) {
    final url = node.animeTitle.url;
    final id = _extractIdFromUrl(url);
    if (id == null) return;

    final category = url.contains('/manga/') ? 'manga' : 'anime';
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
        category: category,
      ),
    );
  }

  static int? _extractIdFromUrl(String url) {
    // URL format: https://myanimelist.net/anime/33/Name or /manga/2/Name
    final match = RegExp(r'/(?:anime|manga)/(\d+)').firstMatch(url);
    return match != null ? int.tryParse(match.group(1)!) : null;
  }

  /// Parse relation string like "Adaptation (Manga)" into type and media type
  _RelationInfo _parseRelation(String relation) {
    final formatted = formatText(relation);
    final match = RegExp(r'^(.+?)\s*\((.+?)\)$').firstMatch(formatted);
    if (match != null) {
      return _RelationInfo(type: match.group(1)!.trim(), mediaType: match.group(2)!.trim());
    }
    return _RelationInfo(type: formatted);
  }
}

class _RelationInfo {
  final String type;
  final String? mediaType;
  const _RelationInfo({required this.type, this.mediaType});
}
