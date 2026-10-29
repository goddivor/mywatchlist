import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_graphql.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_social.dart';
import 'package:mywatchlist/widgets/Kitsu/profile/kitsu_paged_tab.dart';
import 'package:mywatchlist/widgets/Kitsu/profile/kitsu_profile_rows.dart';
import 'package:mywatchlist/widgets/user/list/list_entry_view.dart' show ListEntryStatus;

/// What happened in a [KitsuLibraryEvent], as a sentence in the app language ("Watched episode
/// 4", "Moved from Watching to Dropped"), or `null` for a kind with nothing more to say.
String kitsuEventText(KitsuLibraryEvent event) {
  final s = S.current;
  final isAnime = event.media.kind == KitsuMediaKind.anime;
  final status = event.changes['status'];
  final rating = event.changes['rating'];
  final progress = event.changedTo('progress');
  String statusLabel(Object? value) {
    final mapped = ListEntryStatus.fromMal(switch ('$value') {
      'current' => isAnime ? 'watching' : 'reading',
      'planned' => isAnime ? 'plan_to_watch' : 'plan_to_read',
      final other => other,
    });
    return mapped == null ? '$value' : kitsuStatusLabel(mapped, isAnime: isAnime);
  }

  String score(Object? value) {
    final n = value is num ? value : num.tryParse('$value');
    if (n == null) return '-';
    final out = n / 2;
    return out == out.roundToDouble() ? '${out.round()}' : out.toStringAsFixed(1);
  }

  if (status != null && status.length >= 2 && status[1] != null) {
    return status[0] == null
        ? s.Kitsu_Activity_Status(statusLabel(status[1]))
        : s.Kitsu_Activity_Status_From(statusLabel(status[0]), statusLabel(status[1]));
  }
  if (progress is num) {
    return isAnime
        ? s.Kitsu_Activity_Progress_Anime(progress.toInt())
        : s.Kitsu_Activity_Progress_Manga(progress.toInt());
  }
  if (rating != null && rating.length >= 2 && rating[1] != null) {
    return rating[0] == null
        ? s.Kitsu_Activity_Rated(score(rating[1]))
        : s.Kitsu_Activity_Rated_From(score(rating[0]), score(rating[1]));
  }
  return switch (event.kind) {
    'REACTED' => s.Kitsu_Activity_Reacted,
    'ANNOTATED' => s.Kitsu_Activity_Annotated,
    _ => s.Kitsu_Activity_Updated,
  };
}

/// The "Activity" tab: what the user did on their list, newest first.
class KitsuActivityTab extends StatelessWidget {
  final String slug;
  final KitsuSocial? social;

  const KitsuActivityTab({super.key, required this.slug, this.social});

  @override
  Widget build(BuildContext context) {
    final api = social ?? KitsuSocial.instance;
    return KitsuPagedList<KitsuLibraryEvent>(
      storageKey: 'kitsu_activity_$slug',
      createPager: () => KitsuPager((page) => api.activity(slug, page)),
      emptyText: S.of(context).Kitsu_Activity_Empty,
      itemBuilder: (context, event) => KitsuMediaLine(
        key: ValueKey(event.id),
        media: event.media,
        headline: kitsuEventText(event),
        detail: kitsuTimeAgo(event.createdAt),
      ),
    );
  }
}

/// The last few events of the user for the top of the profile; hidden while loading, when it
/// fails and when there is nothing to show.
class KitsuRecentActivity extends StatefulWidget {
  final String slug;
  final KitsuSocial? social;

  const KitsuRecentActivity({super.key, required this.slug, this.social});

  @override
  State<KitsuRecentActivity> createState() => _KitsuRecentActivityState();
}

class _KitsuRecentActivityState extends State<KitsuRecentActivity> {
  late final Future<List<KitsuLibraryEvent>> _future = (widget.social ?? KitsuSocial.instance)
      .activity(widget.slug, const KitsuPageArgs(first: 5))
      .then((c) => c.nodes);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<KitsuLibraryEvent>>(
      future: _future,
      builder: (context, snapshot) {
        final events = snapshot.data;
        if (events == null || events.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(S.of(context).Kitsu_Recent_Activity,
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            for (final event in events)
              KitsuMediaLine(
                key: ValueKey(event.id),
                media: event.media,
                headline: kitsuEventText(event),
                detail: kitsuTimeAgo(event.createdAt),
              ),
          ],
        );
      },
    );
  }
}
