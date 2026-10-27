import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/user/theme/app_themes.dart';
import 'package:mywatchlist/user/theme/system_bars.dart';
import 'package:mywatchlist/user/theme/theme_bloc.dart';
import 'package:mywatchlist/user/theme/theme_event.dart';
import 'package:mywatchlist/user/theme/theme_state.dart';
import 'package:mywatchlist/widgets/common/app_colors.dart';
import 'package:shared_preferences/shared_preferences.dart';

double _hue(Color c) => HSVColor.fromColor(c).hue;

double _hueDistance(double a, double b) {
  final d = (a - b).abs() % 360;
  return d > 180 ? 360 - d : d;
}

void main() {
  group('system bars', () {
    test('light themes get dark icons, dark themes light icons, bars transparent', () {
      final light = AppThemes.systemOverlayStyle(Brightness.light);
      expect(light.statusBarIconBrightness, Brightness.dark);
      expect(light.systemNavigationBarIconBrightness, Brightness.dark);
      expect(light.statusBarColor, Colors.transparent);
      expect(light.systemNavigationBarColor, Colors.transparent);

      final dark = AppThemes.systemOverlayStyle(Brightness.dark);
      expect(dark.statusBarIconBrightness, Brightness.light);
      expect(dark.systemNavigationBarIconBrightness, Brightness.light);
    });

    test('every app bar uses the theme style, never one derived from its colour', () {
      for (final b in Brightness.values) {
        final theme = AppThemes.generateThemeData(
          seedColor: AppThemes.predefinedColors[1],
          fontFamily: AppThemes.defaultFontFamily,
          brightness: b,
        );
        expect(theme.appBarTheme.systemOverlayStyle, AppThemes.systemOverlayStyle(b));
      }
    });

    test('the style follows the mode, and the device in auto', () {
      ThemeState stateFor(String mode) => ThemeState.fromPreferences(
            seedColor: AppThemes.defaultSeedColor,
            fontFamily: AppThemes.defaultFontFamily,
            themeModeName: mode,
          );
      Brightness icons(String mode, Brightness device) =>
          SystemBars.styleFor(stateFor(mode), device).statusBarIconBrightness!;

      expect(icons('light', Brightness.dark), Brightness.dark);
      expect(icons('dark', Brightness.light), Brightness.light);
      expect(icons('black', Brightness.light), Brightness.light);
      expect(icons('auto', Brightness.light), Brightness.dark);
      expect(icons('auto', Brightness.dark), Brightness.light);
    });

    testWidgets('a transparent app bar over a picture keeps dark icons on a light theme',
        (tester) async {
      final theme = AppThemes.generateThemeData(
        seedColor: AppThemes.predefinedColors[1],
        fontFamily: AppThemes.defaultFontFamily,
        brightness: Brightness.light,
      );
      await tester.pumpWidget(MaterialApp(
        theme: theme,
        home: Scaffold(appBar: AppBar(backgroundColor: Colors.transparent)),
      ));
      final region = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
        ),
      );
      expect(region.value.statusBarIconBrightness, Brightness.dark);
    });
  });

  group('colour scheme', () {
    test('built from the accent: primary, secondary and tertiary share its hue family', () {
      for (final seed in AppThemes.predefinedColors) {
        if (HSVColor.fromColor(seed).saturation < 0.3) continue; // greys have no hue
        final cs = AppThemes.colorScheme(seedColor: seed, brightness: Brightness.light);
        for (final role in [cs.primary, cs.secondary, cs.tertiary, cs.primaryContainer,
          cs.tertiaryContainer]) {
          expect(_hueDistance(_hue(role), _hue(seed)), lessThan(40),
              reason: 'seed ${seed.toARGB32().toRadixString(16)}');
        }
      }
    });

    test('the theme carries the semantic tokens', () {
      final theme = AppThemes.generateThemeData(
        seedColor: AppThemes.defaultSeedColor,
        fontFamily: AppThemes.defaultFontFamily,
        brightness: Brightness.light,
      );
      expect(theme.extension<AppColors>(), isNotNull);
      expect(theme.cardColor, theme.colorScheme.surfaceContainerLow);
    });
  });

  group('tokens', () {
    testWidgets('resolve in light and dark, with different values', (tester) async {
      final found = <Brightness, AppColors>{};
      for (final b in Brightness.values) {
        await tester.pumpWidget(MaterialApp(
          theme: AppThemes.generateThemeData(
            seedColor: AppThemes.predefinedColors[1],
            fontFamily: AppThemes.defaultFontFamily,
            brightness: b,
          ),
          home: Builder(builder: (context) {
            found[b] = AppColors.of(context);
            return const SizedBox();
          }),
        ));
        await tester.pumpAndSettle();
      }
      expect(found[Brightness.light]!.watching.color,
          isNot(found[Brightness.dark]!.watching.color));
      expect(found[Brightness.light]!.score.color.computeLuminance(),
          lessThan(found[Brightness.dark]!.score.color.computeLuminance()));
    });

    testWidgets('a theme without the extension still gets tokens', (tester) async {
      AppColors? tokens;
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.pink)),
        home: Builder(builder: (context) {
          tokens = AppColors.of(context);
          return const SizedBox();
        }),
      ));
      expect(tokens, isNotNull);
    });

    test('tracker status strings map to their tone', () {
      expect(AppColors.toneOf('watching'), ListStatusTone.watching);
      expect(AppColors.toneOf('reading'), ListStatusTone.watching);
      expect(AppColors.toneOf('CURRENT'), ListStatusTone.watching);
      expect(AppColors.toneOf('on_hold'), ListStatusTone.onHold);
      expect(AppColors.toneOf('PAUSED'), ListStatusTone.onHold);
      expect(AppColors.toneOf('plan_to_watch'), ListStatusTone.planned);
      expect(AppColors.toneOf('PLANNING'), ListStatusTone.planned);
      expect(AppColors.toneOf('plantowatch'), ListStatusTone.planned);
      expect(AppColors.toneOf('completed'), ListStatusTone.completed);
      expect(AppColors.toneOf('dropped'), ListStatusTone.dropped);
      expect(AppColors.toneOf('nope'), isNull);
    });

    test('readableOn picks the readable foreground of any swatch', () {
      for (final c in AppThemes.predefinedColors) {
        expect(contrastRatio(readableOn(c), c), greaterThanOrEqualTo(3.0));
      }
    });
  });

  group('ThemeBloc', () {
    Future<ThemeBloc> loaded({Color? accent, Map<String, Object> values = const {}}) async {
      SharedPreferences.setMockInitialValues(values);
      final prefs = await SharedPreferences.getInstance();
      final bloc = ThemeBloc(
        prefs: prefs,
        readDynamicAccent: () async => accent,
        syncSystemBars: false,
      );
      bloc.add(ThemeLoadStarted());
      await pumpEventQueue();
      return bloc;
    }

    test('Material You: the accent follows the system colour when turned on', () async {
      const system = Color(0xFF3F51B5);
      final bloc = await loaded(accent: system);
      expect(bloc.state.dynamicColorAvailable, isTrue);
      expect(bloc.state.effectiveSeed, AppThemes.defaultSeedColor);

      bloc.add(const ThemeDynamicColorChanged(true));
      await pumpEventQueue();
      expect(bloc.state.effectiveSeed, system);
      expect(bloc.prefs.getBool(ThemeBloc.keyDynamicColor), isTrue);

      bloc.add(ThemeSeedColorChanged(AppThemes.predefinedColors[1]));
      await pumpEventQueue();
      expect(bloc.state.useDynamicColor, isFalse);
      expect(bloc.state.effectiveSeed, AppThemes.predefinedColors[1]);
      await bloc.close();
    });

    test('without a system accent, Auto keeps the chosen accent', () async {
      final bloc = await loaded(values: {ThemeBloc.keyDynamicColor: true});
      expect(bloc.state.dynamicColorAvailable, isFalse);
      expect(bloc.state.effectiveSeed, AppThemes.defaultSeedColor);
      await bloc.close();
    });

    test('custom colours are saved, selected, restored and removed', () async {
      const custom = Color(0xFF123456);
      var bloc = await loaded();
      bloc.add(const ThemeCustomColorAdded(custom));
      await pumpEventQueue();
      expect(bloc.state.customColors, [custom]);
      expect(bloc.state.seedColor, custom);
      final saved = {
        ThemeBloc.keyCustomColors: bloc.prefs.getStringList(ThemeBloc.keyCustomColors)!,
        ThemeBloc.keySeedColor: bloc.prefs.getInt(ThemeBloc.keySeedColor)!,
      };
      await bloc.close();

      bloc = await loaded(values: saved);
      expect(bloc.state.customColors, [custom]);
      expect(bloc.state.seedColor, custom);

      bloc.add(const ThemeCustomColorRemoved(custom));
      await pumpEventQueue();
      expect(bloc.state.customColors, isEmpty);
      expect(bloc.state.seedColor, AppThemes.defaultSeedColor);
      await bloc.close();
    });

    test('a background change does not rebuild the theme data', () async {
      final bloc = await loaded();
      final light = bloc.state.lightThemeData;
      bloc.add(const ThemeBackgroundChanged(
        backgroundImagePath: 'assets/images/spring.jpg',
        showBackground: true,
      ));
      await pumpEventQueue();
      expect(bloc.state.backgroundImagePath, 'assets/images/spring.jpg');
      expect(identical(bloc.state.lightThemeData, light), isTrue);
      await bloc.close();
    });

    test('black mode builds DailyAL\'s near-black dark theme', () async {
      final bloc = await loaded(values: {ThemeBloc.keyThemeModeName: 'black'});
      expect(bloc.state.themeMode, ThemeMode.dark);
      expect(bloc.state.darkThemeData.colorScheme.surface, const Color(0xFF0C0404));
      expect(bloc.state.darkThemeData.scaffoldBackgroundColor, const Color(0xFF0C0404));
      await bloc.close();
    });
  });
}
