import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/user_profile/user_profile_data.dart';
import 'package:mywatchlist/services/api/MAL/mal_user_prof.dart';
import 'package:mywatchlist/user/language/language_bloc.dart';
import 'package:mywatchlist/user/theme/app_themes.dart';
import 'package:mywatchlist/widgets/charts/chart_palette.dart';
import 'package:mywatchlist/widgets/common/app_colors.dart';
import 'package:mywatchlist/widgets/user/profile/profile_format.dart';
import 'package:mywatchlist/widgets/user/profile/profile_header.dart';
import 'package:shared_preferences/shared_preferences.dart';

MalUserProf _mal() => MalUserProf.fromJson({
      'id': 42,
      'name': 'neo',
      'gender': 'male',
      'birthday': null,
      'anime_statistics': {
        'num_items': 50,
        'num_items_watching': 3,
        'num_items_completed': 31,
        'num_items_on_hold': 1,
        'num_items_dropped': 3,
        'num_items_plan_to_watch': 12,
        'num_days_watched': 11.0,
        'num_episodes': 610,
        'mean_score': 8.9,
      },
    });

Map<String, dynamic> _jikan() => {
      'mal_id': 42,
      'username': 'neo',
      'statistics': {
        'manga': {'total_entries': 8, 'completed': 5, 'reading': 1, 'plan_to_read': 2},
      },
      'favorites': {
        'anime': [
          {'mal_id': 1, 'title': 'Cowboy Bebop'}
        ],
      },
    };

ThemeData _theme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF607D8B), brightness: brightness);
  return ThemeData(
    colorScheme: scheme,
    extensions: [AppColors.fromScheme(scheme)],
  );
}

const _data = UserProfileData(id: 42, username: 'neo');

