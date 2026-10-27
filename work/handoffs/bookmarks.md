# Handoff — `bookmarks`: Bookmarks: store, screen, add/remove

**Kind** unit · **Priority** P1 · **Group** discovery · **Model** sonnet

## Needs done first
- `app-shell` (App shell seams: settings hub, sidebar, home shell, startup)
- `shared-kit` (Shared UI kit: share builder, app bar menu, select widgets, score reveal, web launcher)

## Owns (may create or edit ONLY these)
- `lib/cache/bookmarks.dart`
- `lib/screens/bookmarks_screen.dart`
- `lib/widgets/bookmarks/**`
- `lib/screens/plainscreen.dart`
- `lib/l10n/units/bookmarks/**`
- `test/units/bookmarks/**`

Plus `PROJECT-STATE.md` (rewrite in place, within its cap) and `docs/DECISIONS.md` (append one line per decision). Anything else you need is a FINDING to report, never an edit.

## Goal
- Bookmark any anime/manga/character/person/forum topic; bookmarks screen (fills app-shell's stub) with tags/filters; fix plainscreen.dart:31-34 pushing an empty SizedBox; expose `Bookmarks.toggle/isBookmarked` for other units; include bookmarks in `export()/import()` for backup.

## Known bugs to fix in scope
- none

## DailyAL reference (read, never copy blindly)
Checkout: `/home/thinkpad/.cache/mwl-mab/dailyal-108` (DAL `upstream/2026.2.6+108`, read-only).
- `lib/cache/book_marks.dart`
- `lib/widgets/home/bookmarks_widget.dart`
- `BookmarkTag`

Port the behaviour into MWL's architecture: BLoC for app-wide state, Provider/ChangeNotifier user singletons, MWL's service layer (`lib/services/api/**`), `S` strings via your l10n fragment, multi-tracker awareness (never assume the active account is MAL without checking).

## Inventory
`work/inventory/*.md` lists, per feature, what MWL has and the bugs found on 2026-10-27.

**UI directive (owner's rule).** MWL's current UI is NOT the reference: the owner wrote it early and calls parts of it badly done. For every screen you touch, read the DAL equivalent's UI code, keep whichever is better (often DAL's), and improve it (hierarchy, spacing, empty/loading/error states, no dead buttons). Stay consistent with the theme system in `lib/user/theme/` (accent color, fonts, dark/black modes). Describe the before/after in the PR body.

## Definition of Done
- Bookmark from detail (after detail-header) and from the sidebar entry on the emulator.
- `tools/heavy.sh flutter analyze` clean (the gate runs the full `tools/heavy.sh tools/verify.sh`).
- PR against `dev` with `Closes #<issue>`, gate tail, decisions, findings.
