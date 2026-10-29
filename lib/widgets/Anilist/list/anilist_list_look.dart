import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_list_service.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_list_write.dart';
import 'package:mywatchlist/widgets/Anilist/media/anilist_media_format.dart';
import 'package:mywatchlist/widgets/Anilist/search/anilist_labels.dart';
import 'package:mywatchlist/widgets/common/app_colors.dart';
import 'package:mywatchlist/widgets/user/list/list_entry_look.dart';
import 'package:mywatchlist/widgets/user/list/list_entry_view.dart';
import 'package:mywatchlist/widgets/user/list/list_query.dart' show mediaTypeLabel;

/// How AniList writes scores and list labels on its list screens (Score display rules of
/// `docs/tracker-ui-references.md`): the user's own score in the account's `scoreFormat`, the
/// community score as a percentage, AniList's status words and the label rail.

/// AniList's value of a shared list status (`CURRENT`, `PAUSED`…), REPEATING when [repeating].
String anilistStatusValueOfShared(ListEntryStatus status, {bool repeating = false}) =>
    switch (status) {
      ListEntryStatus.current => repeating ? 'REPEATING' : 'CURRENT',
      ListEntryStatus.completed => 'COMPLETED',
      ListEntryStatus.onHold => 'PAUSED',
      ListEntryStatus.dropped => 'DROPPED',
      ListEntryStatus.planned => 'PLANNING',
    };

/// The face of a POINT_3 score (1 sad, 2 neutral, 3 happy), AniList's three smileys.
IconData anilistFaceIcon(int face) => face <= 1
    ? Icons.sentiment_dissatisfied_rounded
    : face == 2
        ? Icons.sentiment_neutral_rounded
        : Icons.sentiment_satisfied_alt_rounded;

/// [raw] (AniList's 0-100) in [format] for the shared cards: `85`, `8.5`, `8`, `4` with a star,
/// or a face alone; null when not scored.
ListScoreText? anilistUserScoreText(int raw, AnilistScoreFormat format) {
  if (raw <= 0) return null;
  final s = S.current;
  final value = format.fromRaw(raw);
  switch (format) {
    case AnilistScoreFormat.point5:
      final stars = value.round();
      return ListScoreText('$stars', icon: Icons.star_rounded, spoken: s.Ald_Score_Stars(stars));
    case AnilistScoreFormat.point3:
      final face = value.round();
      return ListScoreText('',
          icon: anilistFaceIcon(face),
          spoken: switch (face) {
            1 => s.Ald_Score_Face_Sad,
            2 => s.Ald_Score_Face_Neutral,
            _ => s.Ald_Score_Face_Happy,
          });
    case AnilistScoreFormat.point10Decimal:
      final text = NumberFormat('0.#', Intl.getCurrentLocale()).format(value);
      return ListScoreText(text, spoken: s.Ald_My_Score(text));
    case AnilistScoreFormat.point100:
    case AnilistScoreFormat.point10:
      final text = '${value.round()}';
      return ListScoreText(text, spoken: s.Ald_My_Score(text));
  }
}

/// AniList's community score (0-100) of a list row whose shared mean is on 0-10; null when
/// AniList has none.
int? anilistPercentOf(ListEntryView entry) {
  final mean = entry.meanScore;
  if (mean == null || mean <= 0) return null;
  return (mean * 10).round().clamp(1, 100);
}

/// The face anilist.co draws next to a percentage: happy from 75, neutral from 50, else sad.
IconData anilistPercentIcon(int percent) => anilistFaceIcon(percent >= 75
    ? 3
    : percent >= 50
        ? 2
        : 1);

/// anilist.co's colour scale of a percentage: < 50 red, 50-74 amber, >= 75 green.
AppColorRole anilistPercentRole(BuildContext context, int percent) {
  final colors = AppColors.of(context);
  return percent >= 75
      ? colors.success
      : percent >= 50
          ? colors.warning
          : colors.danger;
}

