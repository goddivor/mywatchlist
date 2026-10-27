# Handoff — `forum-clubs`: Forum posting, profile links, club members in-app

**Kind** screen · **Priority** P2 · **Group** community · **Model** sonnet

## Needs done first
- `user-profile-mal` (MAL user profile, stats charts and user pop-up)
- `shared-kit` (Shared UI kit: share builder, app bar menu, select widgets, score reveal, web launcher)

## Owns (may create or edit ONLY these)
- `lib/screens/forum/**`
- `lib/widgets/forum/**`
- `lib/pages/MAL/mal_forum_page.dart`
- `lib/l10n/units/forum-clubs/**`
- `test/units/forum-clubs/**`

Plus `PROJECT-STATE.md` (rewrite in place, within its cap) and `docs/DECISIONS.md` (append one line per decision). Anything else you need is a FINDING to report, never an edit.

## Goal
- Reply FAB only copies the URL (forum_posts_screen.dart:117-126) → open a webview to post (DAL); post avatar → profile (post_widget.dart:346); club members/staff → in-app profile instead of browser; share/browser menus; redesign per UI directive.

## Known bugs to fix in scope
- reply FAB
- avatar tap

## DailyAL reference (read, never copy blindly)
Checkout: `/home/thinkpad/.cache/mwl-mab/dailyal-108` (DAL `upstream/2026.2.6+108`, read-only).
- `lib/screens/forumposts.dart`
- `lib/screens/forumtopicsscreen.dart`
- `lib/pages/forumpage.dart`
- `lib/screens/clubscreen.dart`

Port the behaviour into MWL's architecture: BLoC for app-wide state, Provider/ChangeNotifier user singletons, MWL's service layer (`lib/services/api/**`), `S` strings via your l10n fragment, multi-tracker awareness (never assume the active account is MAL without checking).

## Inventory
`work/inventory/*.md` lists, per feature, what MWL has and the bugs found on 2026-10-27.

**UI directive (owner's rule).** MWL's current UI is NOT the reference: the owner wrote it early and calls parts of it badly done. For every screen you touch, read the DAL equivalent's UI code, keep whichever is better (often DAL's), and improve it (hierarchy, spacing, empty/loading/error states, no dead buttons). Stay consistent with the theme system in `lib/user/theme/` (accent color, fonts, dark/black modes). Describe the before/after in the PR body.

## Definition of Done
- Reply opens the MAL post form in-app on the emulator.
- `tools/heavy.sh flutter analyze` clean (the gate runs the full `tools/heavy.sh tools/verify.sh`).
- PR against `dev` with `Closes #<issue>`, gate tail, decisions, findings.
