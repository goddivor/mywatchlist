import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mywatchlist/constants/constants.dart' show AccountType;
import 'package:mywatchlist/services/profile/shared_banner.dart';
import 'package:mywatchlist/services/usage/usage_ping.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A fake back-end + Cloudinary: records each call, answers like the real ones.
class _Backend {
  String? hash;
  String? url;
  final calls = <String>[];
  List<int>? uploaded;

  late final MockClient client = MockClient((request) async {
    calls.add('${request.method} ${request.url.host}${request.url.path}');
    final path = request.url.path;
    if (request.url.host == 'api.cloudinary.com') {
      uploaded = request.bodyBytes;
      return http.Response('{"version": 7}', 200);
    }
    if (request.url.host == 'img.test') return http.Response.bytes([9, 9, 9], 200);
    if (path == '/api/banner/mine' && request.method == 'GET') {
      return http.Response(jsonEncode({'url': url, 'hash': hash}), 200);
    }
    if (path == '/api/banner/mine' && request.method == 'POST') {
      return http.Response(
          jsonEncode({'url': 'https://api.cloudinary.com/v1_1/x/image/upload', 'fields': {'public_id': 'mal_1', 'signature': 'sig'}}),
          200);
    }
    if (path == '/api/banner' && request.method == 'PUT') {
      hash = (jsonDecode(request.body) as Map)['hash'] as String;
      url = 'https://img.test/b.webp';
      return http.Response(jsonEncode({'url': url, 'hash': hash}), 200);
    }
    if (path == '/api/banner' && request.method == 'DELETE') {
      hash = url = null;
      return http.Response('{"url": null}', 200);
    }
    if (path == '/api/banner' && request.method == 'GET') return http.Response(jsonEncode({'url': url}), 200);
    return http.Response('nope', 404);
  });

  late final SharedBanners banners = SharedBanners(
    client: client,
    baseUrl: 'https://api.test',
    authenticated: (send) => send(client, 'tok'),
  );
}

