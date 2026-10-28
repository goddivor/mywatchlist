# Handoff — `mal-session`: Optional MAL website session (WebView login, native cookies, CSRF client) + profile comments

**Kind** unit · **Priority** P0 · **Group** foundation · **Model** opus

## Needs done first
- `color-sweep` (Colour sweep: hardcoded colours of already-merged screens onto the theme tokens)

## Owns (may create or edit ONLY these)
- `lib/services/auth/**`
- `lib/widgets/auth/**`
- `android/app/src/main/kotlin/**`
- `lib/services/api/MAL/web/**`
- `lib/services/auth/mal_web_session*.dart`
- `lib/screens/settings/mal_session_settings.dart`
- `lib/widgets/user/profile/profile_comments*.dart`
- `lib/screens/user_profile/sections/comments_section.dart`
- `lib/l10n/units/mal-session/**`
- `test/units/mal-session/**`
- `pubspec.yaml`
- `test/units/mal-session/**`

Plus `PROJECT-STATE.md` (rewrite in place, within its cap) and `docs/DECISIONS.md` (append one line per decision). Anything else you need is a FINDING to report, never an edit.

## Goal
- OWNER DECISION (overrides the separate-screen idea below): the website session is connected AUTOMATICALLY at MAL login. The OAuth flow already runs in our in-app WebView (AuthWebView) on myanimelist.net, where the user types his MAL credentials, so the WebView ends up holding MAL's website cookies: when the OAuth redirect to mywatchlist://callback arrives, read ALL myanimelist.net cookies natively (incl. HttpOnly) from that same WebView and store them with the tokens in FlutterSecureStorage (session data + cookies + csrf when read). If the cookies are missing (e.g. an older login), offer a one-tap reconnect that reopens the same login; the settings screen only shows the session state and a disconnect. Sign-out clears tokens and cookies together. Add lib/services/auth/** files of the MAL OAuth flow to what you may edit.
- Reports: docs/malclient-report-2026-10-28.md and docs/malclient-fork-report-2026-10-28.md (how MALClient logs in to MAL's website and writes). MAL's official API has no endpoint for comments, forum, messages, friends, clubs, favourites or notifications; MALClient used the website session.
- Step 0 (foundation): an optional 'Connect MyAnimeList website' screen in settings: in-app WebView opens https://myanimelist.net/login.php (reCAPTCHA → never automate credentials), on landing back on myanimelist.net read ALL cookies natively (Android CookieManager.getCookie via a small MethodChannel in MainActivity, or flutter_inappwebview — justify), store them in FlutterSecureStorage, never log them; a `MalWebClient` (dio or http) that sends the cookies, reads `<meta name='csrf_token'>` from the home page and adds it to every POST form, checks the session with GET /editprofile.php?go=myoptions (200 = valid), and clears on logout/expiry with a clear translated state. OAuth stays the main login.
- Profile comments: READ them on every profile (no session needed: the comments block on /profile/<name>, desktop UA) as a Comments tab/section like MALClient; POST a comment (POST /addcomment.php form, see reports), reply (area=2) and delete (ajax.inc.php?t=78) when the session is connected; conversation view (/comtocom.php).
- Real write test (owner approved, his account goddivor): ONLY on his own profile: post one comment, verify it appears, delete it, verify it is gone. Never write anywhere visible to other people. If the owner must log in on the emulator WebView, stop and tell the orchestrator the exact step.
- Owner rules: replicate MALClient/DailyAL UI conventions where MWL would be weaker; no explanatory captions; theme tokens; English + French.

## Known bugs to fix in scope
- none

## DailyAL reference (read, never copy blindly)
Checkout: `/home/thinkpad/.cache/mwl-mab/dailyal-108` (DAL `upstream/2026.2.6+108`, read-only).
- none

Port the behaviour into MWL's architecture: BLoC for app-wide state, Provider/ChangeNotifier user singletons, MWL's service layer (`lib/services/api/**`), `S` strings via your l10n fragment, multi-tracker awareness (never assume the active account is MAL without checking).

## Inventory
`work/inventory/*.md` lists, per feature, what MWL has and the bugs found on 2026-10-27.

**UI directive (owner's rule).** MWL's current UI is NOT the reference: the owner wrote it early and calls parts of it badly done. For every screen you touch, read the DAL equivalent's UI code, keep whichever is better (often DAL's), and improve it (hierarchy, spacing, empty/loading/error states, no dead buttons). Stay consistent with the theme system in `lib/user/theme/` (accent color, fonts, dark/black modes). Describe the before/after in the PR body. **Strings:** every screen you own must be fully translatable — move its existing hardcoded literals (e.g. settings_page.dart:55,119, mal_home_page.dart:45-47, mal_home_page_preferences.dart:65) to `S` through your l10n fragment; the checker switches the app to French and flags any English left on your screens. **Colours:** no hardcoded `Colors.*` or `Color(0x…)` in your screens: use `Theme.of(context).colorScheme` and the semantic tokens of lib/widgets/common/app_colors.dart (theme-colors unit, see docs/THEME.md once merged); move the existing hardcoded colours of your files to them. Every text must stay readable on its background (buttons, chips, badges, text on images) in light, dark and black modes.

**Fluidity rules (owner's rule: MWL must feel as smooth as DailyAL).** See `docs/PERFORMANCE.md` once perf-foundation has merged, and `work/inventory/performance.md`.
- Network images only through `AppImage` (decode at displayed size); no `Image.network`.
- Long or unbounded lists: `ListView.builder`/slivers, never a `Column` of many children in a `SingleChildScrollView`; no `shrinkWrap: true` list inside another scroll view; no scroll view per list item.
- No `Opacity`, `BackdropFilter`, `ImageFilter.blur`, `ShaderMask` or blurred `BoxShadow` on repeated items or on whole pages during animations; use alpha colors / FadeTransition.
- No `setState` in scroll listeners; listeners added once and removed in dispose; dispose every controller you create.
- BlocBuilder/Consumer as low in the tree as possible, with `buildWhen`/`BlocSelector`/`context.select`; `const` constructors wherever possible.
- Heavy JSON/HTML parsing off the UI isolate (`Isolate.run`/`compute`); no sync storage reads in `build`; no `print` in hot paths.
- Look at how DAL makes the same screen fluid and do at least as well; the checker compares janky-frame % on a profile build.

## Definition of Done
- Offline tests on saved pages (comments block, csrf meta, form fields).
- Live: comment posted then deleted on goddivor's profile (screenshots).
- `tools/heavy.sh flutter analyze` clean (the gate runs the full `tools/heavy.sh tools/verify.sh`).
- PR against `dev` with `Closes #<issue>`, gate tail, decisions, findings.
