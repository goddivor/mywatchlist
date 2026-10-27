import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mywatchlist/widgets/common/app_colors.dart';

class AppThemes {
  /// The 19 accent presets of the colour grid (seed colours of the whole scheme).
  static const List<Color> predefinedColors = [
    Color(0xFFFF4545), // Red
    Color(0xFFE91E63), // Pink
    Color(0xFF9C27B0), // Purple
    Color(0xFF673AB7), // Deep Purple
    Color(0xFF607D8B), // Blue Grey
    Color(0xFF03A9F4), // Light Blue
    Color(0xFF2196F3), // Blue
    Color(0xFF00BCD4), // Cyan
    Color(0xFF009688), // Teal
    Color(0xFF4CAF50), // Green
    Color(0xFF8BC34A), // Light Green
    Color(0xFFCDDC39), // Lime
    Color(0xFFFFEB3B), // Yellow
    Color(0xFFFFC107), // Amber
    Color(0xFFFF9800), // Orange
    Color(0xFFFF5722), // Deep Orange
    Color(0xFF795548), // Brown
    Color(0xFF9E9E9E), // Grey
    Color(0xFF263238), // Dark
  ];

  /// Available background images
  static const List<String> backgroundImages = [
    'assets/images/fall.jpg',
    'assets/images/summer.jpg',
    'assets/images/spring.jpg',
    'assets/images/winter.jpg',
    'assets/images/anime-collage.jpg',
  ];

  /// Available font families
  static const List<String> availableFonts = [
    'Poppins',
    'Roboto',
    'OpenSans',
    'Montserrat',
    'Nunito',
    'Quicksand',
  ];

  /// Display names for fonts (for UI)
  static const Map<String, String> fontDisplayNames = {
    'Poppins': 'Poppins',
    'Roboto': 'Roboto',
    'OpenSans': 'Open Sans',
    'Montserrat': 'Montserrat',
    'Nunito': 'Nunito',
    'Quicksand': 'Quicksand',
  };

  /// Default seed color
  static const Color defaultSeedColor = Color(0xFF607D8B);

  /// Default font family
  static const String defaultFontFamily = 'Poppins';

  /// Black mode surfaces (DailyAL's black): a near-black page (`#0C0404`), then dark greys
  /// for the elevated levels so cards, sheets and dialogs stay distinguishable from the page.
  static const Color blackSurface = Color(0xFF0C0404);
  static const Color _blackLow = Color(0xFF161212);
  static const Color _blackMid = Color(0xFF1D1919);
  static const Color _blackHigh = Color(0xFF252121);
  static const Color _blackHighest = Color(0xFF2E2A2A);

