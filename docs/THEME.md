# Theme and colours

Owned by the `theme-colors` unit. Every screen builds on this: **no `Colors.*` and no
`Color(0x…)` in screens**. Use `Theme.of(context).colorScheme` for the accent and surfaces and
`AppColors.of(context)` (lib/widgets/common/app_colors.dart) for meaning.

## Where the theme comes from

- `ThemeBloc` (lib/user/theme/) holds the accent, the mode, the font and the home background.
  `ThemeState.lightThemeData` / `darkThemeData` are built by `AppThemes.generateThemeData`.
- Accent sources: one of the 19 presets (`AppThemes.predefinedColors`), a custom colour from
  the picker (saved in `custom_seed_colors_v1`), or Material You "Auto"
  (`dynamic_color_v1`): the system accent read with `DynamicColorPlugin.getAccentColor()`
  (Android 12+). Without a system accent the Auto swatch is hidden and the chosen accent stays.
- Modes: `auto` (follows the device), `light`, `dark`, `black` (dark with true-black page).

## Colour scheme (`AppThemes.colorScheme`)

- DailyAL's recipe: `ColorScheme.fromSeed(seedColor: accent, brightness: …)` with Material's
  default variant (tonalSpot) at standard contrast (`AppColors.contrastLevel` = 0). Accents are
  soft and pastel (a pink accent gives `#8E4957`, not the vivid `#B80049` of the former
  `fidelity` recipe), tone 40 on light surfaces and tone 80 on dark ones, which keeps accent
  text at 4.5:1 (the test checks it for every preset). Presets, custom colours and Material You
  "Auto" all seed this same builder.
- The tertiary family is the accent's secondary tone (same hue, calmer): Material's default
  hue rotation put teal or orange next to a pink accent.
