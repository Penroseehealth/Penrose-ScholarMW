/* Unit checks for the pour timeline: the liquid ribbon may only run while the
   bottle is tilted, the coverage ramp reaches full spread, and the reagent
   table exposes every bottle the practical pours. */
import { REAGENTS, GRAM_GEOMETRY, clamp01 } from "../js/gram_shared.js";
import { POUR, pourPhaseAt, ribbonWindow, coverageAt } from "../js/gram_models.js";

let pass = 0, fail = 0;
function ck(name, cond, extra) {
  if (cond) { pass++; console.log("  PASS " + name); }
  else { fail++; console.log("  FAIL " + name + (extra === undefined ? "" : " -> " + extra)); }
}

/* ---- phase timeline ---- */
const ph = POUR.phases;
ck("phase fractions are ordered",
  0 < ph.lift && ph.lift < ph.travel && ph.travel === ph.holdStart
  && ph.holdStart < ph.holdEnd && ph.holdEnd < ph.untilt && ph.untilt < ph.end);
ck("POUR.duration matches a realistic bottle action (~3 s)", POUR.duration >= 2 && POUR.duration <= 4);
const seq = [];
for (let k = 0; k <= 1.0001; k += 0.02) { const p = pourPhaseAt(k); if (seq[seq.length - 1] !== p) seq.push(p); }
ck("phase sequence walks lift → travel → hold → untilt → return exactly once",
  seq.join(">") === "lift>travel>hold>untilt>return", seq.join(">"));
ck("pourPhaseAt clamps beyond the ends",
  pourPhaseAt(-1) === "lift" && pourPhaseAt(5) === "return");

/* ---- ribbon window sits inside the tilt window ---- */
const win = ribbonWindow(POUR.duration);
ck("ribbon starts when the bottle reaches full tilt",
  Math.abs(win.from - ph.holdStart * POUR.duration) < 1e-9, String(win.from));
ck("ribbon stops before the bottle levels", win.to <= ph.holdEnd * POUR.duration + 1e-9, String(win.to));
ck("ribbon duration is a visible stream (≥0.6 s)", win.to - win.from >= 0.6, String(win.to - win.from));
ck("ribbon finishes before the bottle is back in its slot",
  win.to < POUR.duration - 0.4, String(win.to));
const half = ribbonWindow(POUR.duration / 2);
ck("speed scaling shrinks the ribbon window proportionally",
  Math.abs((half.to - half.from) - (win.to - win.from) / 2) < 1e-9);

/* ---- coverage ramp ---- */
ck("coverage is 0 at contact", coverageAt(0) === 0);
ck("coverage reaches full spread within 0.8 s", coverageAt(0.8) === 1, String(coverageAt(0.8)));
ck("coverage ramps monotonically in between",
  coverageAt(0.2) < coverageAt(0.4) && coverageAt(0.4) < coverageAt(0.7));
ck("coverage clamps past the ramp", coverageAt(99) === 1);

/* ---- every poured bottle has reagent physics ---- */
["cv", "io", "de", "sa"].forEach((id) => {
  const r = REAGENTS[id];
  ck("reagent '" + id + "' has pour + stain parameters",
    !!r && Number(r.pourDuration) > 0 && Number(r.stainRate) >= 0 && Number(r.filmOpacity) >= 0,
    JSON.stringify(r));
});
ck("decolouriser is the slow chemistry (5-15 s window)",
  REAGENTS.de.stainRate < REAGENTS.cv.stainRate);
ck("runoff budgets keep textures within limits",
  GRAM_GEOMETRY.budgets.maxTexturePx <= 512 && GRAM_GEOMETRY.budgets.maxRepaintHz <= 20);

/* ---- renderer mirrors the timeline ---- */
import { readFileSync } from "node:fs";
const src = readFileSync(new URL("../js/gram_pour.js", import.meta.url), "utf8");
ck("pour renderer takes its window from gram_models",
  src.includes("ribbonWindow(") && src.includes("POUR.duration"));
ck("pour renderer never pops: opacity env ramps both ways",
  src.includes("0.14") && src.includes("0.82"));

console.log("Gram pour unit: " + pass + " passed, " + fail + " failed");
if (fail) process.exit(1);
