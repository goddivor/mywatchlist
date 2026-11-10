/**
 * Shared helpers for the node scripts of multi-agent-build: config loading (the same
 * tools/mab.config bash sources), queue loading (units.json) and owned-path matching.
 * Dependency-free.
 */
import { existsSync, readFileSync, realpathSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { execFileSync } from "node:child_process";

export function findConfig(start = process.cwd()) {
  if (process.env.MAB_CONFIG) return resolve(process.env.MAB_CONFIG);
  let d = resolve(start);
  for (;;) {
    const f = join(d, "tools", "mab.config");
    if (existsSync(f)) return f;
    const up = dirname(d);
    if (up === d) throw new Error(`no tools/mab.config found above ${start} (or set MAB_CONFIG)`);
    d = up;
  }
}

/* A linked worktree resolves to its main checkout, like lib.sh's main_checkout_of. */
function mainCheckoutOf(dir) {
  try {
    const top = realpathSync(execFileSync("git", ["-C", dir, "rev-parse", "--show-toplevel"], { encoding: "utf8", stdio: ["ignore", "pipe", "ignore"] }).trim());
    const common = realpathSync(execFileSync("git", ["-C", dir, "rev-parse", "--path-format=absolute", "--git-common-dir"], { encoding: "utf8", stdio: ["ignore", "pipe", "ignore"] }).trim());
    if (top === realpathSync(dir) && dirname(common) !== top) return dirname(common);
  } catch { /* not a repository */ }
  return dir;
}

/* Parses KEY=value lines: strips quotes, drops trailing comments on unquoted values. */
export function parseConfig(text) {
  const out = {};
  for (const raw of text.split("\n")) {
    const line = raw.trim();
    const m = line.match(/^([A-Za-z_][A-Za-z0-9_]*)=(.*)$/);
    if (!m) continue;
    let v = m[2].trim();
    const q = v[0];
    if (q === '"' || q === "'") {
      const end = v.indexOf(q, 1);
      v = end > 0 ? v.slice(1, end) : v.slice(1);
    } else {
      v = v.replace(/\s+#.*$/, "");
    }
    out[m[1]] = v;
  }
  return out;
}

export function loadConfig(start) {
  let file = findConfig(start);
  const projectDir = mainCheckoutOf(dirname(dirname(file)));
  if (existsSync(join(projectDir, "tools", "mab.config"))) file = join(projectDir, "tools", "mab.config");
  const c = parseConfig(readFileSync(file, "utf8"));
  if (!c.OWNER || !c.COMPONENTS) throw new Error(`OWNER and COMPONENTS are required in ${file}`);
  const components = c.COMPONENTS.split(/\s+/).filter(Boolean);
  const comp = (name) => {
    const dir = resolve(projectDir, c[`PATH_${name}`] || ".");
    return {
      name,
      repo: c[`REPO_${name}`],
      dir,
      queue: join(dir, c[`QUEUE_${name}`] || "work/units.json"),
      index: join(dir, c[`INDEX_${name}`] || "work/INDEX.md"),
      verify: c[`VERIFY_${name}`] || "",
    };
  };
  return {
    file,
    projectDir,
    raw: c,
    owner: c.OWNER,
    projectNumber: c.PROJECT_NUMBER,
    base: c.BASE_BRANCH || "dev",
    coordComponent: c.COORD_COMPONENT || components[0],
    stateFile: c.STATE_FILE || "PROJECT-STATE.md",
    unionFiles: (c.UNION_FILES || "docs/DECISIONS.md").split(/\s+/).filter(Boolean),
    ownsAlways: (c.OWNS_ALWAYS || "").split(/\s+/).filter(Boolean),
    status: { todo: c.STATUS_TODO || "Todo", inprogress: c.STATUS_INPROGRESS || "In Progress", done: c.STATUS_DONE || "Done" },
    components: components.map(comp),
    component: (name) => {
      if (!components.includes(name)) throw new Error(`unknown component '${name}' (COMPONENTS="${c.COMPONENTS}")`);
      return comp(name);
    },
  };
}

/* units.json, normalised: every field the scripts read exists with a safe default. */
export function loadQueue(file) {
  const q = JSON.parse(readFileSync(file, "utf8"));
  const units = (q.units ?? []).map((u) => ({
    ...u,
    kind: u.kind ?? "unit",
    priority: u.priority ?? "P2",
    needs: u.needs ?? [],
    owns: u.owns ?? [],
    skills: u.skills ?? [],
    states: u.states ?? [],
    notes: u.notes ?? [],
    status: u.status ?? "",
    group: u.group ?? null,
    dropped: u.dropped ?? null,
  }));
  return { groups: q.groups ?? [], units };
}

export const isDone = (u) => /done/i.test(u?.status ?? "");
export const isDropped = (u) => Boolean(u?.dropped) || /dropped/i.test(u?.status ?? "");

/* Owned paths may be exact files, directories ending in '/', or globs with * and **. */
export function globToRegExp(glob) {
  if (glob.endsWith("/")) glob += "**";
  let re = "";
  for (let i = 0; i < glob.length; i++) {
    const ch = glob[i];
    if (ch === "*") {
      if (glob[i + 1] === "*") {
        i++;
        if (glob[i + 1] === "/") { i++; re += "(?:.*/)?"; } else re += ".*";
      } else re += "[^/]*";
    } else if (ch === "?") re += "[^/]";
    else re += ch.replace(/[.+^${}()|[\]\\]/g, "\\$&");
  }
  return new RegExp(`^${re}$`);
}
export const matchesAny = (file, globs) => globs.some((g) => globToRegExp(g).test(file));

/* Literal prefix before the first wildcard: two owned paths may overlap when one prefix starts the other. */
const literalPrefix = (g) => {
  const i = g.search(/[*?]/);
  return i < 0 ? g : g.slice(0, i);
};
export function ownsOverlap(a, b) {
  const hits = [];
  for (const x of a)
    for (const y of b) {
      const wild = /[*?]/.test(x) || /[*?]/.test(y) || x.endsWith("/") || y.endsWith("/");
      if (!wild) { if (x === y) hits.push(x); continue; }
      const px = literalPrefix(x), py = literalPrefix(y);
      if (px.startsWith(py) || py.startsWith(px) || matchesAny(x, [y]) || matchesAny(y, [x])) hits.push(`${x} ~ ${y}`);
    }
  return hits;
}
