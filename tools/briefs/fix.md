# Fix brief — MyWatchList (DailyAL port) (read fully before anything else)

You fix defects an independent check found after a merge. Each one is an issue labelled
`post-merge-finding`: <ISSUES — `goddivor/mywatchlist#<N>`: one-line summary, one bullet each>.

## Your branch
- Worktree `<WORKTREE>` on branch `fix/<NAME>`, created from `origin/dev`. Work ONLY inside it.
- You own ONLY these files: <FILES>. Other fix agents own other files at the same time; touching
  a file outside your list breaks their work. Needing one is a finding: stop and report it.
- Your agent slot is `<SLOT>`: ports `<PORTS>` only.

## Read first
`CLAUDE.md`, `AGENTS.md`, `PROJECT-STATE.md`, `docs/DECISIONS.md`, each issue in full (the checker's
reproduction is in it), the handoff of the unit each issue belongs to, and the contract parts it cites.

## How to fix
1. Reproduce each defect first, with the issue's reproduction. A defect you cannot reproduce is
   reported as such, not "fixed".
2. Write the test that fails without the fix, then the fix. Fix the cause, not the symptom: never
   raise a timeout, skip a test or loosen an assertion to go green.
3. A defect that needs a contract change is not yours: report it (the orchestrator batches contract
   gaps into one issue of the contract's repository).
4. Commit in small steps. Conventional commits in English, selective staging by explicit paths, no
   secrets, NO AI attribution anywhere (commits, PR, comments).
- Port DailyAL behaviour, never paste its code: BLoC for app-wide state, Provider/ChangeNotifier for the user singletons, no other state management (project convention).
- UI: MWL's current look is NOT the reference. Compare with DAL, keep the better, improve it. MWL-only flows the owner built (e.g. the account picker) are redesigned too.
- Fix the bugs listed in your handoff that fall inside your Owns; report the others.
- Icons: a feature ported from DailyAL uses the SAME icon as DailyAL for each action/element (look it up in the DAL widget); never substitute another icon.
- User-visible strings go through `S` with keys in YOUR fragment `lib/l10n/units/<UNIT_ID>/` (see CLAUDE.md, Localization). No hardcoded UI text.
- Multi-tracker: never assume the active account is MAL; guard or adapt per tracker.
- Commits: `type(scope): description`, imperative, English. No `Co-Authored-By`, no "Generated with", no assistant name anywhere. Never stage `.env*`, `assets/.env`, keys, credentials, `secret*`.
- Any French written into the repo (docs, strings) must be flawless French (accents, typography, no em dash).
- You WRITE CODE. You never run `flutter build`, `flutter run`, `adb` or the emulator: the checker does that, alone on the machine.
- Every heavy command (`flutter analyze`, `flutter test`, `dart analyze`, `flutter pub get`, `tools/verify.sh`, `tools/l10n/build.sh`) goes through the machine-wide lock: `tools/heavy.sh <command>`. If another agent holds it, you wait — that is expected.
- While iterating, analyze only your own files (`tools/heavy.sh dart analyze lib/<your paths>`), at most once per significant step. The full gate `tools/heavy.sh tools/verify.sh` once, at the end, before pushing.
- Never `pkill -f`, never kill a process you did not start. No server, no port is needed for this project.

## Machine load
One heavy command at a time; browser tests `--workers=2`; servers only on your ports, stopped by
their recorded PID (never `pkill -f`). A test slow alone is a defect to fix, not a timeout to raise.

## Deliver
`git fetch origin && git rebase origin/dev`; the gate `tools/heavy.sh tools/verify.sh` green right before pushing; push
ONLY `fix/<NAME>`; one PR against `dev` with one `Closes #<N>` line PER issue it fixes (merging
into `dev` does not auto-close them: the merge step reads these lines), what was wrong, how it is
fixed, the test that proves it, the gate tail; label `needs-review`. Do not merge.

## Report (your final message)
Per issue: reproduced (yes/no), cause, fix, proving test. The gate tail. Anything left open, and
every file you needed but do not own. The PR URL.
