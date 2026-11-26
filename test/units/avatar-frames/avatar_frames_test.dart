import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mywatchlist/services/frames/avatar_frames.dart';
import 'package:mywatchlist/widgets/common/framed_avatar.dart';

const _flames = {'id': 'flames', 'imageUrl': 'https://img.test/flames.webp', 'scale': 1.4, 'dx': -0.04, 'dy': -0.08};

void main() {
  test('names asked together go in one request; answers, "no frame" included, are cached', () async {
    final calls = <Uri>[];
    final frames = AvatarFrames(
      batchWindow: const Duration(milliseconds: 5),
      client: MockClient((request) async {
        calls.add(request.url);
        return http.Response(jsonEncode({'frames': {'goddivor': _flames}}), 200);
      }),
    );

    final results = await Future.wait([frames.frameOf('Goddivor'), frames.frameOf('someone'), frames.frameOf('GODDIVOR')]);

    expect(calls, hasLength(1));
    expect(calls.single.path, '/api/frames/equipped');
    expect(calls.single.queryParameters['tracker'], 'mal');
    expect(calls.single.queryParameters['users']!.split(','), unorderedEquals(['goddivor', 'someone']));
    expect(results[0]!.id, 'flames');
    expect(results[0]!.scale, 1.4);
    expect(results[1], isNull);
    expect(results[2], results[0]);

    expect(frames.isKnown('someone'), isTrue, reason: 'no frame is an answer too');
    await frames.frameOf('goddivor');
    expect(calls, hasLength(1), reason: 'served from the cache');
  });

  test('an unreachable back-end means no frame, kept for a short time only', () async {
    var now = DateTime(2026, 11, 26, 12);
    var calls = 0;
    final frames = AvatarFrames(
      batchWindow: const Duration(milliseconds: 1),
      now: () => now,
      client: MockClient((_) async {
        calls++;
        return http.Response('oops', 500);
      }),
    );

    expect(await frames.frameOf('goddivor'), isNull);
    now = now.add(const Duration(seconds: 30));
    await frames.frameOf('goddivor');
    expect(calls, 1);
    now = now.add(const Duration(minutes: 1));
    await frames.frameOf('goddivor');
    expect(calls, 2, reason: 'a failure is retried after failureTtl, not after the full ttl');
  });

  test('equip sends the frame with the MAL token and updates the cached avatar', () async {
    http.Request? sent;
    final frames = AvatarFrames(
      authenticated: (send) => send(
        MockClient((request) async {
          sent = request;
          return http.Response(
            jsonEncode({
              'available': [
                {..._flames, 'name': 'Flammes', 'expiresAt': '2026-12-31T00:00:00.000Z'},
              ],
              'equipped': 'flames',
            }),
            200,
          );
        }),
        'token-123',
      ),
    );
    var notified = 0;
    frames.addListener(() => notified++);

    final result = await frames.equip('flames', username: 'Goddivor');

    expect(sent!.method, 'PUT');
    expect(sent!.url.path, '/api/frames/mine');
    expect(sent!.headers['Authorization'], 'Bearer token-123');
    expect(jsonDecode(sent!.body), {'frameId': 'flames'});
    expect(result!.equipped, 'flames');
    expect(result.available.single.name, 'Flammes');
    expect(result.available.single.expiresAt, DateTime.utc(2026, 12, 31));
    expect(frames.cached('goddivor')!.id, 'flames');
    expect(notified, 1);
  });

  test('a frame carries its still preview for lists, the animated file otherwise', () {
    expect(AvatarFrame.fromJson({..._flames, 'previewUrl': 'https://img.test/still.webp'})!.previewUrl,
        'https://img.test/still.webp');
    expect(AvatarFrame.fromJson(_flames)!.previewUrl, isNull);
  });

  testWidgets('FramedAvatar draws the frame around the avatar without changing its size', (tester) async {
    final frames = AvatarFrames(client: MockClient((_) async => http.Response('{}', 200)));
    frames.put('goddivor', AvatarFrame.fromJson(_flames));

    await tester.pumpWidget(MaterialApp(
      home: Center(
        child: FramedAvatar(
          username: 'Goddivor',
          size: 72,
          frames: frames,
          child: const ColoredBox(color: Colors.blue, key: Key('avatar')),
        ),
      ),
    ));

    expect(tester.getSize(find.byType(FramedAvatar)), const Size(72, 72));
    expect(tester.getSize(find.byKey(const Key('avatar'))), const Size(72, 72));
    final frameImage = find.byWidgetPredicate((w) => w is Image && w.image is CachedNetworkImageProvider);
    expect(frameImage, findsOneWidget);
    expect(tester.getSize(frameImage), Size(72 * 1.4, 72 * 1.4));
    final avatarCenter = tester.getCenter(find.byKey(const Key('avatar')));
    final frameCenter = tester.getCenter(frameImage);
    expect(frameCenter.dx, closeTo(avatarCenter.dx - 0.04 * 72, 0.01));
    expect(frameCenter.dy, closeTo(avatarCenter.dy - 0.08 * 72, 0.01));

    // Removing the frame (e.g. from the sheet) updates the avatar at once.
    frames.put('goddivor', null);
    await tester.pump();
    expect(frameImage, findsNothing);
  });

  testWidgets('a framed avatar swaps to its borderless version', (tester) async {
    final frames = AvatarFrames(client: MockClient((_) async => http.Response('{}', 200)));
    frames.put('goddivor', AvatarFrame.fromJson(_flames));
    Widget app() => MaterialApp(
          home: FramedAvatar(
            username: 'goddivor',
            size: 36,
            frames: frames,
            framedChild: const SizedBox(key: Key('borderless')),
            child: const SizedBox(key: Key('bordered')),
          ),
        );

    await tester.pumpWidget(app());
    expect(find.byKey(const Key('borderless')), findsOneWidget);
    expect(find.byKey(const Key('bordered')), findsNothing);

    frames.put('goddivor', null);
    await tester.pump();
    expect(find.byKey(const Key('bordered')), findsOneWidget, reason: 'no frame: the usual border is back');
  });

  testWidgets('the picture grows to fill a hole larger than the avatar; the frame keeps its place', (tester) async {
    final frames = AvatarFrames(client: MockClient((_) async => http.Response('{}', 200)));
    frames.put('goddivor', AvatarFrame.fromJson({..._flames, 'hole': 0.8, 'hx': 0.02, 'hy': 0.03}));

    await tester.pumpWidget(MaterialApp(
      home: Center(
        child: FramedAvatar(
          username: 'goddivor',
          size: 50,
          frames: frames,
          child: const ColoredBox(color: Colors.blue, key: Key('avatar')),
        ),
      ),
    ));

    expect(tester.getSize(find.byType(FramedAvatar)), const Size(50, 50), reason: 'the layout keeps the avatar slot');
    final frameRect = tester.getRect(find.byWidgetPredicate((w) => w is Image && w.image is CachedNetworkImageProvider));
    expect(frameRect.width, closeTo(50 * 1.4, 0.01));
    final picture = tester.getRect(find.byKey(const Key('avatar')));
    expect(picture.width, closeTo(50 * 1.4 * 0.8, 0.01));
    expect(picture.center.dx, closeTo(frameRect.center.dx + 0.02 * frameRect.width, 0.01));
    expect(picture.center.dy, closeTo(frameRect.center.dy + 0.03 * frameRect.width, 0.01));
  });

  testWidgets('a user without a frame shows the plain avatar', (tester) async {
    final frames = AvatarFrames(
      batchWindow: const Duration(milliseconds: 1),
      client: MockClient((_) async => http.Response(jsonEncode({'frames': {}}), 200)),
    );

    await tester.pumpWidget(MaterialApp(
      home: FramedAvatar(username: 'someone', size: 48, frames: frames, child: const SizedBox(key: Key('avatar'))),
    ));
    await tester.pump(const Duration(milliseconds: 10));
    await tester.pump();

    expect(frames.isKnown('someone'), isTrue);

    expect(find.byKey(const Key('avatar')), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });
}
