import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:mywatchlist/services/api/SimKl/scrapper/simkl_web_client.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_client.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_detail_service.dart';

String fixture(String name) => File('test/units/simkl-media-page/fixtures/$name').readAsStringSync();

/// Drops every picture so a widget test never asks the network for one.
String withoutImages(String html) => html.replaceAll(RegExp(r'<img\b[^>]*>', caseSensitive: false), '');

Object? withoutPictures(Object? json) {
  if (json is Map) {
    return {
      for (final e in json.entries)
        if (!const {'poster', 'fanart', 'img', 'trailers'}.contains(e.key)) e.key: withoutPictures(e.value),
    };
  }
  if (json is List) return [for (final e in json) withoutPictures(e)];
  return json;
}

Future<R> inlineRunner<Q, R>(R Function(Q input) parse, Q input) async => parse(input);

/// Fake Simkl: API answers by path, simkl.com pages by URL; records every request.
class FakeSimklSite {
  final Map<String, Object? Function()> api;
  final Map<String, String Function()> pages;
  final List<Uri> apiCalls = [];
  final List<Uri> pageCalls = [];
  final List<Duration> waits = [];
  DateTime clock = DateTime.utc(2026, 10, 28, 12);

  FakeSimklSite({this.api = const {}, this.pages = const {}});

  late final SimklClient client = SimklClient(
    auth: (send, {idempotent}) async => null,
    publicGet: (uri, headers) async {
      apiCalls.add(uri);
      final answer = api[uri.path];
      if (answer == null) return http.Response('{"error":"not_found"}', 404);
      return http.Response.bytes(utf8.encode(jsonEncode(answer())), 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    },
    clientId: () => 'cid',
    appVersion: () async => '1.0.0',
    now: () => clock,
  );

  late final SimklWebClient web = SimklWebClient(
    get: (uri, headers) async {
      pageCalls.add(uri);
      final page = pages[uri.toString()];
      if (page == null) return http.Response('Just a moment...', 403);
      return http.Response.bytes(utf8.encode(page()), 200, headers: {'content-type': 'text/html; charset=utf-8'});
    },
    now: () => clock,
    sleep: (d) async {
      waits.add(d);
      clock = clock.add(d);
    },
  );

  SimklDetailService service() =>
      SimklDetailService(client: client, web: web, runner: inlineRunner, now: () => clock);
}
