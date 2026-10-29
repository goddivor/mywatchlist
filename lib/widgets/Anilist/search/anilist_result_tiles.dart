import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mywatchlist/constants/constants.dart' show AccountType;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_discover_service.dart';
import 'package:mywatchlist/services/tracker_sync_service.dart';
import 'package:mywatchlist/widgets/Anilist/search/anilist_labels.dart';
import 'package:mywatchlist/widgets/Anilist/search/anilist_search_links.dart';
import 'package:mywatchlist/widgets/common/app_colors.dart';
import 'package:mywatchlist/widgets/common/app_image.dart';
import 'package:mywatchlist/widgets/user/sync/sync_entry.dart';
import 'package:mywatchlist/widgets/user/sync/tracker_clients.dart';
import 'package:mywatchlist/widgets/user/sync/tracker_entry_editor.dart';

/// The colour of an AniList score (0-100), anilist.co's scale: under 50 red, under 75 amber,
/// else green.
AppColorRole anilistScoreRole(BuildContext context, int score) {
  final colors = AppColors.of(context);
  if (score < 50) return colors.danger;
  if (score < 75) return colors.warning;
  return colors.success;
}

/// `82%` in the colour of the score, with a face like anilist.co.
class AnilistScoreLabel extends StatelessWidget {
  final int score;
  final TextStyle? style;
  const AnilistScoreLabel({super.key, required this.score, this.style});

