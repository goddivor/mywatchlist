import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mywatchlist/services/api/MAL/mal_connect.dart' show MalSessionExpired;
import 'package:mywatchlist/services/list_export/mal_xml.dart';
import 'package:mywatchlist/services/list_export/mal_xml_import.dart';

String _animePage({bool next = false}) => jsonEncode({
      'data': [
        {
          'node': {'id': 1, 'title': 'Cowboy <Bebop> & Co ]]> end', 'media_type': 'tv', 'num_episodes': 26},
          'list_status': {
            'status': 'completed',
            'score': 9,
            'num_episodes_watched': 26,
            'is_rewatching': true,
            'num_times_rewatched': 2,
            'rewatch_value': 5,
            'priority': 2,
            'start_date': '2020-05',
            'finish_date': '2021',
            'tags': ['space', 'jazz'],
            'comments': 'Great & "fine"',
          },
        },
        {
          'node': {'id': 2, 'title': 'Planned', 'media_type': 'ova', 'num_episodes': 0},
          'list_status': {'status': 'plan_to_watch', 'score': 0, 'num_episodes_watched': 0},
        },
      ],
      if (next) 'paging': {'next': 'https://api.myanimelist.net/v2/next'},
    });

String _mangaPage() => jsonEncode({
      'data': [
        {
          'node': {'id': 7, 'title': 'Berserk', 'media_type': 'manga', 'num_chapters': 0, 'num_volumes': 41},
          'list_status': {
            'status': 'reading',
            'score': 10,
            'num_chapters_read': 300,
            'num_volumes_read': 30,
            'is_rereading': false,
            'num_times_reread': 1,
            'reread_value': 3,
            'priority': 1,
            'start_date': '2019-01-02',
            'tags': [],
            'comments': '',
          },
        },
      ],
    });

MalXmlEntry _entry(int id, {bool anime = true}) => MalXmlEntry(
      id: id,
      isAnime: anime,
      status: anime ? 'watching' : 'reading',
      progress: 3,
    );

