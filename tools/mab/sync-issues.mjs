#!/usr/bin/env node
/**
 * Mirrors each component's unit queue (units.json) into GitHub: one issue per unit on the
 * component's repository, every issue on the Project board, plus the coordination issue.
 *
 *   node sync-issues.mjs [--only <component>] [--dry-run] [--offline]
 *
 *   --dry-run  read GitHub, print the writes it would make, make none
 *   --offline  no GitHub at all: render every issue as if none existed (for checking bodies)
 *
 * Idempotent: an issue is found by the `<!-- unit:<component>/<id> -->` marker in its body; it is
 * created when missing, otherwise title, body and managed labels are updated only when they differ.
 * Managed labels: unit, kind:*, P0..P2, component:*, blocked. Never touched: agent:*, needs-review,
 * post-merge-finding, anything else a human added. Status flows one way, INDEX.md → GitHub.
 * A unit is `blocked` while a unit of its `needs` (same queue, or `<component>/<id>`) is not done.
 */
import { execFileSync } from "node:child_process";
import { existsSync, readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { loadConfig, loadQueue, isDone, isDropped } from "./lib.mjs";

const HERE = dirname(fileURLToPath(import.meta.url));
const argv = process.argv.slice(2);
const OFFLINE = argv.includes("--offline");
const DRY = OFFLINE || argv.includes("--dry-run") || process.env.MAB_DRY_RUN === "1";
const ONLY = argv.includes("--only") ? argv[argv.indexOf("--only") + 1] : null;
const GH = process.env.MAB_GH || "gh";

const conf = loadConfig();
const metaFile = join(dirname(conf.file), "mab.meta");
const meta = existsSync(metaFile)
  ? Object.fromEntries(readFileSync(metaFile, "utf8").split("\n").filter((l) => /^\w+=/.test(l)).map((l) => [l.slice(0, l.indexOf("=")), l.slice(l.indexOf("=") + 1)]))
  : {};

const sleep = (ms) => Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, ms);
const gh = (args) => {
  for (let attempt = 1; ; attempt++) {
    try {
      return execFileSync(GH, args, { encoding: "utf8", maxBuffer: 64 << 20, stdio: ["ignore", "pipe", "pipe"] }).trim();
    } catch (e) {
      // GitHub's secondary rate limit and its occasional 5xx: wait and retry rather than leave a half-synced queue.
      if (attempt < 4 && /rate limit|abuse|submitted too quickly|HTTP 5\d\d|502|503/i.test(String(e.stderr))) { sleep(30_000 * attempt); continue; }
      process.stderr.write(String(e.stderr ?? ""));
      throw e;
    }
  }
};
const ghJson = (args) => (OFFLINE ? null : JSON.parse(gh(args) || "null"));
const write = (args) => (DRY ? console.log("  [dry-run] gh " + args.map((a) => (/\s/.test(a) ? JSON.stringify(a.length > 60 ? a.slice(0, 57) + "..." : a) : a)).join(" ")) : gh(args));

/* ---- every queue, loaded once so cross-component needs resolve ---- */
const queues = {};
for (const c of conf.components) {
  if (existsSync(c.queue)) queues[c.name] = { ...loadQueue(c.queue), comp: c };
  else if (!ONLY || ONLY === c.name) console.log(`skip    ${c.name}: no queue at ${c.queue}`);
}
if (ONLY && !conf.components.some((c) => c.name === ONLY)) { console.error(`unknown component '${ONLY}'`); process.exit(2); }
const unitByKey = new Map();
for (const [name, q] of Object.entries(queues)) for (const u of q.units) unitByKey.set(`${name}/${u.id}`, u);
const needKey = (comp, n) => (n.includes("/") ? n : `${comp}/${n}`);

const LABELS = {
  unit: ["0E8A16", "One unit of the work queue"],
  blocked: ["000000", "Waiting on a unit listed in Needs"],
  P0: ["B60205", "The product is pointless without it"],
  P1: ["D93F0B", "The complete journey"],
  P2: ["FBCA04", "Everything else"],
  coordination: ["5319E7", "Multi-session coordination"],
  "needs-review": ["FBCA04", "A pull request waiting for the merge gate"],
  "post-merge-finding": ["D93F0B", "A defect an independent check found after a merge"],
};
const labelDef = (n) => LABELS[n] ?? (n.startsWith("kind:") ? ["D4C5F9", `Unit kind ${n.slice(5)}`] : n.startsWith("component:") ? ["EDEDED", `Unit of ${n.slice(10)}`] : ["EDEDED", ""]);
function ensureLabels(repo, names) {
  const have = new Set((ghJson(["label", "list", "-R", repo, "--limit", "1000", "--json", "name"]) ?? []).map((l) => l.name));
  let n = 0;
  for (const name of [...new Set(names)].filter((x) => x && !have.has(x))) {
    const [color, desc] = labelDef(name);
    n++;
    write(["label", "create", name, "-R", repo, "--color", color, "--description", desc]);
  }
  return n;
}

