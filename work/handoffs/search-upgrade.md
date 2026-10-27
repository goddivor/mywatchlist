# Handoff — `search-upgrade`: Search: user results, search by id, autocomplete, searchable filters

**Kind** screen · **Priority** P2 · **Group** discovery · **Model** sonnet

## Needs done first
- `shared-kit` (Shared UI kit: share builder, app bar menu, select widgets, score reveal, web launcher)
- `user-profile-mal` (MAL user profile, stats charts and user pop-up)

## Owns (may create or edit ONLY these)
- `lib/screens/search/**`
- `lib/widgets/MAL/search/**`
- `lib/l10n/units/search-upgrade/**`
- `test/units/search-upgrade/**`

Plus `PROJECT-STATE.md` (rewrite in place, within its cap) and `docs/DECISIONS.md` (append one line per decision). Anything else you need is a FINDING to report, never an edit.

## Goal
- User result tap → profile (TODO :2227) and 'User found as …' shortcut; search by MAL id; autocomplete with throttle; SearchableSelect for producers/magazines; three-state include/exclude.
- `_SeasonalSection._maxYear` hard-coded 2027 (:3643) → current year + 1.
- Expose static entry points (e.g. `GeneralSearchScreen.byGenre/byStudio/byMagazine/byTag/bySeason`) used by more-info and featured units; list them in the PR body.
- Split the 3719-line file into parts under lib/screens/search/.

## Known bugs to fix in scope
- user tap TODO
- maxYear 2027

## DailyAL reference (read, never copy blindly)
Checkout: `/home/thinkpad/.cache/mwl-mab/dailyal-108` (DAL `upstream/2026.2.6+108`, read-only).
- `lib/screens/generalsearchscreen.dart`
- `lib/widgets/search/filtermodal.dart`
- `commits da37082, 6b2aafd, fa2fb68, 3f1f0fd, 158e206 (autocomplete), db3355e (search by id, 3-state)`

Port the behaviour into MWL's architecture: BLoC for app-wide state, Provider/ChangeNotifier user singletons, MWL's service layer (`lib/services/api/**`), `S` strings via your l10n fragment, multi-tracker awareness (never assume the active account is MAL without checking).

## Inventory
`work/inventory/*.md` lists, per feature, what MWL has and the bugs found on 2026-10-27.

**UI directive (owner's rule).** MWL's current UI is NOT the reference: the owner wrote it early and calls parts of it badly done. For every screen you touch, read the DAL equivalent's UI code, keep whichever is better (often DAL's), and improve it (hierarchy, spacing, empty/loading/error states, no dead buttons). Stay consistent with the theme system in `lib/user/theme/` (accent color, fonts, dark/black modes). Describe the before/after in the PR body.

## Definition of Done
- Searching a username opens the profile; searching '1' finds Cowboy Bebop by id.
- `tools/heavy.sh flutter analyze` clean (the gate runs the full `tools/heavy.sh tools/verify.sh`).
- PR against `dev` with `Closes #<issue>`, gate tail, decisions, findings.
