import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:mywatchlist/services/api/MAL/mal_api.dart';
import 'package:mywatchlist/services/api/MAL/mal_connect.dart' show MalSessionExpired;

/// One list entry in MyAnimeList's export model, anime or manga. Values are MAL API v2 values
/// (`status` is `watching`, `plan_to_read`, dates are `YYYY`, `YYYY-MM` or `YYYY-MM-DD`).
class MalXmlEntry {
  const MalXmlEntry({
    required this.id,
    required this.isAnime,
    this.title = '',
    this.type = '',
    this.total = 0,
    this.totalVolumes = 0,
    this.status,
    this.score = 0,
    this.progress = 0,
    this.volumesRead = 0,
    this.repeating = false,
    this.timesRepeated = 0,
    this.repeatValue = 0,
    this.priority = 0,
    this.startDate,
    this.finishDate,
    this.tags = const [],
    this.comments = '',
  });

  final int id;
  final bool isAnime;
  final String title;

  /// Anime format (`tv`, `ova`...); empty for manga.
  final String type;

  /// Episodes (anime) or chapters (manga) of the title.
  final int total;
  final int totalVolumes;
  final String? status;
  final int score;

  /// Episodes watched (anime) or chapters read (manga).
  final int progress;
  final int volumesRead;
  final bool repeating;
  final int timesRepeated;
  final int repeatValue;

  /// 0 low, 1 medium, 2 high.
  final int priority;
  final String? startDate;
  final String? finishDate;
  final List<String> tags;
  final String comments;
}

/// A page of the list endpoint, parsed.
class MalXmlPage {
  const MalXmlPage(this.entries, this.hasNext);
  final List<MalXmlEntry> entries;
  final bool hasNext;
}

/// The list endpoint answered with an error status.
class MalXmlExportError implements Exception {
  const MalXmlExportError(this.statusCode);
  final int statusCode;

  @override
  String toString() => 'MalXmlExportError($statusCode)';
}

/// The XML text of one list and the numbers of its `myinfo` block.
class MalXmlExport {
  const MalXmlExport(this.xml, this.count);
  final String xml;
  final int count;
}

/// Builds MyAnimeList's own export XML (`panel.php?go=export`) from the API v2 list of the
/// signed-in account, with no website session. AniList, Kitsu, Simkl and MAL accept the file.
class MalXmlExporter {
  MalXmlExporter({Future<http.Response> Function(String url)? get, String? Function()? userName})
      : _get = get ?? MalApi.authorizedGet,
        _userName = userName ?? (() => null);

  final Future<http.Response> Function(String url) _get;
  final String? Function() _userName;

  /// MAL serves at most 1000 entries per list request.
  static const int pageSize = 1000;

  static const String _listFields = 'list_status{status,score,num_episodes_watched,'
      'num_chapters_read,num_volumes_read,is_rewatching,is_rereading,num_times_rewatched,'
      'num_times_reread,rewatch_value,reread_value,priority,start_date,finish_date,tags,comments}';

  /// URL of one page of the signed-in user's list; adult entries stay in (`nsfw=1`).
  @visibleForTesting
  static String pageUrl({required bool isAnime, required int offset}) {
    final node = isAnime
        ? 'id,title,media_type,num_episodes'
        : 'id,title,media_type,num_chapters,num_volumes';
    return '${MalApi.userBaseEndPoint}/@me/${isAnime ? 'animelist' : 'mangalist'}'
        '?fields=$node,$_listFields&limit=$pageSize&offset=$offset&nsfw=1';
  }

  /// Reads the whole list; [onProgress] gets the number of entries read so far.
  Future<List<MalXmlEntry>> readList({
    required bool isAnime,
    void Function(int count)? onProgress,
  }) async {
    final entries = <MalXmlEntry>[];
    var offset = 0;
    while (true) {
      final response = await _get(pageUrl(isAnime: isAnime, offset: offset));
      if (response.statusCode == 401 && MalApi.sessionExpired.value) {
        throw const MalSessionExpired();
      }
      if (response.statusCode != 200) throw MalXmlExportError(response.statusCode);
      final input = (response.body, isAnime);
      // Big pages (1000 entries, a few hundred KB) are parsed off the UI isolate.
      final page = response.body.length > 32 * 1024
          ? await compute(_parsePageInput, input)
          : _parsePageInput(input);
      entries.addAll(page.entries);
      onProgress?.call(entries.length);
      if (!page.hasNext || page.entries.isEmpty) break;
      offset += pageSize;
    }
    return entries;
  }

  /// The export of the signed-in user's anime or manga list.
  Future<MalXmlExport> export({
    required bool isAnime,
    void Function(int count)? onProgress,
  }) async {
    final entries = await readList(isAnime: isAnime, onProgress: onProgress);
    return MalXmlExport(
      buildXml(entries, isAnime: isAnime, userName: _userName() ?? ''),
      entries.length,
    );
  }

  static MalXmlPage _parsePageInput((String, bool) input) =>
      parsePage(input.$1, isAnime: input.$2);

