import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';

/// One semantic colour with its readable foregrounds, like a [ColorScheme] family.
///
/// - [color]: text, icons or thin marks drawn on a surface (AA 4.5:1 on `surface`).
/// - [onColor]: text or icons drawn on a filled [color] area.
/// - [container]: a tinted area (chip, badge, tile background).
/// - [onContainer]: text or icons drawn on [container].
@immutable
class AppColorRole {
  const AppColorRole({
    required this.color,
    required this.onColor,
    required this.container,
    required this.onContainer,
  });

  final Color color;
  final Color onColor;
  final Color container;
  final Color onContainer;

  /// Builds the four tones of [base] for [brightness] with Material's colour utilities, so the
  /// pairs keep their contrast whatever the hue (a yellow gets a dark foreground, a blue a light
  /// one). `fidelity` keeps the hue recognisable: green stays green, red stays red.
  factory AppColorRole.fromBase(
    Color base, {
    required Brightness brightness,
    double contrastLevel = AppColors.contrastLevel,
  }) {
    final scheme = ColorScheme.fromSeed(
      seedColor: base,
      brightness: brightness,
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
      contrastLevel: contrastLevel,
    );
    return AppColorRole(
      color: scheme.primary,
      onColor: scheme.onPrimary,
      container: scheme.primaryContainer,
      onContainer: scheme.onPrimaryContainer,
    );
  }

  static AppColorRole lerp(AppColorRole a, AppColorRole b, double t) => AppColorRole(
        color: Color.lerp(a.color, b.color, t)!,
        onColor: Color.lerp(a.onColor, b.onColor, t)!,
        container: Color.lerp(a.container, b.container, t)!,
        onContainer: Color.lerp(a.onContainer, b.onContainer, t)!,
      );

  @override
  bool operator ==(Object other) =>
      other is AppColorRole &&
      other.color == color &&
      other.onColor == onColor &&
      other.container == container &&
      other.onContainer == onContainer;

  @override
  int get hashCode => Object.hash(color, onColor, container, onContainer);
}

/// List statuses shared by every tracker (MAL names; AniList, Kitsu and Simkl map onto them).
enum ListStatusTone { watching, completed, onHold, dropped, planned }