- Black mode (DailyAL's): `surface` `#0C0404`, `onSurface` white, then the dark greys
  `#161212`, `#1D1919`, `#252121`, `#2E2A2A` for `surfaceContainerLow` …
  `surfaceContainerHighest`, so cards, sheets and dialogs stay distinct from the page.

| Role | Use it for | Foreground |
|---|---|---|
| `primary` | accent text, selected icons, filled buttons, links, progress | `onPrimary` on it |
| `primaryContainer` | FAB, prominent tinted areas, badges (`AppColors.badge`) | `onPrimaryContainer` |
| `secondaryContainer` | selected chips, tonal buttons, navigation-bar indicator | `onSecondaryContainer` |
| `tertiary(Container)` | a second accent level (same hue, calmer) | `onTertiary(Container)` |
| `surface` | page background | `onSurface`, `onSurfaceVariant` |
| `surfaceContainerLow` | cards, bottom sheets, drawer, unselected chips | idem |
| `surfaceContainer` | bottom bar, menus | idem |
| `surfaceContainerHigh` | dialogs, refresh indicator | idem |
| `surfaceContainerHighest` | input fills, shimmer base, progress tracks | idem |
| `outline` / `outlineVariant` | borders / dividers | |
| `inverseSurface` | snackbars, tooltips | `onInverseSurface`, action `inversePrimary` |
| `error(Container)` | destructive actions, failures | `onError(Container)` |

Every Material component theme in `generateThemeData` (app bar, cards, buttons, FAB, chips,
badges, tabs, navigation bars, sheets, dialogs, menus, drawer, snackbars, list tiles, progress,
tooltips) takes its foreground from the matching `on*` role. `theme.cardColor` is
`surfaceContainerLow`, `scaffoldBackgroundColor` is `surface`.

## Status bar and navigation bar

- `appBarTheme.systemOverlayStyle` = `AppThemes.systemOverlayStyle(brightness)`: transparent
  bars, dark icons on light themes, light icons on dark ones. Never derived from the bar colour
  (a transparent bar over a picture used to give white icons on light themes).
- Screens without an app bar: `SystemBars` (lib/user/theme/system_bars.dart) applies the same
  style through `SystemChrome` whenever the theme changes and when the device switches
  light/dark in Auto. The app draws edge to edge (`SystemUiMode.edgeToEdge`) on every Android
  version, as Android 15+ does anyway: use `SafeArea` or the Scaffold insets at the bottom.
- A screen that needs another style (a full-screen dark picture viewer) wraps itself in
  `AnnotatedRegion<SystemUiOverlayStyle>` with `AppThemes.systemOverlayStyle(Brightness.dark)`.

## Semantic tokens (`AppColors`)

`AppColors.of(context)` returns the theme extension (computed from the scheme when a test or a
local `Theme` has none). Each `AppColorRole` has four colours:

- `color`: icons, stars, bars and large text on a surface (≥ 3:1; for small text prefer
  `container` + `onContainer`);
- `onColor`: text on a filled `color` area (≥ 4.5:1);
- `container`: a tinted area (chip, badge, tile);
- `onContainer`: text on `container` (≥ 4.5:1).

The score and feedback hues are fixed and harmonised with the accent
(`Color.harmonizeWith`, at most 15° towards it), then toned by Material's colour utilities for
light or dark.

The list statuses use DailyAL's colours (its `userChartDefaultColors`), the same for every
accent and every tracker: Watching green `#4CAF50`, Completed blue `#2196F3`, On hold orange
`#FF9800`, Dropped red `#F44336`, Plan to watch / read brown `#795548`. Same hues everywhere,
one shade darker or lighter only where a pair would be unreadable:

| Status | Chip `container` (white bold text, every mode) | Light `color` (white `onColor`) | Dark and black `color` (black `onColor`) |
|---|---|---|---|
| `watching` | `#43A047` green 600 (white 3.30:1; green 500 gives 2.78) | `#388E3C` green 700 | `#4CAF50` green 500 |
| `completed` | `#2196F3` blue 500 (3.12:1) | `#1E88E5` blue 600 | `#2196F3` blue 500 |
| `onHold` | `#EF6C00` orange 800 (3.08:1; orange 500 gives 2.16) | `#E65100` orange 900 | `#FF9800` orange 500 |
| `dropped` | `#F44336` red 500 (3.68:1) | `#F44336` red 500 | `#F44336` red 500 |
| `planned` | `#795548` brown 500 (6.55:1) | `#795548` brown 500 | `#A1887F` brown 300 (brown 500 is 2.6:1 on a dark page) |

`color` is the shade that keeps 3:1 on the page and on cards (light `color` is one shade
darker than the chip where the chip shade falls under 3:1 on a light card). Status chip text
must be bold (it is 3:1, the large or bold text level, not 4.5:1).

Values for the default accent (Blue Grey `#607D8B`), `color / onColor / container /
onContainer`:

| Token | Light | Dark |
|---|---|---|
| `score` | `#725C00` / `#FFFFFF` / `#E7BD00` / `#3E3100` | `#FFDA5E` / `#3C2F00` / `#E7BD00` / `#3E3100` |
| `watching` | `#388E3C` / `#FFFFFF` / `#43A047` / `#FFFFFF` | `#4CAF50` / `#000000` / `#43A047` / `#FFFFFF` |
| `completed` | `#1E88E5` / `#FFFFFF` / `#2196F3` / `#FFFFFF` | `#2196F3` / `#000000` / `#2196F3` / `#FFFFFF` |
| `onHold` | `#E65100` / `#FFFFFF` / `#EF6C00` / `#FFFFFF` | `#FF9800` / `#000000` / `#EF6C00` / `#FFFFFF` |
| `dropped` | `#F44336` / `#FFFFFF` / `#F44336` / `#FFFFFF` | `#F44336` / `#000000` / `#F44336` / `#FFFFFF` |
| `planned` | `#795548` / `#FFFFFF` / `#795548` / `#FFFFFF` | `#A1887F` / `#000000` / `#795548` / `#FFFFFF` |
| `success` | `#00623C` / `#FFFFFF` / `#007E4E` / `#FFFFFF` | `#76DAA1` / `#003920` / `#007E4E` / `#FFFFFF` |
| `warning` | `#AE3111` / `#FFFFFF` / `#F66440` / `#000000` | `#FFB4A2` / `#621100` / `#F66440` / `#000000` |
| `danger` | `#BA1A1A` / `#FFFFFF` / `#FFDAD6` / `#410002` | `#FFB4AB` / `#690005` / `#93000A` / `#FFDAD6` |
| `badge` / `onBadge` | `#BDE9FF` / `#001F2A` | `#004D64` / `#BDE9FF` |
| `shimmerBase` / `shimmerHighlight` | `#DFE3E7` / `#F0F4F8` | `#303538` / `#171C1F` |
| `imageScrim` / `onImageScrim` | `#000000` at 60 % / `#FFFFFF` | same |

Stats charts: the default colour of each status slot (`defaultStatusChartColors`,
lib/widgets/charts/chart_palette.dart) is DailyAL's 500 hue above (`AppColors.watchingBase` …
`plannedBase`); the user can override each slot in the settings.

