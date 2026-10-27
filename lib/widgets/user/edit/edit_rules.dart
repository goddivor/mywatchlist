import 'package:html_unescape/html_unescape.dart';
import 'package:mywatchlist/widgets/user/edit/list_entry.dart';

/// The fields one list update sends; null fields are left unchanged on MAL.
class EntryPatch {
  final String? status;
  final int? score;
  final int? progress;
  final int? volumes;
  final bool? isRepeating;
  final int? timesRepeated;
  final int? repeatValue;
  final int? priority;
  final String? startDate;
  final String? finishDate;
  final String? tags;
  final String? comments;

  const EntryPatch({
    this.status,
    this.score,
    this.progress,
    this.volumes,
    this.isRepeating,
    this.timesRepeated,
    this.repeatValue,
    this.priority,
    this.startDate,
    this.finishDate,
    this.tags,
    this.comments,
  });

  @override
  String toString() => 'EntryPatch(status: $status, score: $score, '
      'progress: $progress, volumes: $volumes, start: $startDate, '
      'finish: $finishDate)';
}

/// Why a progress value was refused.
enum ProgressError { negative, overMaximum }

/// A progress change: either the patch to send or the reason it was refused.
class ProgressPlan {
  final EntryPatch? patch;
  final ProgressError? error;
  const ProgressPlan.send(EntryPatch this.patch) : error = null;
  const ProgressPlan.refuse(ProgressError this.error) : patch = null;
}

String _today(DateTime now) => formatApiDate(now);

bool _isPlanned(String? status) =>
    status == null || status == 'plan_to_watch' || status == 'plan_to_read';

/// Status in progress for the category: `watching` or `reading`.
String activeStatus(bool isAnime) => isAnime ? 'watching' : 'reading';

/// Patch for a status change.
///
/// Completing sets the progress (and manga volumes) to the known total. With
/// [autoDates] on, starting fills the start date and completing fills the
/// finish date, each only when the entry has none (DAL 704b5b5): an existing
/// date is never overwritten.
EntryPatch planStatusChange({
  required EditableContent content,
  required ListEntry? entry,
  required String status,
  required bool autoDates,
  required DateTime now,
}) {
  final completing = status == 'completed';
  int? progress;
  int? volumes;
  if (completing && content.progressTotal > 0) progress = content.progressTotal;
  if (completing && !content.isAnime && content.numVolumes > 0) {
    volumes = content.numVolumes;
  }
  String? start;
  String? finish;
  if (autoDates) {
    if (status == activeStatus(content.isAnime) && entry?.startDate == null) {
      start = _today(now);
    }
    if (completing && entry?.finishDate == null) finish = _today(now);
  }
  return EntryPatch(
    status: status,
    progress: progress,
    volumes: volumes,
    startDate: start,
    finishDate: finish,
  );
}

/// Patch for a new episode (anime) or chapter (manga) count.
///
/// Reaching the known total completes the entry; a planned entry that gets
/// progress moves to watching/reading. With [autoDates] on, the first progress
/// fills an empty start date and completing fills an empty finish date.
ProgressPlan planProgressChange({
  required EditableContent content,
  required ListEntry entry,
  required int progress,
  required bool autoDates,
  required DateTime now,
}) {
  if (progress < 0) return const ProgressPlan.refuse(ProgressError.negative);
  final total = content.progressTotal;
  if (total > 0 && progress > total) {
    return const ProgressPlan.refuse(ProgressError.overMaximum);
  }
  String? status;
  final completes = total > 0 && progress == total;
  if (completes && entry.status != 'completed') {
    status = 'completed';
  } else if (!completes && progress > 0 && _isPlanned(entry.status)) {
    status = activeStatus(content.isAnime);
  }
  String? start;
  String? finish;
  if (autoDates) {
    if (progress > 0 && entry.startDate == null) start = _today(now);
    if (completes && entry.finishDate == null) finish = _today(now);
  }
  int? volumes;
  if (status == 'completed' && !content.isAnime && content.numVolumes > 0) {
    volumes = content.numVolumes;
  }
  return ProgressPlan.send(EntryPatch(
    progress: progress,
    status: status,
    volumes: volumes,
    startDate: start,
    finishDate: finish,
  ));
}

