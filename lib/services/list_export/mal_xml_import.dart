import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:mywatchlist/services/api/MAL/mal_api.dart';
import 'package:mywatchlist/services/api/MAL/mal_connect.dart' show MalSessionExpired;
import 'package:mywatchlist/services/list_export/mal_xml.dart';

/// The entries of a MyAnimeList export file (also what other trackers write in the same
/// format), ready to send to the list API.
class MalXmlDocument {
  const MalXmlDocument({
    this.anime = const [],
    this.manga = const [],
    this.invalid = 0,
  });

  final List<MalXmlEntry> anime;
  final List<MalXmlEntry> manga;

  /// Entries the file holds that cannot be imported (no id or no status).
  final int invalid;

  int get length => anime.length + manga.length;
  bool get isEmpty => length == 0;
}

/// Reads MyAnimeList export XML. The format is flat, so it is read with patterns instead of
/// an XML package.
class MalXmlReader {
  const MalXmlReader._();

  /// Text of an export file; gzip (`.xml.gz`, what MAL's own export gives) is unpacked.
  static String decodeBytes(Uint8List bytes) {
    final raw = bytes.length > 2 && bytes[0] == 0x1f && bytes[1] == 0x8b
        ? gzip.decode(bytes)
        : bytes;
    return utf8.decode(raw, allowMalformed: true);
  }

  /// Parses [xml]; throws [FormatException] when it is not a MyAnimeList export.
  static MalXmlDocument parse(String xml) {
    final text = xml.replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');
    if (!text.contains('<myanimelist')) {
      throw const FormatException('not a MyAnimeList export');
    }
    var invalid = 0;
    List<MalXmlEntry> blocks(String tag, bool isAnime) {
      final result = <MalXmlEntry>[];
      for (final m in RegExp('<$tag>(.*?)</$tag>', dotAll: true).allMatches(text)) {
        final entry = _entry(m.group(1)!, isAnime);
        entry == null ? invalid++ : result.add(entry);
      }
      return result;
    }

    return MalXmlDocument(
      anime: blocks('anime', true),
      manga: blocks('manga', false),
      invalid: invalid,
    );
  }

  /// Same as [parse], off the UI isolate when the file is big.
  static Future<MalXmlDocument> parseAsync(String xml) =>
      xml.length > 200 * 1024 ? compute(parse, xml) : Future.value(parse(xml));

  static MalXmlEntry? _entry(String block, bool isAnime) {
    String? field(String name) {
      final m = RegExp('<$name(?:\\s*/>|>(.*?)</$name>)', dotAll: true).firstMatch(block);
      return m == null ? null : _text(m.group(1) ?? '');
    }

    final id = int.tryParse(field(isAnime ? 'series_animedb_id' : 'manga_mangadb_id') ?? '') ?? 0;
    final status = statusOf(field('my_status'), isAnime: isAnime);
    if (id <= 0 || status == null) return null;
    int number(String? v, int max) => (int.tryParse(v ?? '') ?? 0).clamp(0, max);
    final tags = (field('my_tags') ?? '')
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    return MalXmlEntry(
      id: id,
      isAnime: isAnime,
      title: field(isAnime ? 'series_title' : 'manga_title') ?? '',
      status: status,
      score: number(field('my_score'), 10),
      progress: number(field(isAnime ? 'my_watched_episodes' : 'my_read_chapters'), 100000),
      volumesRead: isAnime ? 0 : number(field('my_read_volumes'), 100000),
      repeating: _flag(field(isAnime ? 'my_rewatching' : 'my_rereading')),
      timesRepeated: number(field(isAnime ? 'my_times_watched' : 'my_times_read'), 100000),
      repeatValue: valueOf(field(isAnime ? 'my_rewatch_value' : 'my_reread_value')),
      priority: priorityOf(field('my_priority')),
      startDate: apiDate(field('my_start_date')),
      finishDate: apiDate(field('my_finish_date')),
      tags: tags,
      comments: field('my_comments') ?? '',
    );
  }

  static bool _flag(String? v) => v == '1' || v?.toLowerCase() == 'true';

