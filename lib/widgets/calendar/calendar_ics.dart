import 'dart:convert';

import 'package:mywatchlist/widgets/calendar/calendar_models.dart';

/// Length of the calendar event created for an episode.
const Duration episodeEventLength = Duration(minutes: 25);

/// Text of one calendar event, already translated by the caller.
class CalendarEventTexts {
  /// Event title of a single episode, e.g. `Ep 5 - Title`.
  final String Function(int episode) episodeTitle;

  /// Event title of a recurring series, e.g. `Title Episode Release Reminder`.
  final String seriesTitle;

  /// Event description of the episode.
  final String Function(int episode, DateTime airingAt) description;

  const CalendarEventTexts({
    required this.episodeTitle,
    required this.seriesTitle,
    required this.description,
  });
}

/// Builds an iCalendar (RFC 5545) file for [entry].
///
/// With [recurringCount] (at least 2) it holds one weekly event repeated that
/// many times, otherwise one event. Times are written in UTC, text is escaped
/// and long lines folded, lines end with CRLF as the standard requires.
String buildIcs(
  CalendarEntry entry, {
  required CalendarEventTexts texts,
  int? recurringCount,
  DateTime? now,
}) {
  final stamp = _utc(now ?? DateTime.now());
  final recurring = recurringCount != null && recurringCount > 1;
  final lines = <String>[
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//MyWatchList//Anime Calendar//EN',
    'CALSCALE:GREGORIAN',
    'BEGIN:VEVENT',
    'UID:mal-${entry.malId}-ep${entry.episode}${recurring ? '-weekly' : ''}@mywatchlist',
    'DTSTAMP:$stamp',
    'DTSTART:${_utc(entry.airingAt)}',
    'DTEND:${_utc(entry.airingAt.add(episodeEventLength))}',
    'SUMMARY:${escapeIcsText(recurring ? texts.seriesTitle : texts.episodeTitle(entry.episode))}',
    'DESCRIPTION:${escapeIcsText(texts.description(entry.episode, entry.airingAt))}',
    if (recurring) 'RRULE:FREQ=WEEKLY;COUNT=$recurringCount',
    'BEGIN:VALARM',
    'ACTION:DISPLAY',
    'TRIGGER:-PT10M',
    'DESCRIPTION:${escapeIcsText(texts.episodeTitle(entry.episode))}',
    'END:VALARM',
    'END:VEVENT',
    'END:VCALENDAR',
  ];
  return '${lines.map(foldIcsLine).join('\r\n')}\r\n';
}

/// `yyyyMMddTHHmmssZ` of [t] in UTC.
String _utc(DateTime t) {
  final u = t.toUtc();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${u.year.toString().padLeft(4, '0')}${two(u.month)}${two(u.day)}'
      'T${two(u.hour)}${two(u.minute)}${two(u.second)}Z';
}

/// Escapes a TEXT value: backslash, semicolon, comma and line breaks.
String escapeIcsText(String text) => text
    .replaceAll('\\', '\\\\')
    .replaceAll(';', '\;')
    .replaceAll(',', '\\,')
    .replaceAll('\r\n', '\\n')
    .replaceAll('\n', '\\n');

/// Folds [line] so that no physical line exceeds 75 bytes (continuations start
/// with one space), never cutting a UTF-8 character in two.
String foldIcsLine(String line) {
  if (utf8.encode(line).length <= 75) return line;
  final out = StringBuffer();
  var budget = 75;
  var used = 0;
  for (final rune in line.runes) {
    final char = String.fromCharCode(rune);
    final size = utf8.encode(char).length;
    if (used + size > budget) {
      out.write('\r\n ');
      budget = 74; // the leading space counts
      used = 0;
    }
    out.write(char);
    used += size;
  }
  return out.toString();
}

/// A file name for the .ics of [title]: letters, digits and underscores only.
String icsFileName(String title) {
  final clean = title.replaceAll(RegExp(r'[^\w\s]', unicode: true), '').trim().replaceAll(RegExp(r'\s+'), '_');
  return '${clean.isEmpty ? 'anime' : clean}_calendar.ics';
}
