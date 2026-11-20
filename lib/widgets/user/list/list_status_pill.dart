import 'package:flutter/material.dart';
import 'package:mywatchlist/user/list_cache/list_status_cache.dart';
import 'package:mywatchlist/widgets/MAL/home/animegridcard.dart' show NodeStatusValue;

/// "In my list" for a row: the status of [id] in the user's list (from [ListStatusCache], kept
/// up to date by every edit and the background list read) as a coloured pill, with the score
/// the user gave when there is one. Nothing when the title is not in the list. Rebuilds alone
/// when that entry changes.
class ListStatusPill extends StatelessWidget {
  final int id;

  /// `anime` or `manga`.
  final String category;

  const ListStatusPill({super.key, required this.id, required this.category});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<CachedListStatus?>(
      valueListenable: ListStatusCache.instance.watch(id, category: category),
      builder: (context, entry, _) {
        if (entry == null) return const SizedBox.shrink();
        final value = NodeStatusValue.fromString(entry.status);
        final role = value.role(context);
        final label = value.status;
        if (role == null || label == null) return const SizedBox.shrink();
        final theme = Theme.of(context);
        final style = theme.textTheme.labelSmall
            ?.copyWith(color: role.onContainer, fontWeight: FontWeight.w700);
        return Semantics(
          label: [value.fullLabel ?? label, if (entry.score > 0) '${entry.score}'].join(', '),
          excludeSemantics: true,
          child: Container(
            key: ValueKey('list-status-$category-$id'),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: role.container,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: style),
                if (entry.score > 0) ...[
                  const SizedBox(width: 6),
                  Icon(Icons.star_rounded, size: 12, color: role.onContainer),
                  const SizedBox(width: 2),
                  Text('${entry.score}', style: style),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