  /// A node's text: CDATA taken verbatim, the rest with its entities decoded.
  static String _text(String raw) {
    final out = StringBuffer();
    var last = 0;
    for (final m in RegExp(r'<!\[CDATA\[(.*?)\]\]>', dotAll: true).allMatches(raw)) {
      out.write(_entities(raw.substring(last, m.start)));
      out.write(m.group(1));
      last = m.end;
    }
    out.write(_entities(raw.substring(last)));
    return out.toString().trim();
  }

  static String _entities(String s) => s.replaceAllMapped(
        RegExp(r'&(#x[0-9a-fA-F]+|#\d+|amp|lt|gt|quot|apos);'),
        (m) {
          final e = m.group(1)!;
          switch (e) {
            case 'amp':
              return '&';
            case 'lt':
              return '<';
            case 'gt':
              return '>';
            case 'quot':
              return '"';
            case 'apos':
              return "'";
          }
          final code = e.startsWith('#x')
              ? int.tryParse(e.substring(2), radix: 16)
              : int.tryParse(e.substring(1));
          return code == null || code <= 0 || code > 0x10FFFF ? m.group(0)! : String.fromCharCode(code);
        },
      );

  /// API status of an export status (word or MAL's number), null when unknown.
  static String? statusOf(String? value, {required bool isAnime}) {
    final v = (value ?? '').toLowerCase().replaceAll(RegExp(r'[\s_-]'), '');
    final planned = isAnime ? 'plan_to_watch' : 'plan_to_read';
    final current = isAnime ? 'watching' : 'reading';
    return switch (v) {
      '1' || 'watching' || 'reading' || 'currentlywatching' || 'currentlyreading' => current,
      '2' || 'completed' => 'completed',
      '3' || 'onhold' => 'on_hold',
      '4' || 'dropped' => 'dropped',
      '6' || 'plantowatch' || 'plantoread' => planned,
      _ => null,
    };
  }

  /// 0 low, 1 medium, 2 high.
  static int priorityOf(String? value) => switch ((value ?? '').toLowerCase()) {
        '1' || 'medium' => 1,
        '2' || 'high' => 2,
        _ => 0,
      };

  /// Rewatch value 0 to 5, from MAL's word or number.
  static int valueOf(String? value) => switch ((value ?? '').toLowerCase().trim()) {
        '1' || 'very low' => 1,
        '2' || 'low' => 2,
        '3' || 'medium' => 3,
        '4' || 'high' => 4,
        '5' || 'very high' => 5,
        _ => 0,
      };

  /// An export date as the API takes it (`0000-00-00` is none, `2020-00-00` is `2020`).
  static String? apiDate(String? value) {
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value ?? '');
    if (m == null || m.group(1) == '0000') return null;
    if (m.group(2) == '00') return m.group(1);
    if (m.group(3) == '00') return '${m.group(1)}-${m.group(2)}';
    return value;
  }
}

/// What an import did.
class MalXmlImportResult {
  const MalXmlImportResult({
    required this.saved,
    required this.skipped,
    required this.failed,
    required this.total,
    this.cancelled = false,
    this.sessionExpired = false,
  });

  /// Entries written to the list.
  final int saved;

  /// Entries left alone because they were already in the list.
  final int skipped;

  /// Entries MAL refused (a title that no longer exists, a network error).
  final int failed;
  final int total;
  final bool cancelled;

  /// The import stopped because the MAL session ended.
  final bool sessionExpired;
}

typedef MalXmlSaveAnime = Future<void> Function(MalXmlEntry entry);
typedef MalXmlSaveManga = Future<void> Function(MalXmlEntry entry);

/// Writes the entries of a [MalXmlDocument] to the signed-in MAL list, one list update each
/// (`PUT my_list_status`), paced and retried on a rate limit.
class MalXmlImporter {
  MalXmlImporter({
    MalXmlSaveAnime? saveAnime,
    MalXmlSaveManga? saveManga,
    Future<http.Response> Function(String url)? get,
    Future<void> Function(Duration)? pause,
    this.gap = const Duration(milliseconds: 250),
    this.retries = 3,
  })  : _saveAnime = saveAnime ?? _defaultSaveAnime,
        _saveManga = saveManga ?? _defaultSaveManga,
        _get = get ?? MalApi.authorizedGet,
        _pause = pause ?? Future.delayed;

  final MalXmlSaveAnime _saveAnime;
  final MalXmlSaveManga _saveManga;
  final Future<http.Response> Function(String url) _get;
  final Future<void> Function(Duration) _pause;

