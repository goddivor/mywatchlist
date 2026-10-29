import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_detail_models.dart';
import 'package:mywatchlist/widgets/Simkl/media/simkl_media_format.dart';
import 'package:mywatchlist/widgets/Simkl/media/simkl_media_sections.dart' show simklPagePadding;
import 'package:mywatchlist/widgets/common/app_colors.dart';
import 'package:mywatchlist/widgets/common/app_image.dart';
import 'package:mywatchlist/widgets/user/list/list_entry_view.dart';

/// What the next-episode card of the title page says.
enum SimklNextKind {
  /// The user's next episode has aired: it can be marked watched.
  watchNext,

  /// The next episode (the user's, or the title's) is still to air.
  upcoming,

  /// The title has finished airing (not on the user's list, or nothing left to watch).
  ended,

  /// Everything is watched and the title has a direct sequel.
  sequel,
}

/// The next-episode card's content: episode number, its title and air time, or the sequel.
@immutable
class SimklNextUp {
  final SimklNextKind kind;
  final int? episode;
  final String? episodeTitle;
  final DateTime? date;
  final SimklLinkedTitle? sequel;

  const SimklNextUp(this.kind, {this.episode, this.episodeTitle, this.date, this.sequel});
}

/// Computes the next-episode card from the record, its episodes and the user's entry (null =
/// not on the list or signed out). Null when there is nothing worth a card.
SimklNextUp? simklNextUp({
  required SimklTitle title,
  required List<SimklEpisode>? episodes,
  required ListEntryView? entry,
  required DateTime now,
}) {
  final regular = [
    for (final e in episodes ?? const <SimklEpisode>[])
      if (!e.isSpecial && e.number != null) e,
  ]..sort((a, b) => a.number!.compareTo(b.number!));
  bool aired(SimklEpisode e) => e.aired && (e.date == null || !e.date!.isAfter(now));
  final ended = SimklFormat.status(title.status) == S.current.Smp_Status_Ended;
  final sequel = title.relations
      .where((r) => r.relationType?.toLowerCase() == 'sequel')
      .firstOrNull;
  final total = entry != null && entry.total > 0 ? entry.total : (title.totalEpisodes ?? 0);

  final status = entry?.status;
  if (entry != null && status != null && status != ListEntryStatus.dropped) {
    final next = entry.progress + 1;
    final done = status == ListEntryStatus.completed || (total > 0 && next > total);
    if (done) return sequel == null ? null : SimklNextUp(SimklNextKind.sequel, sequel: sequel);
    final ep = regular.where((e) => e.number == next).firstOrNull;
    if (ep == null) {
      // No episode list: an ended title with episodes left has them all aired.
      return ended ? SimklNextUp(SimklNextKind.watchNext, episode: next) : null;
    }
    if (aired(ep)) return SimklNextUp(SimklNextKind.watchNext, episode: next, episodeTitle: _t(ep), date: ep.date);
    return SimklNextUp(SimklNextKind.upcoming, episode: next, episodeTitle: _t(ep), date: ep.date);
  }

  final coming = regular.where((e) => !aired(e) && e.date != null).firstOrNull;
  if (coming != null) {
    return SimklNextUp(SimklNextKind.upcoming, episode: coming.number, episodeTitle: _t(coming), date: coming.date);
  }
  final last = regular.where(aired).lastOrNull;
  if (last != null && ended) {
    return SimklNextUp(SimklNextKind.ended, episode: last.number, episodeTitle: _t(last), date: last.date);
  }
  return null;
}

String? _t(SimklEpisode e) => e.title.isEmpty ? null : e.title;

/// The next-episode card: what to watch next (with "Mark Ep. N watched"), when the next episode
/// airs (exact time in the time zone setting and a countdown), the last aired episode, or the
/// sequel once everything is watched.
class SimklNextEpisodeCard extends StatelessWidget {
  final SimklNextUp next;
  final DateTime now;
  final VoidCallback? onMark;
  final bool marking;
  final VoidCallback? onOpenSequel;

