# Independent check — MyWatchList (DailyAL port) (read fully before anything else)

You are an INDEPENDENT checker. These units were squash-merged into `dev` of `goddivor/mywatchlist` after their
own gate passed: <UNITS_AND_MERGE_COMMITS>. A green gate proves the builder's own tests pass; it does
not prove the feature is right. Find out whether what was merged works, honours the contract and the
owner's rules, and did not break what already existed. You did not write this code: verify by
running things, never by trusting a PR body or a builder's report.

## Setup
- Read the component's `CLAUDE.md` and `PROJECT-STATE.md` first.
- Work in a THROW-AWAY detached worktree of the latest merge commit, never in a main checkout or
  another agent's worktree:
  `git -C . worktree add --detach .wt/check-<NAME> <COMMIT>` — remove it at the
  end with `git worktree remove --force`.
- Your agent slot is `<SLOT>`: ports `<PORTS>` only. Record every server PID under
  `tools/.mab/pids/check-<NAME>-<what>.pid` and stop it by that PID.
- One heavy command at a time; browser tests with `--workers=2`. A timeout that passes when re-run
  alone is load, not a defect — say so and move on.
- You are the ONLY agent allowed to build and use the emulator. Take the machine lock for the whole build+install: `tools/heavy.sh bash -c 'GRADLE_OPTS=-Dorg.gradle.java.home=/usr/lib/jvm/java-21-openjdk-amd64 flutter build apk --debug && adb -s emulator-5554 install -r build/app/outputs/flutter-apk/app-debug.apk'` (copy `assets/.env` into your worktree first, run `tools/l10n/build.sh` if it exists).
- Emulator `emulator-5554` (AVD `mwl_compare`) has MWL (`com.teen.mywatchlist`) and DailyAL (`io.github.jica98`) with the owner's accounts logged in. NEVER uninstall either app or clear their data (it would log the owner out); `install -r` only.
- "A screen" here = drive it on the emulator with `adb shell input tap/swipe/text`, `adb exec-out screencap -p > <your scratch>/x.png` and look at the image; open the same screen in DailyAL and compare (owner's UI rule: the result must be at least as good as DAL's). Ignore the 375/1440 browser widths of the generic text.
- Logs: `adb -s emulator-5554 logcat -d | grep -iE "flutter.*(error|exception)"` (ignore gralloc/GPU noise).

## For each merged unit
1. **Intent.** Its handoff (`work/handoffs/<unit>.md`), the contract parts it implements, and for a
   screen its mockups/artifact and every state they draw.
2. **Read the merged diff** (`git show <commit>`) for logic defects: wrong condition, missing case,
   unhandled error, authorization decided the wrong way, a write without its audit trail, a secret in
   a log, a race, a leak outside the caller's scope, hardcoded UI text, an unusable control rendered
   instead of absent.
3. **Run it.** Its own tests, then the tests of every unit that USES what changed (grep the
   importers). A screen: drive it in a real browser through its main flow and its states at a mobile
   width (375) and a desktop width (1440), and look at the screenshots. A server piece: a throw-away
   probe of a path the builder did not test (an edge, a refusal, a concurrent call), kept out of
   the repository.
4. **Integration.** Does it fit what was merged before and after it (seams, exported names other
   units import, shared pieces, migration order, generated files up to date)? Run the FULL component
   gate `tools/heavy.sh tools/verify.sh` once, at the end.

## Do not
Push, commit, open PRs, edit any worktree but yours, or change the contract. You report; the
orchestrator turns each defect into an issue and dispatches the fixes.

## Report (your final message)
Per unit: VERDICT `works` / `works with defects` / `broken`. Then each finding: severity
(blocking / should fix / minor), file:line, the exact reproduction (command or steps), observed vs
required (cite the contract, mockup or rule). Separate what you VERIFIED by running from what you
only suspect from reading. Mention regressions in other units. Factual and short. Remove your
worktree and stop your processes before reporting.