  /// Parses one answer of the list endpoint.
  static MalXmlPage parsePage(String body, {required bool isAnime}) {
    final root = json.decode(body);
    if (root is! Map) return const MalXmlPage([], false);
    final data = root['data'];
    final entries = <MalXmlEntry>[];
    if (data is List) {
      for (final item in data) {
        if (item is! Map || item['node'] is! Map) continue;
        final node = item['node'] as Map;
        final id = _int(node['id']);
        if (id <= 0) continue;
        final list = item['list_status'] is Map ? item['list_status'] as Map : const {};
        entries.add(MalXmlEntry(
          id: id,
          isAnime: isAnime,
          title: node['title']?.toString() ?? '',
          type: isAnime ? node['media_type']?.toString() ?? '' : '',
          total: _int(isAnime ? node['num_episodes'] : node['num_chapters']),
          totalVolumes: isAnime ? 0 : _int(node['num_volumes']),
          status: list['status']?.toString(),
          score: _int(list['score']),
          progress: _int(isAnime ? list['num_episodes_watched'] : list['num_chapters_read']),
          volumesRead: isAnime ? 0 : _int(list['num_volumes_read']),
          repeating: (isAnime ? list['is_rewatching'] : list['is_rereading']) == true,
          timesRepeated: _int(isAnime ? list['num_times_rewatched'] : list['num_times_reread']),
          repeatValue: _int(isAnime ? list['rewatch_value'] : list['reread_value']),
          priority: _int(list['priority']),
          startDate: _text(list['start_date']),
          finishDate: _text(list['finish_date']),
          tags: [
            for (final t in (list['tags'] is List ? list['tags'] as List : const []))
              if (t.toString().trim().isNotEmpty) t.toString().trim(),
          ],
          comments: list['comments']?.toString() ?? '',
        ));
      }
    }
    final paging = root['paging'];
    return MalXmlPage(entries, paging is Map && paging['next'] != null);
  }

