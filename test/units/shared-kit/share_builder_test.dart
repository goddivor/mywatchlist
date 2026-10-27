import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/widgets/common/share_builder.dart';

import '../../helpers/pump_app.dart';

void main() {
  setUpAll(() => S.load(const Locale('en')));

  const url = ShareField(label: 'Url', value: 'https://myanimelist.net/anime/1', labelled: false);
  const title = ShareField(label: 'Title', value: 'Cowboy Bebop');
  const score = ShareField(label: 'Score', value: '8.75');

  group('buildShareText', () {
    test('a single selected field is shared bare', () {
      expect(buildShareText([url, title.copyWith(selected: false)]), url.value);
      expect(buildShareText([title, score.copyWith(selected: false)]), 'Cowboy Bebop');
    });

    test('several fields are labelled and joined', () {
      expect(buildShareText([url, title, score]), '${url.value}\nTitle: Cowboy Bebop\nScore: 8.75');
    });

    test('format options apply', () {
      const format = ShareFormat(prefix: '- ', separator: ' = ', joiner: '; ', alwaysLabel: true);
      expect(buildShareText([title], format: format), '- Title = Cowboy Bebop');
    });

    test('nothing selected gives an empty text', () {
      expect(buildShareText([title.copyWith(selected: false)]), '');
    });
  });

  test('contentShareFields skips missing values', () {
    final fields = contentShareFields(url: 'u', title: 'T', mean: 8.5, synopsis: '  ');
    expect(fields.map((f) => f.label), ['Url', 'Title', 'Score']);
    expect(fields[2].value, '8.50');
  });

  testWidgets('ShareBuilder keeps one field checked and previews the text', (tester) async {
    String? shared;
    await pumpInApp(
      tester,
      ShareBuilder(fields: const [url, title], onCopy: (_) {}, onShare: (t) => shared = t),
    );
    expect(find.text('Select one'), findsOneWidget);
    await tester.tap(find.text('Select one'));
    await tester.pump();
    expect(find.text(url.value), findsNWidgets(2)); // tile subtitle + preview

    // The last checked field cannot be unchecked.
    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();
    expect(tester.widget<Checkbox>(find.byType(Checkbox).first).value, isTrue);

    await tester.tap(find.byIcon(Icons.share_outlined));
    expect(shared, url.value);
  });

  testWidgets('showShareBuilder copies and closes', (tester) async {
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      calls.add(call);
      return null;
    });
    await pumpInApp(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => showShareBuilder(context, fields: const [url, title, score]),
          child: const Text('open'),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(ShareBuilder), findsOneWidget);
    await tester.tap(find.text('Copy'));
    await tester.pumpAndSettle();
    expect(find.byType(ShareBuilder), findsNothing);
    expect(calls.where((c) => c.method == 'Clipboard.setData'), hasLength(1));
    expect(find.text('Copied to Clipboard!'), findsOneWidget);
  });

  testWidgets('a single field is shared without the sheet', (tester) async {
    final previous = shareTextSender;
    addTearDown(() => shareTextSender = previous);
    String? sent;
    shareTextSender = (text, subject) async => sent = text;
    await pumpInApp(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => showShareBuilder(context, fields: const [url]),
          child: const Text('open'),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(ShareBuilder), findsNothing);
    expect(sent, url.value);
  });
}
