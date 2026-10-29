import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/settings/theme_settings.dart';
import 'package:mywatchlist/user/language/language_bloc.dart';
import 'package:mywatchlist/user/theme/app_themes.dart';
import 'package:mywatchlist/user/theme/theme_bloc.dart';
import 'package:mywatchlist/user/theme/theme_event.dart';
import 'package:mywatchlist/user/theme/theme_state.dart';
import 'package:mywatchlist/widgets/common/app_colors.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _spring = 'assets/images/spring.jpg';
const _summer = 'assets/images/summer.jpg';
const _fall = 'assets/images/fall.jpg';
const _winter = 'assets/images/winter.jpg';
const _collage = 'assets/images/anime-collage.jpg';

// DailyAL's season themes (themedata.dart v2ToV3ThemeMap) as Material presets.
const _pink = Color(0xFFE91E63);
const _deepOrange = Color(0xFFFF5722);
const _brown = Color(0xFF795548);
const _lightBlue = Color(0xFF03A9F4);

Future<ThemeBloc> _loaded({Color? wallpaper, Map<String, Object> values = const {}}) async {
  SharedPreferences.setMockInitialValues(values);
  final prefs = await SharedPreferences.getInstance();
  final bloc = ThemeBloc(
    prefs: prefs,
    readDynamicAccent: () async => wallpaper,
    syncSystemBars: false,
  );
  bloc.add(ThemeLoadStarted());
  await pumpEventQueue();
  return bloc;
}

Future<void> _background(ThemeBloc bloc, String path) async {
  bloc.add(ThemeBackgroundChanged(backgroundImagePath: path, showBackground: true));
  await pumpEventQueue();
}

