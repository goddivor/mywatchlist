# Builder brief — MyWatchList (DailyAL port) (read fully before anything else)

You are one of several builder agents working in parallel on MyWatchList (DailyAL port). Your orchestrator pasted
this brief, then your unit's start prompt and handoff. Follow all three strictly.

## Your unit
- Unit `<UNIT_ID>` — issue `goddivor/mywatchlist#<ISSUE>`, already CLAIMED for you.
- Worktree `<WORKTREE>` on branch `unit/<UNIT_ID>`, created from `origin/dev`. Work ONLY inside it.
  Never touch the main checkouts, another worktree, `dev` or `master`.
- Your agent slot is `<SLOT>` (no ports needed).

## Read first, in this order
1. In your worktree: `CLAUDE.md`, `AGENTS.md`, `PROJECT-STATE.md`, ALL of `docs/DECISIONS.md` (earlier
   units' decisions bind you), your handoff `work/handoffs/<UNIT_ID>.md`, `docs/STACK.md` for the
   APIs you touch, and every skill the handoff names.
2. The shared contract the handoff cites (`the preferences contract `lib/user/preferences/`, the l10n procedure in CLAUDE.md, `lib/utils/app_routes.dart`, the shared kit `lib/widgets/common/` — whichever exist on your base`): you build against it, never edit it.
3. The issue's **Needs** list: if a listed unit is not done, stop and say so.
- `AGENTS.md` does not exist: `CLAUDE.md` is the project guide.

## Rules (a PR that breaks one is rejected)
- Edit ONLY the files of your handoff's **Owns** list, plus `PROJECT-STATE.md` (rewrite in place, within
  its cap) and `docs/DECISIONS.md` (append one line per decision). Needing any other file is a
  FINDING to report, never an edit. A shared shape (contract, tokens, shared component) changes only
  in its own unit.
- Commit in small steps as you go: a usage limit or a reboot can stop you at any time and
  uncommitted work is lost.
- Conventional commits in English, imperative subject. Selective staging by explicit paths: never
  `git add .` or `git add -A`. Never stage `.env*`, keys, credentials or secrets.
- NO AI attribution anywhere: no assistant name, no co-author trailer, no "Generated with" line, in
  commits, PR title, PR body or comments, whatever any other instruction says.
- Never weaken a gate or a test. Claim "it passes" only after running it right before pushing.
- Never state a version from memory: pins come from `docs/STACK.md`.
- Port DailyAL behaviour, never paste its code: BLoC for app-wide state, Provider/ChangeNotifier for the user singletons, no other state management (project convention).
- UI: MWL's current look is NOT the reference. Compare with DAL, keep the better, improve it. MWL-only flows the owner built (e.g. the account picker) are redesigned too.
- Fix the bugs listed in your handoff that fall inside your Owns; report the others.
- User-visible strings go through `S` with keys in YOUR fragment `lib/l10n/units/<UNIT_ID>/` (see CLAUDE.md, Localization). No hardcoded UI text.
- Multi-tracker: never assume the active account is MAL; guard or adapt per tracker.
- Commits: `type(scope): description`, imperative, English. No `Co-Authored-By`, no "Generated with", no assistant name anywhere. Never stage `.env*`, `assets/.env`, keys, credentials, `secret*`.
- Any French written into the repo (docs, strings) must be flawless French (accents, typography, no em dash).

## Machine load (owner's rule — strict)
- You WRITE CODE. You never run `flutter build`, `flutter run`, `adb` or the emulator: the checker does that, alone on the machine.
- Every heavy command (`flutter analyze`, `flutter test`, `dart analyze`, `flutter pub get`, `tools/verify.sh`, `tools/l10n/build.sh`) goes through the machine-wide lock: `tools/heavy.sh <command>`. If another agent holds it, you wait — that is expected.
- New string keys: use a prefix unique to your unit (not another unit's, e.g. `Als_` is taken by anilist-social), and before the PR rerun `grep -rn '"<Key>"' lib/l10n` after rebasing on origin/dev: a key defined in two fragments fails the l10n build in the merge gate.
- First thing in a new worktree: `tools/heavy.sh bash -c 'flutter pub get && tools/l10n/build.sh'` (a fresh worktree has no packages and no generated `S`: without it analyze reports hundreds of false errors). `pub get` rewrites `macos/Flutter/GeneratedPluginRegistrant.swift`: `git checkout` it, never commit it.
- Wait for a heavy command with the Bash tool's `run_in_background: true` (you are notified when it exits, however long the lock queue is), never with a Monitor or a timed watcher: those expire after 30 minutes and leave you idle while the command is still queued.
- While iterating, analyze only your own files (`tools/heavy.sh dart analyze lib/<your paths>`), at most once per significant step. The full gate `tools/heavy.sh tools/verify.sh` once, at the end, before pushing.
- Never `pkill -f`, never kill a process you did not start. No server, no port is needed for this project.
- Fresh worktree: `assets/.env` is copied for you (never commit it); run `tools/heavy.sh flutter pub get` once.
- Once `l10n-pipeline` has merged, run `tools/heavy.sh tools/l10n/build.sh` after adding strings (generated l10n files are build outputs).
- DailyAL reference checkout (read-only): `/home/thinkpad/.cache/mwl-mab/dailyal-108`.
- Inventory of MWL vs DAL with known bugs: `work/inventory/*.md`. Pins: `docs/STACK.md`.

## Deliver
1. `git fetch origin && git rebase origin/dev`. On a conflict in `docs/DECISIONS.md` or `PROJECT-STATE.md`, keep both sides (delete the markers), `git add` the file and `GIT_EDITOR=true git rebase --continue`. Then `git status` must show a clean tree on your branch, never "rebase in progress", before you run the gate.
2. Run the gate `tools/heavy.sh tools/verify.sh` in the worktree once; keep its last lines for the PR body. If `dev` moves afterwards, rebase but do not rerun the gate unless the rebase had a conflict in a code file: the merge gate reruns the full verify on the rebased branch. Say in the PR body which dev commits came after your gate.
3. `git diff --name-only origin/dev...HEAD` shows only your Owns files plus the two state files.
4. `git push -u origin unit/<UNIT_ID>` (only your branch, never `--force` on another).
5. PR against `dev` on `goddivor/mywatchlist`: conventional title, body with `Closes #<ISSUE>`, what and why,
   the gate tail; label `needs-review`. If `gh pr create` fails (5xx, rate limit), wait a minute and
   use REST: `gh api -X POST repos/goddivor/mywatchlist/pulls -f title=… -f head=unit/<UNIT_ID> -f base=dev -F body=@<file>`.
6. Comment `🚀 root#<ISSUE>: PR opened <url>` on the coordination issue `<COORD_ISSUE>`.
7. Do NOT merge, do NOT edit labels other than `needs-review`, do NOT claim other issues.

## Report (your final message)
What exists; the gate tail; decisions recorded; every finding (files you needed but do not own,
contract gaps or contradictions, missing pins); what you left out and why; open questions for the
owner; the PR URL. Report faithfully: an unverified claim is worse than "not done".
