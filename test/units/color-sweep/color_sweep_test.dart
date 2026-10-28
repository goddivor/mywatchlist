import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/user/theme/app_themes.dart';
import 'package:mywatchlist/widgets/MAL/home/animegridcard.dart' show NodeStatusValue;
import 'package:mywatchlist/widgets/common/app_colors.dart';
import 'package:mywatchlist/widgets/loading/shimmercolor.dart' show ShimmerColors;
import 'package:mywatchlist/widgets/user/edit/edit_labels.dart';

/// Colour sweep: the edit sheet, the sync widget and the home cards read the
/// list status tokens (DailyAL's hues), and every badge over a cover stays
/// readable in light, dark and black.
void main() {
  // NodeStatusValue reads the translated status labels.
  setUpAll(() => S.load(const Locale('en')));

  final modes = <String, (Brightness, bool)>{
    'light': (Brightness.light, false),
    'dark': (Brightness.dark, false),
    'black': (Brightness.dark, true),
  };

  ThemeData themeFor((Brightness, bool) mode) => AppThemes.generateThemeData(
        seedColor: AppThemes.defaultSeedColor,
        fontFamily: AppThemes.defaultFontFamily,
        brightness: mode.$1,
        isBlack: mode.$2,
      );

  Future<BuildContext> contextIn(WidgetTester tester, ThemeData theme) async {
    late BuildContext captured;
    await tester.pumpWidget(MaterialApp(
      theme: theme,
      home: Builder(builder: (context) {
        captured = context;
        return const SizedBox.shrink();
      }),
    ));
    return captured;
  }

  for (final mode in modes.entries) {
    testWidgets('edit sheet status dot uses the status tokens (${mode.key})', (tester) async {
      final theme = themeFor(mode.value);
      final context = await contextIn(tester, theme);
      final t = theme.extension<AppColors>()!;
      expect(statusColor(context, 'watching'), t.watching.color);
      expect(statusColor(context, 'reading'), t.watching.color);
      expect(statusColor(context, 'completed'), t.completed.color);
      expect(statusColor(context, 'on_hold'), t.onHold.color);
      expect(statusColor(context, 'dropped'), t.dropped.color);
      // Plan to watch is DailyAL's brown, never the old orange.
      expect(statusColor(context, 'plan_to_watch'), t.planned.color);
      expect(statusColor(context, 'plan_to_read'), t.planned.color);
      expect(statusColor(context, null), theme.colorScheme.outline);
    });

    testWidgets('home card status button reads the status chip tokens (${mode.key})',
        (tester) async {
      final theme = themeFor(mode.value);
      final context = await contextIn(tester, theme);
      final t = theme.extension<AppColors>()!;
      final cases = {
        'watching': t.watching,
        'completed': t.completed,
        'on_hold': t.onHold,
        'dropped': t.dropped,
        'plan_to_watch': t.planned,
        'plan_to_read': t.planned,
      };
      for (final entry in cases.entries) {
        final nsv = NodeStatusValue.fromString(entry.key);
        final role = nsv.role(context)!;
        expect(role.container, entry.value.container, reason: entry.key);
        // Bold chip text: 3:1 (large or bold text level), white in every mode.
        expect(contrastRatio(role.onContainer, role.container), greaterThanOrEqualTo(3.0),
            reason: entry.key);
        expect(nsv.color, AppColors.statusChips[AppColors.toneOf(entry.key)]);
      }
      expect(NodeStatusValue.fromString('unknown').role(context), isNull);
    });

    test('My List episode badges are solid blue / red with white text (${mode.key})', () {
      final t = themeFor(mode.value).extension<AppColors>()!;
      // Same in every mode: DailyAL's blue 500 and red 500 with white text.
      expect(t.completed.container, const Color(0xFF2196F3));
      expect(t.dropped.container, const Color(0xFFF44336));
      expect(t.completed.onContainer, const Color(0xFFFFFFFF));
      expect(t.dropped.onContainer, const Color(0xFFFFFFFF));
      expect(contrastRatio(t.completed.onContainer, t.completed.container),
          greaterThanOrEqualTo(3.0));
      expect(contrastRatio(t.dropped.onContainer, t.dropped.container),
          greaterThanOrEqualTo(3.0));
    });

    test('badges and titles over covers stay readable on a white picture (${mode.key})', () {
      final t = themeFor(mode.value).extension<AppColors>()!;
      final overWhite = Color.alphaBlend(t.imageScrim, const Color(0xFFFFFFFF));
      expect(contrastRatio(t.onImageScrim, overWhite), greaterThanOrEqualTo(4.5));
    });

    testWidgets('shimmer placeholders follow the theme (${mode.key})', (tester) async {
      final theme = themeFor(mode.value);
      final t = theme.extension<AppColors>()!;
      final context = await contextIn(tester, theme);
      final shimmer = ShimmerColors.fromContext(context);
      expect(shimmer.baseColor, t.shimmerBase);
      expect(shimmer.highlightColor, t.shimmerHighlight);
      if (mode.value.$1 == Brightness.dark) {
        // No light grey box left in dark or black mode.
        expect(t.shimmerBase.computeLuminance(), lessThan(0.2));
      } else {
        expect(t.shimmerBase.computeLuminance(), greaterThan(0.5));
      }
    });
  }
}
