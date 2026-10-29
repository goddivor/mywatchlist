import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/SimKl/scrapper/simkl_web_client.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_cdn.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_client.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_detail_service.dart';
import 'package:mywatchlist/user/accounts/account_bloc.dart';
import 'package:mywatchlist/user/language/language_bloc.dart';
import 'package:mywatchlist/user/MAL/mal_home_preferences_bloc.dart';
import 'package:mywatchlist/user/preferences/preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Saved Simkl answers of `fixtures/` (copied from the simkl-media-page unit's real captures).
String fixture(String name) => File('test/units/simkl-redesign/fixtures/$name').readAsStringSync();

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

http.Response jsonResponse(Object? body, [int status = 200]) => http.Response.bytes(
      utf8.encode(body is String ? body : jsonEncode(body)),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

Future<R> inlineRunner<Q, R>(R Function(Q input) parse, Q input) async => parse(input);

/// A fake Simkl: API answers by path (public and signed-in), simkl.com pages by URL, CDN files by
/// path. Records every request; nothing reaches the network or a real account.
class FakeSimkl {
  FakeSimkl({this.api = const {}, this.pages = const {}, this.cdnFiles = const {}});

  final Map<String, Object? Function(http.Request request)> api;
  final Map<String, String Function()> pages;
  final Map<String, Object? Function()> cdnFiles;
  final List<http.Request> requests = [];
  final List<Uri> publicCalls = [];
  DateTime clock = DateTime.utc(2026, 10, 28, 12);

  http.Response _answer(String path, http.Request? request) {
    final a = api[path];
    if (a == null) return jsonResponse({'error': 'not_found'}, 404);
    return jsonResponse(a(request ?? http.Request('GET', Uri.parse('https://api.simkl.com$path'))));
  }

  late final SimklClient client = SimklClient(
    auth: (send, {idempotent}) => send(
      MockClient((request) async {
        requests.add(request);
        return _answer(request.url.path, request);
      }),
      'test-token',
    ),
    publicGet: (uri, headers) async {
      publicCalls.add(uri);
      return _answer(uri.path, null);
    },
    clientId: () => 'cid',
    appVersion: () async => '1.0.0',
    now: () => clock,
  );

  late final SimklWebClient web = SimklWebClient(
    get: (uri, headers) async {
      final page = pages[uri.toString()];
      if (page == null) return http.Response('Just a moment...', 403);
      return http.Response.bytes(utf8.encode(page()), 200, headers: {'content-type': 'text/html; charset=utf-8'});
    },
    now: () => clock,
    sleep: (d) async => clock = clock.add(d),
  );

  late final SimklCdn cdn = SimklCdn(
    get: (uri, headers) async {
      final f = cdnFiles[uri.path];
      return f == null ? jsonResponse({}, 404) : jsonResponse(f());
    },
    clientId: () => 'cid',
    appVersion: () async => '1.0.0',
  );

  SimklDetailService details() => SimklDetailService(client: client, web: web, runner: inlineRunner, now: () => clock);

  Iterable<http.Request> writes() => requests.where((r) => r.method == 'POST');
}

/// A `sync/all-items/anime` item.
Map<String, dynamic> listItem({
  required int id,
  String title = 'Title',
  String status = 'watching',
  int watched = 0,
  int total = 12,
  int notAired = 0,
}) =>
    {
      'status': status,
      'watched_episodes_count': watched,
      'total_episodes_count': total,
      'not_aired_episodes_count': notAired,
      'show': {
        'title': '$title $id',
        'year': 2024,
        'ids': {'simkl': id, 'slug': 'slug-$id'},
      },
    };

/// Pumps [page] in a MaterialApp with the app's blocs, at 360 dp wide.
Future<void> pumpPage(WidgetTester tester, Widget page, {String locale = 'en', double height = 4000}) async {
  SharedPreferences.setMockInitialValues({});
  await LanguageBloc.apply(locale);
  final prefs = PreferencesBloc(store: PreferencesStore(await SharedPreferences.getInstance()));
  addTearDown(prefs.close);
  tester.view.physicalSize = Size(360, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final parts = locale.split('_');
  await tester.pumpWidget(MultiBlocProvider(
    providers: [
      BlocProvider(create: (_) => AccountBloc()),
      BlocProvider(create: (_) => HomePreferencesBloc()),
      BlocProvider.value(value: prefs),
    ],
    child: MaterialApp(
      locale: Locale(parts.first, parts.length > 1 ? parts[1] : null),
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.delegate.supportedLocales,
      home: page,
    ),
  ));
  await tester.pumpAndSettle();
}
