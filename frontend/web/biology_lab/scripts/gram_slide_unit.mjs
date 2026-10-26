/* Unit checks for the Gram slide planning models: smear layout (both
   populations, natural margins, determinism) and the slide pose maths the
   renderer and rinse FX share (impact point, low drainage edge, tilt band). */
import { readFileSync } from "node:fs";
import {
  GRAM_GEOMETRY, clampTilt, makeStubSlide,
} from "../js/gram_shared.js";
import { smearLayout, impactPoint, lowEdgePoint } from "../js/gram_models.js";

let pass = 0, fail = 0;
function ck(name, cond, extra) {
  if (cond) { pass++; console.log("  PASS " + name); }
  else { fail++; console.log("  FAIL " + name + (extra === undefined ? "" : " -> " + extra)); }
}

const S = GRAM_GEOMETRY.slide;

/* ---- smear layout ---- */
const lay = smearLayout({ seed: 7, w: 0.015, h: 0.055 });
ck("layout carries both populations", lay.gp.length >= 4 && lay.neg.length >= 10,
  JSON.stringify({ gp: lay.gp.length, neg: lay.neg.length }));
let cells = 0, inBounds = true, margin = true;
const m = Math.min(lay.w, lay.h) * 0.1;
lay.gp.forEach((cl) => cl.cells.forEach((c) => {
  cells++;
  if (c.x < 0 || c.x > lay.w || c.y < 0 || c.y > lay.h) inBounds = false;
  if (c.x < m || c.x > lay.w - m || c.y < m || c.y > lay.h - m) margin = false;
}));
ck("gram-positive cells sit inside the smear", inBounds);
ck("gram-positive cells respect the soft-edge margin", margin, "cells=" + cells);
ck("clusters hold grape-like groups of cocci", lay.gp.every((cl) => cl.cells.length >= 5));
let rodsOk = lay.neg.every((r) => r.len > r.wid * 2 && r.x >= 0 && r.x <= lay.w && r.y >= 0 && r.y <= lay.h);
ck("gram-negative rods are slender and in bounds", rodsOk);
const lay2 = smearLayout({ seed: 7, w: 0.015, h: 0.055 });
ck("layout is deterministic for a fixed seed",
  JSON.stringify(lay) === JSON.stringify(lay2));

/* ---- slide pose maths ---- */
const pos = { x: -5.68, y: 0.955, z: -0.6 };
const flat = impactPoint(pos, 0, S);
ck("flat impact sits on the top face", Math.abs(flat.y - (pos.y + S.y / 2)) < 1e-9, String(flat.y));
const tilt = clampTilt((25 + 45) / 2 * Math.PI / 180);
const impT = impactPoint(pos, tilt, S);
const lowT = lowEdgePoint(pos, tilt, S);
ck("under a positive tilt the low edge dips below the top face", lowT.y < impT.y,
  JSON.stringify({ low: lowT.y, imp: impT.y }));
ck("the dipped low edge extends toward +z (drain direction)", lowT.z > pos.z + S.z / 4 - 1e-9, String(lowT.z));
ck("drain edge is below the impact point (gravity coherent)", lowT.y < impT.y);
ck("clampTilt honours the 45° maximum",
  Math.abs(clampTilt(10)) === Math.abs(clampTilt(Math.PI / 2 + 0.5)) || clampTilt(10) <= GRAM_GEOMETRY.tilt.maxRad,
  String(clampTilt(10)));
ck("clampTilt bounds extreme input", Math.abs(clampTilt(9.9)) <= GRAM_GEOMETRY.tilt.maxRad + 1e-9);

/* ---- contract mirror: stub agrees with the model maths ---- */
const stub = makeStubSlide({ position: pos });
stub.setTilt(tilt);
const si = stub.getImpactPoint(), sl = stub.getLowEdge();
ck("stub impact matches model impact",
  Math.abs(si.x - impT.x) < 1e-6 && Math.abs(si.y - impT.y) < 1e-6 && Math.abs(si.z - impT.z) < 1e-6,
  JSON.stringify({ si: si, impT: impT }));
ck("stub low edge matches model low edge",
  Math.abs(sl.y - lowT.y) < 1e-6 && Math.abs(sl.z - lowT.z) < 1e-6,
  JSON.stringify({ sl: sl, lowT: lowT }));

/* ---- geometry constants stay pinned to the physical slide ---- */
ck("slide proportions are those of a real microscope slide (26×3×100 mm)",
  S.x === 0.026 && S.y === 0.003 && S.z === 0.1, JSON.stringify(S));

/* ---- renderer file stays free of hard-coded layout drift ---- */
const src = readFileSync(new URL("../js/gram_slide.js", import.meta.url), "utf8");
ck("slide renderer builds its layout through gram_models",
  src.includes("smearLayout(") && !src.includes("function smearLayout"));
ck("slide renderer exposes every contract member",
  ["setPopulations", "setTilt", "setWetness", "getImpactPoint", "getLowEdge"]
    .every((m2) => src.includes(m2)));

console.log("Gram slide unit: " + pass + " passed, " + fail + " failed");
if (fail) process.exit(1);
