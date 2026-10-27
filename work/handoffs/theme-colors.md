# Handoff — `theme-colors`: Theme colours: status bar, coherent accents per theme, colour tokens, contrast

**Kind** foundation · **Priority** P0 · **Group** settings · **Model** opus

## Needs done first
- `perf-foundation` (Fluidity foundation: 120 Hz, image decoding, shimmers, root rebuilds)
- `deps-prefs-contract` (Dependencies, Android permissions and the preferences contract)

## Owns (may create or edit ONLY these)
- `lib/widgets/common/bottomnavbar.dart`
- `lib/widgets/common/nav_indicator.dart`
- `test/smoke/nav_indicator_test.dart`
- `lib/user/theme/**`
- `lib/screens/settings/theme_settings.dart`
- `lib/widgets/common/app_colors.dart`
- `lib/widgets/common/background.dart`
- `lib/utils/sidebar_bg_manager.dart`
- `lib/user/userpref.dart`
- `docs/THEME.md`
- `lib/l10n/units/theme-colors/**`
- `test/units/theme-colors/**`

Plus `PROJECT-STATE.md` (rewrite in place, within its cap) and `docs/DECISIONS.md` (append one line per decision). Anything else you need is a FINDING to report, never an edit.

## Goal
- The owner reports colour bugs. Seen on the emulator (Spring theme, light): the status bar clock and icons are WHITE on a near-white pink background (unreadable) — no `systemOverlayStyle` exists anywhere in lib/; the selected tab is dark teal, the card edit button orange, the score star green and the chips grey on a pink theme: the palette is not coherent; many colours are hardcoded (`Colors.*` / `Color(0x…)` in ~25 files: animegridcard, constants, scorestatisticswidget, reviews, featured, entry cards, charts, side_bar…).
- Fix the theme at the source: `appBarTheme.systemOverlayStyle` (and the navigation bar) per brightness for every theme mode (light, dark, black, Auto) and every seasonal theme, with a transparent status bar and readable icons; one coherent accent per theme driving `ColorScheme` (primary, secondary, tertiary, containers, surfaces, outline) so chips, tabs, FABs, badges, switches and the bottom bar all use it; correct contrast in dark and black (WCAG AA for text).
- Add semantic colour tokens as a `ThemeExtension` in lib/widgets/common/app_colors.dart (e.g. score, status per list status — watching/completed/on hold/dropped/plan —, success/warning/danger, overlay scrims for text on images, badge background/foreground) with light/dark values, so screens never hardcode colours. Document them in docs/THEME.md with a usage table.
- Theme settings (taken over from settings-theme-about-backup): Material You 'Auto' accent (dynamic_color, Android 12+), custom colour picker (flex_color_picker), keep the 19 presets; the background image path moves off the legacy `UserMal.instance.pref.bgImagePath` (sidebar_bg_manager.dart:240-247) into ThemeBloc / the contract, then delete the reduced lib/user/userpref.dart if nothing else needs it.
- Issue #110 item 2: lib/widgets/common/background.dart ignores `forceBg` and decodes the full image — honour it and decode at screen size (AppImage/SizedDecodeImage).
- Owner's words: buttons and coloured areas whose colour makes the text unreadable, and dark mode, must be handled properly everywhere. So: every filled/tonal/outlined button, chip, badge, FAB, snackbar, dialog, bottom sheet, nav bar and app bar gets its foreground from the matching `on*` role (onPrimary, onPrimaryContainer, onSurfaceVariant…), never a fixed white/black; text on images always sits on the scrim token; verify AA contrast (4.5:1 text, 3:1 large text/icons) for every accent preset × light/dark/black with a unit test that computes the contrast ratios of the ColorScheme roles you generate.
- Dark and black modes: real dark surfaces (no light cards or white sheets left in dark), elevated surfaces distinguishable, images and shimmers adapted, the status bar and navigation bar icons light; black mode = true black backgrounds with readable dark-grey surfaces.
- Bottom navigation bar (owner request, screenshot): REMOVE the small underline bar that appears under the active icon; the active tab keeps only its rounded tinted background (pill) and the accent-coloured icon. Inactive icons readable in every theme. Update test/smoke/nav_indicator_test.dart accordingly.
- Compare with DailyAL's theme (lib/theme/): keep what is better.