  @override
  Widget build(BuildContext context) {
    final color = anilistScoreRole(context, score).color;
    final icon = score < 50
        ? Icons.sentiment_dissatisfied_rounded
        : score < 75
            ? Icons.sentiment_neutral_rounded
            : Icons.sentiment_satisfied_alt_rounded;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 3),
        Text('$score%',
            style: (style ?? Theme.of(context).textTheme.bodySmall)
                ?.copyWith(color: color, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

/// `TV · 28 eps · 2023` (anime) or `Manga · 120 ch · 2019`.
String anilistTypeLine(AnilistSearchMedia item) {
  final m = item.media;
  final s = S.current;
  final length = m.isAnime
      ? (m.episodes != null && m.episodes! > 0
          ? (m.format == 'MOVIE' && item.duration != null && item.duration! > 0
              ? s.Als_Minutes_Short(item.duration!)
              : s.Srch_Episodes_Short(m.episodes!))
          : null)
      : (m.chapters != null && m.chapters! > 0
          ? s.Als_Chapters_Short(m.chapters!)
          : item.volumes != null && item.volumes! > 0
              ? s.Srch_Volumes_Short(item.volumes!)
              : null);
  final year = item.startYear ?? m.seasonYear;
  return [
    if (m.format != null) AnilistLabels.format(m.format!),
    if (length != null) length,
    if (year != null) '$year',
  ].join(' · ');
}

/// The signed-in user's status badge of [entry].
class AnilistStatusBadge extends StatelessWidget {
  final AnilistListEntry entry;
  final bool anime;
  const AnilistStatusBadge({super.key, required this.entry, required this.anime});

  @override
  Widget build(BuildContext context) {
    final role = AppColors.of(context).statusOf(entry.status) ??
        AppColorRole(
          color: Theme.of(context).colorScheme.primary,
          onColor: Theme.of(context).colorScheme.onPrimary,
          container: Theme.of(context).colorScheme.primaryContainer,
          onContainer: Theme.of(context).colorScheme.onPrimaryContainer,
        );
    return DecoratedBox(
      decoration: BoxDecoration(color: role.container, borderRadius: BorderRadius.circular(6)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text(
          AnilistLabels.listStatus(entry.status, anime: anime),
          maxLines: 1,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: role.onContainer),
        ),
      ),
    );
  }
}

/// Opens the tracker editor on [item]'s entry (or a new one) and answers the title with the
/// saved entry, null when nothing changed. The one AniList edit path of the search, so
/// `anilist-list-fidelity`'s own editor replaces it here.
Future<AnilistSearchMedia?> editAnilistSearchEntry(BuildContext context, AnilistSearchMedia item,
    {TrackerSyncService? service}) async {
  final anime = item.media.isAnime;
  final initial = item.entry == null ? null : AnilistEntryClient.parseEntry(item.entry!.json, anime);
  final saved = await showTrackerEntryEditor(
    context,
    service: service ?? TrackerSyncService.instance,
    tracker: AccountType.anilist,
    trackerId: '${item.id}',
    malId: item.media.malId ?? 0,
    category: item.media.category,
    initial: initial,
  );
  if (saved == null) return null;
  if (saved.isRemoved) return item.withEntry(null);
  return item.withEntry(anilistEntryOf(saved, fallbackId: item.entry?.id ?? 0));
}

/// [saved] as the entry a result row keeps (and the editor reads next time).
AnilistListEntry? anilistEntryOf(SyncEntry saved, {int fallbackId = 0}) {
  final status = saved.status == null ? null : StatusMaps.toTracker(saved.status!, AccountType.anilist);
  if (status == null) return null;
  final id = int.tryParse(saved.entryId ?? '') ?? fallbackId;
  return AnilistListEntry(id: id, status: status, json: {
    'id': id,
    'status': status,
    'score': saved.score,
    'progress': saved.progress,
    'progressVolumes': saved.volumes,
    'repeat': saved.repeat,
    'notes': saved.notes,
    'startedAt': SyncDates.toFuzzy(saved.startDate),
    'completedAt': SyncDates.toFuzzy(saved.finishDate),
  });
}

NumberFormat _compact() => NumberFormat.compact(locale: Intl.getCurrentLocale());

/// A search result as a list row: `#rank`, score and members, title, type line, own status,
/// and the edit pencil while signed in. Fixed height so the list never measures it.
class AnilistResultRow extends StatelessWidget {
  static const double height = 124;

  final AnilistSearchMedia item;

  /// Position in the results (0 based), shown as `#rank`.
  final int index;

  /// Shows the pencil (signed in to AniList).
  final bool editable;
  final ValueChanged<AnilistSearchMedia>? onEdited;

  const AnilistResultRow({
    super.key,
    required this.item,
    required this.index,
    this.editable = false,
    this.onEdited,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final muted = cs.onSurfaceVariant;
    final m = item.media;
    final members = m.popularity ?? 0;
    final typeLine = anilistTypeLine(item);
    return InkWell(
      onTap: () => openAnilistSearchTitle(context, category: m.category, id: m.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: SizedBox(
          height: height - 12,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppImage(
                url: m.coverUrl,
                width: 80,
                height: 112,
                borderRadius: BorderRadius.circular(8),
                placeholderColor: cs.surfaceContainerHighest,
                errorWidget: (_) => ColoredBox(
                  color: cs.surfaceContainerHighest,
                  child: Icon(Icons.image_not_supported_outlined, color: muted),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('#${index + 1}', style: theme.textTheme.titleMedium),
                        const SizedBox(width: 8),
                        if (item.score != null) AnilistScoreLabel(score: item.score!),
                        if (members > 0)
                          Flexible(
                            child: Padding(
                              padding: const EdgeInsetsDirectional.only(start: 4),
                              child: Text(
                                '(${_compact().format(members)})',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelSmall?.copyWith(color: muted),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      m.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w400),
                    ),
                    if (typeLine.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        typeLine,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(color: muted),
                      ),
                    ],
                    const Spacer(),
                    if (item.entry != null) AnilistStatusBadge(entry: item.entry!, anime: m.isAnime),
                  ],
                ),
              ),
              if (editable)
                IconButton(
                  tooltip: S.current.Edit,
                  icon: const Icon(Icons.edit_rounded),
                  visualDensity: VisualDensity.compact,
                  onPressed: () async {
                    final edited = await editAnilistSearchEntry(context, item);
                    if (edited != null) onEdited?.call(edited);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A search result as a grid card: cover with the score and own status, title, type line.
class AnilistResultCard extends StatelessWidget {
  final AnilistSearchMedia item;
  const AnilistResultCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final colors = AppColors.of(context);
    final m = item.media;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => openAnilistSearchTitle(context, category: m.category, id: m.id),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AppImage(
                    url: m.coverUrl,
                    borderRadius: BorderRadius.circular(10),
                    placeholderColor: cs.surfaceContainerHighest,
                    errorWidget: (_) => ColoredBox(
                      color: cs.surfaceContainerHighest,
                      child: Icon(Icons.image_not_supported_outlined, color: cs.onSurfaceVariant),
                    ),
                  ),
                  if (item.score != null)
                    PositionedDirectional(
                      top: 6,
                      start: 6,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: colors.imageScrim,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          child: Text(
                            '${item.score}%',
                            style: theme.textTheme.labelSmall
                                ?.copyWith(color: colors.onImageScrim, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ),
                  if (item.entry != null)
                    PositionedDirectional(
                      bottom: 6,
                      start: 6,
                      end: 6,
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: AnilistStatusBadge(entry: item.entry!, anime: m.isAnime),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(m.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium),
            Text(
              anilistTypeLine(item),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

/// A character, staff member, studio or user of the search. Fixed height.
class AnilistHitRow extends StatelessWidget {
  static const double height = 84;

  final AnilistSearchHit hit;
  const AnilistHitRow({super.key, required this.hit});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final muted = cs.onSurfaceVariant;
    final round = hit.kind == AnilistSearchKind.users;
    final second = [
      if (hit.nativeName != null) hit.nativeName!,
      if (hit.detail != null) hit.detail!,
    ].join(' · ');
    final picture = hit.kind == AnilistSearchKind.studios
        ? SizedBox(
            width: 52,
            height: 72,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: cs.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.movie_creation_outlined, color: muted),
            ),
          )
        : AppImage(
            url: hit.imageUrl,
            width: round ? 56 : 52,
            height: round ? 56 : 72,
            borderRadius: BorderRadius.circular(round ? 28 : 8),
            placeholderColor: cs.surfaceContainerHighest,
            errorWidget: (_) => ColoredBox(
              color: cs.surfaceContainerHighest,
              child: Icon(Icons.person_outline_rounded, color: muted),
            ),
          );
    return InkWell(
      onTap: () => openAnilistSearchHit(context, hit),
      child: SizedBox(
        height: height,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              SizedBox(width: 56, child: Center(child: picture)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(hit.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w400)),
                    if (second.isNotEmpty)
                      Text(second,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(color: muted)),
                  ],
                ),
              ),
              if (hit.favourites != null && hit.favourites! > 0) ...[
                Icon(Icons.favorite_rounded, size: 16, color: AppColors.of(context).danger.color),
                const SizedBox(width: 4),
                Text(_compact().format(hit.favourites), style: theme.textTheme.bodySmall),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
