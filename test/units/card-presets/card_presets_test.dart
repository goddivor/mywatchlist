import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/user/preferences/preferences.dart';
import 'package:mywatchlist/widgets/user/list/card_layout_editor.dart';
import 'package:mywatchlist/widgets/user/list/cards/custom_entry_card.dart';
import 'package:mywatchlist/widgets/user/list/cards/entry_parts.dart';
import 'package:mywatchlist/widgets/user/list/list_entry_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _app(Widget child) => MaterialApp(
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.delegate.supportedLocales,
      home: child,
    );

const _entry = ListEntryView(id: 1, category: 'anime', title: 'Frieren', total: 28, progress: 4);

void main() {
  setUpAll(() => S.load(const Locale('en')));
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('built-in styles as custom cards', () {
    test('each keeps the built-in height and cover width', () {
      final sizes = {
        for (final s in BuiltInCardStyle.values)
          s: (builtInCardLayout(s).height, builtInCardLayout(s).imageWidth),
      };
      expect(sizes[BuiltInCardStyle.compact], (56.0, 36.0));
      expect(sizes[BuiltInCardStyle.comfortable], (128.0, 84.0));
      expect(sizes[BuiltInCardStyle.spacious], (168.0, 112.0));
    });

    test('each lists every field once, the ones the style lacks hidden', () {
      for (final style in BuiltInCardStyle.values) {
        final fields = builtInCardLayout(style).fields;
        expect(fields.map((f) => f.type).toSet(), CustomizableFieldType.values.toSet(), reason: '$style');
        expect(fields, hasLength(CustomizableFieldType.values.length), reason: '$style');
        final shown = {for (final f in fields) if (!f.hidden) f.type};
        expect(shown, containsAll([CustomizableFieldType.image, CustomizableFieldType.title]),
            reason: '$style');
      }
      final spacious = {
        for (final f in builtInCardLayout(BuiltInCardStyle.spacious).fields) if (!f.hidden) f.type
      };
      expect(spacious, contains(CustomizableFieldType.genre));
    });
  });

  group('cover width', () {
    test('is saved, and a layout saved before it reads the old 86', () {
      final props = builtInCardLayout(BuiltInCardStyle.compact).copyWith(id: 'x');
      expect(ContentCardProps.fromJson(props.toJson()).imageWidth, 36);
      final old = props.toJson()..remove('imageWidth');
      expect(ContentCardProps.fromJson(old).imageWidth, ContentCardProps.defaultImageWidth);
      expect(ContentCardProps.fromJson({...props.toJson(), 'imageWidth': 999.0}).imageWidth,
          ContentCardProps.maxImageWidth);
    });

    testWidgets('sizes the cover of the card', (tester) async {
      await tester.pumpWidget(_app(Scaffold(
        body: CustomEntryCard(
          props: builtInCardLayout(BuiltInCardStyle.spacious),
          entry: _entry,
          now: DateTime(2026, 11, 20),
          locale: 'en',
        ),
      )));
      expect(tester.widget<EntryCover>(find.byType(EntryCover)).width, 112);
    });
  });

  testWidgets('New card starts from a built-in style, editable and saved with its sizes',
      (tester) async {
    ContentCardProps? saved;
    await tester.pumpWidget(_app(Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () async {
              saved = await Navigator.of(context).push<ContentCardProps>(MaterialPageRoute(
                builder: (_) => CardLayoutEditor(
                  props: builtInCardLayout(BuiltInCardStyle.compact).copyWith(id: 'c', profileName: 'Compact'),
                ),
              ));
            },
            child: const Text('open'),
          ),
        ),
      ),
    )));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text(S.current.UserList_Card_Height(56)), findsOneWidget);
    expect(find.text(S.current.Cps_Cover_Width(36)), findsOneWidget);

    await tester.drag(find.byKey(const ValueKey('card-cover-width')), const Offset(60, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text(S.current.UserList_Save));
    await tester.pumpAndSettle();
    expect(saved?.height, 56);
    expect(saved!.imageWidth, greaterThan(36));
  });

  testWidgets('the New card button offers the three built-in styles and the default card',
      (tester) async {
    await tester.pumpWidget(_app(const CardLayoutsPage()));
    await tester.tap(find.text(S.current.UserList_New_Card));
    await tester.pumpAndSettle();
    expect(find.text(S.current.Cps_Start_From), findsOneWidget);
    for (final name in ['comfortable', 'compact', 'spacious', 'blank']) {
      expect(find.byKey(ValueKey('card-start-$name')), findsOneWidget);
    }
    await tester.tap(find.byKey(const ValueKey('card-start-spacious')));
    await tester.pumpAndSettle();
    expect(find.text(S.current.UserList_Card_Height(168)), findsOneWidget);
    expect(find.text(S.current.Cps_Cover_Width(112)), findsOneWidget);
  });
}
