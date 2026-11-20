import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/user/list_cache/list_status_cache.dart';
import 'package:mywatchlist/widgets/MAL/home/animegridcard.dart' show NodeStatusValue;

/// The signed-in user's own entry for a title of another user's list: a person icon, the
/// status in its colour and the score, so it never reads as the other user's status pill
/// next to it. Read from [ListStatusCache] (the whole list is kept there); nothing when the
/// title is not in the user's list. Rebuilds alone when that entry changes.
class MyListMark extends StatelessWidget {
  const MyListMark({
    super.key,
    required this.id,
    required this.category,
    this.dense = false,
    this.onImage = false,
    this.cache,
  });

  final int id;

  /// `anime` or `manga`.
  final String category;

  /// The tighter form for small cards and covers.
  final bool dense;

  /// Drawn over a cover: a thin outline keeps it apart from the picture.
  final bool onImage;

  /// The user's statuses (tests give their own).
  final ListStatusCache? cache;

  @override
  Widget build(BuildContext context) {
    final source = cache ?? ListStatusCache.instance;
    return ValueListenableBuilder<CachedListStatus?>(
      valueListenable: source.watch(id, category: category),
      builder: (context, entry, _) {
        if (entry == null) return const SizedBox.shrink();
        final value = NodeStatusValue.fromString(entry.status);
        final role = value.role(context);
        final label = value.status;
        if (role == null || label == null) return const SizedBox.shrink();
        final s = S.of(context);
        final full = value.fullLabel ?? label;
        final theme = Theme.of(context);
        final style = theme.textTheme.labelSmall?.copyWith(
          color: role.onContainer,
          fontWeight: FontWeight.w700,
          fontSize: dense ? 10 : 11,
          height: 1.1,
        );
        final iconSize = dense ? 12.0 : 13.0;
        return Semantics(
          label: entry.score > 0 ? s.Mlp_Mine_Score(full, entry.score) : s.Mlp_Mine(full),
          excludeSemantics: true,
          child: Container(
            key: ValueKey('my-list-$category-$id'),
            padding: EdgeInsets.symmetric(horizontal: dense ? 5 : 7, vertical: dense ? 2 : 3),
            decoration: BoxDecoration(
              color: role.container,
              borderRadius: BorderRadius.circular(999),
              border: onImage ? Border.all(color: role.onContainer.withValues(alpha: 0.35)) : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.person_rounded, size: iconSize, color: role.onContainer),
                const SizedBox(width: 3),
                Text(label, style: style),
                if (entry.score > 0) ...[
                  SizedBox(width: dense ? 3 : 5),
                  Icon(Icons.star_rounded, size: iconSize - 1, color: role.onContainer),
                  const SizedBox(width: 1),
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
