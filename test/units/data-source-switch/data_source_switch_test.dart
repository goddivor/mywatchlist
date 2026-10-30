import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_client.dart';
import 'package:mywatchlist/services/api/jikan_source.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'source_fakes.dart';

Future<SharedPreferences> _prefs([Map<String, Object> values = const {}]) async {
  SharedPreferences.setMockInitialValues(values);
  return SharedPreferences.getInstance();
}

void main() {
  group('launch choice', () {
    test('Jikan answers the probe: Jikan is the source, Tenrai is never asked', () async {
      final rig = SourceRig(probe: true);
      await rig.source.start(await _prefs());
      expect(rig.source.active, DataSource.jikan);
      expect(rig.source.jikanMuted, isFalse);
      final response = await rig.get('/anime/1/full');
      expect(response.body, contains('"jikan"'));
      expect(rig.tenraiServer.requests, isEmpty);
    });

    test('Jikan fails the probe: Tenrai only, Jikan muted one month and saved', () async {
      final rig = SourceRig(probe: false);
      final prefs = await _prefs();
      await rig.source.start(prefs);
      expect(rig.source.active, DataSource.tenrai);
      expect(rig.source.jikanMutedUntil, rig.clock.add(const Duration(days: 30)));
      await Future<void>.delayed(Duration.zero);
      expect(DateTime.parse(prefs.getString(JikanSource.mutedUntilKey)!),
          rig.clock.add(const Duration(days: 30)));

      final response = await rig.get('/anime/1/full');
      expect(response.body, contains('"tenrai"'));
      expect(rig.jikanServer.requests, isEmpty);
      expect(rig.tenraiServer.requests.single.toString(), 'https://api.tenrai.org/v1/anime/1/full');
    });

    test('a probe that times out or throws selects Tenrai', () async {
      final silent = SourceRig(probe: null);
      await silent.source.start(await _prefs());
      expect(silent.source.active, DataSource.tenrai, reason: 'probeTimeout elapsed');

      final throwing = JikanSource(probe: () async => throw http.ClientException('refused'));
      await throwing.start(await _prefs());
      expect(throwing.active, DataSource.tenrai);
    });

    test('the default probe: one light Jikan request, a 5xx counts as down, a 429 as up', () async {
      final asked = <Uri>[];
      var status = 503;
      JikanSource build() => JikanSource(
            probeClient: MockClient((r) async {
              asked.add(r.url);
              return http.Response('{}', status);
            }),
          );
      final down = build();
      await down.start(await _prefs());
      expect(down.active, DataSource.tenrai);
      expect(asked.single, JikanSource.probeUrl);
      status = 429;
      final up = build();
      await up.start(await _prefs());
      expect(up.active, DataSource.jikan);
    });

    test('a saved mute: Tenrai without probing Jikan until the date, then a probe again', () async {
      final until = DateTime(2026, 11, 20);
      final saved = {
        JikanSource.mutedUntilKey: until.toIso8601String(),
        JikanSource.mutedSinceKey: DateTime(2026, 10, 21).toIso8601String(),
      };
      final rig = SourceRig(probe: true);
      await rig.source.start(await _prefs(saved));
      expect(rig.probe.calls, 0, reason: 'muted Jikan is not probed');
      expect(rig.source.active, DataSource.tenrai);
      expect(rig.source.jikanMutedUntil, until);
      await rig.get('/anime/1/full');
      await rig.get('/top/anime');
      expect(rig.jikanServer.requests, isEmpty, reason: 'muted Jikan is never called');

      final later = SourceRig(probe: true, now: until.add(const Duration(minutes: 1)));
      await later.source.start(await _prefs(saved));
      expect(later.probe.calls, 1);
      expect(later.source.active, DataSource.jikan);
      expect(later.source.jikanMuted, isFalse);
    });

    test('requests wait for the probe and go only to the chosen source', () async {
      final rig = SourceRig(probe: null);
      final probing = rig.source.start(await _prefs());
      final response = rig.get('/anime/1/full');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(rig.jikanServer.requests, isEmpty, reason: 'nothing leaves before the choice');
      expect(rig.tenraiServer.requests, isEmpty);
      rig.probe.pending!.complete(false);
      await probing;
      expect((await response).body, contains('"tenrai"'));
      expect(rig.jikanServer.requests, isEmpty);
    });

    test('the wait for the probe is bounded', () async {
      final rig = SourceRig(probe: null, readyTimeout: const Duration(milliseconds: 30));
      unawaited(rig.source.start(await _prefs()));
      final response = await rig.get('/anime/1/full');
      expect(response.body, contains('"jikan"'), reason: 'still undecided: the default source');
    });

    test('a source never started uses Jikan at once', () async {
      final rig = SourceRig();
      expect(await rig.source.ready.then((_) => rig.source.active), DataSource.jikan);
      await rig.get('/anime/1/full');
      expect(rig.jikanServer.requests, hasLength(1));
      expect(rig.probe.calls, 0);
    });
  });

  group('during the session', () {
    test('Jikan refused: Tenrai answers after the failure, Jikan is muted, next requests skip it',
        () async {
      final rig = SourceRig(jikan: ServerMode.refused);
      final prefs = await _prefs();
      await rig.source.start(prefs);
      expect(rig.source.active, DataSource.jikan);

      final response = await rig.get('/anime/1/full');
      expect(response.body, contains('"tenrai"'));
      expect(rig.source.active, DataSource.tenrai);
      expect(rig.source.jikanMuted, isTrue);
      expect(rig.inFlight.max, 1, reason: 'never both servers at once');
      await Future<void>.delayed(Duration.zero);
      expect(prefs.getString(JikanSource.mutedUntilKey), isNotNull);

      await rig.get('/anime/1/characters');
      expect(rig.jikanServer.requests, hasLength(1));
      expect(rig.client.isUnreachable, isFalse);
    });

    test('a silent Jikan: Tenrai only after the Jikan timeout, never in parallel', () async {
      final rig = SourceRig(jikan: ServerMode.silent, requestTimeout: const Duration(milliseconds: 60));
      await rig.source.start(await _prefs());
      final watch = Stopwatch()..start();
      final response = await rig.get('/anime/1/statistics');
      expect(response.body, contains('"tenrai"'));
      expect(watch.elapsed, greaterThanOrEqualTo(const Duration(milliseconds: 60)),
          reason: 'Tenrai is asked only once Jikan gave up, no hedge');
      expect(rig.source.active, DataSource.tenrai);
    });

    test('many requests failing together switch once and none reaches both servers at once', () async {
      final rig = SourceRig(jikan: ServerMode.refused);
      await rig.source.start(await _prefs());
      var changes = 0;
      rig.source.addListener(() => changes++);
      final answers = await Future.wait([
        for (final p in ['/anime/1/full', '/anime/2/full', '/anime/3/full']) rig.get(p),
      ]);
      expect(answers.every((r) => r.body.contains('"tenrai"')), isTrue);
      expect(changes, 1);
      // Each request went to Jikan, then to Tenrai: per request the two never overlap.
      for (final p in ['/anime/1/full', '/anime/2/full', '/anime/3/full']) {
        expect(rig.jikanServer.requests.where((u) => u.path == '/v4$p'), hasLength(1));
        expect(rig.tenraiServer.requests.where((u) => u.path == '/v1$p'), hasLength(1));
      }
    });

    test('a Jikan 5xx goes back to the caller, Jikan stays the source', () async {
      final rig = SourceRig(jikan: ServerMode.error503);
      await rig.source.start(await _prefs());
      final response = await rig.get('/anime/1/reviews');
      expect(response.statusCode, 503);
      expect(rig.source.active, DataSource.jikan);
      expect(rig.tenraiServer.requests, isEmpty);
    });

    test('Tenrai down while Jikan is muted: the request fails, Jikan is not asked', () async {
      final rig = SourceRig(probe: false, tenrai: ServerMode.refused);
      await rig.source.start(await _prefs());
      await expectLater(rig.get('/anime/1/full'), throwsA(isA<JikanUnavailable>()));
      expect(rig.jikanServer.requests, isEmpty);
      expect(rig.client.isUnreachable, isTrue, reason: 'no source left: callers go to their fallbacks');
    });

    test('Tenrai down while Jikan is no longer muted: Jikan takes over', () async {
      final rig = SourceRig(probe: false, tenrai: ServerMode.refused);
      await rig.source.start(await _prefs());
      // Ten days later the mute is shortened to one week: it is over, Tenrai stays the
      // source of the session until it fails.
      rig.clock = rig.clock.add(const Duration(days: 10));
      await rig.source.setMuteDuration(JikanMuteDuration.oneWeek);
      expect(rig.source.jikanMuted, isFalse);
      expect(rig.source.active, DataSource.tenrai);
      final response = await rig.get('/anime/1/full');
      expect(response.body, contains('"jikan"'));
      expect(rig.source.active, DataSource.jikan);
      expect(rig.inFlight.max, 1);
    });

    test('an endpoint Tenrai lacks fails at once while Jikan is muted', () async {
      final rig = SourceRig(probe: false);
      await rig.source.start(await _prefs());
      for (final path in ['/users/someone/full', '/users/someone/statistics', '/anime/1/userupdates', '/clubs/1']) {
        await expectLater(rig.get(path), throwsA(isA<JikanUnavailable>()));
      }
      expect(rig.jikanServer.requests, isEmpty);
      expect(rig.tenraiServer.requests, isEmpty);
      expect(rig.client.isUnreachable, isFalse, reason: 'Tenrai-served requests keep working');
    });

    test('Retry buttons do not end a mute', () async {
      final rig = SourceRig(probe: false);
      await rig.source.start(await _prefs());
      rig.client.resetReachability();
      expect(rig.source.jikanMuted, isTrue);
      expect(rig.source.active, DataSource.tenrai);
    });
  });

  group('settings', () {
    test('Test again: Jikan answers -> unmuted and saved; fails -> muted again from now', () async {
      final rig = SourceRig(probe: false);
      final prefs = await _prefs();
      await rig.source.start(prefs);
      expect(rig.source.active, DataSource.tenrai);

      rig.probe.answer = true;
      expect(await rig.source.testAgain(), DataSource.jikan);
      expect(rig.source.jikanMuted, isFalse);
      await Future<void>.delayed(Duration.zero);
      expect(prefs.getString(JikanSource.mutedUntilKey), isNull);
      await rig.get('/anime/1/full');
      expect(rig.jikanServer.requests, hasLength(1));

      rig.clock = rig.clock.add(const Duration(days: 2));
      rig.probe.answer = false;
      expect(await rig.source.testAgain(), DataSource.tenrai);
      expect(rig.source.jikanMutedUntil, rig.clock.add(const Duration(days: 30)));
    });

    test('the mute duration is saved, read at launch and applied to the next mute', () async {
      final rig = SourceRig(probe: true);
      final prefs = await _prefs();
      await rig.source.start(prefs);
      await rig.source.setMuteDuration(JikanMuteDuration.threeMonths);
      expect(prefs.getString(JikanSource.muteDurationKey), 'threeMonths');

      final next = SourceRig(probe: false);
      await next.source.start(prefs);
      expect(next.source.muteDuration, JikanMuteDuration.threeMonths);
      expect(next.source.jikanMutedUntil, next.clock.add(const Duration(days: 90)));
    });

    test('changing the duration recomputes a running mute from its start', () async {
      final rig = SourceRig(probe: false);
      await rig.source.start(await _prefs());
      final start = rig.clock;
      await rig.source.setMuteDuration(JikanMuteDuration.twoWeeks);
      expect(rig.source.jikanMutedUntil, start.add(const Duration(days: 14)));
    });

    test('default duration: one month', () {
      expect(JikanMuteDuration.byName(null), JikanMuteDuration.oneMonth);
      expect(JikanMuteDuration.byName('nonsense'), JikanMuteDuration.oneMonth);
      expect(JikanSource().muteDuration, JikanMuteDuration.oneMonth);
    });
  });

  test('the app client uses the shared selector', () {
    expect(JikanClient.instance.source, same(JikanSource.instance));
  });
}