  /// The colour scheme of one accent, DailyAL's recipe: `ColorScheme.fromSeed` with
  /// Material's default variant (tonalSpot), which gives soft, pastel accents (tone 40 on light
  /// surfaces, tone 80 on dark ones, so accent text keeps 4.5:1) and surfaces tinted by the
  /// accent.
  ///
  /// The tertiary family is the accent's secondary tone (same hue, calmer) instead of
  /// Material's default hue rotation, so no foreign colour (teal on pink…) appears in chips,
  /// FABs or tabs.
  static ColorScheme colorScheme({
    required Color seedColor,
    required Brightness brightness,
    bool isBlack = false,
  }) {
    final base = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
      contrastLevel: AppColors.contrastLevel,
    );
    final scheme = base.copyWith(
      tertiary: base.secondary,
      onTertiary: base.onSecondary,
      tertiaryContainer: base.secondaryContainer,
      onTertiaryContainer: base.onSecondaryContainer,
      tertiaryFixed: base.secondaryFixed,
      tertiaryFixedDim: base.secondaryFixedDim,
      onTertiaryFixed: base.onSecondaryFixed,
      onTertiaryFixedVariant: base.onSecondaryFixedVariant,
    );
    if (!isBlack || brightness != Brightness.dark) return scheme;
    const white = Color(0xFFFFFFFF);
    return scheme.copyWith(
      surface: blackSurface,
      surfaceDim: blackSurface,
      surfaceBright: _blackHighest,
      surfaceContainerLowest: blackSurface,
      surfaceContainerLow: _blackLow,
      surfaceContainer: _blackMid,
      surfaceContainerHigh: _blackHigh,
      surfaceContainerHighest: _blackHighest,
      onSurface: white,
      surfaceTint: Colors.transparent,
    );
  }

  /// Status bar and navigation bar for a theme: transparent, icons dark on light themes and
  /// light on dark ones (Android draws edge to edge from Android 15).
  static SystemUiOverlayStyle systemOverlayStyle(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
      // iOS reads the bar's own brightness (the opposite of the icons').
      statusBarBrightness: dark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: dark ? Brightness.light : Brightness.dark,
      systemNavigationBarContrastEnforced: false,
      systemStatusBarContrastEnforced: false,
    );
  }

  /// Generate a ThemeData from a seed color, font family and brightness
  static ThemeData generateThemeData({
    required Color seedColor,
    required String fontFamily,
    required Brightness brightness,
    bool isBlack = false,
  }) {
    final cs = colorScheme(
      seedColor: seedColor,
      brightness: brightness,
      isBlack: isBlack,
    );
    final tokens = AppColors.fromScheme(cs, black: isBlack && brightness == Brightness.dark);
    final overlay = systemOverlayStyle(brightness);
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      fontFamily: fontFamily,
      brightness: brightness,
    );

    return base.copyWith(
      extensions: <ThemeExtension<dynamic>>[tokens],
      scaffoldBackgroundColor: cs.surface,
      canvasColor: cs.surface,
      cardColor: cs.surfaceContainerLow,
      dividerColor: cs.outlineVariant,
      disabledColor: cs.onSurface.withValues(alpha: 0.38),
      hintColor: cs.onSurfaceVariant,
      shadowColor: cs.shadow,
      textTheme: base.textTheme.apply(bodyColor: cs.onSurface, displayColor: cs.onSurface),
      iconTheme: IconThemeData(color: cs.onSurfaceVariant),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 2,
        centerTitle: true,
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        surfaceTintColor: cs.surfaceTint,
        iconTheme: IconThemeData(color: cs.onSurface),
        actionsIconTheme: IconThemeData(color: cs.onSurfaceVariant),
        // Never derived from the bar colour: a transparent bar over a picture used to give
        // white icons on light themes.
        systemOverlayStyle: overlay,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: cs.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: cs.surfaceContainerLow,
          foregroundColor: cs.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: cs.primary,
          foregroundColor: cs.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: cs.primary,
          side: BorderSide(color: cs.outline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: cs.primary),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: cs.primaryContainer,
        foregroundColor: cs.onPrimaryContainer,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: cs.surfaceContainerLow,
        selectedColor: cs.secondaryContainer,
        disabledColor: cs.onSurface.withValues(alpha: 0.12),
        labelStyle: TextStyle(color: cs.onSurfaceVariant),
        secondaryLabelStyle: TextStyle(color: cs.onSecondaryContainer),
        iconTheme: IconThemeData(color: cs.onSurfaceVariant),
        checkmarkColor: cs.onSecondaryContainer,
        side: BorderSide(color: cs.outlineVariant),
      ),
      badgeTheme: BadgeThemeData(
        backgroundColor: cs.error,
        textColor: cs.onError,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: cs.primary,
        unselectedLabelColor: cs.onSurfaceVariant,
        indicatorColor: cs.primary,
        dividerColor: cs.outlineVariant,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: cs.surfaceContainer,
        indicatorColor: cs.secondaryContainer,
        surfaceTintColor: Colors.transparent,
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
              color: states.contains(WidgetState.selected)
                  ? cs.onSecondaryContainer
                  : cs.onSurfaceVariant,
            )),
        labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
              color: states.contains(WidgetState.selected) ? cs.onSurface : cs.onSurfaceVariant,
            )),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: cs.surfaceContainer,
        selectedItemColor: cs.primary,
        unselectedItemColor: cs.onSurfaceVariant,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: cs.surfaceContainerLow,
        modalBackgroundColor: cs.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        dragHandleColor: cs.onSurfaceVariant.withValues(alpha: 0.4),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: cs.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: base.textTheme.headlineSmall?.copyWith(color: cs.onSurface),
        contentTextStyle: base.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
        iconColor: cs.secondary,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: cs.surfaceContainer,
        surfaceTintColor: Colors.transparent,
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: cs.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: cs.inverseSurface,
        contentTextStyle: TextStyle(color: cs.onInverseSurface),
        actionTextColor: cs.inversePrimary,
        closeIconColor: cs.onInverseSurface,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: cs.onSurfaceVariant,
        textColor: cs.onSurface,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: cs.primary,
        circularTrackColor: cs.surfaceContainerHighest,
        linearTrackColor: cs.surfaceContainerHighest,
        refreshBackgroundColor: cs.surfaceContainerHigh,
      ),
      dividerTheme: DividerThemeData(color: cs.outlineVariant),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: cs.inverseSurface,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: TextStyle(color: cs.onInverseSurface),
      ),
    );
  }
}
