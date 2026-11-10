import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_anime_review.dart';

/// One reaction kind of a MyAnimeList review.
enum ReviewReactionKind { nice, loveIt, funny, confusing, informative, wellWritten, creative }

extension ReviewReactionStyle on ReviewReactionKind {
  String get label => switch (this) {
        ReviewReactionKind.nice => S.current.Social_Reaction_Nice,
        ReviewReactionKind.loveIt => S.current.Social_Reaction_Love_It,
        ReviewReactionKind.funny => S.current.Social_Reaction_Funny,
        ReviewReactionKind.confusing => S.current.Social_Reaction_Confusing,
        ReviewReactionKind.informative => S.current.Social_Reaction_Informative,
        ReviewReactionKind.wellWritten => S.current.Social_Reaction_Well_Written,
        ReviewReactionKind.creative => S.current.Social_Reaction_Creative,
      };

  IconData get icon => switch (this) {
        ReviewReactionKind.nice => Icons.thumb_up,
        ReviewReactionKind.loveIt => Icons.favorite,
        ReviewReactionKind.funny => Icons.mood,
        ReviewReactionKind.confusing => Icons.help_outline,
        ReviewReactionKind.informative => Icons.psychology,
        ReviewReactionKind.wellWritten => Icons.description,
        ReviewReactionKind.creative => Icons.lightbulb_outline,
      };
}

/// The non-zero reactions of a review, most numerous first.
List<(ReviewReactionKind, int)> sortedReactions(Reactions? reactions) {
  if (reactions == null) return const [];
  final all = <(ReviewReactionKind, int?)>[
    (ReviewReactionKind.nice, reactions.nice),
    (ReviewReactionKind.loveIt, reactions.loveIt),
    (ReviewReactionKind.funny, reactions.funny),
    (ReviewReactionKind.confusing, reactions.confusing),
    (ReviewReactionKind.informative, reactions.informative),
    (ReviewReactionKind.wellWritten, reactions.wellWritten),
    (ReviewReactionKind.creative, reactions.creative),
  ];
  final result = [
    for (final (kind, count) in all)
      if ((count ?? 0) > 0) (kind, count!),
  ];
  result.sort((a, b) => b.$2.compareTo(a.$2));
  return result;
}