void main() {
  group('season accents', () {
    test('each seasonal background maps to DailyAL\'s accent', () {
      expect(AppThemes.seasonAccentFor(_spring), _pink);
      expect(AppThemes.seasonAccentFor(_summer), _deepOrange);
      expect(AppThemes.seasonAccentFor(_fall), _brown);
      expect(AppThemes.seasonAccentFor(_winter), _lightBlue);
      expect(AppThemes.seasonAccentFor(_collage), _brown);
      expect(AppThemes.seasonAccentFor('/data/user/0/x/bg.jpg'), _brown);
      expect(AppThemes.seasonAccentFor(null), _brown);
    });

    test('season accents are presets of the colour grid', () {
      final presets = AppThemes.predefinedColors.map((c) => c.toARGB32()).toSet();
      for (final accent in AppThemes.seasonAccents.values) {
        expect(presets, contains(accent.toARGB32()));
      }
      expect(AppThemes.seasonAccents.keys, everyElement(isIn(AppThemes.backgroundImages)));
    });

    test('a new install gets DailyAL\'s default: Fall background, Brown accent, Auto (season)',
        () async {
      final bloc = await _loaded();
      expect(bloc.state.backgroundImagePath, _fall);
      expect(bloc.state.followSeason, isTrue);
      expect(bloc.state.effectiveSeed, _brown);
      expect(AppThemes.defaultSeedColor, _brown);
      expect(ThemeState.initial().effectiveSeed, _brown);
      expect(ThemeState.initial().backgroundImagePath, _fall);
      await bloc.close();
    });

    test('in Auto (season) the accent follows the background picture', () async {
      final bloc = await _loaded();
      for (final (path, accent) in [
        (_spring, _pink),
        (_summer, _deepOrange),
        (_winter, _lightBlue),
        (_fall, _brown),
      ]) {
        await _background(bloc, path);
        expect(bloc.state.effectiveSeed, accent, reason: path);
        expect(
          bloc.state.lightThemeData.colorScheme.primary,
          AppThemes.colorScheme(seedColor: accent, brightness: Brightness.light).primary,
          reason: path,
        );
      }
      await bloc.close();
    });

    test('hiding the background keeps the season accent of the chosen picture', () async {
      final bloc = await _loaded();
      await _background(bloc, _winter);
      bloc.add(const ThemeBackgroundChanged(backgroundImagePath: _winter, showBackground: false));
      await pumpEventQueue();
      expect(bloc.state.effectiveSeed, _lightBlue);
      await bloc.close();
    });
  });

  group('explicit picks win', () {
    test('a preset stays whatever the background, and the theme is not rebuilt', () async {
      final bloc = await _loaded();
      bloc.add(ThemeSeedColorChanged(AppThemes.predefinedColors[6])); // Blue
      await pumpEventQueue();
      expect(bloc.state.followSeason, isFalse);
      expect(bloc.prefs.getBool(ThemeBloc.keyAccentSeason), isFalse);
      final light = bloc.state.lightThemeData;
      await _background(bloc, _spring);
      expect(bloc.state.effectiveSeed, AppThemes.predefinedColors[6]);
      expect(identical(bloc.state.lightThemeData, light), isTrue);
      await bloc.close();
    });

    test('a custom colour stays whatever the background', () async {
      const custom = Color(0xFF123456);
      final bloc = await _loaded();
      bloc.add(const ThemeCustomColorAdded(custom));
      await pumpEventQueue();
      await _background(bloc, _summer);
      expect(bloc.state.effectiveSeed, custom);
      await bloc.close();
    });

    test('Material You stays whatever the background; Auto (season) turns it off', () async {
      const system = Color(0xFF3F51B5);
      final bloc = await _loaded(wallpaper: system);
      bloc.add(const ThemeDynamicColorChanged(true));
      await pumpEventQueue();
      await _background(bloc, _spring);
      expect(bloc.state.effectiveSeed, system);
      expect(bloc.state.followSeason, isFalse);

      bloc.add(const ThemeSeasonAccentSelected());
      await pumpEventQueue();
      expect(bloc.state.useDynamicColor, isFalse);
      expect(bloc.state.followSeason, isTrue);
      expect(bloc.state.effectiveSeed, _pink);
      expect(bloc.prefs.getBool(ThemeBloc.keyAccentSeason), isTrue);
      expect(bloc.prefs.getBool(ThemeBloc.keyDynamicColor), isFalse);
      await bloc.close();
    });

    test('removing the custom accent brings Auto (season) back', () async {
      const custom = Color(0xFF654321);
      final bloc = await _loaded();
      await _background(bloc, _winter);
      bloc.add(const ThemeCustomColorAdded(custom));
      await pumpEventQueue();
      bloc.add(const ThemeCustomColorRemoved(custom));
      await pumpEventQueue();
      expect(bloc.state.followSeason, isTrue);
      expect(bloc.state.effectiveSeed, _lightBlue);
      await bloc.close();
    });

    test('the choice survives a restart', () async {
      var bloc = await _loaded();
      bloc.add(ThemeSeedColorChanged(AppThemes.predefinedColors[0]));
      await pumpEventQueue();
      final saved = {
        ThemeBloc.keySeedColor: bloc.prefs.getInt(ThemeBloc.keySeedColor)!,
        ThemeBloc.keyAccentSeason: bloc.prefs.getBool(ThemeBloc.keyAccentSeason)!,
        ThemeBloc.keyBgImagePath: _spring,
      };
      await bloc.close();
      bloc = await _loaded(values: saved);
      expect(bloc.state.effectiveSeed, AppThemes.predefinedColors[0]);

      bloc.add(const ThemeSeasonAccentSelected());
      await pumpEventQueue();
      final again = {
        ThemeBloc.keySeedColor: bloc.prefs.getInt(ThemeBloc.keySeedColor)!,
        ThemeBloc.keyAccentSeason: bloc.prefs.getBool(ThemeBloc.keyAccentSeason)!,
        ThemeBloc.keyBgImagePath: _spring,
      };
      await bloc.close();
      bloc = await _loaded(values: again);
      expect(bloc.state.followSeason, isTrue);
      expect(bloc.state.effectiveSeed, _pink);
      await bloc.close();
    });
  });

  group('migration of settings saved before theme-seasons', () {
    test('a saved accent (even the former Blue Grey default) is kept', () async {
      for (final argb in [0xFF607D8B, 0xFFE91E63, 0xFF123456]) {
        final bloc = await _loaded(values: {
          ThemeBloc.keySeedColor: argb,
          ThemeBloc.keyBgImagePath: _summer,
        });
        expect(bloc.state.followSeason, isFalse);
        expect(bloc.state.effectiveSeed, Color(argb));
        await bloc.close();
      }
    });

    test('Material You on is kept', () async {
      const system = Color(0xFF3F51B5);
      final bloc = await _loaded(wallpaper: system, values: {ThemeBloc.keyDynamicColor: true});
      expect(bloc.state.followSeason, isFalse);
      expect(bloc.state.effectiveSeed, system);
      await bloc.close();
    });

    test('never chosen: the saved background gives its season accent', () async {
      final bloc = await _loaded(values: {ThemeBloc.keyBgImagePath: _winter});
      expect(bloc.state.followSeason, isTrue);
      expect(bloc.state.backgroundImagePath, _winter);
      expect(bloc.state.effectiveSeed, _lightBlue);
      await bloc.close();
    });
  });

  group('contrast', () {
    for (final accent in AppThemes.seasonAccents.values) {
      final hex = accent.toARGB32().toRadixString(16);
      test('season accent $hex stays readable in light, dark and black', () {
        for (final (brightness, black) in [
          (Brightness.light, false),
          (Brightness.dark, false),
          (Brightness.dark, true),
        ]) {
          final cs = AppThemes.colorScheme(
            seedColor: accent,
            brightness: brightness,
            isBlack: black,
          );
          final why = '$hex $brightness black=$black';
          expect(contrastRatio(cs.primary, cs.surface), greaterThanOrEqualTo(4.5), reason: why);
          expect(contrastRatio(cs.onPrimary, cs.primary), greaterThanOrEqualTo(4.5), reason: why);
          expect(contrastRatio(cs.onSecondaryContainer, cs.secondaryContainer),
              greaterThanOrEqualTo(4.5),
              reason: why);
          expect(contrastRatio(cs.onSurface, cs.surface), greaterThanOrEqualTo(4.5), reason: why);
          if (black) expect(cs.surface, AppThemes.blackSurface, reason: why);
        }
      });
    }
  });

  group('theme settings', () {
    Future<ThemeBloc> pumpSettings(WidgetTester tester) async {
      final bloc = await tester.runAsync(() => _loaded()) as ThemeBloc;
      await tester.pumpWidget(BlocProvider.value(
        value: bloc,
        child: MaterialApp(theme: bloc.state.lightThemeData, home: const ThemeSettings()),
      ));
      await tester.pump();
      return bloc;
    }

    testWidgets('mode labels are translated and keep their full size', (tester) async {
      LanguageBloc.apply('fr_FR');
      addTearDown(() => LanguageBloc.apply('en'));
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3; // 360 dp wide, a small phone
      addTearDown(tester.view.reset);
      final bloc = await pumpSettings(tester);
      await tester.scrollUntilVisible(find.text('Sombre'), 200,
          scrollable: find.byType(Scrollable).first);

      for (final label in ['Auto', 'Clair', 'Sombre', 'Noir']) {
        final finder = find.text(label);
        expect(finder, findsOneWidget, reason: label);
        expect(find.ancestor(of: finder, matching: find.byType(FittedBox)), findsNothing,
            reason: label);
      }
      final size = (String label) => tester.getSize(find.text(label)).height;
      expect(size('Sombre'), size('Auto'));
      expect(find.text('Light'), findsNothing);
      await tester.runAsync(bloc.close);
    });

    testWidgets('the Auto (season) swatch selects the season accent', (tester) async {
      final bloc = await pumpSettings(tester);
      await tester.tap(find.bySemanticsLabel(S.current.Theme_Color_Brown));
      await tester.pump();
      await tester.runAsync(pumpEventQueue);
      expect(bloc.state.followSeason, isFalse);

      await tester.tap(find.bySemanticsLabel(S.current.Theme_Accent_Season_Label));
      await tester.pump();
      await tester.runAsync(pumpEventQueue);
      expect(bloc.state.followSeason, isTrue);
      await tester.runAsync(bloc.close);
    });
  });
}
