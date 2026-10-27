# Handoff — `detail-social`: Reviews AI summary + share, interest stacks and user updates linking to profiles

**Kind** unit · **Priority** P2 · **Group** detail · **Model** sonnet

## Needs done first
- `detail-split` (Split the 1852-line detail screen into sections with seams)
- `user-profile-mal` (MAL user profile, stats charts and user pop-up)
- `backend-parsers` (mwl-api: port DAL's missing routes and HTML parsers)

## Owns (may create or edit ONLY these)
- `lib/widgets/MAL/content/show_reviews.dart`
- `lib/widgets/MAL/review/**`
- `lib/widgets/MAL/content/intereststackwidget.dart`
- `lib/widgets/MAL/content/userupdate_widget.dart`
- `lib/screens/MAL/interest_stack_detail_screen.dart`
- `lib/l10n/units/detail-social/**`
- `test/units/detail-social/**`

Plus `PROJECT-STATE.md` (rewrite in place, within its cap) and `docs/DECISIONS.md` (append one line per decision). Anything else you need is a FINDING to report, never an edit.

## Goal
- Review AI summary (verdict, pros/cons) via backend `getReviewsSummary`; share a review; reviewer tap → profile (TODO at review_detail_page.dart:92).
- Interest stacks: username tap → profile (intereststackwidget.dart:195); edit button on stack entries works (interest_stack_detail_screen.dart:771) — call the edit sheet directly.
- Reviews: remove the SingleChildScrollView created per review item (show_reviews.dart:174, performance.md #6).
- User updates: user/avatar tap → profile (userupdate_widget.dart:91, :107).

## Known bugs to fix in scope
- none

## DailyAL reference (read, never copy blindly)
Checkout: `/home/thinkpad/.cache/mwl-mab/dailyal-108` (DAL `upstream/2026.2.6+108`, read-only).
- `lib/pages/animedetailed/reviewpage.dart`
- `ReviewGeneratedSummary`
- `lib/pages/animedetailed/intereststackwidget.dart`
- `lib/pages/animedetailed/userupdates.dart`

Port the behaviour into MWL's architecture: BLoC for app-wide state, Provider/ChangeNotifier user singletons, MWL's service layer (`lib/services/api/**`), `S` strings via your l10n fragment, multi-tracker awareness (never assume the active account is MAL without checking).

## Inventory
`work/inventory/*.md` lists, per feature, what MWL has and the bugs found on 2026-10-27.

**UI directive (owner's rule).** MWL's current UI is NOT the reference: the owner wrote it early and calls parts of it badly done. For every screen you touch, read the DAL equivalent's UI code, keep whichever is better (often DAL's), and improve it (hierarchy, spacing, empty/loading/error states, no dead buttons). Stay consistent with the theme system in `lib/user/theme/` (accent color, fonts, dark/black modes). Describe the before/after in the PR body.

**Fluidity rules (owner's rule: MWL must feel as smooth as DailyAL).** See `docs/PERFORMANCE.md` once perf-foundation has merged, and `work/inventory/performance.md`.
- Network images only through `AppImage` (decode at displayed size); no `Image.network`.
- Long or unbounded lists: `ListView.builder`/slivers, never a `Column` of many children in a `SingleChildScrollView`; no `shrinkWrap: true` list inside another scroll view; no scroll view per list item.
- No `Opacity`, `BackdropFilter`, `ImageFilter.blur`, `ShaderMask` or blurred `BoxShadow` on repeated items or on whole pages during animations; use alpha colors / FadeTransition.
- No `setState` in scroll listeners; listeners added once and removed in dispose; dispose every controller you create.
- BlocBuilder/Consumer as low in the tree as possible, with `buildWhen`/`BlocSelector`/`context.select`; `const` constructors wherever possible.
- Heavy JSON/HTML parsing off the UI isolate (`Isolate.run`/`compute`); no sync storage reads in `build`; no `print` in hot paths.
- Look at how DAL makes the same screen fluid and do at least as well; the checker compares janky-frame % on a profile build.

## Definition of Done
- Every user name in these widgets opens the in-app profile.
- `tools/heavy.sh flutter analyze` clean (the gate runs the full `tools/heavy.sh tools/verify.sh`).
- PR against `dev` with `Closes #<issue>`, gate tail, decisions, findings.