## Known bugs to fix in scope
- white status bar icons on light themes
- incoherent accent colours
- hardcoded colours
- Background ignores forceBg

## DailyAL reference (read, never copy blindly)
Checkout: `/home/thinkpad/.cache/mwl-mab/dailyal-108` (DAL `upstream/2026.2.6+108`, read-only).
- `lib/theme/theme.dart`
- `lib/theme/themedata.dart`
- `lib/pages/settings/themesettings.dart`

Port the behaviour into MWL's architecture: BLoC for app-wide state, Provider/ChangeNotifier user singletons, MWL's service layer (`lib/services/api/**`), `S` strings via your l10n fragment, multi-tracker awareness (never assume the active account is MAL without checking).

## Inventory
`work/inventory/*.md` lists, per feature, what MWL has and the bugs found on 2026-10-27.

**UI directive (owner's rule).** MWL's current UI is NOT the reference: the owner wrote it early and calls parts of it badly done. For every screen you touch, read the DAL equivalent's UI code, keep whichever is better (often DAL's), and improve it (hierarchy, spacing, empty/loading/error states, no dead buttons). Stay consistent with the theme system in `lib/user/theme/` (accent color, fonts, dark/black modes). Describe the before/after in the PR body. **Strings:** every screen you own must be fully translatable — move its existing hardcoded literals (e.g. settings_page.dart:55,119, mal_home_page.dart:45-47, mal_home_page_preferences.dart:65) to `S` through your l10n fragment; the checker switches the app to French and flags any English left on your screens. **Colours:** no hardcoded `Colors.*` or `Color(0x…)` in your screens: use `Theme.of(context).colorScheme` and the semantic tokens of lib/widgets/common/app_colors.dart (theme-colors unit, see docs/THEME.md once merged); move the existing hardcoded colours of your files to them. Every text must stay readable on its background (buttons, chips, badges, text on images) in light, dark and black modes. **Icons (owner's rule):** for a feature ported from DailyAL, use THE SAME ICON as DailyAL for each action and element (grep the DAL widget for its `Icons.*` / custom icon and reuse it), never a different MWL pick.

**Fluidity rules (owner's rule: MWL must feel as smooth as DailyAL).** See `docs/PERFORMANCE.md` once perf-foundation has merged, and `work/inventory/performance.md`.
- Network images only through `AppImage` (decode at displayed size); no `Image.network`.
- Long or unbounded lists: `ListView.builder`/slivers, never a `Column` of many children in a `SingleChildScrollView`; no `shrinkWrap: true` list inside another scroll view; no scroll view per list item.
- No `Opacity`, `BackdropFilter`, `ImageFilter.blur`, `ShaderMask` or blurred `BoxShadow` on repeated items or on whole pages during animations; use alpha colors / FadeTransition.
- No `setState` in scroll listeners; listeners added once and removed in dispose; dispose every controller you create.
- BlocBuilder/Consumer as low in the tree as possible, with `buildWhen`/`BlocSelector`/`context.select`; `const` constructors wherever possible.
- Heavy JSON/HTML parsing off the UI isolate (`Isolate.run`/`compute`); no sync storage reads in `build`; no `print` in hot paths.
- Look at how DAL makes the same screen fluid and do at least as well; the checker compares janky-frame % on a profile build.

## Definition of Done
- Widget tests: overlay style per brightness, ColorScheme built from the accent, tokens resolve in light and dark.
- Checker: screenshots of home, detail, list, settings in Spring/Summer/Autumn/Winter light, dark and black: readable status bar, one accent family per theme, no garish leftovers.
- `tools/heavy.sh flutter analyze` clean (the gate runs the full `tools/heavy.sh tools/verify.sh`).
- PR against `dev` with `Closes #<issue>`, gate tail, decisions, findings.