void main() {
  group('export', () {
    test('builds the MAL anime document', () {
      final page = MalXmlExporter.parsePage(_animePage(), isAnime: true);
      final xml = MalXmlExporter.buildXml(page.entries, isAnime: true, userName: 'neo');
      expect(xml, startsWith('<?xml version="1.0" encoding="UTF-8" ?>'));
      expect(xml, contains('<user_export_type>1</user_export_type>'));
      expect(xml, contains('<user_total_anime>2</user_total_anime>'));
      expect(xml, contains('<user_total_completed>1</user_total_completed>'));
      expect(xml, contains('<user_total_plantowatch>1</user_total_plantowatch>'));
      expect(xml, contains('<series_animedb_id>1</series_animedb_id>'));
      expect(xml, contains('<series_type>TV</series_type>'));
      expect(xml, contains('<series_type>OVA</series_type>'));
      expect(xml, contains('<my_status>Completed</my_status>'));
      expect(xml, contains('<my_status>Plan to Watch</my_status>'));
      expect(xml, contains('<my_start_date>2020-05-00</my_start_date>'));
      expect(xml, contains('<my_finish_date>2021-00-00</my_finish_date>'));
      expect(xml, contains('<my_finish_date>0000-00-00</my_finish_date>'));
      expect(xml, contains('<my_priority>HIGH</my_priority>'));
      expect(xml, contains('<my_rewatch_value>Very High</my_rewatch_value>'));
      expect(xml, contains('<my_rewatching>1</my_rewatching>'));
      expect(xml, contains('<![CDATA[space, jazz]]>'));
      expect(xml, contains(']]]]><![CDATA[>'));
      expect(xml.trim(), endsWith('</myanimelist>'));
    });

    test('builds the manga document', () {
      final page = MalXmlExporter.parsePage(_mangaPage(), isAnime: false);
      final xml = MalXmlExporter.buildXml(page.entries, isAnime: false, userName: 'neo');
      expect(xml, contains('<user_export_type>2</user_export_type>'));
      expect(xml, contains('<manga_mangadb_id>7</manga_mangadb_id>'));
      expect(xml, contains('<manga_volumes>41</manga_volumes>'));
      expect(xml, contains('<my_read_chapters>300</my_read_chapters>'));
      expect(xml, contains('<my_read_volumes>30</my_read_volumes>'));
      expect(xml, contains('<my_status>Reading</my_status>'));
      expect(xml, contains('<my_priority>MEDIUM</my_priority>'));
    });

    test('forbidden control characters never reach the file', () {
      expect(MalXmlExporter.cdata('a\u0001b'), '<![CDATA[ab]]>');
    });

    test('reads every page of the list', () async {
      final urls = <String>[];
      final exporter = MalXmlExporter(
        userName: () => 'neo',
        get: (url) async {
          urls.add(url);
          return http.Response(_animePage(next: urls.length == 1), 200);
        },
      );
      final out = await exporter.export(isAnime: true);
      expect(out.count, 4);
      expect(urls.length, 2);
      expect(urls[0], contains('/users/@me/animelist'));
      expect(urls[0], contains('nsfw=1'));
      expect(urls[1], contains('offset=1000'));
    });

    test('an error status stops the export', () {
      final exporter = MalXmlExporter(get: (_) async => http.Response('no', 500));
      expect(exporter.export(isAnime: true), throwsA(isA<MalXmlExportError>()));
    });
  });

  group('read', () {
    test('what the export writes reads back the same', () {
      final entries = MalXmlExporter.parsePage(_animePage(), isAnime: true).entries;
      final doc = MalXmlReader.parse(MalXmlExporter.buildXml(entries, isAnime: true, userName: 'neo'));
      expect(doc.anime.length, 2);
      expect(doc.invalid, 0);
      final a = doc.anime.first;
      expect(a.id, 1);
      expect(a.title, 'Cowboy <Bebop> & Co ]]> end');
      expect(a.status, 'completed');
      expect(a.score, 9);
      expect(a.progress, 26);
      expect(a.repeating, isTrue);
      expect(a.timesRepeated, 2);
      expect(a.repeatValue, 5);
      expect(a.priority, 2);
      expect(a.startDate, '2020-05');
      expect(a.finishDate, '2021');
      expect(a.tags, ['space', 'jazz']);
      expect(a.comments, 'Great & "fine"');
      expect(doc.anime.last.startDate, isNull);
      expect(doc.anime.last.status, 'plan_to_watch');
    });

    test('manga round trip', () {
      final entries = MalXmlExporter.parsePage(_mangaPage(), isAnime: false).entries;
      final doc = MalXmlReader.parse(MalXmlExporter.buildXml(entries, isAnime: false, userName: 'neo'));
      final m = doc.manga.single;
      expect(m.id, 7);
      expect(m.status, 'reading');
      expect(m.progress, 300);
      expect(m.volumesRead, 30);
      expect(m.startDate, '2019-01-02');
      expect(m.repeatValue, 3);
      expect(m.priority, 1);
    });

    test('numeric statuses, plain text, entities and comments', () {
      const xml = '''
<myanimelist><!-- <anime><series_animedb_id>99</series_animedb_id></anime> -->
<anime><series_animedb_id>5</series_animedb_id><series_title>A &amp; B &#233;</series_title>
<my_status>6</my_status><my_score>11</my_score><my_tags/><my_start_date>0000-00-00</my_start_date></anime>
<anime><series_animedb_id>6</series_animedb_id><my_status>Currently Watching</my_status></anime>
<anime><series_animedb_id>0</series_animedb_id><my_status>1</my_status></anime>
<anime><series_animedb_id>8</series_animedb_id><my_status>weird</my_status></anime>
</myanimelist>''';
      final doc = MalXmlReader.parse(xml);
      expect(doc.anime.map((e) => e.id), [5, 6]);
      expect(doc.invalid, 2);
      expect(doc.anime.first.status, 'plan_to_watch');
      expect(doc.anime.first.title, 'A & B é');
      expect(doc.anime.first.score, 10);
      expect(doc.anime.first.tags, isEmpty);
      expect(doc.anime.last.status, 'watching');
    });

    test('a file that is not an export is refused', () {
      expect(() => MalXmlReader.parse('<html></html>'), throwsFormatException);
    });

    test('gzip files are unpacked', () {
      final bytes = gzip.encode(utf8.encode('<myanimelist></myanimelist>'));
      expect(MalXmlReader.decodeBytes(Uint8List.fromList(bytes)), '<myanimelist></myanimelist>');
    });

    test('dates', () {
      expect(MalXmlReader.apiDate('2020-00-00'), '2020');
      expect(MalXmlReader.apiDate('2020-04-00'), '2020-04');
      expect(MalXmlReader.apiDate('2020-04-09'), '2020-04-09');
      expect(MalXmlReader.apiDate('0000-00-00'), isNull);
      expect(MalXmlReader.apiDate(''), isNull);
    });
  });

  group('import', () {
    MalXmlImporter importer({
      List<int>? saved,
      Future<void> Function(MalXmlEntry)? onSave,
      Set<int> existing = const {},
      List<Duration>? pauses,
    }) =>
        MalXmlImporter(
          saveAnime: onSave ?? (e) async => saved?.add(e.id),
          saveManga: onSave ?? (e) async => saved?.add(e.id),
          get: (url) async => http.Response(
              jsonEncode({
                'data': [
                  for (final id in existing) {'node': {'id': id, 'title': 't'}},
                ],
              }),
              200),
          pause: (d) async => pauses?.add(d),
        );

    test('writes every entry, anime then manga', () async {
      final saved = <int>[];
      final doc = MalXmlDocument(anime: [_entry(1), _entry(2)], manga: [_entry(9, anime: false)]);
      final progress = <int>[];
      final result = await importer(saved: saved).run(doc,
          overwrite: true, onProgress: (done, total) => progress.add(done));
      expect(saved, [1, 2, 9]);
      expect(result.saved, 3);
      expect(result.failed, 0);
      expect(progress, [1, 2, 3]);
    });

    test('keeps what is already in the list', () async {
      final saved = <int>[];
      final doc = MalXmlDocument(anime: [_entry(1), _entry(2)]);
      final result = await importer(saved: saved, existing: {1}).run(doc, overwrite: false);
      expect(saved, [2]);
      expect(result.skipped, 1);
      expect(result.saved, 1);
    });

    test('retries a rate limit, then gives up on a refusal', () async {
      var calls = 0;
      final pauses = <Duration>[];
      final doc = MalXmlDocument(anime: [_entry(1), _entry(2)]);
      final result = await importer(
        pauses: pauses,
        onSave: (e) async {
          if (e.id == 1 && ++calls < 3) throw Exception('Failed to update list status: 429');
          if (e.id == 2) throw Exception('Failed to update list status: 404');
        },
      ).run(doc, overwrite: true);
      expect(calls, 3);
      expect(result.saved, 1);
      expect(result.failed, 1);
      expect(pauses, contains(const Duration(seconds: 2)));
      expect(pauses, contains(const Duration(seconds: 4)));
    });

    test('stops when the session ends', () async {
      final saved = <int>[];
      final doc = MalXmlDocument(anime: [_entry(1), _entry(2)]);
      final result = await importer(onSave: (e) async {
        if (e.id == 2) throw const MalSessionExpired();
        saved.add(e.id);
      }).run(doc, overwrite: true);
      expect(saved, [1]);
      expect(result.sessionExpired, isTrue);
      expect(result.saved, 1);
    });

    test('stops when asked', () async {
      final saved = <int>[];
      final doc = MalXmlDocument(anime: [_entry(1), _entry(2), _entry(3)]);
      final result = await importer(saved: saved).run(doc,
          overwrite: true, isCancelled: () => saved.length == 1);
      expect(saved, [1]);
      expect(result.cancelled, isTrue);
    });
  });
}
