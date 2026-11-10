import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/utils/web_launcher.dart';

import '../../helpers/pump_app.dart';

void main() {
  setUpAll(() => S.load(const Locale('en')));

  group('parseMalLink', () {
    test('reads kind and id from MAL URLs', () {
      final link = parseMalLink(Uri.parse('https://myanimelist.net/anime/5114/Fullmetal_Alchemist'))!;
      expect(link.kind, 'anime');
      expect(link.id, 5114);
      expect(link.segments.last, 'Fullmetal_Alchemist');
    });

    test('reads query ids and relative paths', () {
      expect(parseMalLink(Uri.parse('https://www.myanimelist.net/forum/?topicid=42'))!.id, 42);
      final relative = parseMalLink(Uri.parse('/people/118/Hiroshi_Kamiya'))!;
      expect(relative.kind, 'people');
      expect(relative.id, 118);
    });

    test('ignores other sites and the home page', () {
      expect(parseMalLink(Uri.parse('https://anilist.co/anime/1')), isNull);
      expect(parseMalLink(Uri.parse('https://myanimelist.net/')), isNull);
      expect(parseMalLink(Uri.parse('mailto:someone@example.com')), isNull);
    });
  });

  group('openLink', () {
    final opened = <Uri>[];
    setUp(() {
      opened.clear();
      WebLauncher.opener = (uri, {barColor, onBarColor, external = false}) async {
        opened.add(uri);
        return true;
      };
    });
    tearDown(() {
      WebLauncher.opener = defaultUrlOpener;
      WebLauncher.internalLinkHandler = null;
    });

    Future<void> pumpLink(WidgetTester tester, String url) => pumpInApp(
          tester,
          Builder(
            builder: (context) => TextButton(onPressed: () => openLink(context, url), child: const Text('link')),
          ),
        );

    testWidgets('asks before opening an external link', (tester) async {
      await pumpLink(tester, 'https://example.com/page');
      await tester.tap(find.text('link'));
      await tester.pumpAndSettle();
      expect(find.text('https://example.com/page'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(opened, isEmpty);

      await tester.tap(find.text('link'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open link'));
      await tester.pumpAndSettle();
      expect(opened, [Uri.parse('https://example.com/page')]);
    });

    testWidgets('a handled MAL link opens in the app without asking', (tester) async {
      MalLink? routed;
      WebLauncher.internalLinkHandler = (context, link) async {
        routed = link;
        return true;
      };
      await pumpLink(tester, 'https://myanimelist.net/manga/2/Berserk');
      await tester.tap(find.text('link'));
      await tester.pumpAndSettle();
      expect(routed?.kind, 'manga');
      expect(routed?.id, 2);
      expect(find.byType(AlertDialog), findsNothing);
      expect(opened, isEmpty);
    });

    testWidgets('an unhandled relative MAL path opens on myanimelist.net', (tester) async {
      await pumpLink(tester, '/anime/1/Cowboy_Bebop');
      await tester.tap(find.text('link'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open link'));
      await tester.pumpAndSettle();
      expect(opened.single.toString(), 'https://myanimelist.net/anime/1/Cowboy_Bebop');
    });
  });
}
