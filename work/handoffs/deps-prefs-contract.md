# Handoff — `deps-prefs-contract`: Dependencies, Android permissions and the preferences contract

**Kind** contract · **Priority** P0 · **Group** foundation · **Model** opus

## Needs done first
- `l10n-pipeline` (Restore the localization pipeline (ARB sources, per-unit fragments, working language picker))

## Owns (may create or edit ONLY these)
- `pubspec.yaml`
- `pubspec.lock`
- `android/app/src/main/AndroidManifest.xml`
- `android/app/build.gradle`
- `android/app/build.gradle.kts`
- `lib/main.dart`
- `lib/user/preferences/**`
- `lib/user/userpref.dart`
- `lib/user/user_preference.dart`
- `lib/user/anime_manga_pref.dart`
- `lib/user/anime_manga_pref.g.dart`
- `lib/user/anime_manga_tab_pref.dart`
- `lib/user/anime_manga_tab_pref.g.dart`
- `lib/user/list_pref.dart`
- `lib/services/notifications/notification_service.dart`
- `lib/l10n/units/deps-prefs-contract/**`
- `test/units/deps-prefs-contract/**`

Plus `PROJECT-STATE.md` (rewrite in place, within its cap) and `docs/DECISIONS.md` (append one line per decision). Anything else you need is a FINDING to report, never an edit.

## Goal
- Add, in ONE pass, every dependency the queued units need (check pins against pub.dev; record them in docs/STACK.md is not yours — list them in the PR body): flutter_local_notifications, timezone, dynamic_color, flex_color_picker, translator_plus, package_info_plus, device_info_plus, add_2_calendar, open_filex, flutter_displaymode, graphview, fl_chart, share_plus (if absent), path_provider (if absent), file_picker (if absent), build_runner (dev). Move json_serializable to dev_dependencies.
- Manifest: POST_NOTIFICATIONS, SCHEDULE_EXACT_ALARM/USE_EXACT_ALARM, RECEIVE_BOOT_COMPLETED + the flutter_local_notifications receivers, calendar permissions, REQUEST_INSTALL_PACKAGES + a FileProvider for the in-app updater. Keep the OAuth intent filters.
- PREFERENCES CONTRACT (shared shape every later unit reads): a `PreferencesBloc` (BLoC, per project convention) in `lib/user/preferences/` holding typed, persisted models for ALL DAL preferences: user prefs (preferred title EN/JA/Romaji, startup page, NSFW, show anime/manga card, allow YouTube player, keep pages in memory, show priority, auto-translate synopsis, only last quote, auto start/end date, airing info in list, stats chart colors, preferred link type), anime/manga prefs (countdown on detail, detail background, show private notes, hide score, global seasonal filter, timezone, default add-to-list status anime/manga, detail tab order/visibility), list prefs (default list tab, card view props), notification prefs (enabled lists, large image). Events to update each field; a getter API that non-widget code can call.
- Remove the duplicates (TimezonePref declared twice, the unused models replaced by the contract), keeping existing saved values readable (migrate keys).
- Create the stub `lib/services/notifications/notification_service.dart` with a no-op `init()` called from main.dart; the notifications unit fills it.

## Known bugs to fix in scope
- none

## DailyAL reference (read, never copy blindly)
Checkout: `/home/thinkpad/.cache/mwl-mab/dailyal-108` (DAL `upstream/2026.2.6+108`, read-only).
- `lib/user/userpref.dart`
- `lib/user/anime_manga_pref.dart`
- `lib/user/anime_manga_tab_pref.dart`
- `lib/user/list_pref.dart`
- `lib/user/hompagepref.dart`
- `lib/notifservice.dart (NotifPref)`
- `pubspec.yaml`
- `android/app/src/main/AndroidManifest.xml`

Port the behaviour into MWL's architecture: BLoC for app-wide state, Provider/ChangeNotifier user singletons, MWL's service layer (`lib/services/api/**`), `S` strings via your l10n fragment, multi-tracker awareness (never assume the active account is MAL without checking).

## Inventory
`work/inventory/*.md` lists, per feature, what MWL has and the bugs found on 2026-10-27.

## Definition of Done
- `test/units/deps-prefs-contract/` covers persistence round-trip and key migration.
- App starts on the emulator with the new providers (checker verifies).
- PR body lists every added dependency with its version and the unit that needs it.
- `tools/heavy.sh flutter analyze` clean (the gate runs the full `tools/heavy.sh tools/verify.sh`).
- PR against `dev` with `Closes #<issue>`, gate tail, decisions, findings.
