import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mwl_api/handlers/handler_core.dart';
import 'package:mwl_commons/mwl_commons.dart';

/// Invalid request parameters are refused with a 400 before any network
/// call (issue #72): the root test config forbids the network, so a handler
/// that went on to fetch a page would fail here with a 500, not a 400.
void main() {
  final core = HandlerCore();

  Future<(int, Map<String, dynamic>)> get(String pathAndQuery) async {
    final response =
        await core.respond(Uri.parse('http://localhost/$pathAndQuery'));
    final body = jsonDecode(await response.readAsString());
    return (response.statusCode, body as Map<String, dynamic>);
  }

  group('schedules', () {
    test('an unknown season is refused, not replaced by the current one',
        () async {
      final (status, body) = await get('schedules?season=bogus&year=2025');
      expect(status, 400);
      expect(body['error'], true);
      expect(body['message'], contains('season'));
    });

    test('a non-numeric year is refused, not replaced by the current one',
        () async {
      final (status, body) = await get('schedules?season=fall&year=soon');
      expect(status, 400);
      expect(body['message'], contains('year'));
    });
  });

  group('numeric path ids', () {
    for (final route in [
      'anime/abc',
      'manga/abc',
      'character/abc',
      'people/abc',
      'character/abc/pics',
      'people/abc/pics',
    ]) {
      test('$route answers 400 instead of crashing the handler', () async {
        final (status, body) = await get(route);
        expect(status, 400);
        expect(body['error'], true);
        expect(body['message'], contains('id'));
      });
    }

    test('the in-process entry point returns the 400 error as JSON', () async {
      final raw = await core
          .handleRequestAsString(Uri.parse('http://localhost/anime/abc'));
      expect(raw, isNotNull);
      final body = jsonDecode(raw!) as Map<String, dynamic>;
      expect(body['error'], true);
      expect(body['status'], 400);
    });
  });

  group('PathMatcher.intPathParam', () {
    final matcher = PathMatcher('anime/*id', (_, __, ___) async => {});

    test('parses a numeric segment', () {
      expect(matcher.intPathParam('anime/42'), 42);
    });

    test('throws BadRequest on a non-numeric segment', () {
      expect(() => matcher.intPathParam('anime/abc'),
          throwsA(isA<BadRequest>()));
    });

    test('pathParam<int> no longer throws a cast error', () {
      expect(() => matcher.pathParam<int>('anime/abc'),
          throwsA(isA<BadRequest>()));
    });
  });
}
