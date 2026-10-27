#!/usr/bin/env node
/**
 * Checks that a branch only changed files its unit owns.
 *
 *   git diff --name-only origin/dev...HEAD | node owns-check.mjs <component> <unit-id>
 *
 * Allowed: the unit's `owns` (files, dirs ending in '/', globs), plus STATE_FILE, UNION_FILES and
 * OWNS_ALWAYS from the config. Prints every file outside that list; exit 1 when there is one,
 * exit 2 when the unit is unknown or has no owns list.
 */
import { existsSync, readFileSync } from "node:fs";
import { loadConfig, loadQueue, matchesAny } from "./lib.mjs";

const [comp, unitId] = process.argv.slice(2);
if (!comp || !unitId) { console.error("usage: … | node owns-check.mjs <component> <unit-id>"); process.exit(2); }
const conf = loadConfig();
const c = conf.component(comp);
if (!existsSync(c.queue)) { console.error(`no queue at ${c.queue}`); process.exit(2); }
const unit = loadQueue(c.queue).units.find((u) => u.id === unitId);
if (!unit) { console.error(`unit '${unitId}' is not in ${c.queue}`); process.exit(2); }
if (!unit.owns.length) { console.error(`unit '${unitId}' declares no owns list`); process.exit(2); }

const allowed = [...unit.owns, conf.stateFile, ...conf.unionFiles, ...conf.ownsAlways];
const files = readFileSync(0, "utf8").split("\n").map((s) => s.trim()).filter(Boolean);
const outside = files.filter((f) => !matchesAny(f, allowed));
for (const f of outside) console.log(`outside owns: ${f}`);
process.exit(outside.length ? 1 : 0);