void main() {
  late Directory dir;
  setUp(() {
    dir = Directory.systemTemp.createTempSync('banner_test');
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() => dir.deleteSync(recursive: true));

  File local(List<int> bytes) => File('${dir.path}/bg.jpg')..writeAsBytesSync(bytes);

  test('a banner set before the update is uploaded once, silently, then left alone', () async {
    final backend = _Backend();
    final file = local([1, 2, 3]);
    var saved = 0;

    final first = await backend.banners.sync(username: 'goddivor', localPath: file.path, save: (_) async => saved++);
    expect(first, BannerSync.uploaded);
    expect(backend.uploaded, isNotNull);
    expect(backend.hash, SharedBanners.hashOf([1, 2, 3]));
    expect(backend.calls, contains('POST api.cloudinary.com/v1_1/x/image/upload'));

    backend.calls.clear();
    final second = await backend.banners.sync(username: 'goddivor', localPath: file.path, save: (_) async => saved++);
    expect(second, BannerSync.upToDate);
    expect(backend.calls, ['GET api.test/api/banner/mine'], reason: 'the hash says it is online: nothing is sent');
    expect(saved, 0);
  });

  test('a local banner changed after a sync is uploaded again', () async {
    final backend = _Backend();
    final file = local([1, 2, 3]);
    await backend.banners.sync(username: 'g', localPath: file.path, save: (_) async {});
    file.writeAsBytesSync([4, 5, 6]);
    expect(await backend.banners.sync(username: 'g', localPath: file.path, save: (_) async {}), BannerSync.uploaded);
    expect(backend.hash, SharedBanners.hashOf([4, 5, 6]));
  });

  test('two phones with different banners settle on the account one, no ping-pong', () async {
    final backend = _Backend();
    // Phone A: its banner goes online.
    await backend.banners.sync(username: 'g', localPath: local([1, 2, 3]).path, save: (_) async {});
    final online = backend.hash;

    // Phone B (its own storage), with an older banner of its own: it takes the account's.
    SharedPreferences.setMockInitialValues({});
    final b = File('${dir.path}/b.jpg')..writeAsBytesSync([7, 7]);
    final result = await backend.banners.sync(
      username: 'g',
      localPath: b.path,
      save: (bytes) async => b.writeAsBytesSync(bytes),
    );
    expect(result, BannerSync.downloaded);
    expect(backend.hash, online, reason: 'phone B did not overwrite the account banner');

    // Next launch of B: the downloaded copy differs from the uploaded file but nothing changed.
    backend.calls.clear();
    expect(await backend.banners.sync(username: 'g', localPath: b.path, save: (_) async {}), BannerSync.upToDate);
    expect(backend.calls, ['GET api.test/api/banner/mine']);
  });

  test('a banner removed on another phone is removed here', () async {
    final backend = _Backend();
    final file = local([1, 2, 3]);
    await backend.banners.sync(username: 'g', localPath: file.path, save: (_) async {});
    backend.hash = backend.url = null; // removed elsewhere
    var removed = false;
    final result = await backend.banners.sync(
      username: 'g',
      localPath: file.path,
      save: (_) async {},
      removeLocal: () async => removed = true,
    );
    expect(result, BannerSync.removedLocal);
    expect(removed, isTrue);
  });

  test('another phone (no local banner) gets the online one', () async {
    final backend = _Backend()
      ..hash = 'a' * 40
      ..url = 'https://img.test/b.webp';
    List<int>? saved;
    final result = await backend.banners.sync(username: 'g', localPath: null, save: (b) async => saved = b);
    expect(result, BannerSync.downloaded);
    expect(saved, [9, 9, 9]);
  });

  test('nothing anywhere: nothing happens', () async {
    final backend = _Backend();
    expect(await backend.banners.sync(username: 'g', localPath: null, save: (_) async {}), BannerSync.upToDate);
    expect(backend.calls, ['GET api.test/api/banner/mine']);
  });

  test('signed out or offline: failed, tried again at the next launch', () async {
    final banners = SharedBanners(baseUrl: 'https://api.test', authenticated: (_) async => null);
    expect(await banners.sync(username: 'g', localPath: null, save: (_) async {}), BannerSync.failed);
  });

  test('everyone reads the shared banner; removing it clears it', () async {
    final backend = _Backend()..url = 'https://img.test/b.webp';
    expect(await backend.banners.urlOf('Goddivor'), 'https://img.test/b.webp');
    expect(backend.calls.last, 'GET api.test/api/banner');
    expect(await backend.banners.remove(username: 'goddivor'), isTrue);
    expect(await backend.banners.urlOf('goddivor'), isNull);
  });

  group('usage ping', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('sends an anonymous install id once a day', () async {
      final sent = <Map<String, dynamic>>[];
      var now = DateTime.utc(2026, 11, 27, 9);
      final ping = UsagePing(
        baseUrl: 'https://api.test',
        now: () => now,
        client: MockClient((request) async {
          sent.add(jsonDecode(request.body) as Map<String, dynamic>);
          return http.Response('{"ok":true}', 200);
        }),
      );
      Future<bool> send() => ping.maybeSend(
            version: '1.2.3',
            platform: 'android',
            locale: 'fr-FR',
            trackers: const [AccountType.myanimelist, AccountType.simkl],
          );

      expect(await send(), isTrue);
      expect(await send(), isFalse, reason: 'already sent today');
      now = now.add(const Duration(days: 1));
      expect(await send(), isTrue);

      expect(sent, hasLength(2));
      expect(sent.first.keys, unorderedEquals(['installId', 'version', 'platform', 'locale', 'trackers']));
      expect(sent.first['installId'], matches(RegExp(r'^[0-9a-f]{32}$')));
      expect(sent.last['installId'], sent.first['installId'], reason: 'the same install keeps its id');
      expect(sent.first['trackers'], ['mal', 'simkl']);
    });

    test('a failed ping is tried again the same day', () async {
      var ok = false;
      final ping = UsagePing(
        baseUrl: 'https://api.test',
        client: MockClient((_) async => http.Response('', ok ? 200 : 500)),
      );
      Future<bool> send() => ping.maybeSend(version: '1', platform: 'android', locale: 'en', trackers: const []);
      expect(await send(), isFalse);
      ok = true;
      expect(await send(), isTrue);
    });
  });
}
