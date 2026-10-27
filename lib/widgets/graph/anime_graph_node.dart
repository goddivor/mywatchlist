import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/user/list_cache/list_status_cache.dart';
import 'package:mywatchlist/widgets/MAL/home/animegridcard.dart'
    show NodeStatusValue;
import 'package:mywatchlist/widgets/common/app_image.dart';
import 'package:mywatchlist/widgets/graph/anime_graph_data.dart';
import 'package:mywatchlist/widgets/graph/graph_labels.dart';

/// Size of a node as the layout sees it. Fixed, so a tap or a selection never moves the graph.
const Size kGraphNodeSize = Size(124, 168);
const double _cover = 96;

/// One title of the graph: round cover, title and "year · type".
///
/// Built once per node. A selection change repaints only the ring (a [ValueListenableBuilder]
/// whose child, the cover, is not rebuilt) and a list status change only the ring color; no
/// opacity layer, blur or shadow, so a graph of dozens of titles stays smooth to pan and zoom.
class AnimeGraphNode extends StatelessWidget {
  final GraphNodeData node;
  final ValueListenable<int> selectedId;

  /// The status in the list when the cache does not know the title (MAL's words).
  final String? fallbackStatus;

  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const AnimeGraphNode({
    super.key,
    required this.node,
    required this.selectedId,
    required this.onTap,
    required this.onLongPress,
    this.fallbackStatus,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cover = ClipOval(
      child: AppImage(
        url: node.imageUrl,
        width: _cover,
        height: _cover,
        placeholderColor: theme.colorScheme.surfaceContainerHighest,
        errorWidget: (_) => ColoredBox(
          color: theme.colorScheme.surfaceContainerHighest,
          child: Icon(Icons.movie_outlined,
              color: theme.colorScheme.onSurfaceVariant),
        ),
      ),
    );
    final meta = [
      if (node.year != null) '${node.year}',
      GraphLabels.mediaType(node.mediaType),
    ].where((e) => e.isNotEmpty).join(' · ');

    // A drawing with a fixed node size: system text scaling would overflow it.
    return MediaQuery.withNoTextScaling(
        child: SizedBox(
      width: kGraphNodeSize.width,
      height: kGraphNodeSize.height,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        onLongPress: onLongPress,
        child: Column(
          children: [
            ValueListenableBuilder<CachedListStatus?>(
              valueListenable: ListStatusCache.instance.watch(node.id),
              builder: (context, cached, _) {
                final status = cached?.status ?? fallbackStatus;
                final color = status == null
                    ? null
                    : NodeStatusValue.fromString(status).color;
                return ValueListenableBuilder<int>(
                  valueListenable: selectedId,
                  child: cover,
                  builder: (context, selected, child) {
                    final isSelected = selected == node.id;
                    return Container(
                      width: _cover + 16,
                      height: _cover + 16,
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected
                            ? theme.colorScheme.primary.withValues(alpha: 0.18)
                            : null,
                        border: Border.all(
                          color: isSelected
                              ? theme.colorScheme.primary
                              : (color ?? theme.colorScheme.outlineVariant),
                          width: isSelected ? 4 : (color == null ? 1.5 : 3),
                        ),
                      ),
                      child: child,
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 6),
            Text(
              node.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelMedium
                  ?.copyWith(height: 1.15, fontWeight: FontWeight.w600),
            ),
            if (meta.isNotEmpty)
              Text(
                meta,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
          ],
        ),
      ),
    ));
  }
}

/// The text of a node's details line in the sheet: season, type, airing status.
String graphNodeSummary(GraphNodeData node) {
  final parts = [
    GraphLabels.season(node.season, node.year),
    GraphLabels.mediaType(node.mediaType),
    GraphLabels.airing(node.status),
  ].where((e) => e.isNotEmpty);
  final text = parts.join(' · ');
  return text.isEmpty ? S.current.Rg_Unknown : text;
}