Widget _profileAppBar(ThemeData theme) => MaterialApp(
      theme: theme,
      localizationsDelegates: const [S.delegate],
      home: DefaultTabController(
        length: 2,
        child: Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                expandedHeight: kToolbarHeight + ProfileHeader.bandHeight + 48,
                backgroundColor: theme.colorScheme.surface,
                foregroundColor: theme.colorScheme.onSurface,
                title: const Text('neo-title'),
                flexibleSpace: const ProfileHeader(data: _data, isSelf: false, bottomInset: 48),
                bottom: const TabBar(tabs: [Tab(text: 'Stats'), Tab(text: 'About')]),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 2000)),
            ],
          ),
        ),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => LanguageBloc.apply('en'));
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => LanguageBloc.apply('en'));

  group('watch', () {
    final repo = UserProfileRepository.instance;

    test('shows the official MAL data before Jikan answers, then merges it', () async {
      final jikan = Completer<Map<String, dynamic>>();
      repo.malSelf = () async => _mal();
      repo.jikanFull = (_) => jikan.future;

      final values = <UserProfileData>[];
      final done = repo.watch(null, forceRefresh: true).listen(values.add).asFuture<void>();
      await pumpEventQueue();
      expect(values, hasLength(1));
      expect(values.first.anime.totalEntries, 50);
      expect(values.first.extras, ProfileExtras.loading);
      expect(values.first.favorites.isEmpty, isTrue);

      jikan.complete(_jikan());
      await done;
      expect(values, hasLength(2));
      expect(values.last.extras, ProfileExtras.ready);
      expect(values.last.manga.totalEntries, 8);
      expect(values.last.favorites.anime.single.title, 'Cowboy Bebop');
    });

    test('Jikan failing keeps the MAL data and marks the rest unavailable', () async {
      repo.malSelf = () async => _mal();
      repo.jikanFull = (_) async => throw Exception('offline');
      final values = await repo.watch(null, forceRefresh: true).toList();
      expect(values.map((v) => v.extras), [ProfileExtras.loading, ProfileExtras.unavailable]);
      expect(values.last.anime.meanScore, 8.9);
    });

    test('another user without Jikan nor cache is an error', () async {
      repo.jikanFull = (_) async => throw Exception('offline');
      await expectLater(
        repo.watch('nobody', forceRefresh: true).toList(),
        throwsA(isA<UserProfileUnavailable>()),
      );
    });
  });

  group('formatting', () {
    test('French: locale decimals, translated gender, media types and sources', () async {
      await LanguageBloc.apply('fr_FR');
      expect(profileMean(8.9), '8,90');
      expect(profileNumber(1234), '1 234');
      expect(profileGenderLabel('Male'), 'Homme');
      expect(profileGenderLabel('female'), 'Femme');
      expect(profileGenderLabel('Non-Binary'), 'Non binaire');
      expect(profileSourceLabel('light_novel'), S.current.Mi_Source_Light_Novel);
      expect(profileMediaTypeLabel('movie'), S.current.UserList_Media_Movie);
      expect(profileMediaTypeLabel('movie'), isNot('movie'));
    });

    test('English', () async {
      await LanguageBloc.apply('en');
      expect(profileMean(8.9), '8.90');
      expect(profileMean(null), S.current.Pp_No_Value);
      expect(profileGenderLabel('male'), 'Male');
    });
  });

  test('chart colours are the list status tokens of the theme', () {
    for (final brightness in Brightness.values) {
      final tokens = AppColors.fromScheme(_theme(brightness).colorScheme);
      final colors = themedStatusChartColors(tokens, const [-1, -1, -1, -1, -1]);
      expect(colors, [
        tokens.watching.color,
        tokens.completed.color,
        tokens.onHold.color,
        tokens.dropped.color,
        tokens.planned.color,
      ]);
      // A slot the user picked wins.
      expect(themedStatusChartColors(tokens, const [0xFF112233])[0], const Color(0xFF112233));
    }
  });

  for (final brightness in Brightness.values) {
    testWidgets('header, title and tabs are readable in ${brightness.name}', (tester) async {
      final theme = _theme(brightness);
      await tester.pumpWidget(_profileAppBar(theme));
      final cs = theme.colorScheme;

      final name = tester.widget<Text>(find.text('neo'));
      expect(contrastRatio(name.style!.color!, cs.surface), greaterThanOrEqualTo(4.5));

      // The header sits on the opaque surface of the app bar, not on a dark block.
      final appBarMaterial = tester.widget<Material>(
        find.descendant(of: find.byType(AppBar), matching: find.byType(Material)).first,
      );
      expect(appBarMaterial.color, cs.surface);

      final title = tester.widget<DefaultTextStyle>(
        find.ancestor(of: find.text('neo-title'), matching: find.byType(DefaultTextStyle)).first,
      );
      expect(contrastRatio(title.style.color!.withValues(alpha: 1), cs.surface),
          greaterThanOrEqualTo(4.5));

      final tabStyle = DefaultTextStyle.of(tester.element(find.text('About'))).style;
      expect(contrastRatio(tabStyle.color!.withValues(alpha: 1), cs.surface),
          greaterThanOrEqualTo(4.5));
      expect(tester.takeException(), isNull);

      // Collapsing slides the band away without layout errors.
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }

  test('the app themes give the status bar icons the contrast of the page', () {
    expect(AppThemes.systemOverlayStyle(Brightness.light).statusBarIconBrightness, Brightness.dark);
    expect(AppThemes.systemOverlayStyle(Brightness.dark).statusBarIconBrightness, Brightness.light);
  });

  test('every English key of the fragment has a French translation without em dash', () {
    Map<String, dynamic> read(String locale) => jsonDecode(
          File('lib/l10n/units/profile-polish/intl_$locale.arb').readAsStringSync(),
        ) as Map<String, dynamic>;
    final en = read('en');
    final fr = read('fr_FR');
    for (final key in en.keys.where((k) => !k.startsWith('@'))) {
      expect(fr.containsKey(key), isTrue, reason: 'missing in fr_FR: $key');
      expect(fr[key], isNot(contains('—')), reason: 'em dash in $key');
    }
  });
}
