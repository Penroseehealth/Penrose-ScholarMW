/**
 * Automated validation of the laboratory theme catalogue (themes.js).
 *
 * Asserts: exactly 20 themes, unique names, every required slot present as a
 * valid 24-bit hex (or null for `fill` = original mixed cupboard fills), no
 * forbidden safety/scientific keys, and that every theme is clearly
 * distinguishable from the Classic baseline.
 *
 * Run: node scripts/themes_test.mjs   (exit code 0 = pass)
 */
import { dirname, join } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const ROOT = dirname(dirname(fileURLToPath(import.meta.url)));
// themes.js is a browser classic script (UMD-ish): it attaches to the global
// object, which is exactly what index.html reads as window.BIO_LAB_THEMES.
await import(pathToFileURL(join(ROOT, "themes.js")).href);
const THEMES = globalThis.BIO_LAB_THEMES;

const SLOTS = [
  "floor", "wall", "dado", "rail", "ceil", "slab", "top", "carcass", "door", "cab",
  "plinth", "dark", "frame", "shelf", "board", "baseClad", "fill",
];
const FORBIDDEN = ["red", "extRed", "liquid", "glass", "winGlass", "steel", "chrome", "panel"];

let failures = 0;
const fail = (msg) => { failures++; console.error("FAIL  " + msg); };
const ok = (msg) => console.log("ok    " + msg);

if (!Array.isArray(THEMES)) fail("themes.js did not export an array");
else ok(`exported ${THEMES.length} themes`);

if (THEMES.length !== 20) fail(`expected exactly 20 themes, got ${THEMES.length}`);
else ok("exactly 20 themes");

const names = new Set();
const signatures = new Set();
const base = THEMES[0];

THEMES.forEach((th, i) => {
  const label = `theme[${i}]`;
  if (typeof th.name !== "string" || !th.name.trim()) fail(`${label}: missing name`);
  else if (names.has(th.name)) fail(`${label}: duplicate name '${th.name}'`);
  else names.add(th.name);

  for (const slot of SLOTS) {
    const v = th[slot];
    if (slot === "fill") {
      if (v !== null && !(Number.isInteger(v) && v >= 0 && v <= 0xffffff)) {
        fail(`${label} (${th.name}): fill must be hex int or null`);
      }
      continue;
    }
    if (!Number.isInteger(v) || v < 0 || v > 0xffffff) {
      fail(`${label} (${th.name}): slot '${slot}' is not a 24-bit hex int (got ${v})`);
    }
  }

  for (const key of Object.keys(th)) {
    if (FORBIDDEN.includes(key)) fail(`${label} (${th.name}): forbidden scientific/safety key '${key}'`);
  }

  // Distinguishability: the whole-room slots must differ from Classic on >= 3
  // of the 5 most visible surfaces (Classic itself is exempt — it IS the baseline).
  if (i > 0) {
    let diff = 0;
    for (const slot of ["floor", "wall", "top", "cab", "door"]) {
      if (th[slot] !== base[slot]) diff++;
    }
    if (diff < 3) fail(`${label} (${th.name}): too similar to Classic (${diff}/5 core slots differ)`);

    const sig = ["floor", "wall", "top", "cab"].map((s) => th[s]).join(",");
    if (signatures.has(sig)) fail(`${label} (${th.name}): identical floor/wall/top/cab combination as another theme`);
    signatures.add(sig);
  }
});

if (failures === 0) {
  ok("all themes pass structure, safety and distinctness checks");
  console.log(`\nPASS  ${THEMES.length} laboratory themes validated`);
  process.exit(0);
} else {
  console.error(`\nFAIL  ${failures} check(s) failed`);
  process.exit(1);
}