  static int _int(Object? v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

  static String? _text(Object? v) {
    final t = v?.toString().trim();
    return t == null || t.isEmpty ? null : t;
  }

  /// MAL's export status words, per API status.
  static const Map<String, String> animeStatusWords = {
    'watching': 'Watching',
    'completed': 'Completed',
    'on_hold': 'On-Hold',
    'dropped': 'Dropped',
    'plan_to_watch': 'Plan to Watch',
  };

  static const Map<String, String> mangaStatusWords = {
    'reading': 'Reading',
    'completed': 'Completed',
    'on_hold': 'On-Hold',
    'dropped': 'Dropped',
    'plan_to_read': 'Plan to Read',
  };

  /// `series_type` words of MAL's export, per API `media_type`.
  static const Map<String, String> typeWords = {
    'tv': 'TV',
    'movie': 'Movie',
    'ova': 'OVA',
    'ona': 'ONA',
    'special': 'Special',
    'tv_special': 'Special',
    'music': 'Music',
    'cm': 'CM',
    'pv': 'PV',
  };

  static const List<String> _priorityWords = ['LOW', 'MEDIUM', 'HIGH'];

  /// An API date as the export writes it: unknown parts are zeros, no date is `0000-00-00`.
  @visibleForTesting
  static String xmlDate(String? date) {
    final m = RegExp(r'^(\d{4})(?:-(\d{2}))?(?:-(\d{2}))?$').firstMatch(date ?? '');
    if (m == null) return '0000-00-00';
    return '${m.group(1)}-${m.group(2) ?? '00'}-${m.group(3) ?? '00'}';
  }

  /// A text node: CDATA, with `]]>` split and characters XML 1.0 forbids dropped.
  @visibleForTesting
  static String cdata(String text) {
    final clean = text.replaceAll(RegExp('[\u0000-\u0008\u000B\u000C\u000E-\u001F￾￿]'), '');
    return '<![CDATA[${clean.replaceAll(']]>', ']]]]><![CDATA[>')}]]>';
  }

  /// The export document of [entries] (all of one kind, [isAnime]).
  static String buildXml(List<MalXmlEntry> entries,
      {required bool isAnime, required String userName}) {
    final words = isAnime ? animeStatusWords : mangaStatusWords;
    int count(String status) => entries.where((e) => e.status == status).length;
    final b = StringBuffer()
      ..writeln('<?xml version="1.0" encoding="UTF-8" ?>')
      ..writeln('<myanimelist>')
      ..writeln('\t<myinfo>')
      ..writeln('\t\t<user_id></user_id>')
      ..writeln('\t\t<user_name>${cdata(userName)}</user_name>')
      ..writeln('\t\t<user_export_type>${isAnime ? 1 : 2}</user_export_type>')
      ..writeln('\t\t<user_total_${isAnime ? 'anime' : 'manga'}>${entries.length}'
          '</user_total_${isAnime ? 'anime' : 'manga'}>')
      ..writeln('\t\t<user_total_${isAnime ? 'watching' : 'reading'}>'
          '${count(isAnime ? 'watching' : 'reading')}'
          '</user_total_${isAnime ? 'watching' : 'reading'}>')
      ..writeln('\t\t<user_total_completed>${count('completed')}</user_total_completed>')
      ..writeln('\t\t<user_total_onhold>${count('on_hold')}</user_total_onhold>')
      ..writeln('\t\t<user_total_dropped>${count('dropped')}</user_total_dropped>')
      ..writeln('\t\t<user_total_${isAnime ? 'plantowatch' : 'plantoread'}>'
          '${count(isAnime ? 'plan_to_watch' : 'plan_to_read')}'
          '</user_total_${isAnime ? 'plantowatch' : 'plantoread'}>')
      ..writeln('\t</myinfo>');
    for (final e in entries) {
      final status = words[e.status] ?? '';
      final priority = _priorityWords[e.priority.clamp(0, 2)];
      final tags = e.tags.join(', ');
      if (isAnime) {
        b
          ..writeln('\t<anime>')
          ..writeln('\t\t<series_animedb_id>${e.id}</series_animedb_id>')
          ..writeln('\t\t<series_title>${cdata(e.title)}</series_title>')
          ..writeln('\t\t<series_type>${typeWords[e.type] ?? e.type.toUpperCase()}</series_type>')
          ..writeln('\t\t<series_episodes>${e.total}</series_episodes>')
          ..writeln('\t\t<my_id>0</my_id>')
          ..writeln('\t\t<my_watched_episodes>${e.progress}</my_watched_episodes>')
          ..writeln('\t\t<my_start_date>${xmlDate(e.startDate)}</my_start_date>')
          ..writeln('\t\t<my_finish_date>${xmlDate(e.finishDate)}</my_finish_date>')
          ..writeln('\t\t<my_rated></my_rated>')
          ..writeln('\t\t<my_score>${e.score}</my_score>')
          ..writeln('\t\t<my_storage></my_storage>')
          ..writeln('\t\t<my_storage_value>0.00</my_storage_value>')
          ..writeln('\t\t<my_status>$status</my_status>')
          ..writeln('\t\t<my_comments>${cdata(e.comments)}</my_comments>')
          ..writeln('\t\t<my_times_watched>${e.timesRepeated}</my_times_watched>')
          ..writeln('\t\t<my_rewatch_value>${_rewatchWord(e.repeatValue)}</my_rewatch_value>')
          ..writeln('\t\t<my_priority>$priority</my_priority>')
          ..writeln('\t\t<my_tags>${cdata(tags)}</my_tags>')
          ..writeln('\t\t<my_rewatching>${e.repeating ? 1 : 0}</my_rewatching>')
          ..writeln('\t\t<my_rewatching_ep>0</my_rewatching_ep>')
          ..writeln('\t\t<my_discuss>1</my_discuss>')
          ..writeln('\t\t<my_sns>default</my_sns>')
          ..writeln('\t\t<update_on_import>1</update_on_import>')
          ..writeln('\t</anime>');
      } else {
        b
          ..writeln('\t<manga>')
          ..writeln('\t\t<manga_mangadb_id>${e.id}</manga_mangadb_id>')
          ..writeln('\t\t<manga_title>${cdata(e.title)}</manga_title>')
          ..writeln('\t\t<manga_volumes>${e.totalVolumes}</manga_volumes>')
          ..writeln('\t\t<manga_chapters>${e.total}</manga_chapters>')
          ..writeln('\t\t<my_id>0</my_id>')
          ..writeln('\t\t<my_read_volumes>${e.volumesRead}</my_read_volumes>')
          ..writeln('\t\t<my_read_chapters>${e.progress}</my_read_chapters>')
          ..writeln('\t\t<my_start_date>${xmlDate(e.startDate)}</my_start_date>')
          ..writeln('\t\t<my_finish_date>${xmlDate(e.finishDate)}</my_finish_date>')
          ..writeln('\t\t<my_scanalation_group>${cdata('')}</my_scanalation_group>')
          ..writeln('\t\t<my_score>${e.score}</my_score>')
          ..writeln('\t\t<my_storage></my_storage>')
          ..writeln('\t\t<my_retail_volumes>0</my_retail_volumes>')
          ..writeln('\t\t<my_status>$status</my_status>')
          ..writeln('\t\t<my_comments>${cdata(e.comments)}</my_comments>')
          ..writeln('\t\t<my_times_read>${e.timesRepeated}</my_times_read>')
          ..writeln('\t\t<my_tags>${cdata(tags)}</my_tags>')
          ..writeln('\t\t<my_priority>$priority</my_priority>')
          ..writeln('\t\t<my_reread_value>${_rewatchWord(e.repeatValue)}</my_reread_value>')
          ..writeln('\t\t<my_rereading>${e.repeating ? 1 : 0}</my_rereading>')
          ..writeln('\t\t<my_discuss>1</my_discuss>')
          ..writeln('\t\t<my_sns>default</my_sns>')
          ..writeln('\t\t<update_on_import>1</update_on_import>')
          ..writeln('\t</manga>');
      }
    }
    b.writeln('</myanimelist>');
    return b.toString();
  }

  /// MAL's export writes the rewatch value as a word (empty for 0).
  static String _rewatchWord(int value) => switch (value) {
        1 => 'Very Low',
        2 => 'Low',
        3 => 'Medium',
        4 => 'High',
        5 => 'Very High',
        _ => '',
      };
}
