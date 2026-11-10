# Handoff — `l10n-pipeline`: Restore the localization pipeline (ARB sources, per-unit fragments, working language picker)

**Kind** contract · **Priority** P0 · **Group** foundation · **Model** opus

## Needs done first
- `gate-fix` (Make the merge gate meaningful)

## Owns (may create or edit ONLY these)
- `lib/l10n/**`
- `l10n.yaml`
- `lib/generated/**`
- `lib/user/language/**`
- `lib/screens/settings/language_settings.dart`
- `lib/main.dart`
- `pubspec.yaml`
- `pubspec.lock`
- `tools/l10n/**`
- `tools/verify.sh`
- `.gitignore`
- `CLAUDE.md`
- `test/units/l10n-pipeline/**`

Plus `PROJECT-STATE.md` (rewrite in place, within its cap) and `docs/DECISIONS.md` (append one line per decision). Anything else you need is a FINDING to report, never an edit.

## Goal
- MWL has generated messages for 11 locales but no .arb sources, so strings cannot change. Rebuild ARB sources (start from DAL's lib/l10n/*.arb, add MWL's own keys found in lib/generated) and a reproducible generation step.
- PARALLEL-SAFE STRINGS (the reason this is a contract): design it so parallel units never edit the same file to add strings. Required shape: each unit adds its keys ONLY in `lib/l10n/units/<unit-id>/intl_<locale>.arb` (English mandatory, other locales optional, fallback to English); `tools/l10n/build.sh` merges base + all fragments and regenerates `S`. Merged ARBs and `lib/generated/` become build outputs (git-ignored), and `tools/verify.sh` runs the build step first. Document the procedure in CLAUDE.md (Localization section).
- Fix the language setting: picker codes vs generated locale names mismatch (only en/ja load), `language_bloc.dart:27` emits after await in a `void async` handler, saved language never applied at startup (`S.load` never called), `main.dart:203` hardcodes en_US and MaterialApp ignores LanguageBloc, two storage keys. Add the missing locales to the picker (ar, id, tr) and RTL for Arabic.
- Also fix `main.dart:60-75`: an AccountBloc is created and listened to but never provided (the provided one is a different instance at l.91), so the AccountManagerSingleton listener is dead.

## Known bugs to fix in scope
- Language picker broken (see goal).
- AccountBloc double instance in main.dart.

## DailyAL reference (read, never copy blindly)
Checkout: `/home/thinkpad/.cache/mwl-mab/dailyal-108` (DAL `upstream/2026.2.6+108`, read-only).
- `lib/l10n/*.arb`
- `lib/generated/`
- `lib/pages/settings/langsettings.dart`
- `lib/user/user.dart (setLocale)`

Port the behaviour into MWL's architecture: BLoC for app-wide state, Provider/ChangeNotifier user singletons, MWL's service layer (`lib/services/api/**`), `S` strings via your l10n fragment, multi-tracker awareness (never assume the active account is MAL without checking).

## Inventory
`work/inventory/*.md` lists, per feature, what MWL has and the bugs found on 2026-10-27.

## Definition of Done
- Switching to French in settings changes the UI immediately and survives a restart.
- A fresh clone + `tools/l10n/build.sh` + `flutter analyze` is green.
- CLAUDE.md explains how a unit adds a string.
- `tools/heavy.sh flutter analyze` clean (the gate runs the full `tools/heavy.sh tools/verify.sh`).
- PR against `dev` with `Closes #<issue>`, gate tail, decisions, findings.
