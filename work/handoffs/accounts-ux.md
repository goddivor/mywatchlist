# Handoff — `accounts-ux`: Redesign the account picker, account switcher and account management

**Kind** screen · **Priority** P1 · **Group** user · **Model** sonnet

## Needs done first
- `app-shell` (App shell seams: settings hub, sidebar, home shell, startup)

## Owns (may create or edit ONLY these)
- `lib/screens/account_switcher_page.dart`
- `lib/screens/manage_accounts_page.dart`
- `lib/screens/onboarding_trackers.dart`
- `lib/pages/login_page.dart`
- `lib/screens/settings/accounts_settings.dart`
- `lib/user/trackers/**`
- `lib/widgets/common/acc_widget.dart`
- `lib/widgets/common/signin_widget.dart`
- `lib/widgets/common/logout_dialog.dart`
- `lib/widgets/Kitsu/kitsu_login_dialog.dart`
- `lib/l10n/units/accounts-ux/**`
- `test/units/accounts-ux/**`

Plus `PROJECT-STATE.md` (rewrite in place, within its cap) and `docs/DECISIONS.md` (append one line per decision). Anything else you need is a FINDING to report, never an edit.

## Goal
- The owner says the current flow (select an account, then press Continue, for every app) is badly done. Redesign the whole account experience: first-run tracker connection, switching the active account (one tap, no Continue step), adding/removing accounts, re-login when a token is dead.
- Fill the Accounts settings page stub (login/logout per tracker, active account, connected services).
- This is an MWL-only flow (DAL has one MAL account): design it from scratch for 4 trackers; look at DAL only for the sign-in visuals.

## Known bugs to fix in scope
- none

## DailyAL reference (read, never copy blindly)
Checkout: `/home/thinkpad/.cache/mwl-mab/dailyal-108` (DAL `upstream/2026.2.6+108`, read-only).
- `lib/pages/settings/accounts_settings.dart`
- `lib/widgets/user/signinpage.dart`

Port the behaviour into MWL's architecture: BLoC for app-wide state, Provider/ChangeNotifier user singletons, MWL's service layer (`lib/services/api/**`), `S` strings via your l10n fragment, multi-tracker awareness (never assume the active account is MAL without checking).

## Inventory
`work/inventory/*.md` lists, per feature, what MWL has and the bugs found on 2026-10-27.

**UI directive (owner's rule).** MWL's current UI is NOT the reference: the owner wrote it early and calls parts of it badly done. For every screen you touch, read the DAL equivalent's UI code, keep whichever is better (often DAL's), and improve it (hierarchy, spacing, empty/loading/error states, no dead buttons). Stay consistent with the theme system in `lib/user/theme/` (accent color, fonts, dark/black modes). Describe the before/after in the PR body.

## Definition of Done
- Switching account is one tap from the home shell.
- No dead buttons.
- Before/after screenshots described in the PR body (the checker re-takes them).
- `tools/heavy.sh flutter analyze` clean (the gate runs the full `tools/heavy.sh tools/verify.sh`).
- PR against `dev` with `Closes #<issue>`, gate tail, decisions, findings.