/// Semantic colour tokens of MyWatchList, as a [ThemeExtension] of every app theme.
///
/// Screens never hardcode `Colors.*` or `Color(0x…)`: they use `Theme.of(context).colorScheme`
/// for the accent and surfaces, and these tokens for meaning (score, list status, success,
/// warning, danger, text on images, badges, shimmer). Every token is derived from a fixed hue
/// harmonised with the theme accent (so it belongs to the theme's colour family) and has light
/// and dark values with AA contrast. Table and usage: docs/THEME.md.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.score,
    required this.watching,
    required this.completed,
    required this.onHold,
    required this.dropped,
    required this.planned,
    required this.success,
    required this.warning,
    required this.danger,
    required this.badge,
    required this.onBadge,
    required this.imageScrim,
    required this.onImageScrim,
    required this.shimmerBase,
    required this.shimmerHighlight,
  });

  /// Contrast level given to Material's colour utilities for the app theme and the tokens
  /// (0 = Material's standard: tone 40 accents on light surfaces, tone 80 on dark ones, which
  /// keeps accent text at 4.5:1; "medium" 0.5 turned a pink accent into maroon).
  static const double contrastLevel = 0.0;

  /// Base hues, before harmonisation with the accent.
  static const Color scoreBase = Color(0xFFFFB300);
  static const Color watchingBase = Color(0xFF2E7D32);
  static const Color completedBase = Color(0xFF1565C0);
  static const Color onHoldBase = Color(0xFFF9A825);
  static const Color droppedBase = Color(0xFFC62828);
  static const Color plannedBase = Color(0xFF78909C);
  static const Color successBase = Color(0xFF2E7D32);
  static const Color warningBase = Color(0xFFEF6C00);

  /// Opacity of [imageScrim]: with it, [onImageScrim] stays above 4.5:1 even on a white picture.
  static const double imageScrimOpacity = 0.6;

  /// Score stars, score chips and score charts.
  final AppColorRole score;

  /// List statuses (badges, chips, progress bars, chart slices).
  final AppColorRole watching;
  final AppColorRole completed;
  final AppColorRole onHold;
  final AppColorRole dropped;
  final AppColorRole planned;

  /// Feedback: saved, synced, airing (success); not yet aired, rate limit (warning);
  /// delete, sign out, failure (danger, the scheme's error family).
  final AppColorRole success;
  final AppColorRole warning;
  final AppColorRole danger;

  /// Small badges over cards and covers (episode count, rank, "new").
  final Color badge;
  final Color onBadge;

  /// Scrim behind any text or icon drawn on a picture (cover titles, banners), and the
  /// foreground to use on it. Same value in light and dark: pictures do not follow the theme.
  final Color imageScrim;
  final Color onImageScrim;

  /// Loading placeholders.
  final Color shimmerBase;
  final Color shimmerHighlight;

  /// Tokens for [scheme] (the app theme's scheme; [black] for the true-black mode).
  factory AppColors.fromScheme(ColorScheme scheme, {bool black = false}) {
    final brightness = scheme.brightness;
    AppColorRole role(Color base) => AppColorRole.fromBase(
          base.harmonizeWith(scheme.primary),
          brightness: brightness,
        );
    return AppColors(
      score: role(scoreBase),
      watching: role(watchingBase),
      completed: role(completedBase),
      onHold: role(onHoldBase),
      dropped: role(droppedBase),
      planned: role(plannedBase),
      success: role(successBase),
      warning: role(warningBase),
      danger: AppColorRole(
        color: scheme.error,
        onColor: scheme.onError,
        container: scheme.errorContainer,
        onContainer: scheme.onErrorContainer,
      ),
      badge: scheme.primaryContainer,
      onBadge: scheme.onPrimaryContainer,
      imageScrim: const Color(0xFF000000).withValues(alpha: imageScrimOpacity),
      onImageScrim: const Color(0xFFFFFFFF),
      shimmerBase: black ? scheme.surfaceContainer : scheme.surfaceContainerHighest,
      shimmerHighlight: black ? scheme.surfaceContainerHighest : scheme.surfaceContainerLow,
    );
  }

  static final Expando<AppColors> _fallbacks = Expando<AppColors>();

  /// The tokens of the nearest theme. A theme built outside `AppThemes` (tests, a local
  /// `Theme`) gets tokens computed from its colour scheme, cached per scheme.
  static AppColors of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<AppColors>() ??
        (_fallbacks[theme.colorScheme] ??= AppColors.fromScheme(theme.colorScheme));
  }

  /// The role of a list status.
  AppColorRole status(ListStatusTone tone) => switch (tone) {
        ListStatusTone.watching => watching,
        ListStatusTone.completed => completed,
        ListStatusTone.onHold => onHold,
        ListStatusTone.dropped => dropped,
        ListStatusTone.planned => planned,
      };

  /// The role of a tracker status string (MAL `watching`/`reading`, `on_hold`,
  /// `plan_to_watch`…; AniList `CURRENT`, `PAUSED`, `PLANNING`…; Kitsu `current`, `planned`…;
  /// Simkl `plantowatch`, `hold`…). Null when unknown.
  AppColorRole? statusOf(String? status) {
    final tone = toneOf(status);
    return tone == null ? null : this.status(tone);
  }

  /// Maps a tracker status string to its [ListStatusTone].
  static ListStatusTone? toneOf(String? status) {
    final s = status?.toLowerCase().replaceAll(RegExp(r'[\s_-]'), '');
    return switch (s) {
      'watching' || 'reading' || 'current' || 'repeating' || 'rewatching' =>
        ListStatusTone.watching,
      'completed' => ListStatusTone.completed,
      'onhold' || 'paused' || 'hold' => ListStatusTone.onHold,
      'dropped' => ListStatusTone.dropped,
      'plantowatch' || 'plantoread' || 'planning' || 'planned' => ListStatusTone.planned,
      _ => null,
    };
  }

  /// A top-to-bottom scrim for text at the bottom of a picture.
  LinearGradient get bottomScrimGradient => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [imageScrim.withValues(alpha: 0), imageScrim],
      );

  @override
  AppColors copyWith({
    AppColorRole? score,
    AppColorRole? watching,
    AppColorRole? completed,
    AppColorRole? onHold,
    AppColorRole? dropped,
    AppColorRole? planned,
    AppColorRole? success,
    AppColorRole? warning,
    AppColorRole? danger,
    Color? badge,
    Color? onBadge,
    Color? imageScrim,
    Color? onImageScrim,
    Color? shimmerBase,
    Color? shimmerHighlight,
  }) {
    return AppColors(
      score: score ?? this.score,
      watching: watching ?? this.watching,
      completed: completed ?? this.completed,
      onHold: onHold ?? this.onHold,
      dropped: dropped ?? this.dropped,
      planned: planned ?? this.planned,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      badge: badge ?? this.badge,
      onBadge: onBadge ?? this.onBadge,
      imageScrim: imageScrim ?? this.imageScrim,
      onImageScrim: onImageScrim ?? this.onImageScrim,
      shimmerBase: shimmerBase ?? this.shimmerBase,
      shimmerHighlight: shimmerHighlight ?? this.shimmerHighlight,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      score: AppColorRole.lerp(score, other.score, t),
      watching: AppColorRole.lerp(watching, other.watching, t),
      completed: AppColorRole.lerp(completed, other.completed, t),
      onHold: AppColorRole.lerp(onHold, other.onHold, t),
      dropped: AppColorRole.lerp(dropped, other.dropped, t),
      planned: AppColorRole.lerp(planned, other.planned, t),
      success: AppColorRole.lerp(success, other.success, t),
      warning: AppColorRole.lerp(warning, other.warning, t),
      danger: AppColorRole.lerp(danger, other.danger, t),
      badge: Color.lerp(badge, other.badge, t)!,
      onBadge: Color.lerp(onBadge, other.onBadge, t)!,
      imageScrim: Color.lerp(imageScrim, other.imageScrim, t)!,
      onImageScrim: Color.lerp(onImageScrim, other.onImageScrim, t)!,
      shimmerBase: Color.lerp(shimmerBase, other.shimmerBase, t)!,
      shimmerHighlight: Color.lerp(shimmerHighlight, other.shimmerHighlight, t)!,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AppColors &&
      other.score == score &&
      other.watching == watching &&
      other.completed == completed &&
      other.onHold == onHold &&
      other.dropped == dropped &&
      other.planned == planned &&
      other.success == success &&
      other.warning == warning &&
      other.danger == danger &&
      other.badge == badge &&
      other.onBadge == onBadge &&
      other.imageScrim == imageScrim &&
      other.onImageScrim == onImageScrim &&
      other.shimmerBase == shimmerBase &&
      other.shimmerHighlight == shimmerHighlight;

  @override
  int get hashCode => Object.hash(score, watching, completed, onHold, dropped, planned, success,
      warning, danger, badge, onBadge, imageScrim, onImageScrim, shimmerBase, shimmerHighlight);
}

/// Black or white, whichever reads best on [background] (for colours that are not theme
/// roles, e.g. a colour swatch or a user-picked chart colour).
Color readableOn(Color background) {
  const white = Color(0xFFFFFFFF);
  const black = Color(0xFF000000);
  return contrastRatio(background, white) >= contrastRatio(background, black) ? white : black;
}

/// WCAG 2.x contrast ratio of two opaque colours (1 to 21).
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}
