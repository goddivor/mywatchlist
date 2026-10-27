import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/screens/user_profile/user_profile_data.dart';
import 'package:mywatchlist/services/api/MAL/mal_user_prof.dart';
import 'package:mywatchlist/services/api/MAL/scrapper/user_friends.dart';
import 'package:mywatchlist/services/api/MAL/scrapper/user_history.dart';
import 'package:mywatchlist/services/api/MAL/scrapper/user_anime_statistics.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> jikanFull({String name = 'neo'}) => {
      'mal_id': 42,
      'username': name,
      'gender': 'Male',
      'location': 'Zion',
      'birthday': '1999-03-31T00:00:00+00:00',
      'joined': '2015-06-01T00:00:00+00:00',
      'images': {
        'jpg': {'image_url': 'https://img/neo.jpg'}
      },
      'statistics': {
        'anime': {
          'days_watched': 10.5,
          'mean_score': 7.8,
          'watching': 2,
          'completed': 30,
          'on_hold': 1,
          'dropped': 3,
          'plan_to_watch': 9,
          'total_entries': 45,
          'episodes_watched': 600,
        },
        'manga': {
          'days_read': 4.0,
          'mean_score': 8.1,
          'reading': 1,
          'completed': 5,
          'on_hold': 0,
          'dropped': 0,
          'plan_to_read': 2,
          'total_entries': 8,
          'chapters_read': 300,
          'volumes_read': 20,
        },
      },
      'favorites': {
        'anime': [
          {
            'mal_id': 1,
            'title': 'Cowboy Bebop',
            'images': {
              'jpg': {'image_url': 'https://img/1.jpg'}
            }
          }
        ],
        'characters': [
          {'mal_id': 5, 'name': 'Spike', 'images': {'jpg': {'image_url': 'https://img/5.jpg'}}}
        ],
        'manga': [],
        'people': [],
      },
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('Jikan statistics map to the shared ListStats shape', () {
    final stats = parseJikanStatistics(jikanFull());
    expect(stats.anime.totalEntries, 45);
    expect(stats.anime.progress, 600);
    expect(stats.anime.statusCounts, [2, 30, 1, 3, 9]);
    expect(stats.manga.progress, 300);
    expect(stats.manga.volumes, 20);
    expect(stats.manga.statusCounts, [1, 5, 0, 0, 2]);
    expect(parseJikanStatistics(null).anime.isEmpty, isTrue);
  });

  test('merge keeps the official anime numbers and Jikan manga and favorites', () {
    final mal = MalUserProf.fromJson({
      'id': 42,
      'name': 'neo',
      'picture': 'https://mal/neo.jpg',
      'birthday': null,
      'anime_statistics': {
        'num_items': 50,
        'num_items_watching': 3,
        'num_items_completed': 31,
        'num_items_on_hold': 1,
        'num_items_dropped': 3,
        'num_items_plan_to_watch': 12,
        'num_days_watched': 11.0,
        'num_days_watching': 1.0,
        'num_days_completed': 9.0,
        'num_days_on_hold': 0.5,
        'num_days_dropped': 0.5,
        'num_episodes': 610,
        'mean_score': 7.9,
      },
    });
    final data = UserProfileRepository.merge('neo', mal: mal, jikan: jikanFull());

    expect(data.pictureUrl, 'https://mal/neo.jpg');
    expect(data.anime.totalEntries, 50);
    expect(data.anime.meanScore, 7.9);
    expect(data.animeDays, [1.0, 9.0, 0.5, 0.5]);
    expect(data.manga.totalEntries, 8);
    expect(data.gender, 'Male');
    expect(data.favorites.anime.single.title, 'Cowboy Bebop');
    expect(data.favorites.characters.single.title, 'Spike');
    expect(data.favorites.isEmpty, isFalse);
  });

  test('a null birthday no longer breaks MalUserProf.fromJson', () {
    final prof = MalUserProf.fromJson({'id': 1, 'name': 'x', 'birthday': null});
    expect(prof.birthday, isNull);
    expect(prof.toJson()['name'], 'x');
  });

  test('profile data survives a JSON round trip', () {
    final data = UserProfileRepository.merge('neo', jikan: jikanFull());
    final copy = UserProfileData.fromJson(data.toJson());
    expect(copy.username, 'neo');
    expect(copy.anime.statusCounts, data.anime.statusCounts);
    expect(copy.favorites.anime.single.id, 1);
  });

  group('UserProfileRepository.load', () {
    late int jikanCalls;
    late bool jikanFails;

    setUp(() {
      jikanCalls = 0;
      jikanFails = false;
      UserProfileRepository.instance.jikanFull = (name) async {
        jikanCalls++;
        if (jikanFails) throw Exception('offline');
        return jikanFull(name: name);
      };
    });

    test('serves a fresh cached profile without asking again', () async {
      final repo = UserProfileRepository.instance;
      final first = await repo.load('Neo');
      expect(first.username, 'Neo');
      expect(jikanCalls, 1);

      final second = await repo.load('neo');
      expect(second.anime.totalEntries, 45);
      expect(jikanCalls, 1);

      await repo.load('neo', forceRefresh: true);
      expect(jikanCalls, 2);
    });

    test('falls back to the cache when the network fails, then reports unavailable', () async {
      final repo = UserProfileRepository.instance;
      await repo.load('trinity');
      jikanFails = true;
      final stale = await repo.load('trinity', forceRefresh: true);
      expect(stale.username, 'trinity');

      await expectLater(repo.load('unknown'), throwsA(isA<UserProfileUnavailable>()));
    });
  });

  group('page envelopes', () {
    test('friends from the Jikan body', () {
      final page = parseFriendsEnvelope({
        'data': {
          'pagination': {'has_next_page': true},
          'data': [
            {
              'user': {
                'username': 'morpheus',
                'images': {
                  'jpg': {'image_url': 'https://img/m.jpg'}
                }
              },
              'last_online': '2 hours ago',
              'friends_since': 'Jan 1, 2020',
            },
            {'user': {}},
          ]
        }
      });
      expect(page.hasNextPage, isTrue);
      expect(page.friends, hasLength(1));
      expect(page.friends.single.imageUrl, 'https://img/m.jpg');
      expect(page.friends.single.lastOnline, '2 hours ago');
    });

    test('friends from the HTML parser shape and from nothing', () {
      final page = parseFriendsEnvelope({
        'data': {
          'friends': [
            {
              'user': {'username': 'oracle', 'imageUrl': 'https://img/o.jpg'},
              'lastOnline': 'Now',
              'friendSince': ''
            }
          ]
        }
      });
      expect(page.friends.single.username, 'oracle');
      expect(page.friends.single.friendsSince, isNull);
      expect(parseFriendsEnvelope(null).friends, isEmpty);
    });

    test('history entries, day labels and clock', () {
      final entries = parseHistoryEnvelope({
        'data': {
          'histories': [
            {'id': 1, 'title': 'Bebop', 'history': 'Ep. 5', 'category': 'anime', 'time': 'Today, 9:12 AM'},
            {'id': 0, 'title': 'Skipped', 'history': '', 'category': 'anime', 'time': 'x'},
            {'id': 2, 'title': 'Berserk', 'history': 'Ch. 3', 'category': null, 'time': 'Oct 5, 2:03 AM'},
          ]
        }
      }, category: 'manga');
      expect(entries, hasLength(2));
      expect(entries.first.dayLabel, 'Today');
      expect(entries.first.clock, '9:12 AM');
      expect(entries.last.category, 'manga');
      expect(entries.last.dayLabel, 'Oct 5');
      expect(parseHistoryEnvelope(null, category: 'anime'), isEmpty);
    });
  });
}
