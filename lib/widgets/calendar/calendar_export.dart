import 'dart:io';

import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/utils/file_service.dart';
import 'package:mywatchlist/widgets/calendar/calendar_ics.dart';
import 'package:mywatchlist/widgets/calendar/calendar_models.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Brand names of the related links LiveChart lists, in display order.
const Map<String, String> _linkLabels = {
  'website': 'Website',
  'twitter': 'Twitter',
  'anilist': 'AniList',
  'mal': 'MyAnimeList',
  'anidb': 'AniDB',
  'animeplanet': 'AnimePlanet',
  'anisearch': 'AniSearch',
  'kitsu': 'Kitsu',
  'crunchyroll': 'Crunchyroll',
  'hidive': 'Hidive',
  'netflix': 'Netflix',
};

/// Description of the event of [entry]'s episode, with its related links.
String eventDescription(CalendarEntry entry, int episode, DateTime airingAt) {
  final date = DateFormat.yMMMd().format(airingAt.toLocal());
  final buffer = StringBuffer(
    S.current.Cal_Event_Description(entry.title, episode, date),
  );
  final links = <String>[
    for (final kind in _linkLabels.keys)
      if ((entry.relatedLinks[kind] ?? '').isNotEmpty) '${_linkLabels[kind]}: ${entry.relatedLinks[kind]}',
  ];
  if (links.isNotEmpty) {
    buffer
      ..write('\n\n${S.current.Cal_Event_Links}:\n')
      ..write(links.join('\n'));
  }
  return buffer.toString();
}

/// Translated texts of the calendar event of [entry].
CalendarEventTexts eventTexts(CalendarEntry entry) => CalendarEventTexts(
      episodeTitle: (ep) => S.current.Cal_Event_Title(ep, entry.title),
      seriesTitle: S.current.Cal_Event_Series_Title(entry.title),
      description: (ep, at) => eventDescription(entry, ep, at),
    );

/// Hands the episode over to the outside world: the device calendar app, or an
/// .ics file saved or shared.
class CalendarExporter {
  const CalendarExporter._();

  /// Opens the device calendar's "new event" screen. [recurringCount] (at least
  /// 2) repeats the event every week. Completes with false when it failed.
  static Future<bool> addToDevice(CalendarEntry entry, {int? recurringCount}) async {
    try {
      final recurring = recurringCount != null && recurringCount > 1;
      final texts = eventTexts(entry);
      final start = entry.airingAt.toLocal();
      final event = Event(
        title: recurring ? texts.seriesTitle : texts.episodeTitle(entry.episode),
        description: texts.description(entry.episode, entry.airingAt),
        startDate: start,
        endDate: start.add(episodeEventLength),
        iosParams: IOSParams(reminder: const Duration(minutes: 10), url: entry.imageUrl),
        androidParams: AndroidParams(emailInvites: const []),
        recurrence: recurring ? Recurrence(frequency: Frequency.weekly, ocurrences: recurringCount) : null,
      );
      return await Add2Calendar.addEvent2Cal(event);
    } catch (e) {
      debugPrint('Calendar: add to device failed ($e)');
      return false;
    }
  }

  static String _ics(CalendarEntry entry, int? recurringCount) =>
      buildIcs(entry, texts: eventTexts(entry), recurringCount: recurringCount);

  /// Saves the .ics in the Downloads folder; false when writing failed.
  static Future<bool> saveIcs(CalendarEntry entry, {int? recurringCount}) async {
    try {
      await FileStorage.writeFile(_ics(entry, recurringCount), icsFileName(entry.title));
      return true;
    } catch (e) {
      debugPrint('Calendar: saving the .ics failed ($e)');
      return false;
    }
  }

  /// Opens the system share sheet with the .ics; false when it failed.
  static Future<bool> shareIcs(CalendarEntry entry, {int? recurringCount}) async {
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/${icsFileName(entry.title)}');
      await file.writeAsString(_ics(entry, recurringCount));
      await Share.shareXFiles([XFile(file.path, mimeType: 'text/calendar')]);
      return true;
    } catch (e) {
      debugPrint('Calendar: sharing the .ics failed ($e)');
      return false;
    }
  }
}