/// Patch for a new volume count (manga); volumes never change the status.
ProgressPlan planVolumesChange({
  required EditableContent content,
  required int volumes,
}) {
  if (volumes < 0) return const ProgressPlan.refuse(ProgressError.negative);
  if (content.numVolumes > 0 && volumes > content.numVolumes) {
    return const ProgressPlan.refuse(ProgressError.overMaximum);
  }
  return ProgressPlan.send(EntryPatch(volumes: volumes));
}

/// Patch for adding the content with the default status of the preferences.
EntryPatch planAdd({
  required EditableContent content,
  required String preferredStatus,
  required bool autoDates,
  required DateTime now,
}) {
  final status = validStatus(preferredStatus, isAnime: content.isAnime);
  return planStatusChange(
    content: content,
    entry: null,
    status: status,
    autoDates: autoDates,
    now: now,
  );
}

const List<String> animeStatuses = [
  'watching',
  'completed',
  'on_hold',
  'dropped',
  'plan_to_watch',
];

const List<String> mangaStatuses = [
  'reading',
  'completed',
  'on_hold',
  'dropped',
  'plan_to_read',
];

/// [status] when it is a list status of the category, else the matching one
/// (`watching` ↔ `reading`, `plan_to_watch` ↔ `plan_to_read`), else plan to.
String validStatus(String status, {required bool isAnime}) {
  final statuses = isAnime ? animeStatuses : mangaStatuses;
  if (statuses.contains(status)) return status;
  const swap = {
    'watching': 'reading',
    'reading': 'watching',
    'plan_to_watch': 'plan_to_read',
    'plan_to_read': 'plan_to_watch',
  };
  final other = swap[status];
  if (other != null && statuses.contains(other)) return other;
  return isAnime ? 'plan_to_watch' : 'plan_to_read';
}

/// Number of episodes the episode picker offers, or null for a free number.
///
/// The known total first; for a show still airing without a total, the weeks
/// since its release start (or start season) + 1, never below what was
/// watched (DAL b5f1e8d / e7eef19); otherwise the watched count + 10.
int? episodePickerCount(EditableContent content, int watched, DateTime now) {
  if (!content.isAnime) return null;
  if (content.numEpisodes > 0) return content.numEpisodes;
  final aired = estimateAiredEpisodes(content, now);
  if (aired != null) return aired > watched ? aired : watched + 1;
  if (watched > 0) return watched + 10;
  return null;
}

/// Episodes aired so far for a weekly show still airing, or null.
int? estimateAiredEpisodes(EditableContent content, DateTime now) {
  if (!content.isAnime || content.airingStatus != 'currently_airing') {
    return null;
  }
  final start = _releaseStart(content);
  if (start == null || start.isAfter(now)) return null;
  return now.difference(start).inDays ~/ 7 + 1;
}

DateTime? _releaseStart(EditableContent content) {
  final full = content.releaseStart == null
      ? null
      : DateTime.tryParse(content.releaseStart!);
  if (full != null) return full;
  final year = content.startSeasonYear;
  final month = switch (content.startSeason?.toLowerCase()) {
    'winter' => 1,
    'spring' => 4,
    'summer' => 7,
    'fall' || 'autumn' => 10,
    _ => null,
  };
  if (year == null || month == null) return null;
  return DateTime(year, month, 1);
}

final HtmlUnescape _unescape = HtmlUnescape();
final RegExp _lineBreak = RegExp(r'<br\s*/?>\r?\n?', caseSensitive: false);

/// MAL text as the user typed it: `<br />` back to line breaks and HTML
/// entities decoded (`&amp;` → `&`, `&#039;` → `'`) — DAL 3f89382 / 2f6b9da.
String decodeMalText(String text) =>
    _unescape.convert(text.replaceAll(_lineBreak, '\n'));

/// Tags as one editable line: decoded and comma separated.
String tagsToText(List<String> tags) =>
    tags.map(decodeMalText).map((t) => t.trim()).where((t) => t.isNotEmpty).join(', ');

/// The tags line the user typed, as MAL's comma separated `tags` field.
String textToTags(String text) => text
    .split(',')
    .map((t) => t.trim())
    .where((t) => t.isNotEmpty)
    .join(',');

/// Parses a MAL date, partial ones (`2024-03`, `2024`) included, for the picker.
DateTime? parseApiDate(String? date) {
  if (date == null) return null;
  final full = DateTime.tryParse(date);
  if (full != null) return full;
  final parts = date.split('-').map(int.tryParse).toList();
  if (parts.isEmpty || parts.first == null) return null;
  final month = parts.length > 1 ? parts[1] : null;
  return DateTime(parts.first!, month ?? 1, 1);
}
