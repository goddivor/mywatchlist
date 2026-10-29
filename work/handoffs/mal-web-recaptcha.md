# Handoff — `mal-web-recaptcha`: MAL writes protected by reCAPTCHA go through an invisible WebView; user pictures in messages

**Kind** unit · **Priority** P0 · **Group** user · **Model** opus

## Needs done first
- `mal-hub-followups` (MAL hub follow-ups: in-app thread on message tap, JSON posts through postJson, message poller next to the hub poller)

## Owns (may create or edit ONLY these)
- `lib/services/api/MAL/web/mal_web_form_submitter.dart`
- `lib/services/api/MAL/web/mal_web_client.dart`
- `lib/services/api/MAL/web/mal_messages_api.dart`
- `lib/services/api/MAL/web/profile_comments_api.dart`
- `lib/services/api/MAL/web/mal_notifications_api.dart`
- `lib/screens/mal_web/**`
- `lib/widgets/forum/forum_common.dart`
- `lib/l10n/units/mal-web-recaptcha/**`
- `test/units/mal-web-recaptcha/**`
- `test/units/mal-messages/**`
- `test/units/mal-session/**`
- `test/units/mal-web-recaptcha/**`

Plus `PROJECT-STATE.md` (rewrite in place, within its cap) and `docs/DECISIONS.md` (append one line per decision). Anything else you need is a FINDING to report, never an edit.

## Goal
- Owner bug 2026-10-29, checked live on the emulator with the owner's session: replying to a private message fails with 'Couldn't reach MyAnimeList'. Cause, read from MAL's real reply form (mymessages.php?go=send&replyid=&threadid=&toname=) and its script all-*.js: the form fields are subject, message, action_type (empty; 'preview' for Preview) and the submit button has class btn-recaptcha-submit; MAL's script (.recaptcha-form / btn-recaptcha-submit, grecaptcha.execute(window.GRECAPTCHA_SITE_KEY,{action})) appends a hidden g-recaptcha-response (reCAPTCHA v3, sitekey 6Ld_1aIZAAAAAF6bNdR67ICKIaeXLKlbhE7t2Qz4) before submitting. A plain HTTP POST from the app has no token, so MAL refuses it; there is no csrf_token field in that form.
- Fix: a MalWebFormSubmitter that loads the real MAL form page in an invisible WebView (webview_flutter, already a dependency; host it offstage or headless) with the MalWebSession cookies set through WebViewCookieManager, fills the fields by JavaScript, clicks MAL's own submit button so MAL's script adds the reCAPTCHA v3 token, then reads the result page (goodresult / badresult / redirect) and reports success or MAL's error text. Use it for MalMessagesApi.send and reply. Then check every other MWL write through MalWebClient (profile comments in profile_comments_api.dart, notifications JSON posts, friend actions) against MAL's all-*.js: route the ones MAL protects with reCAPTCHA (recaptcha-form, grecaptcha.execute: favourites use action 'social') through the submitter; keep plain HTTP for the others. A timeout (20 s) or a page without the form gives a clear error, never a silent failure.
- Also from the owner (same session): the message inbox, sent box and thread show initials ('LO') instead of the users' MAL profile pictures. Read the picture from MAL's markup when present, otherwise from the user's MAL profile (cache per user), shown in ForumAvatar.
- Fakes only in tests (a fake submitter); never send anything to MAL from tests. The orchestrator tests the real send on the emulator with the owner's approval.

## Known bugs to fix in scope
- none

## DailyAL reference (read, never copy blindly)
Checkout: `/home/thinkpad/.cache/mwl-mab/dailyal-108` (DAL `upstream/2026.2.6+108`, read-only).
- none

Port the behaviour into MWL's architecture: BLoC for app-wide state, Provider/ChangeNotifier user singletons, MWL's service layer (`lib/services/api/**`), `S` strings via your l10n fragment, multi-tracker awareness (never assume the active account is MAL without checking).

## Inventory
`work/inventory/*.md` lists, per feature, what MWL has and the bugs found on 2026-10-27.

## Definition of Done
- Tests: the submitter fills subject/message and reads goodresult/badresult; send and reply use it; avatars resolved; plain writes unchanged.
- `tools/heavy.sh flutter analyze` clean (the gate runs the full `tools/heavy.sh tools/verify.sh`).
- PR against `dev` with `Closes #<issue>`, gate tail, decisions, findings.