  const SimklNextEpisodeCard({
    super.key,
    required this.next,
    required this.now,
    this.onMark,
    this.marking = false,
    this.onOpenSequel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final s = S.current;
    final heading = switch (next.kind) {
      SimklNextKind.watchNext || SimklNextKind.sequel => s.Skr_Next_To_Watch,
      SimklNextKind.upcoming => s.Skr_Next_Episode,
      SimklNextKind.ended => s.Skr_Last_Aired,
    };
    final sequel = next.sequel;
    final line = sequel != null
        ? '${s.Smp_Rel_Sequel} · ${sequel.title}'
        : [
            if (next.episode != null) s.Sk_Episode_Short(next.episode!),
            if (next.episodeTitle != null) next.episodeTitle!,
          ].join(' · ');
    final date = next.date;
    final detail = switch (next.kind) {
      SimklNextKind.upcoming when date != null =>
        [SimklFormat.dayClock(date), SimklFormat.countdown(date, now)].whereType<String>().join(' · '),
      SimklNextKind.ended => [
          if (date != null) SimklFormat.episodeDate(date),
          s.Smp_Status_Ended,
        ].join(' · '),
      SimklNextKind.watchNext when date != null => SimklFormat.episodeDate(date),
      SimklNextKind.sequel => [
          if (sequel?.animeType != null) SimklFormat.type(sequel!.animeType),
          if (sequel?.year != null) '${sequel!.year}',
        ].whereType<String>().join(' · '),
      _ => '',
    };
    final icon = switch (next.kind) {
      SimklNextKind.watchNext => Icons.play_circle_outline_rounded,
      SimklNextKind.upcoming => Icons.schedule_rounded,
      SimklNextKind.ended => Icons.flag_outlined,
      SimklNextKind.sequel => Icons.skip_next_rounded,
    };
    final mark = next.kind == SimklNextKind.watchNext && next.episode != null ? onMark : null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(simklPagePadding, 12, simklPagePadding, 0),
      child: Material(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: next.kind == SimklNextKind.sequel ? onOpenSequel : null,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
            child: Row(
              children: [
                if (sequel?.posterUrl != null) ...[
                  AppImage(
                    url: sequel!.posterUrl,
                    width: 44,
                    height: 66,
                    borderRadius: BorderRadius.circular(8),
                    placeholderColor: scheme.surfaceContainerHighest,
                  ),
                  const SizedBox(width: 12),
                ] else ...[
                  Icon(icon, color: scheme.onSecondaryContainer),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(heading, style: theme.textTheme.labelMedium?.copyWith(color: scheme.onSecondaryContainer)),
                      if (line.isNotEmpty)
                        Text(
                          line,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(color: scheme.onSecondaryContainer),
                        ),
                      if (detail.isNotEmpty)
                        Text(
                          detail,
                          style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSecondaryContainer),
                        ),
                    ],
                  ),
                ),
                if (mark != null)
                  marking
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.5)),
                        )
                      : IconButton.filled(
                          tooltip: s.Skr_Mark_Watched(next.episode!),
                          onPressed: mark,
                          icon: const Icon(Icons.check_rounded),
                        )
                else if (next.kind == SimklNextKind.sequel)
                  Icon(Icons.chevron_right_rounded, color: scheme.onSecondaryContainer),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The user's place in the title: list status (or "Add to list"), their rating and the
/// progress bar. Every part opens the list editor.
class SimklMyStatusBar extends StatelessWidget {
  final ListEntryView? entry;
  final int total;
  final VoidCallback onEdit;

  const SimklMyStatusBar({super.key, required this.entry, required this.total, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = AppColors.of(context);
    final s = S.current;
    final e = entry;
    final status = e?.status;
    final role = status?.colors(context);
    final known = total > 0 ? total : (e?.total ?? 0);
    final statusButton = status == null
        ? FilledButton.icon(onPressed: onEdit, icon: const Icon(Icons.add), label: Text(s.Smp_Add_To_List))
        : FilledButton.icon(
            onPressed: onEdit,
            style: FilledButton.styleFrom(backgroundColor: role!.container, foregroundColor: role.onContainer),
            icon: Icon(status.icon),
            label: Text(status.label(isAnime: true)),
          );
    return Padding(
      padding: const EdgeInsets.fromLTRB(simklPagePadding, 14, simklPagePadding, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: statusButton),
              const SizedBox(width: 8),
              FilledButton.tonalIcon(
                onPressed: onEdit,
                icon: Icon(
                  (e?.score ?? 0) > 0 ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: (e?.score ?? 0) > 0 ? colors.score.color : null,
                ),
                label: Text((e?.score ?? 0) > 0 ? '${e!.score}' : s.Skr_Rate),
              ),
            ],
          ),
          if (e != null && status != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: known > 0 ? (e.progress / known).clamp(0.0, 1.0) : 0,
                      minHeight: 6,
                      color: role!.color,
                      backgroundColor: scheme.surfaceContainerHighest,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  known > 0 ? '${e.progress} / $known' : '${e.progress}',
                  style: theme.textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