| Token | Meaning |
|---|---|
| `score` | score stars, score chips, score charts |
| `watching` | Watching / Reading (MAL), CURRENT and REPEATING (AniList), current (Kitsu) |
| `completed` | Completed |
| `onHold` | On hold / PAUSED / hold |
| `dropped` | Dropped |
| `planned` | Plan to watch / read, PLANNING, planned, plantowatch |
| `success` | saved, synced, airing now |
| `warning` | not yet aired, rate limit, stale data |
| `danger` | delete, sign out, failure (the scheme's error family) |
| `badge` / `onBadge` | small badges over cards (`primaryContainer` / `onPrimaryContainer`) |
| `imageScrim` / `onImageScrim` | behind any text on a picture: black at 60 %, white text (≥ 4.5:1 even on a white picture); same in every mode; `bottomScrimGradient` for cover titles |
| `shimmerBase` / `shimmerHighlight` | loading placeholders |

Helpers: `AppColors.toneOf(status)` and `statusOf(status)` map any tracker's status string to
its role; `readableOn(color)` gives black or white for a colour that is not a theme role
(a swatch, a user-picked chart colour); `contrastRatio(a, b)` is the WCAG ratio.

### Usage

```dart
final cs = Theme.of(context).colorScheme;
final tokens = AppColors.of(context);
final status = tokens.statusOf(entry.status) ?? tokens.planned;

Container(
  color: status.container,
  child: Text(label, style: TextStyle(color: status.onContainer)),
);
Icon(Icons.star_rounded, color: tokens.score.color);
DecoratedBox(
  decoration: BoxDecoration(gradient: tokens.bottomScrimGradient),
  child: Text(title, style: TextStyle(color: tokens.onImageScrim)),
);
```

Do: filled area + its `on*` role; text on a picture always on `imageScrim`; dark variants come
for free (never test `brightness` to pick a colour). Don't: `Colors.white` text on an accent,
`Colors.grey` chips, `Colors.black54` overlays, a fixed `Colors.amber` star, a light `Card`
colour in dark mode.

## Contrast test

`test/units/theme-colors/contrast_test.dart` checks, for the 19 presets plus white and black
custom accents, in light, dark and black: every `on*` pair ≥ 4.5:1, `onSurface`,
`onSurfaceVariant` and `primary` on every surface level ≥ 4.5:1, `outline`, `error` and the
bottom-bar icons ≥ 3:1, every score and feedback token pair ≥ 4.5:1, every list status pair
(bold chip text) ≥ 3:1, every token `color` on surfaces ≥ 3:1, and white text on the image
scrim over a white picture ≥ 4.5:1. It also pins the recipe (the scheme equals DailyAL's
`fromSeed` default), the black page `#0C0404` with increasing grey levels, DailyAL's status
hues for every tracker's status strings, and the default chart colours.
A new role or token gets a line there.

## Bottom bar

`BottomNavBar` (lib/widgets/common/bottomnavbar.dart): bar `surfaceContainer`, active tab = a
rounded pill (`BottomNavBar.pillColor`: `primary` at 12 % over the bar) with a `primary` icon,
inactive icons `onSurfaceVariant`.
There is no underline bar under the active icon (owner's request).

## Background images

- Home background: `ThemeBloc` (`bg_image_path`, `custom_bg_image_path`, `show_bg`).
  `Background` (lib/widgets/common/background.dart) shows the picture when `show_bg` is on, or
  always with `forceBg` (pictures that are the page's content) or a local file, and decodes it
  at the painted size (`AppImage` / `SizedDecodeImage`).
- Sidebar picture: `SidebarBackgroundManager`, its own key `sidebar_bg_image_path_v1` (both
  used to share `bg_image_path`; the legacy sidebar file is adopted once). The legacy
  `UserMal.pref.bgImagePath` (lib/user/userpref.dart) is no longer written; the file stays only
  while `lib/user/user.dart` declares `UserMal.pref`.
