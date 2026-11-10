/// One line of a user's MyAnimeList history ("Watched ep. 5 of ...").
class ProfileHistoryEntry {
  final int id;
  final String title;

  /// Progress text, e.g. "Ep. 5".
  final String progress;

  /// `anime` or `manga`.
  final String category;

  /// MAL's own wording: "Today, 9:12 AM", "Yesterday, 11:03 PM" or "Oct 5, 2:03 AM".
  final String time;

  const ProfileHistoryEntry({
    required this.id,
    required this.title,
    required this.progress,
    required this.category,
    required this.time,
  });

  /// The day part of [time] ("Today", "Yesterday", "Oct 5"), used to group entries.
  String get dayLabel {
    final comma = time.indexOf(',');
    return (comma > 0 ? time.substring(0, comma) : time).trim();
  }

  /// The clock part of [time], empty when MAL gave none.
  String get clock {
    final comma = time.lastIndexOf(',');
    return comma > 0 ? time.substring(comma + 1).trim() : '';
  }
}

/// Reads the `data` of a `users/history` envelope (`{histories: [...]}` or a bare list).
List<ProfileHistoryEntry> parseHistoryEnvelope(
  Map<String, dynamic>? envelope, {
  required String category,
}) {
  final payload = envelope?['data'];
  final rows = payload is Map ? payload['histories'] : payload;
  if (rows is! List) return const [];
  final out = <ProfileHistoryEntry>[];
  for (final row in rows) {
    if (row is! Map) continue;
    final id = (row['id'] as num?)?.toInt() ?? 0;
    final title = (row['title'] as String?)?.trim() ?? '';
    if (id == 0 || title.isEmpty) continue;
    out.add(ProfileHistoryEntry(
      id: id,
      title: title,
      progress: (row['history'] as String?)?.trim() ?? '',
      category: (row['category'] as String?) ?? category,
      time: (row['time'] as String?)?.trim() ?? '',
    ));
  }
  return out;
}