/// The community score as AniList writes it: `82%` (`82 %` in French) with its face.
ListScoreText? anilistPercentText(ListEntryView entry) {
  final percent = anilistPercentOf(entry);
  if (percent == null) return null;
  final text = AnilistMediaFormat.percent(percent);
  return ListScoreText(text,
      icon: anilistPercentIcon(percent), spoken: S.current.Ald_Average_Score(text));
}

/// AniList's marks of a list entry: notes, private, priority (the rewatch count has its pill).
List<ListCardBadge> anilistBadgesOf(AnilistListEntry? detail) {
  if (detail == null) return const [];
  final s = S.current;
  final notes = detail.notes.trim();
  return [
    if (notes.isNotEmpty)
      ListCardBadge(icon: Icons.sticky_note_2_outlined, label: s.Ald_Notes, detail: notes),
    if (detail.private)
      ListCardBadge(icon: Icons.lock_outline_rounded, label: s.Ald_Private, detail: s.Ald_Private),
    if (detail.priority > 0)
      ListCardBadge(
        icon: Icons.flag_outlined,
        label: '${detail.priority}',
        detail: s.Ald_Priority(detail.priority),
      ),
  ];
}

/// One label of the rail and the colour role that highlights it (null = plain).
typedef AnilistRailLabel = ({String text, AppColorRole? role});

/// The next episode of an airing anime row: its number when known and when it airs (UTC).
/// The number is the first episode not released yet (calendar, then the weekly estimate),
/// the moment AniList's weekly slot (built from `nextAiringEpisode.airingAt`).
({int? episode, DateTime at})? anilistNextAiring(ListEntryView e, DateTime now) {
  if (!e.isAnime || e.releaseState != ReleaseState.releasing) return null;
  final slot = e.broadcast;
  if (slot == null) return null;
  final released = e.releasedCount(now);
  final episode = released == null ? null : released + 1;
  return (
    episode: episode != null && (e.total <= 0 || episode <= e.total) ? episode : null,
    at: slot.nextAiring(now),
  );
}

/// The label rail of a list row (Otraku's vocabulary): format · `Ep 8 in 1d 3h` · `2 behind`
/// · own status ([showStatus], tabs that mix statuses).
List<AnilistRailLabel> anilistRailOf(
  BuildContext context,
  ListEntryView e,
  AnilistListEntry? detail, {
  required DateTime now,
  required bool showStatus,
}) {
  final s = S.current;
  final colors = AppColors.of(context);
  final format = detail?.format;
  final next = anilistNextAiring(e, now);
  final countdown = next == null ? null : AnilistMediaFormat.countdown(next.at, now: now);
  final behind = e.status == ListEntryStatus.current ? e.unseenCount(now) : 0;
  final status = e.status;
  final statusValue = detail?.status ??
      (status == null ? null : anilistStatusValueOfShared(status, repeating: e.repeating));
  return [
    if (format != null && format.isNotEmpty)
      (text: AnilistLabels.format(format), role: null)
    else if (e.mediaType != null)
      (text: mediaTypeLabel(e.mediaType!), role: null),
    if (countdown != null)
      (
        text: next!.episode == null
            ? s.Ald_Airs_In(countdown)
            : s.Amp_Next_Episode(next.episode!, countdown),
        role: colors.success,
      ),
    if (behind > 0) (text: s.Amp_Behind(behind), role: colors.warning),
    if (showStatus && statusValue != null)
      (
        text: AnilistLabels.listStatus(statusValue, anime: e.isAnime),
        role: colors.statusOf(_malStatusOf(statusValue)),
      ),
  ];
}

String? _malStatusOf(String anilist) => switch (anilist) {
      'CURRENT' || 'REPEATING' => 'watching',
      'COMPLETED' => 'completed',
      'PAUSED' => 'on_hold',
      'DROPPED' => 'dropped',
      'PLANNING' => 'plan_to_watch',
      _ => null,
    };
