# Handoff — `app-icon`: Circular adaptive launcher icon like DailyAL

**Kind** unit · **Priority** P0 · **Group** release · **Model** sonnet

## Needs done first
- `deps-prefs-contract` (Dependencies, Android permissions and the preferences contract)

## Owns (may create or edit ONLY these)
- `pubspec.yaml`
- `android/app/src/main/res/mipmap-*/**`
- `android/app/src/main/res/mipmap-anydpi-v26/**`
- `android/app/src/main/res/values/ic_launcher_background.xml`
- `assets/images/app_icon/**`
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/**`
- `tools/icon/**`
- `lib/l10n/units/app-icon/**`
- `test/units/app-icon/**`

Plus `PROJECT-STATE.md` (rewrite in place, within its cap) and `docs/DECISIONS.md` (append one line per decision). Anything else you need is a FINDING to report, never an edit.

## Goal
- Owner: 'why is the icon not circular like DailyAL's? fix it'. Today MWL ships no adaptive icon (no mipmap-anydpi-v26/ic_launcher.xml): Android puts the square dark mwl-black-bg.png logo inside its own teal circle. DailyAL ships an adaptive icon: a full dark circle with the white logo centred.
- Build an adaptive icon: foreground = only the white 'mwL' letters on a TRANSPARENT background, extracted from assets/images/mwl-black-bg.png (1024×1024) — e.g. with ImageMagick in a script kept in tools/icon/ (threshold the near-white pixels to an alpha mask, keep anti-aliasing), scaled to sit inside the 66 % safe zone; background = the logo's dark navy gradient (sample its colours) as a colour or a background PNG; monochrome = the letters only (Android 13 themed icons). Keep the legacy square/round mipmaps for old Android, generated from the same layers so they also look circular on round launchers.
- Prefer flutter_launcher_icons (already a dev dependency, config `flutter_icons:` in pubspec.yaml): set adaptive_icon_background / adaptive_icon_foreground / adaptive_icon_monochrome and regenerate with `tools/heavy.sh dart run flutter_launcher_icons`; commit the generated res files. iOS keeps a square icon (iOS masks it itself).

## Known bugs to fix in scope
- none

## DailyAL reference (read, never copy blindly)
Checkout: `/home/thinkpad/.cache/mwl-mab/dailyal-108` (DAL `upstream/2026.2.6+108`, read-only).
- `android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml (adaptive icon: background + foreground + monochrome)`
- `android/app/src/main/res/mipmap-*/ic_launcher_foreground.png`

Port the behaviour into MWL's architecture: BLoC for app-wide state, Provider/ChangeNotifier user singletons, MWL's service layer (`lib/services/api/**`), `S` strings via your l10n fragment, multi-tracker awareness (never assume the active account is MAL without checking).

## Inventory
`work/inventory/*.md` lists, per feature, what MWL has and the bugs found on 2026-10-27.

## Definition of Done
- mipmap-anydpi-v26/ic_launcher.xml (+ ic_launcher_round.xml) exist with background/foreground/monochrome.
- Checker: launcher screenshot on the emulator next to DailyAL — a full dark circle with the white mwL letters, no square inside.
- `tools/heavy.sh flutter analyze` clean (the gate runs the full `tools/heavy.sh tools/verify.sh`).
- PR against `dev` with `Closes #<issue>`, gate tail, decisions, findings.
