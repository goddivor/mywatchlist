import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/services/api/MAL/mal_anime.dart';
import 'package:mywatchlist/services/api/MAL/models/my_anime_list_status.dart';
import 'package:mywatchlist/services/api/MAL/models/my_manga_list_status.dart';
import 'package:mywatchlist/services/auth/mal_authresp.dart';
import 'package:mywatchlist/services/auth/retry_policy.dart';
import 'package:mywatchlist/user/accounts/provider/account_manager_singleton.dart';
import 'package:mywatchlist/user/user_mal_v2.dart';
import 'package:mywatchlist/widgets/user/edit/edit_rules.dart';
import 'package:mywatchlist/widgets/user/edit/list_entry.dart';
import 'package:mywatchlist/widgets/user/edit/list_entry_service.dart';

import 'fixtures.dart';

/// MAL over a fake HTTP client: `GET /{anime|manga}/{id}` answers [content]
/// with the stored list entry, `PUT …/my_list_status` merges the form body
/// into it and answers the whole entry, as the real API does.
class _FakeMal {
  _FakeMal(this.content, {required this.isAnime})
      : entry = Map<String, dynamic>.from(
            content['my_list_status'] as Map<String, dynamic>);

  final Map<String, dynamic> content;
  final bool isAnime;
  Map<String, dynamic> entry;
  final puts = <Map<String, String>>[];

  static const _renamed = {'num_watched_episodes': 'num_episodes_watched'};
  static const _ints = {
    'score',
    'num_episodes_watched',
    'num_chapters_read',
    'num_volumes_read',
    'priority',
    'num_times_rewatched',
    'num_times_reread',
    'rewatch_value',
    'reread_value',
  };

  MockClient get client => MockClient((req) async {
        if (req.method == 'PUT') {
          final form = Uri.splitQueryString(req.body);
          puts.add(form);
          for (final e in form.entries) {
            final key = _renamed[e.key] ?? e.key;
            entry[key] = _ints.contains(key)
                ? int.parse(e.value)
                : key.startsWith('is_')
                    ? e.value == 'true'
                    : key == 'tags'
                        ? e.value.split(',')
                        : e.value;
          }
          return http.Response(jsonEncode(entry), 200);
        }
        return http.Response(
            jsonEncode({...content, 'my_list_status': entry}), 200);
      });
}

