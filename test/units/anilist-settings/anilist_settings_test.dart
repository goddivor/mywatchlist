import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mywatchlist/services/api/Anilist/anilist_graphql.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_settings_service.dart';

import '../../helpers/no_network.dart';

const viewer = {
  'about': 'Hello',
  'donatorTier': 0,
  'donatorBadge': '',
  'options': {
    'titleLanguage': 'ENGLISH_STYLISED',
    'staffNameLanguage': 'NATIVE',
    'displayAdultContent': true,
    'includeAdultContentInSearch': false,
    'includeAdultContentInQuickSearch': false,
    'displayAdultActivities': false,
    'airingNotifications': true,
    'profileColor': 'pink',
    'timezone': '+09:00',
    'activityMergeTime': 720,
    'restrictMessagesToFollowing': true,
    'notificationOptions': [
      {'type': 'AIRING', 'enabled': true},
      {'type': 'ACTIVITY_LIKE', 'enabled': false},
    ],
    'disabledListActivity': [
      {'type': 'PLANNING', 'disabled': true},
    ],
  },
  'mediaListOptions': {
    'scoreFormat': 'POINT_100',
    'rowOrder': 'score',
    'animeList': {
      'sectionOrder': ['Watching'],
      'splitCompletedSectionByFormat': true,
      'customLists': ['Favs'],
      'advancedScoring': ['Story'],
      'advancedScoringEnabled': true,
    },
    'mangaList': null,
  },
};

class Sent {
  final String query;
  final Map<String, dynamic> variables;
  final bool write;
  Sent(String body, this.write)
      : query = (jsonDecode(body) as Map)['query'] as String,
        variables = Map<String, dynamic>.from((jsonDecode(body) as Map)['variables'] as Map? ?? {});
}

AnilistSettingsService fake(List<Sent> log, Map<String, dynamic> Function(Sent) answer) {
  http.Response reply(String body, bool write) {
    final s = Sent(body, write);
    log.add(s);
    return http.Response(jsonEncode({'data': answer(s)}), 200);
  }

  return AnilistSettingsService(
    client: AnilistGraphql(
      sender: (b, {required auth}) async => reply(b, false),
      mutationSender: (b, {required auth}) async => reply(b, true),
    ),
  );
}

void main() {
  setUpAll(forbidNetwork);

  test('load reads options, list options and the profile text', () async {
    final log = <Sent>[];
    final s = await fake(log, (_) => {'Viewer': viewer}).load();
    expect(s.titleLanguage, AnilistTitleLanguage.englishStylised);
    expect(s.staffNameLanguage, AnilistStaffNameLanguage.native);
    expect(s.scoreFormat, AnilistScoreFormat.point100);
    expect(s.rowOrder, 'score');
    expect(s.timezone, '+09:00');
    expect(s.notificationOptions['ACTIVITY_LIKE'], false);
    expect(s.disabledListActivity['PLANNING'], true);
    expect(s.anime.customLists, ['Favs']);
    expect(s.anime.advancedScoringEnabled, true);
    expect(s.manga.customLists, isEmpty);
    expect(log.single.write, false);
  });

  test('update sends only the fields given, as one write', () async {
    final log = <Sent>[];
    final svc = fake(log, (_) => {'UpdateUser': viewer});
    await svc.update(
      titleLanguage: AnilistTitleLanguage.native,
      displayAdultContent: false,
      notificationOptions: {'AIRING': false},
    );
    final sent = log.single;
    expect(sent.write, true);
    expect(sent.query, contains('UpdateUser(titleLanguage: \$titleLanguage'));
    expect(sent.query, contains('\$notificationOptions: [NotificationOptionInput]'));
    expect(sent.variables.keys.toSet(), {'titleLanguage', 'displayAdultContent', 'notificationOptions'});
    expect(sent.variables['titleLanguage'], 'NATIVE');
    expect(sent.variables['notificationOptions'], [
      {'type': 'AIRING', 'enabled': false}
    ]);
  });

  test('addCustomList sends the whole array; deleteCustomList uses the mutation', () async {
    final log = <Sent>[];
    final svc = fake(log, (s) => s.query.contains('DeleteCustomList')
        ? {'DeleteCustomList': {'deleted': true}, 'Viewer': viewer}
        : {'UpdateUser': viewer, 'Viewer': viewer});
    await svc.addCustomList(' New ', anime: false, current: ['A']);
    expect(log.first.variables['mangaListOptions'], {'customLists': ['A', 'New']});
    expect(log.first.variables.containsKey('animeListOptions'), false);
    await svc.deleteCustomList('A', anime: true);
    expect(log[1].write, true);
    expect(log[1].variables, {'customList': 'A', 'type': 'ANIME'});
    expect(log[2].write, false);
  });

  test('previewMarkdown asks AniList and skips empty text', () async {
    final log = <Sent>[];
    final svc = fake(log, (_) => {'Markdown': {'html': '<p>x</p>'}});
    expect(await svc.previewMarkdown('  '), '');
    expect(log, isEmpty);
    expect(await svc.previewMarkdown('**x**'), '<p>x</p>');
  });
}
