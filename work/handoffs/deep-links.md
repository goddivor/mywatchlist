# Handoff — `deep-links`: Open myanimelist.net links in the app

**Kind** unit · **Priority** P2 · **Group** release · **Model** sonnet

## Needs done first
- `app-shell` (App shell seams: settings hub, sidebar, home shell, startup)
- `deps-prefs-contract` (Dependencies, Android permissions and the preferences contract)

## Owns (may create or edit ONLY these)
- `lib/utils/deep_links.dart`
- `lib/l10n/units/deep-links/**`
- `test/units/deep-links/**`

Plus `PROJECT-STATE.md` (rewrite in place, within its cap) and `docs/DECISIONS.md` (append one line per decision). Anything else you need is a FINDING to report, never an edit.

## Goal
- Register `WebLauncher.internalLinkHandler` (shared-kit, lib/utils/web_launcher.dart) from lib/utils/deep_links.dart at startup so in-app MAL links (anime, manga, character, people, forum, profile) open their screen instead of a browser tab; handled MAL links open directly, without a confirmation dialog (owner default). Map myanimelist.net anime/manga/character/people/profile/forum URLs to in-app screens via app_routes. The intent filters go in the manifest (contract's file): report the exact XML as a finding.

## Known bugs to fix in scope
- none

## DailyAL reference (read, never copy blindly)
Checkout: `/home/thinkpad/.cache/mwl-mab/dailyal-108` (DAL `upstream/2026.2.6+108`, read-only).
- `lib/util/pathutils.dart`
- `android/app/src/main/AndroidManifest.xml (intent filters)`
- `main.dart onGenerateRoute`

Port the behaviour into MWL's architecture: BLoC for app-wide state, Provider/ChangeNotifier user singletons, MWL's service layer (`lib/services/api/**`), `S` strings via your l10n fragment, multi-tracker awareness (never assume the active account is MAL without checking).

## Inventory
`work/inventory/*.md` lists, per feature, what MWL has and the bugs found on 2026-10-27.

## Definition of Done
- `adb shell am start -d https://myanimelist.net/anime/1` opens Cowboy Bebop in the app.
- `tools/heavy.sh flutter analyze` clean (the gate runs the full `tools/heavy.sh tools/verify.sh`).
- PR against `dev` with `Closes #<issue>`, gate tail, decisions, findings.
