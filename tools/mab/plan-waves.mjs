#!/usr/bin/env node
/**
 * Plans the build waves from the unit queues (units.json of each component). Offline: no GitHub.
 *
 *   node plan-waves.mjs [--component <name>] [--json]
 *
 * Prints, per component:
 *   - wave 1 = the units ready now (every need done), with the model tier each deserves;
 *   - owned-file overlaps inside wave 1 (those units must run sequentially, or be grouped);
 *   - the later waves (dependency levels) and anything unreachable (unknown need or cycle).
 * A need written `<component>/<id>` points into another component's queue.
 * Keystone = a unit that a large share of the remaining work depends on: give it the strongest model.
 */
import { existsSync } from "node:fs";
import { loadConfig, loadQueue, isDone, isDropped, ownsOverlap } from "./lib.mjs";

const argv = process.argv.slice(2);
const opt = (k) => (argv.includes(k) ? argv[argv.indexOf(k) + 1] : null);
const JSON_OUT = argv.includes("--json");
const ONLY = opt("--component");

const conf = loadConfig();
const queues = {};
for (const c of conf.components) if (existsSync(c.queue)) queues[c.name] = loadQueue(c.queue);
if (ONLY && !queues[ONLY]) {
  console.error(`no queue for component '${ONLY}' (looked for ${conf.component(ONLY).queue})`);
  process.exit(2);
}

const keyOf = (comp, id) => `${comp}/${id}`;
const all = new Map();
for (const [comp, q] of Object.entries(queues)) for (const u of q.units) all.set(keyOf(comp, u.id), { ...u, comp });
const resolveNeed = (comp, n) => (n.includes("/") ? n : keyOf(comp, n));

const report = {};
for (const [comp, q] of Object.entries(queues)) {
  if (ONLY && comp !== ONLY) continue;
  const remaining = q.units.filter((u) => !isDone(u) && !isDropped(u));
  const done = new Set([...all.values()].filter(isDone).map((u) => keyOf(u.comp, u.id)));
  const unknown = remaining.flatMap((u) => u.needs.map((n) => resolveNeed(comp, n)).filter((k) => !all.has(k)).map((k) => `${u.id} → ${k}`));

  // Dependency levels over the remaining units of this component (other components' needs must be done already).
  const waves = [];
  const placed = new Set(done);
  let pending = [...remaining];
  while (pending.length) {
    const wave = pending.filter((u) => u.needs.every((n) => placed.has(resolveNeed(comp, n))));
    if (!wave.length) break;
    waves.push(wave);
    for (const u of wave) placed.add(keyOf(comp, u.id));
    pending = pending.filter((u) => !wave.includes(u));
  }
  const stuck = pending.map((u) => ({ id: u.id, waitingOn: u.needs.map((n) => resolveNeed(comp, n)).filter((k) => !placed.has(k)) }));

  // Transitive dependants among the remaining units → keystones.
  const dependants = (id) => {
    const seen = new Set();
    const walk = (k) => {
      for (const u of remaining) if (!seen.has(u.id) && u.needs.some((n) => resolveNeed(comp, n) === k)) { seen.add(u.id); walk(keyOf(comp, u.id)); }
    };
    walk(keyOf(comp, id));
    return seen.size;
  };
  const threshold = Math.max(3, Math.ceil(remaining.length * 0.3));
  const tier = (u) => (dependants(u.id) >= threshold || /contract|shared|foundation|kit/i.test(u.kind) ? "strongest (keystone)" : "standard");

  const ready = waves[0] ?? [];
  const overlaps = [];
  for (let i = 0; i < ready.length; i++)
    for (let j = i + 1; j < ready.length; j++) {
      const a = ready[i], b = ready[j];
      if (a.group && a.group === b.group) continue;
      const hits = ownsOverlap(a.owns, b.owns);
      if (hits.length) overlaps.push({ a: a.id, b: b.id, files: hits });
    }
  const noOwns = ready.filter((u) => !u.owns.length).map((u) => u.id);

  report[comp] = {
    ready: ready.map((u) => ({ id: u.id, title: u.title, priority: u.priority, group: u.group, dependants: dependants(u.id), model: tier(u) })),
    overlaps, noOwns,
    later: waves.slice(1).map((w) => w.map((u) => u.id)),
    stuck, unknown,
    counts: { done: q.units.filter(isDone).length, remaining: remaining.length, dropped: q.units.filter(isDropped).length },
  };
}

if (JSON_OUT) {
  console.log(JSON.stringify(report, null, 2));
} else {
  for (const [comp, r] of Object.entries(report)) {
    console.log(`\n== ${comp}: ${r.counts.done} done, ${r.counts.remaining} remaining, ${r.counts.dropped} dropped`);
    console.log(`wave 1 — ready now (${r.ready.length}):`);
    const order = { P0: 0, P1: 1, P2: 2 };
    for (const u of [...r.ready].sort((x, y) => (order[x.priority] ?? 9) - (order[y.priority] ?? 9)))
      console.log(`  ${u.priority}  ${u.id}${u.group ? ` [group ${u.group}]` : ""}  — ${u.dependants} dependant(s), model: ${u.model}`);
    for (const o of r.overlaps) console.log(`  ! overlap ${o.a} ↔ ${o.b}: ${o.files.join(", ")} — run sequentially or group them`);
    if (r.noOwns.length) console.log(`  ! no owns list: ${r.noOwns.join(", ")} — declare owned files before launching`);
    r.later.forEach((w, i) => console.log(`wave ${i + 2}: ${w.join(", ")}`));
    for (const s of r.stuck) {
      const other = s.waitingOn.filter((k) => !k.startsWith(`${comp}/`) && !r.unknown.some((x) => x.endsWith(k)));
      if (other.length === s.waitingOn.length) console.log(`  waits  ${s.id}: on ${other.join(", ")} (another component, not done yet)`);
      else console.log(`  ! unreachable ${s.id}: waits on ${s.waitingOn.join(", ")} (unknown unit or dependency cycle)`);
    }
    for (const u of r.unknown) console.log(`  ! unknown need: ${u}`);
  }
}
