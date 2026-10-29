import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_list_service.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_list_write.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_media_detail.dart';
import 'package:mywatchlist/widgets/Anilist/list/anilist_entry_editor.dart';
import 'package:mywatchlist/widgets/Anilist/media/anilist_media_format.dart';
import 'package:mywatchlist/widgets/Anilist/search/anilist_labels.dart';
import 'package:mywatchlist/widgets/common/app_colors.dart';
import 'package:mywatchlist/widgets/user/list/list_entry_view.dart';

/// The shared list row of [t], as `showAnilistEntryEditor` reads it.
ListEntryView anilistEditView(AnilistEditTarget t) {
  final base = ListEntryView(
    id: t.id,
    malId: t.malId,
    category: t.category,
    title: t.title,
    imageUrl: t.coverUrl,
    mediaType: anilistMediaType(t.format),
    total: t.total,
    totalVolumes: t.category == 'manga' ? t.totalVolumes : 0,
  );
  final e = t.entry;
  return e == null ? base : anilistApplyDetail(base, e);
}

/// Opens the AniList editor (`showAnilistEntryEditor`, every field of `SaveMediaListEntry`)
/// on [t]; whatever it saves or deletes, the kept AniList list of the category is dropped
/// so My List reads it again. [editor] replaces the sheet (tests).
Future<AnilistEditResult?> editAnilistTitleEntry(
  BuildContext context,
  AnilistEditTarget t, {
  AnilistListWrite? write,
  AnilistListService? lists,
  Future<AnilistEditResult?> Function(BuildContext context, AnilistEditTarget target)? editor,
}) async {
  final result = editor != null
      ? await editor(context, t)
      : await showAnilistEntryEditor(
          context,
          entry: anilistEditView(t),
          detail: t.entry,
          options: t.options,
          write: write,
        );
  if (result != null) (lists ?? AnilistListService.instance).invalidate(t.category);
  return result;
}

/// The `SaveMediaListEntry` of a "+1" on [entry] of a title with [total] units (0 = unknown):
/// planning starts it, the last unit completes it (with today as finish date when empty and
/// one more rewatch for a Rewatching entry). The score is never sent.
AnilistEntryInput anilistPlusOne(AnilistListEntry entry, {required int total, required DateTime today}) {
  final progress = total > 0 && entry.progress >= total ? total : entry.progress + 1;
  String two(int n) => n.toString().padLeft(2, '0');
  final day = '${today.year}-${two(today.month)}-${two(today.day)}';
  final completes = total > 0 && progress >= total;
  if (completes) {
    return AnilistEntryInput(
      mediaId: entry.mediaId,
      progress: progress,
      status: 'COMPLETED',
      repeat: entry.isRepeating ? entry.repeat + 1 : null,
      completedAt: (entry.completedAt == null || entry.completedAt!.isEmpty) ? day : null,
    );
  }
  if (entry.status == 'PLANNING') {
    return AnilistEntryInput(
      mediaId: entry.mediaId,
      progress: progress,
      status: 'CURRENT',
      startedAt: (entry.startedAt == null || entry.startedAt!.isEmpty) ? day : null,
    );
  }
  return AnilistEntryInput(mediaId: entry.mediaId, progress: progress);
}

/// The user's entry on the title: status, progress bar with +1, score in their format and
/// dates; a tap opens the editor.
class AnilistMyEntryCard extends StatelessWidget {
  const AnilistMyEntryCard({
    super.key,
    required this.detail,
    required this.onEdit,
    required this.onPlusOne,
    this.busy = false,
  });

  final AnilistMediaDetail detail;
  final VoidCallback onEdit;
  final VoidCallback onPlusOne;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final e = detail.entry!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final s = S.of(context);
    final role = AppColors.of(context).statusOf(e.status);
    final total = detail.total;
    final format = detail.listOptions?.scoreFormat ?? AnilistScoreFormat.point10;
    final canStep = e.status != 'COMPLETED' && (total == 0 || e.progress < total);
    final dates = [
      if (e.startedAt?.isNotEmpty == true) s.Amp_Started(AnilistMediaFormat.date(e.startedAt!)),
      if (e.completedAt?.isNotEmpty == true) s.Amp_Completed(AnilistMediaFormat.date(e.completedAt!)),
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Material(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onEdit,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: role?.container ?? scheme.primaryContainer,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              child: Text(
                                AnilistLabels.listStatus(e.status ?? 'PLANNING', anime: detail.isAnime),
                                style: theme.textTheme.labelMedium?.copyWith(
                                    color: role?.onContainer ?? scheme.onPrimaryContainer),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            s.Amp_Progress(e.progress, total > 0 ? '$total' : '?'),
                            style: theme.textTheme.labelLarge,
                          ),
                          const Spacer(),
                          AnilistUserScore(
                            raw: e.scoreRaw,
                            format: format,
                            style: theme.textTheme.labelLarge?.copyWith(color: scheme.primary),
                          ),
                        ],
                      ),
                      if (total > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 8, right: 8),
                          child: LinearProgressIndicator(
                            value: (e.progress / total).clamp(0, 1).toDouble(),
                            minHeight: 4,
                            borderRadius: BorderRadius.circular(2),
                            color: role?.color ?? scheme.primary,
                            backgroundColor: scheme.surfaceContainerHighest,
                          ),
                        ),
                      if (dates.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            dates,
                            style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ),
                    ],
                  ),
                ),
                if (canStep)
                  busy
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
                        )
                      : IconButton.filledTonal(
                          tooltip: s.Amp_Plus_One,
                          icon: const Icon(Icons.exposure_plus_1),
                          onPressed: onPlusOne,
                        ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
