/* Unit checks for the choreography director: pours fire exactly at the four
   stain steps inside the bottle's tilt window, rinses start after arrival and
   stop on leaving, the slide holds the wash angle during rinses, chemistry
   accumulates across steps (purple Gram+ through decolourisation, pink Gram-
   after safranin, film cleared by the final rinse) and resets on replay. */
import {
  createStainState, makeStubSlide, makeStubPour, makeStubRinse, GRAM_GEOMETRY, REAGENTS,
} from "../js/gram_shared.js";
import { RINSE, ribbonWindow, POUR } from "../js/gram_models.js";
import { createGramChoreo } from "../js/gram_choreo.js";

let pass = 0, fail = 0;
function ck(name, cond, extra) {
  if (cond) { pass++; console.log("  PASS " + name); }
  else { fail++; console.log("  FAIL " + name + (extra === undefined ? "" : " -> " + extra)); }
}

/* mirror of the eleven GP_STEPS entries the integration passes in */
const STEPS = [
  { n: "Loop & smear", k: "flame", a: "slide" },
  { n: "Crystal violet", k: "stain", a: "bottle:cv" },
  { n: "Water rinse", k: "rinse", a: "tap" },
  { n: "Iodine", k: "stain", a: "bottle:io" },
  { n: "Water rinse", k: "rinse", a: "tap" },
  { n: "Decolorize", k: "stain", a: "bottle:de" },
  { n: "Water rinse", k: "rinse", a: "tap" },
  { n: "Safranin", k: "stain", a: "bottle:sa" },
  { n: "Water rinse", k: "rinse", a: "tap" },
  { n: "Warm", k: "flame", a: "slide" },
  { n: "Microscope", k: "none", a: "micro" },
];

function fakeChem() {
  let base = createStainState();
  const fx = { resetCalls: 0 };
  fx.applyReagent = function () { return base.applyReagent.apply(base, arguments); };
  fx.rinse = function () { return base.rinse.apply(base, arguments); };
  fx.setDamp = function () { return base.setDamp.apply(base, arguments); };
  fx.getDamp = function () { return base.getDamp(); };
  fx.snapshot = function () { return base.snapshot(); };
  fx.reset = function () { fx.resetCalls++; base = createStainState(); };
  return fx;
}

const slide = makeStubSlide({ position: { x: -5.68, y: 0.955, z: -0.6 } });
const pour = makeStubPour({});
const rinse = makeStubRinse({});
const chem = fakeChem();
const tapStub = { mode: "drip", target: 1, t: 1 };
const ch = createGramChoreo({
  slide: slide, pour: pour, rinse: rinse, steps: STEPS, chem: chem,
  deps: {
    route: (id) => ({ from: { x: -5.25, y: 1.23, z: 0.18 }, to: slide.getImpactPoint() }),
    tap: () => tapStub,
  },
});

const DT = 1 / 30;
function run(stepIdx, seconds) {
  ch.setStep(stepIdx);
  for (let s = 0; s * DT < seconds; s++) ch.tick(DT);
}

/* ---- stain step: pour fires inside the bottle tilt window ---- */
ch.setStep(1);
for (let s = 0; s * DT < ribbonWindow(POUR.duration).from - 0.05; s++) ch.tick(DT);
ck("no liquid before the bottle is tilted", pour.calls.pours.length === 0,
  JSON.stringify(pour.calls.pours));
for (let s = 0; s * DT < 1.2; s++) ch.tick(DT);
ck("one pour once the bottle holds its tilt", pour.calls.pours.length === 1, String(pour.calls.pours.length));
ck("the pour carries the stage's reagent id", pour.calls.pours[0].reagentId === "cv");
ck("the pour has a route with from and to", !!pour.calls.pours[0].from && !!pour.calls.pours[0].to);
ck("slide stays level while staining", Math.abs(slide.getTilt()) < 1e-6, String(slide.getTilt()));

/* ---- rinse step: arrival → tilt → tap stream mode ---- */
run(2, RINSE.arriveAt + RINSE.tiltRamp + 0.5);
ck("rinse started after the slide arrived", rinse.calls.starts.length === 1);
ck("rinse carries the last stain being washed", rinse.calls.starts[0].reagentId === "cv");
ck("tap was forced into continuous stream mode", tapStub.mode === "stream", tapStub.mode);
ck("slide holds a wash tilt inside the working band",
  slide.getTilt() >= GRAM_GEOMETRY.tilt.minRad - 1e-6 && slide.getTilt() <= GRAM_GEOMETRY.tilt.maxRad + 1e-6,
  String(slide.getTilt()));
ck("chemistry is being rinsed", chem.snapshot().film.alpha >= 0);

/* ---- leaving the rinse stops water and levels the slide ---- */
run(3, 1.0);
ck("rinse stopped when the stage changed", rinse.calls.stops >= 1, String(rinse.calls.stops));
ck("tap mode restored after the rinse", tapStub.mode === "drip", tapStub.mode);
ck("slide returns toward level off the rinse",
  Math.abs(slide.getTilt()) < 0.05, String(slide.getTilt()));

/* ---- full sequence: correct staining principles at the end ---- */
const slide2 = makeStubSlide({ position: { x: -5.68, y: 0.955, z: -0.6 } });
const pour2 = makeStubPour({});
const rinse2 = makeStubRinse({});
const chem2 = fakeChem();
const ch2 = createGramChoreo({
  slide: slide2, pour: pour2, rinse: rinse2, steps: STEPS, chem: chem2,
  deps: { route: () => ({ from: { x: 0, y: 1, z: 0 }, to: { x: 0, y: 0, z: 0 } }), tap: () => tapStub },
});
const times = [6, 8, 4, 8, 4, 8, 4, 8, 4, 4, 2];  /* generous per-stage dwell */
for (let i = 0; i < STEPS.length; i++) {
  ch2.setStep(i);
  for (let s = 0; s * DT < times[i]; s++) ch2.tick(DT);
}
const snap = chem2.snapshot();
const hex = (v) => "#" + v.toString(16).padStart(6, "0");
ck("four reagent pours fired across the run",
  pour2.calls.pours.length === 4 && pour2.calls.pours.map((p) => p.reagentId).join() === "cv,io,de,sa",
  JSON.stringify(pour2.calls.pours));
ck("four rinses ran", rinse2.calls.starts.length === 4, String(rinse2.calls.starts.length));
ck("Gram-positive cells keep the purple complex to the end",
  (snap.pos.colour & 255) > ((snap.pos.colour >> 16) & 255)
  && ((snap.pos.colour >> 16) & 255) > ((snap.pos.colour >> 8) & 255),
  hex(snap.pos.colour));
ck("Gram-positive cells stay fully stained", snap.pos.alpha > 0.9, String(snap.pos.alpha));
ck("Gram-negative cells are pink-red after safranin", snap.neg.colour === REAGENTS.sa.colour, hex(snap.neg.colour));
ck("Gram-negative opacity recovered by the counterstain", snap.neg.alpha > 0.8, String(snap.neg.alpha));
ck("final rinse clears the reagent film", snap.film.alpha < 0.05, String(snap.film.alpha));

/* ---- replay resets the chemistry ---- */
ch2.setStep(0);
ck("replaying from the top resets chemistry",
  chem2.resetCalls >= 1 && chem2.snapshot().pos.alpha === 0,
  JSON.stringify({ resets: chem2.resetCalls, alpha: chem2.snapshot().pos.alpha }));
ck("inspection helpers report state", ch2.getLastStain() === null && ch2.getStep() === 0);

console.log("Gram choreo unit: " + pass + " passed, " + fail + " failed");
if (fail) process.exit(1);