void main() {
  final user = UserMalV2.instance;
  const service = MalListEntryService();

  void useMal(_FakeMal mal) {
    user.clientFactory = () => mal.client;
    user.retryPolicy = RetryPolicy(sleep: (_) async {});
  }

  setUp(() {
    dotenv.testLoad(fileInput: 'MAL_CLIENT_ID=cid\nMAL_CLIENT_SECRET=sec');
    FlutterSecureStorage.setMockInitialValues({});
    AccountManagerSingleton().updateAccountType(AccountType.myanimelist);
    user.setAuthResponse(AuthResponse(
      accessToken: 'TOKEN',
      refreshToken: 'R1',
      expiresIn: 3600,
      createdTime: DateTime.now(),
    ));
  });

  tearDown(() {
    user.clientFactory = http.Client.new;
    user.retryPolicy = const RetryPolicy();
    AccountManagerSingleton().updateAccountType(AccountType.none);
  });

  group('list-status models keep MAL text dates', () {
    test('anime: month and year-only dates stay as sent', () {
      final s = MyAnimeListStatus.fromJson(
          {'start_date': '2019', 'finish_date': '2019-03'});
      expect(s.startDate, '2019');
      expect(s.finishDate, '2019-03');
      expect(s.toJson()['start_date'], '2019');
      expect(s.toJson()['finish_date'], '2019-03');
    });

    test('manga: month and year-only dates stay as sent', () {
      final s = MyMangaListStatus.fromJson(
          {'start_date': '2020-06', 'finish_date': '2021'});
      expect(s.startDate, '2020-06');
      expect(s.finishDate, '2021');
      expect(s.toJson()['finish_date'], '2021');
    });

    test('built from the full MyListStatus without losing a field', () {
      final full = MyListStatus.fromJson({
        'status': 'reading',
        'score': 7,
        'num_episodes_watched': 0,
        'is_rewatching': false,
        'updated_at': '2024-02-10T12:00:00+00:00',
        'num_chapters_read': 113,
        'num_volumes_read': 12,
        'is_rereading': true,
        'start_date': '2020-06',
        'finish_date': '2021',
        'priority': 1,
        'tags': ['a'],
        'comments': 'c',
        'num_times_reread': 2,
        'reread_value': 3,
      });
      final m = MyMangaListStatus.fromListStatus(full);
      expect(m.numChaptersRead, 113);
      expect(m.numVolumesRead, 12);
      expect(m.isRereading, isTrue);
      expect(m.startDate, '2020-06');
      expect(m.finishDate, '2021');
      expect(m.numTimesReread, 2);
      expect(m.rereadValue, 3);
      expect(m.updatedAt, DateTime.utc(2024, 2, 10, 12));
      final a = MyAnimeListStatus.fromListStatus(full);
      expect(a.startDate, '2020-06');
      expect(a.finishDate, '2021');
    });
  });

  group('open -> save -> reopen over MAL keeps partial dates', () {
    test('anime: a score change leaves 2019-03 untouched', () async {
      final mal = _FakeMal(completedAnimeJson(), isAnime: true);
      mal.entry['start_date'] = '2019';
      useMal(mal);

      final opened = await service.load(5114, isAnime: true);
      expect(opened.entry!.startDate, '2019');
      expect(opened.entry!.finishDate, '2019-03');

      final saved = await service.update(5114,
          isAnime: true,
          patch: const EntryPatch(score: 9),
          previous: opened.entry);
      expect(mal.puts.single, {'score': '9'});
      expect(saved.entry.score, 9);
      expect(saved.entry.startDate, '2019');
      expect(saved.entry.finishDate, '2019-03');
      // The tracker's answer given to onListStatusChange keeps them too.
      final status = saved.status as MyAnimeListStatus;
      expect(status.score, 9);
      expect(status.startDate, '2019');
      expect(status.finishDate, '2019-03');

      final reopened = await service.load(5114, isAnime: true);
      expect(reopened.entry!.startDate, '2019');
      expect(reopened.entry!.finishDate, '2019-03');
    });

    test('anime: the answer alone is enough (no previous entry)', () async {
      final mal = _FakeMal(completedAnimeJson(), isAnime: true);
      useMal(mal);

      final saved = await service.update(5114,
          isAnime: true, patch: const EntryPatch(priority: 1));
      expect(saved.entry.finishDate, '2019-03');
      expect(saved.entry.timesRepeated, 2);
      expect(saved.entry.tags, ['shounen', 'Tom &amp; Jerry']);
    });

    test('manga: partial dates, chapters and volumes survive a save',
        () async {
      final mal = _FakeMal(readingMangaJson(), isAnime: false);
      mal.entry['start_date'] = '2020-06';
      mal.entry['finish_date'] = '2021';
      useMal(mal);

      final opened = await service.load(2, isAnime: false);
      final saved = await service.update(2,
          isAnime: false,
          patch: const EntryPatch(progress: 113),
          previous: opened.entry);
      expect(mal.puts.single, {'num_chapters_read': '113'});
      expect(saved.entry.progress, 113);
      expect(saved.entry.volumes, 12);
      expect(saved.entry.isRepeating, isTrue);
      expect(saved.entry.startDate, '2020-06');
      expect(saved.entry.finishDate, '2021');
      final status = saved.status as MyMangaListStatus;
      expect(status.numChaptersRead, 113);
      expect(status.startDate, '2020-06');

      final reopened = await service.load(2, isAnime: false);
      expect(reopened.entry!.startDate, '2020-06');
      expect(reopened.entry!.finishDate, '2021');

      // The user list rebuilds its row from the reported status.
      final row = ListEntry.fromMangaStatus(status, previous: opened.entry);
      expect(row.progress, 113);
      expect(row.startDate, '2020-06');
      expect(row.finishDate, '2021');
    });

    test('a date set in the sheet is sent and kept as text', () async {
      final mal = _FakeMal(readingMangaJson(), isAnime: false);
      useMal(mal);

      final saved = await service.update(2,
          isAnime: false, patch: const EntryPatch(finishDate: '2026-10-27'));
      expect(mal.puts.single, {'finish_date': '2026-10-27'});
      expect(saved.entry.finishDate, '2026-10-27');
      expect(saved.entry.startDate, '2020-06-01');
    });
  });
}