  /// Wait between two writes.
  final Duration gap;

  /// Extra tries of a write that hit a rate limit or a network error.
  final int retries;

  static Future<void> _defaultSaveAnime(MalXmlEntry e) async {
    await MalApi().saveAnimeListStatus(
      animeId: e.id,
      status: e.status,
      score: e.score,
      numWatchedEpisodes: e.progress,
      isRewatching: e.repeating,
      numTimesRewatched: e.timesRepeated,
      rewatchValue: e.repeatValue,
      priority: e.priority,
      tags: e.tags.join(','),
      comments: e.comments,
      startDate: e.startDate,
      finishDate: e.finishDate,
    );
  }

  static Future<void> _defaultSaveManga(MalXmlEntry e) async {
    await MalApi().saveMangaListStatus(
      mangaId: e.id,
      status: e.status,
      score: e.score,
      numChaptersRead: e.progress,
      numVolumesRead: e.volumesRead,
      isRereading: e.repeating,
      numTimesReread: e.timesRepeated,
      rereadValue: e.repeatValue,
      priority: e.priority,
      tags: e.tags.join(','),
      comments: e.comments,
      startDate: e.startDate,
      finishDate: e.finishDate,
    );
  }

  /// Ids already in the signed-in user's list.
  Future<Set<int>> existingIds({required bool isAnime}) async {
    final ids = <int>{};
    var offset = 0;
    while (true) {
      final url = '${MalApi.userBaseEndPoint}/@me/${isAnime ? 'animelist' : 'mangalist'}'
          '?fields=id&limit=${MalXmlExporter.pageSize}&offset=$offset&nsfw=1';
      final response = await _get(url);
      if (response.statusCode == 401 && MalApi.sessionExpired.value) {
        throw const MalSessionExpired();
      }
      if (response.statusCode != 200) throw MalXmlExportError(response.statusCode);
      final page = MalXmlExporter.parsePage(response.body, isAnime: isAnime);
      ids.addAll(page.entries.map((e) => e.id));
      if (!page.hasNext || page.entries.isEmpty) break;
      offset += MalXmlExporter.pageSize;
    }
    return ids;
  }

  static final RegExp _transient = RegExp(r'\b(429|5\d\d)\b');

  bool _worthRetrying(Object e) =>
      e is SocketException ||
      e is TimeoutException ||
      e is http.ClientException ||
      _transient.hasMatch(e.toString());

  /// Imports [doc]. With [overwrite] false, titles already in the list are left alone.
  /// [onProgress] gets (done, total); [isCancelled] is polled between writes.
  Future<MalXmlImportResult> run(
    MalXmlDocument doc, {
    required bool overwrite,
    void Function(int done, int total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final total = doc.length;
    var done = 0, saved = 0, skipped = 0, failed = 0;
    MalXmlImportResult result({bool cancelled = false, bool expired = false}) =>
        MalXmlImportResult(
          saved: saved,
          skipped: skipped,
          failed: failed,
          total: total,
          cancelled: cancelled,
          sessionExpired: expired,
        );
    try {
      for (final isAnime in [true, false]) {
        final entries = isAnime ? doc.anime : doc.manga;
        if (entries.isEmpty) continue;
        final existing = overwrite ? const <int>{} : await existingIds(isAnime: isAnime);
        for (final entry in entries) {
          if (isCancelled?.call() ?? false) return result(cancelled: true);
          if (existing.contains(entry.id)) {
            skipped++;
          } else if (await _write(entry)) {
            saved++;
            await _pause(gap);
          } else {
            failed++;
          }
          onProgress?.call(++done, total);
        }
      }
    } on MalSessionExpired {
      return result(expired: true);
    }
    return result();
  }

  Future<bool> _write(MalXmlEntry entry) async {
    for (var attempt = 0;; attempt++) {
      try {
        await (entry.isAnime ? _saveAnime(entry) : _saveManga(entry));
        return true;
      } on MalSessionExpired {
        rethrow;
      } catch (e) {
        if (attempt >= retries || !_worthRetrying(e)) {
          debugPrint('MAL XML import: ${entry.id} refused: $e');
          return false;
        }
        await _pause(Duration(seconds: 2 << attempt));
      }
    }
  }
}
