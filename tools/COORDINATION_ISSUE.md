# Multi-session coordination protocol

Several agent sessions build this project at the same time, possibly on several machines. GitHub is
the only shared channel: **this issue, the labels and the Project board are the source of truth.**

## Roles
- **Orchestrator / merge master** — one session at a time, announced here. Claims units, briefs
  builder agents, and is the only session that merges into `dev` and moves cards to Done.
- **Worker** — any other session. Builds units, opens PRs against `dev`. Never merges.
- **Owner** (the human) — the only one who promotes `dev → main`.

## Claiming (mandatory before any work)
1. Take the open unit issue of highest priority (`P0` → `P1` → `P2`) with **no `agent:*` label** and
   **no `blocked` label** (`blocked` = a unit in its Needs list is not done).
2. `tools/mab/agentctl.sh claim [component] <N>` — adds `agent:<id>`, comments `🔒 claimed`, moves
   the card to In Progress, waits, re-reads: on a double claim the lexicographically smaller id keeps it.
3. One claim per agent. Grouped units are claimed together. `release` to give one back.

## Branches and PRs
- One unit = one issue = one branch `unit/<id>` = one worktree (`agentctl.sh wt`) = the files its
  handoff's **Owns** list names. Nothing else is edited.
- PR to `dev`, label `needs-review`, body `Closes #<N>` + what/why + the gate's last lines.
- Conventional commits in English, selective staging, **no AI attribution of any kind**.
- A merge into `dev` does not auto-close issues: the merge master closes them.

## Findings
An independent checker runs after every few merges. Each defect becomes an issue labelled
`post-merge-finding`; a batch is done when its finding issues are closed.

## Status board
Short comments only: `👋 online`, `🔒 claimed`, `🚀 PR opened <url>`, `✅ merged`, `🔁 rebase <files>`,
`⛔ blocked by …`, `⏸ paused`. Discussion belongs on the PR or the unit issue.