const coordRepo = conf.component(conf.coordComponent).repo;
const COORD = OFFLINE ? null : ghJson(["issue", "list", "-R", coordRepo, "--label", "coordination", "--state", "open", "--json", "number"])?.[0]?.number;
const list = (a) => (a?.length ? a.map((x) => `- ${x}`).join("\n") : "- _none_");
const code = (a) => (a ?? []).map((x) => `\`${x}\``);

function syncQueue(name, q) {
  const repo = q.comp.repo;
  if (!repo) throw new Error(`REPO_${name} missing in ${conf.file}`);
  const units = q.units.filter((u) => !isDropped(u));
  const key = (u) => `${name}/${u.id}`;
  const count = { created: 0, updated: 0, closed: 0, boardAdded: 0, boardStatus: 0, labels: 0 };

  const existing = ghJson(["issue", "list", "-R", repo, "--state", "all", "--limit", "2000", "--json", "number,title,body,labels,state,url"]) ?? [];
  const byKey = {};
  for (const i of existing) {
    const m = i.body?.match(/<!-- unit:([\w./-]+) -->/);
    if (m) byKey[m[1]] = i;
  }
  const ref = (k) => {
    const [c] = k.split("/");
    const n = c === name ? byKey[k]?.number : null;
    return n ? `#${n} \`${k.split("/").slice(1).join("/")}\`` : `\`${k}\``;
  };
  const blockedBy = (u) => u.needs.map((n) => needKey(name, n)).filter((k) => !isDone(unitByKey.get(k)));

  const body = (u) => {
    const g = u.group && q.groups.find((x) => x.id === u.group);
    const head = [`**Component** \`${name}\``, `**Kind** ${u.kind}`, `**Priority** ${u.priority}`, u.entry && `**Entry** \`${u.entry}\``, u.artifact && `**Artifact** \`${u.artifact}\``]
      .filter(Boolean).join(" · ");
    return `<!-- unit:${key(u)} -->
${head}
${g ? `\n> 🔗 Part of the **${g.title ?? g.id}** group — claimed and built in ONE pass with ${(g.units ?? []).filter((x) => x !== u.id).map((x) => ref(`${name}/${x}`)).join(", ")}.\n` : ""}
### Needs done first
${u.needs.length ? u.needs.map((n) => { const k = needKey(name, n); return `- ${ref(k)} — ${unitByKey.get(k)?.status || "unknown unit"}`; }).join("\n") : "- nothing"}

### Read before working
- \`CLAUDE.md\` and \`PROJECT-STATE.md\` of this repository
- \`work/handoffs/${u.id}.md\` — the handoff (owned files, states, Definition of Done, start prompt)
- Skills: ${code(u.skills).join(", ") || "_none listed_"}

### Owns (may create or edit ONLY these)
${list(code(u.owns))}

### States to cover
${list(u.states)}

### Watch-points
${list(u.notes)}

### Protocol
Claim: \`tools/mab/agentctl.sh claim ${name} <this issue>\`, then \`tools/mab/agentctl.sh wt ${name} <this issue> ${u.id}\` (branch \`unit/${u.id}\` from \`origin/${conf.base}\`). Gate: \`${q.comp.verify || "the component's verify command"}\`. PR to \`${conf.base}\` of \`${repo}\` with the label \`needs-review\` and \`Closes #<this issue>\`, then a 🚀 comment on the coordination issue${COORD ? ` ${coordRepo}#${COORD}` : ""}. Do not merge.
`;
  };
  const labelsOf = (u) => {
    const l = ["unit", `kind:${u.kind}`, u.priority, `component:${name}`];
    if (blockedBy(u).length) l.push("blocked");
    return l;
  };
  const managed = (l) => l === "unit" || l === "blocked" || l.startsWith("kind:") || l.startsWith("component:") || /^P[0-9]$/.test(l);

  count.labels = ensureLabels(repo, [...units.flatMap(labelsOf), "needs-review", "post-merge-finding", ...(name === conf.coordComponent ? ["coordination"] : [])]);

  /* pass 1: create missing issues, so references resolve in pass 2 */
  for (const u of units) {
    if (byKey[key(u)]) continue;
    const title = `[${u.id}] ${u.title ?? u.id}`;
    count.created++;
    if (DRY) { console.log(`create  ${repo} ${title}${OFFLINE ? `\n${body(u).replace(/^/gm, "    | ")}` : ""}`); continue; }
    const url = gh(["issue", "create", "-R", repo, "--title", title, "--body", body(u), "--label", labelsOf(u).join(",")]);
    byKey[key(u)] = { number: Number(url.split("/").pop()), url, title, body: body(u), labels: labelsOf(u).map((n) => ({ name: n })), state: "OPEN" };
  }

  /* pass 2: reconcile title, body, managed labels, state */
  for (const u of units) {
    const i = byKey[key(u)];
    if (!i || i.number === undefined) continue;
    const title = `[${u.id}] ${u.title ?? u.id}`;
    const want = labelsOf(u);
    const have = (i.labels ?? []).map((l) => l.name);
    const add = want.filter((l) => !have.includes(l));
    const remove = have.filter((l) => managed(l) && !want.includes(l));
    const args = ["issue", "edit", String(i.number), "-R", repo];
    if (i.title !== title) args.push("--title", title);
    if (i.body !== body(u)) args.push("--body", body(u));
    if (add.length) args.push("--add-label", add.join(","));
    if (remove.length) args.push("--remove-label", remove.join(","));
    if (args.length > 5) { console.log(`update  ${repo}#${i.number} ${u.id}`); count.updated++; write(args); }
    if (isDone(u) && i.state !== "CLOSED") { console.log(`close   ${repo}#${i.number}`); count.closed++; write(["issue", "close", String(i.number), "-R", repo]); }
  }

  /* the coordination issue, once, on the coordination component */
  if (name === conf.coordComponent && !COORD) {
    const tpl = [join(dirname(conf.file), "COORDINATION_ISSUE.md"), join(HERE, "..", "assets", "coordination-issue.md")].find(existsSync);
    console.log("create  coordination issue");
    write(["issue", "create", "-R", repo, "--title", "[coordination] Multi-session agent protocol", "--body", tpl ? readFileSync(tpl, "utf8") : "Coordination issue.", "--label", "coordination"]);
  }

  /* the board: every unit issue on it, Status set when missing (agentctl moves it during work) */
  if (!DRY && conf.projectNumber) {
    if (!meta.PROJECT_ID) console.log("skip    board: no tools/mab.meta (run agentctl.sh init-project)");
    else {
      const items = ghJson(["project", "item-list", String(conf.projectNumber), "--owner", conf.owner, "--limit", "3000", "--format", "json"])?.items ?? [];
      const itemOf = Object.fromEntries(items.filter((it) => it.content?.repository === repo).map((it) => [it.content.number, it]));
      const OPT = { todo: meta.STATUS_TODO_ID, inprogress: meta.STATUS_INPROGRESS_ID, done: meta.STATUS_DONE_ID };
      const NAME = { [conf.status.todo]: "todo", [conf.status.inprogress]: "inprogress", [conf.status.done]: "done" };
      for (const u of units) {
        const i = byKey[key(u)];
        if (!i) continue;
        let item = itemOf[i.number];
        if (!item) {
          count.boardAdded++;
          item = JSON.parse(gh(["project", "item-add", String(conf.projectNumber), "--owner", conf.owner, "--url", i.url ?? `https://github.com/${repo}/issues/${i.number}`, "--format", "json"]));
          item.status = null;
        }
        const want = isDone(u) ? "done" : /progress/i.test(u.status) ? "inprogress" : "todo";
        const have = NAME[item.status] ?? null;
        if (!have || (want === "done" && have !== "done")) {
          count.boardStatus++;
          gh(["project", "item-edit", "--project-id", meta.PROJECT_ID, "--id", item.id, "--field-id", meta.STATUS_FIELD_ID, "--single-select-option-id", OPT[want]]);
        }
      }
    }
  }
  const changes = Object.entries(count).filter(([, n]) => n).map(([k, n]) => `${k} ${n}`).join(", ") || "no change";
  console.log(`OK — ${repo}: ${units.length} unit issue(s) — ${changes}${DRY ? " (dry run)" : ""}.`);
}

for (const [name, q] of Object.entries(queues)) if (!ONLY || ONLY === name) syncQueue(name, q);
