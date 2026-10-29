# Handoff — `mal-pm-composer`: MAL messages: WhatsApp-style formatting, photo upload to catbox.moe, BBCode rendering in threads

**Kind** unit · **Priority** P1 · **Group** user · **Model** opus

## Needs done first
- `mal-web-recaptcha` (MAL writes protected by reCAPTCHA go through an invisible WebView; user pictures in messages)

## Owns (may create or edit ONLY these)
- `lib/screens/mal_web/compose_message_screen.dart`
- `lib/screens/mal_web/message_thread_screen.dart`
- `lib/widgets/mal_web/message_tiles.dart`
- `lib/widgets/mal_web/message_composer/**`
- `lib/services/upload/**`
- `lib/l10n/units/mal-pm-composer/**`
- `test/units/mal-pm-composer/**`
- `test/units/mal-pm-composer/**`

Plus `PROJECT-STATE.md` (rewrite in place, within its cap) and `docs/DECISIONS.md` (append one line per decision). Anything else you need is a FINDING to report, never an edit.

## Goal
- Owner request 2026-10-29 (decision in docs/DECISIONS.md): MAL private messages work like a chat app. (1) Composer (compose_message_screen.dart and the reply bar of message_thread_screen.dart): WhatsApp-style formatting: select text, the selection toolbar offers Bold, Italic, Underline, Strikethrough, Spoiler and Link, which wrap the selection in MAL BBCode ([b] [i] [u] [s] [spoiler] [url=…]); a small formatting row above the keyboard does the same for the cursor. (2) Images: an attach button picks a photo (image_picker, already a dependency), uploads it to catbox.moe (POST https://catbox.moe/user/api.php, reqtype=fileupload, fileToUpload; no account, answer is the URL) with a progress indicator and a clear error on failure, then inserts [img]URL[/img]; also 'insert image link' for an existing URL. Before sending, a preview of the formatted message. (3) Rendering: the thread bubbles and the inbox preview render MAL's message HTML/BBCode properly: bold, italic, underline, strike, spoilers (tap to reveal), links (open in app/browser), quotes, and inline images (tap to zoom), without layout errors on unbounded widths. (4) Sending still goes through MalWebFormSubmitter (reCAPTCHA), unchanged.
- Never send a real message or upload a real image from tests: fakes only. MAL screens follow DailyAL conventions; no explanatory captions.

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
- Tests: selection formatting produces the right BBCode; upload (fake) inserts [img]; rendering shows bold/italic/spoiler/image; sending unchanged.
- `tools/heavy.sh flutter analyze` clean (the gate runs the full `tools/heavy.sh tools/verify.sh`).
- PR against `dev` with `Closes #<issue>`, gate tail, decisions, findings.
