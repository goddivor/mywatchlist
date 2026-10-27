import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/main.dart' show appNavigatorKey;
import 'package:mywatchlist/utils/deep_links.dart';
import 'package:mywatchlist/utils/web_launcher.dart';

/// System links handed to the app, without the platform channel.
class _FakeAppLinks implements AppLinks {
  _FakeAppLinks(this.initial);

  final Uri? initial;
  final StreamController<Uri> controller = StreamController<Uri>.broadcast();

  @override
  Stream<Uri> get uriLinkStream => controller.stream;

  @override
  Future<Uri?> getInitialLink() async => initial;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late List<Uri> opened;

  setUp(() {
    opened = [];
    WebLauncher.opener = (uri, {barColor, onBarColor, external = false}) async {
      opened.add(uri);
      return true;
    };
  });

  tearDown(() async {
    await DeepLinks.stop();
    WebLauncher.opener = defaultUrlOpener;
  });

  testWidgets('a system link without an in-app screen opens the browser', (tester) async {
    await tester.pumpWidget(MaterialApp(navigatorKey: appNavigatorKey, home: const SizedBox()));
    final links = _FakeAppLinks(null);
    await DeepLinks.start(appLinks: links);

    links.controller.add(Uri.parse('https://myanimelist.net/stacks/1'));
    await tester.pump();
    links.controller.add(Uri.parse('https://myanimelist.net/forum/'));
    await tester.pump();

    expect(opened, [Uri.parse('https://myanimelist.net/stacks/1'), Uri.parse('https://myanimelist.net/forum/')]);
    await links.controller.close();
  });

  testWidgets('the initial link is handled once, OAuth and foreign links are ignored', (tester) async {
    await tester.pumpWidget(MaterialApp(navigatorKey: appNavigatorKey, home: const SizedBox()));
    final initial = Uri.parse('https://myanimelist.net/topanime.php');
    final links = _FakeAppLinks(initial);
    await DeepLinks.start(appLinks: links);
    links.controller.add(initial);
    links.controller.add(Uri.parse('com.teen.mywatchlist://myanimelist-callback?code=x'));
    links.controller.add(Uri.parse('https://example.com/anime/1'));
    await tester.pump();

    expect(opened, [initial]);
    expect(WebLauncher.internalLinkHandler, isNotNull);
    await links.controller.close();
  });
}
