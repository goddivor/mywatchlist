import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/user/theme/app_themes.dart';
import 'package:mywatchlist/widgets/common/app_colors.dart';
import 'package:mywatchlist/widgets/common/bottomnavbar.dart';

/// WCAG AA over every accent preset × light / dark / black: 4.5:1 for text pairs,
/// 3:1 for icons, large text and accent marks.
void main() {
  const text = 4.5;
  const icon = 3.0;

  final modes = <String, (Brightness, bool)>{
    'light': (Brightness.light, false),
    'dark': (Brightness.dark, false),
    'black': (Brightness.dark, true),
  };

  // The presets plus the two extremes a custom picker can give.
  final seeds = [...AppThemes.predefinedColors, const Color(0xFFFFFFFF), const Color(0xFF000000)];

  for (final seed in seeds) {
    for (final mode in modes.entries) {
      final hex = seed.toARGB32().toRadixString(16);
      test('accent #$hex in ${mode.key} mode is readable', () {
        final theme = AppThemes.generateThemeData(
          seedColor: seed,
          fontFamily: AppThemes.defaultFontFamily,
          brightness: mode.value.$1,
          isBlack: mode.value.$2,
        );
        final cs = theme.colorScheme;
        final t = theme.extension<AppColors>()!;
        final failures = <String>[];
        void check(String name, Color fg, Color bg, double min) {
          final ratio = contrastRatio(fg, bg);
          if (ratio < min) failures.add('$name ${ratio.toStringAsFixed(2)} < $min');
        }

        final surfaces = {
          'surface': cs.surface,
          'surfaceContainerLowest': cs.surfaceContainerLowest,
          'surfaceContainerLow': cs.surfaceContainerLow,
          'surfaceContainer': cs.surfaceContainer,
          'surfaceContainerHigh': cs.surfaceContainerHigh,
          'surfaceContainerHighest': cs.surfaceContainerHighest,
        };

        // Filled areas and their foregrounds (buttons, chips, FABs, badges, snackbars).
        check('onPrimary/primary', cs.onPrimary, cs.primary, text);
        check('onPrimaryContainer/primaryContainer', cs.onPrimaryContainer, cs.primaryContainer, text);
        check('onSecondary/secondary', cs.onSecondary, cs.secondary, text);
        check('onSecondaryContainer/secondaryContainer', cs.onSecondaryContainer,
            cs.secondaryContainer, text);
        check('onTertiary/tertiary', cs.onTertiary, cs.tertiary, text);
        check('onTertiaryContainer/tertiaryContainer', cs.onTertiaryContainer,
            cs.tertiaryContainer, text);
        check('onError/error', cs.onError, cs.error, text);
        check('onErrorContainer/errorContainer', cs.onErrorContainer, cs.errorContainer, text);
        check('onInverseSurface/inverseSurface', cs.onInverseSurface, cs.inverseSurface, text);
        check('inversePrimary/inverseSurface', cs.inversePrimary, cs.inverseSurface, text);

        // Text on every surface level (cards, sheets, dialogs, menus, bottom bar).
        for (final s in surfaces.entries) {
          check('onSurface/${s.key}', cs.onSurface, s.value, text);
          check('onSurfaceVariant/${s.key}', cs.onSurfaceVariant, s.value, text);
          // Text buttons, tabs, links: accent text on surfaces.
          check('primary/${s.key}', cs.primary, s.value, text);
          check('error/${s.key}', cs.error, s.value, icon);
          check('outline/${s.key}', cs.outline, s.value, icon);
        }

        // Bottom bar: accent icon in its pill, inactive icons on the bar.
        check('primary/nav pill', cs.primary, BottomNavBar.pillColor(cs), icon);
        check('onSurfaceVariant/surfaceContainer (nav)', cs.onSurfaceVariant,
            cs.surfaceContainer, icon);

        // Semantic tokens.
        final roles = {
          'score': t.score,
          'watching': t.watching,
          'completed': t.completed,
          'onHold': t.onHold,
          'dropped': t.dropped,
          'planned': t.planned,
          'success': t.success,
          'warning': t.warning,
          'danger': t.danger,
        };
        for (final r in roles.entries) {
          check('${r.key}.onColor/color', r.value.onColor, r.value.color, text);
          check('${r.key}.onContainer/container', r.value.onContainer, r.value.container, text);
          check('${r.key}.color/surface', r.value.color, cs.surface, icon);
          check('${r.key}.color/surfaceContainerLow', r.value.color, cs.surfaceContainerLow, icon);
        }
        check('onBadge/badge', t.onBadge, t.badge, text);

        expect(failures, isEmpty, reason: failures.join('\n'));
      });
    }
  }

  test('text on the image scrim stays readable on a white or a black picture', () {
    final t = AppColors.fromScheme(ColorScheme.fromSeed(seedColor: AppThemes.defaultSeedColor));
    for (final picture in const [Color(0xFFFFFFFF), Color(0xFF000000), Color(0xFFFFEB3B)]) {
      final composite = Color.alphaBlend(t.imageScrim, picture);
      expect(contrastRatio(t.onImageScrim, composite), greaterThanOrEqualTo(text));
    }
  });

  test('black mode uses true black pages and distinct elevated surfaces', () {
    final cs = AppThemes.colorScheme(
      seedColor: AppThemes.predefinedColors[1],
      brightness: Brightness.dark,
      isBlack: true,
    );
    expect(cs.surface, const Color(0xFF000000));
    final levels = [
      cs.surface,
      cs.surfaceContainerLow,
      cs.surfaceContainer,
      cs.surfaceContainerHigh,
      cs.surfaceContainerHighest,
    ];
    for (var i = 1; i < levels.length; i++) {
      expect(levels[i].computeLuminance(), greaterThan(levels[i - 1].computeLuminance()));
    }
  });

  test('dark mode has dark surfaces (no light card or sheet left)', () {
    for (final seed in AppThemes.predefinedColors) {
      final cs = AppThemes.colorScheme(seedColor: seed, brightness: Brightness.dark);
      for (final s in [cs.surface, cs.surfaceContainerLow, cs.surfaceContainerHigh,
        cs.surfaceContainerHighest]) {
        expect(s.computeLuminance(), lessThan(0.08));
      }
    }
  });
}
