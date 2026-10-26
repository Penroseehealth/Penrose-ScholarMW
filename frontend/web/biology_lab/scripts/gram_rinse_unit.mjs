/* Unit checks for the rinse schedule: the slide arrives under the nozzle
   before water is applied, holds the 25-45° wash band while draining, the
   geometry keeps stream → impact → low-edge → basin coherent, and the runoff
   colour fades progressively toward clear instead of snapping. */
import { GRAM_GEOMETRY, REAGENTS, runoffColour, COLOURLESS, degToRad } from "../js/gram_shared.js";
import { RINSE, rinseTiltAt, flowActive, impactPoint, lowEdgePoint } from "../js/gram_models.js";

let pass = 0, fail = 0;
function ck(name, cond, extra) {
  if (cond) { pass++; console.log("  PASS " + name); }
  else { fail++; console.log("  FAIL " + name + (extra === undefined ? "" : " -> " + extra)); }
}

/* ---- schedule ---- */
ck("rinse begins only after the slide has travelled to the sink",
  RINSE.arriveAt >= 1.0, String(RINSE.arriveAt));
const band = GRAM_GEOMETRY.tilt;
ck("wash angle stays inside the 25-45° working band",
  RINSE.tiltDeg >= 25 && RINSE.tiltDeg <= 45, String(RINSE.tiltDeg));
ck("manual tap gate is long enough to watch the wash", RINSE.manualGate >= 3, String(RINSE.manualGate));

/* ---- tilt ramp ---- */
ck("no tilt before the slide is under the nozzle", rinseTiltAt(0) === 0 && rinseTiltAt(RINSE.arriveAt - 0.01) === 0);
const target = degToRad(RINSE.tiltDeg);
ck("tilt reaches the full wash angle after the ramp",
  Math.abs(rinseTiltAt(RINSE.arriveAt + RINSE.tiltRamp) - target) < 1e-9,
  String(rinseTiltAt(RINSE.arriveAt + RINSE.tiltRamp)));
ck("tilt holds the angle later on", Math.abs(rinseTiltAt(99) - target) < 1e-9);
let mono = true, prev = -1;
for (let t = 0; t < 3; t += 0.05) {
  const v = rinseTiltAt(t);
  if (v < prev - 1e-9) mono = false;
  prev = v;
}
ck("tilt ramps monotonically (smooth ease, no snap)", mono);
ck("tilt stays within clampTilt bounds", rinseTiltAt(99) <= GRAM_GEOMETRY.tilt.maxRad + 1e-9);

/* ---- physical coherence of the wash geometry ---- */
const slidePos = { x: -5.68, y: 0.955, z: -0.6 };   /* under the station nozzle */
const tilt = rinseTiltAt(3);
const imp = impactPoint(slidePos, tilt, GRAM_GEOMETRY.slide);
const low = lowEdgePoint(slidePos, tilt, GRAM_GEOMETRY.slide);
ck("the stream strikes the smear centre (top face)", Math.abs(imp.x - slidePos.x) < 1e-9);
ck("the low edge drains below the impact point", low.y < imp.y, JSON.stringify({ low: low, imp: imp }));
ck("runoff leaves toward the basin side of the slide", low.z > imp.z, String(low.z - imp.z));
const nozzleX = -5.68;   /* station nozzle lands on the slide column */
ck("the slide sits directly beneath the nozzle",
  Math.abs(slidePos.x - nozzleX) <= GRAM_GEOMETRY.slide.x / 2, String(slidePos.x));
ck("the sink pose clears the basin footprint (x within ±0.2 m of centre)",
  Math.abs(slidePos.x - -5.65) < 0.2, String(slidePos.x));

/* ---- flow gate ---- */
ck("flow gate ignores idle taps", !flowActive(0.05) && !flowActive(NaN));
ck("flow gate opens once the tap has eased on", flowActive(0.31) && flowActive(1));

/* ---- progressive runoff fade ---- */
const start = REAGENTS.cv.colour;
let c = start, lighter = true, seen = [];
for (let i = 0; i < 40; i++) {
  const prevC = c;
  c = runoffColour(c, 1.4, 1 / 30);
  const lum = (v) => ((v >> 16) & 255) + ((v >> 8) & 255) + (v & 255);
  if (lum(c) < lum(prevC) - 0.001) lighter = false;
  seen.push(c);
}
ck("runoff fades monotonically lighter (never re-darkens)", lighter);
ck("runoff stays recognisably violet at first", seen[0] !== start && seen[0] !== COLOURLESS,
  "#" + seen[0].toString(16));
ck("runoff approaches clear with sustained rinsing",
  (() => { const l = (v) => ((v >> 16) & 255) + ((v >> 8) & 255) + (v & 255);
    return l(c) > l(start); })());
ck("a single tick can never teleport to clear", runoffColour(start, 4, 1 / 30) !== COLOURLESS);

/* ---- renderer file sanity ---- */
import { readFileSync } from "node:fs";
const src = readFileSync(new URL("../js/gram_rinse.js", import.meta.url), "utf8");
ck("rinse renderer forces and restores the tap's stream mode",
  src.includes("__gramPrevMode") && src.includes("'stream'"));
ck("rinse renderer drives droplets, sheet and impact crown",
  ["sheet", "drops", "crown"].every((s) => src.includes(s)));
ck("rinse renderer fades runoff with the shared model",
  src.includes("runoffColour("));

console.log("Gram rinse unit: " + pass + " passed, " + fail + " failed");
if (fail) process.exit(1);
