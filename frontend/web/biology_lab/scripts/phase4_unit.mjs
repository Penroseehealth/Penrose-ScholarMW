/**
 * Phase 4 unit tests: scientific simulation layer (js/science.js)
 * (no browser, no THREE).
 *
 * Exercises the real experiment registry: documented rules, deterministic
 * results, explicit uncertainty, and microscope optics with meaningful
 * consequences for incorrect settings.
 *
 * Run: node scripts/phase4_unit.mjs   (exit 0 = all pass)
 */
import { createScience } from "../js/science.js";

const checks = [];
let fails = 0;
const check = (name, ok, detail) => {
  checks.push({ name, ok: Boolean(ok), detail });
  if (!ok) fails++;
  console.log(`${ok ? "PASS" : "FAIL"}  ${name}${detail ? "  [" + detail + "]" : ""}`);
};

const s = createScience();

/* ---- registry ---- */
const ids = s.experiments().map((e) => e.id);
check("registry exposes >= 9 experiments", ids.length >= 9, ids.join(","));
for (const id of ["osmosis", "enzyme", "foodTests", "photosynthesis", "germination", "respiration", "transpiration", "quadrat", "microorganisms"]) {
  check(`module present: ${id}`, ids.includes(id));
}
check("every module documents objective/apparatus/principles/safety/assumptions",
  s.experiments().every((e) =>
    e.objective && e.apparatus.length && e.principles.length && e.safety.length && e.assumptions.length));
check("every module input declares a default", s.experiments().every((e) =>
  Object.values(e.inputs).every((inp) => inp.def !== undefined)));
check("run returns full shape", (() => {
  const r = s.run("osmosis", s.defaults("osmosis"));
  return !!(r.measurements && r.results && r.uncertainty && r.uncertainty.note &&
    Array.isArray(r.observations) && r.observations.length &&
    Array.isArray(r.assumptions) && Array.isArray(r.method));
})());
check("unknown experiment fails fast", s.run("teleport", {}).error === "unknown-experiment:teleport");
check("defaults merge into partial inputs", s.run("enzyme", { tempC: 50 }).inputs.pH === 6.8);

/* ---- deterministic rules ---- */
const q1 = s.run("quadrat", { trueCoverPct: 40, throws: 10, seed: 42 });
const q2 = s.run("quadrat", { trueCoverPct: 40, throws: 10, seed: 42 });
check("quadrat is deterministic for a fixed seed",
  JSON.stringify(q1.results.samples) === JSON.stringify(q2.results.samples));
const q3 = s.run("quadrat", { trueCoverPct: 40, throws: 10, seed: 7 });
check("quadrat seed changes the samples", q3.results.samples[0].x !== q1.results.samples[0].x);
check("quadrat mean is near the true cover (10 throws)",
  Math.abs(q1.results.meanCoverPct - 40) <= 2 * q1.results.seCoverPct + 3,
  `mean=${q1.results.meanCoverPct} se=${q1.results.seCoverPct}`);
check("quadrat has SE and a 95% CI bracketing the mean",
  q1.results.seCoverPct > 0 && q1.results.ci95[0] < q1.results.meanCoverPct &&
  q1.results.ci95[1] > q1.results.meanCoverPct);
check("quadrat frequency in [0,100]", q1.results.frequencyPct >= 0 && q1.results.frequencyPct <= 100);
check("rng helpers exported", typeof s.makeRng === "function" && typeof s.gauss === "function");
check("makeRng is a stable stream", (() => {
  const r = s.makeRng(7);
  const a = [r(), r(), r()];
  const r2 = s.makeRng(7);
  return a[0] === r2() && a[1] === r2() && a[2] === r2();
})());

/* ---- osmotic potential + osmosis ---- */
const psi1 = s.osmoticPotential(1, 1, 20);
check("osmotic potential 1 M at 20 C ~ -2.437 MPa", Math.abs(psi1 + 2.437) < 0.01, psi1 + " MPa");
check("osmotic potential 1 M at 25 C ~ -2.479 MPa", Math.abs(s.osmoticPotential(1, 1, 25) + 2.479) < 0.01);
check("osmotic potential is linear in C", Math.abs(s.osmoticPotential(0.5, 1, 20) - psi1 / 2) < 1e-9);
check("osmotic potential is linear in i", Math.abs(s.osmoticPotential(1, 2, 20) - 2 * psi1) < 1e-9);
const osmPure = s.run("osmosis", { concentrationM: 0, minutes: 60, tempC: 20, initialMassG: 5 });
const osmConc = s.run("osmosis", { concentrationM: 1.0, minutes: 60, tempC: 20, initialMassG: 5 });
check("osmosis: pure water gains mass", osmPure.results.massChangePct > 5, osmPure.results.massChangePct + " %");
check("osmosis: 1 M sucrose loses mass", osmConc.results.massChangePct < -5, osmConc.results.massChangePct + " %");
check("osmosis: monotone in concentration (pure > 0.5M > 1M)",
  osmPure.results.massChangePct > s.run("osmosis", { concentrationM: 0.5 }).results.massChangePct &&
  s.run("osmosis", { concentrationM: 0.5 }).results.massChangePct > osmConc.results.massChangePct);
check("osmosis: isotonic concentration near 0.31 M",
  Math.abs(osmPure.results.isotonicConcentrationM - 0.308) < 0.02, osmPure.results.isotonicConcentrationM + "");
check("osmosis: near isotonic, no net movement",
  Math.abs(s.run("osmosis", { concentrationM: 0.31 }).results.massChangePct) < 0.5);
check("osmosis: temperature changes rate but not equilibrium",
  s.run("osmosis", { concentrationM: 0, minutes: 60, tempC: 35 }).results.massChangePct >
  osmPure.results.massChangePct &&
  s.run("osmosis", { concentrationM: 0, minutes: 500, tempC: 35 }).results.equilibriumChangePct ===
  osmPure.results.equilibriumChangePct);
const osmA = s.run("osmosis", { concentrationM: 0.2, minutes: 30 });
const osmB = s.run("osmosis", { concentrationM: 0.2, minutes: 60 });
check("osmosis: longer exposure moves further toward equilibrium",
  osmB.results.massChangePct > osmA.results.massChangePct && osmB.results.massChangePct < osmPure.results.equilibriumChangePct);
check("osmosis assess: correct direction + isotonic score full marks",
  (() => {
    const a = s.assess("osmosis", { concentrationM: 0 }, osmPure.results, { direction: "gain", isotonicM: 0.31 });
    return a.score === a.max && a.max > 0;
  })());
check("osmosis assess: wrong direction loses the point",
  s.assess("osmosis", { concentrationM: 0 }, osmPure.results, { direction: "loss" }).score === 0);

/* ---- enzyme ---- */
const enzOpt = s.run("enzyme", { tempC: 37, pH: 6.8 });
const enzHot = s.run("enzyme", { tempC: 70, pH: 6.8 });
const enzCold = s.run("enzyme", { tempC: 5, pH: 6.8 });
const enzAcid = s.run("enzyme", { tempC: 37, pH: 4 });
check("enzyme optimum in 35-41 C", enzOpt.results.optimumTempC >= 35 && enzOpt.results.optimumTempC <= 41,
  enzOpt.results.optimumTempC + " C");
check("enzyme: 70 C denatured (rate ~0, interpretation names denaturation)",
  enzHot.results.relativeRate < 0.01 && /denatur/i.test(enzHot.results.interpretation));
check("enzyme: 5 C slow (cold limits rate)", enzCold.results.relativeRate < 0.3);
check("enzyme: away-from-optimum pH is slower",
  enzAcid.results.relativeRate < enzOpt.results.relativeRate * 0.1);
check("enzyme: pH 6.8 at optimum is the fastest of the set",
  enzOpt.results.relativeRate >= s.run("enzyme", { tempC: 37, pH: 6 }).results.relativeRate &&
  enzOpt.results.relativeRate >= s.run("enzyme", { tempC: 37, pH: 8 }).results.relativeRate);
check("enzyme: clear time consistent with rate",
  enzOpt.results.starchClearSec != null && enzOpt.results.starchClearSec > 0 && enzHot.results.starchClearSec === null);
check("enzyme: uncertainty documents optimum error",
  typeof enzOpt.uncertainty.optimumErrorC === "number" && enzOpt.uncertainty.optimumErrorC > 0);
check("enzyme assess: optimum + denaturation reason = full marks",
  (() => {
    const a = s.assess("enzyme", { tempC: 37 }, enzOpt.results, { optimumC: enzOpt.results.optimumTempC, reason: "denaturation above the optimum" });
    return a.score === a.max && a.max === 2;
  })());

/* ---- food tests ---- */
const foodAll = s.run("foodTests", { reducingSugarG: 10, proteinG: 20, starchG: 12, lipidG: 9 });
check("food: all four tests positive at high concentrations",
  foodAll.results.benedict.positive && foodAll.results.biuret.positive &&
  foodAll.results.iodine.positive && foodAll.results.emulsion.positive);
check("food: benedict colour grades (blue < green < orange < brick red)",
  /blue/.test(s.run("foodTests", { reducingSugarG: 0 }).results.benedict.color) &&
  /green/.test(s.run("foodTests", { reducingSugarG: 1 }).results.benedict.color) &&
  /orange/.test(s.run("foodTests", { reducingSugarG: 3 }).results.benedict.color) &&
  /brick red/.test(s.run("foodTests", { reducingSugarG: 10 }).results.benedict.color));
const foodNone = s.run("foodTests", { reducingSugarG: 0, proteinG: 0, starchG: 0, lipidG: 0 });
check("food: zero sample gives four negatives",
  !foodNone.results.benedict.positive && !foodNone.results.biuret.positive &&
  !foodNone.results.iodine.positive && !foodNone.results.emulsion.positive);
check("food assess: names iodine for starch and Benedict's for sugars",
  s.assess("foodTests", {}, foodAll.results, { starchReagent: "iodine", sugarReagent: "Benedict's" }).score === 2);

/* ---- photosynthesis ---- */
const photoVar = s.run("photosynthesis", { leafType: "variegated", lightMinutes: 120 });
const photoDark = s.run("photosynthesis", { leafType: "control-dark", lightMinutes: 0 });
const photoCtrl = s.run("photosynthesis", { leafType: "control-light", lightMinutes: 120 });
check("photosynthesis: variegated - starch only in green regions",
  photoVar.results.regions.every((r) => (r.chlorophyll ? r.starchMg > 0 : r.starchMg === 0)));
check("photosynthesis: dark control has no starch anywhere",
  photoDark.results.regions.every((r) => r.starchMg === 0) && photoDark.results.lightRequired === false);
check("photosynthesis: light control is fully blue-black",
  photoCtrl.results.regions.every((r) => r.starchMg > 0));
check("photosynthesis: longer light exposure makes more starch",
  photoVar.results.regions[0].starchMg > s.run("photosynthesis", { leafType: "variegated", lightMinutes: 15 }).results.regions[0].starchMg);
check("photosynthesis assess: destarch + chlorophyll answers = full marks",
  s.assess("photosynthesis", {}, photoVar.results, { whyDestarch: "destarching removes stored starch", pattern: "starch only where chlorophyll" }).score === 2);

/* ---- germination ---- */
const germGood = s.run("germination", { waterPresent: true, oxygenAccess: "normal", tempC: 20, days: 5, seeds: 20 });
const germNoWater = s.run("germination", { waterPresent: false, oxygenAccess: "normal", tempC: 20, days: 5, seeds: 20 });
const germAnoxia = s.run("germination", { waterPresent: true, oxygenAccess: "none", tempC: 20, days: 5, seeds: 20 });
const germCold = s.run("germination", { waterPresent: true, oxygenAccess: "normal", tempC: 2, days: 5, seeds: 20 });
check("germination: suitable conditions germinate most seeds",
  germGood.results.finalGerminatedPct > 40, germGood.results.finalGerminatedPct + " %");
check("germination: no water limits completely (0 %)",
  germNoWater.results.finalGerminatedPct === 0 && germNoWater.results.limitingFactor === "water");
check("germination: anoxia strongly reduces germination",
  germAnoxia.results.finalGerminatedPct < germGood.results.finalGerminatedPct * 0.25 &&
  /oxygen/i.test(germAnoxia.results.limitingFactor));
check("germination: below Tmin no germination (temperature limits)",
  germCold.results.finalGerminatedPct === 0 && /temperature/i.test(germCold.results.limitingFactor));
check("germination: cumulative curve is monotone",
  germGood.results.curve.every((p, i, a) => i === 0 || p.germinatedPct >= a[i - 1].germinatedPct));
check("germination assess: names the limiting factor",
  s.assess("germination", {}, germNoWater.results, { limitingFactor: "water" }).score === 1);

/* ---- respiration ---- */
const resp25 = s.run("respiration", { tempC: 25, organism: "germinating-peas", minutes: 30, seeds: 10, co2Absorbed: true });
const resp35 = s.run("respiration", { tempC: 35, organism: "germinating-peas", minutes: 30, seeds: 10, co2Absorbed: true });
const respBoiled = s.run("respiration", { tempC: 25, organism: "boiled-control", minutes: 30, seeds: 10, co2Absorbed: true });
const respNoKoh = s.run("respiration", { tempC: 25, organism: "germinating-peas", minutes: 30, seeds: 10, co2Absorbed: false });
check("respiration: KOH contraction equals O2 used",
  resp25.results.volumeChangeMl === -resp25.results.o2ConsumedMl);
check("respiration: Q10 ~ 2 (35 C roughly double 25 C)",
  resp35.results.o2ConsumedMl / resp25.results.o2ConsumedMl > 1.7 &&
  resp35.results.o2ConsumedMl / resp25.results.o2ConsumedMl < 2.3,
  (resp35.results.o2ConsumedMl / resp25.results.o2ConsumedMl).toFixed(2));
check("respiration: boiled control consumes ~ no O2",
  respBoiled.results.o2ConsumedMl < resp25.results.o2ConsumedMl * 0.1);
check("respiration: without KOH net volume change ~ 0 (RQ = 1)",
  Math.abs(respNoKoh.results.volumeChangeMl) < 0.01, respNoKoh.results.volumeChangeMl + " mL");
check("respiration: doubles with twice the time",
  s.run("respiration", { tempC: 25, organism: "germinating-peas", minutes: 60, seeds: 10, co2Absorbed: true }).results.o2ConsumedMl ===
  2 * resp25.results.o2ConsumedMl);
check("respiration: scales with seed number",
  s.run("respiration", { tempC: 25, organism: "germinating-peas", minutes: 30, seeds: 20, co2Absorbed: true }).results.o2ConsumedMl ===
  2 * resp25.results.o2ConsumedMl);

/* ---- transpiration ---- */
const tr1 = s.run("transpiration", { lightOn: true, tempC: 22, leafAreaCm2: 40, minutes: 60 });
const tr2 = s.run("transpiration", { lightOn: false, tempC: 22, leafAreaCm2: 40, minutes: 60 });
const tr3 = s.run("transpiration", { lightOn: true, tempC: 22, leafAreaCm2: 20, minutes: 60 });
check("transpiration: rate positive with light", tr1.results.rateMlPerMin > 0);
check("transpiration: dark run is slower (stomata closed)",
  tr2.results.rateMlPerMin < tr1.results.rateMlPerMin * 0.7,
  `${tr2.results.rateMlPerMin} vs ${tr1.results.rateMlPerMin}`);
check("transpiration: halving leaf area halves the rate",
  Math.abs(tr3.results.rateMlPerMin * 2 - tr1.results.rateMlPerMin) < 0.01,
  `${tr3.results.rateMlPerMin} vs ${tr1.results.rateMlPerMin}`);
check("transpiration: volume lost consistent with duration",
  Math.abs(tr1.results.volumeLostMl - tr1.results.rateMlPerMin * 60) < 0.01);

/* ---- microorganisms ---- */
const microOk = s.run("microorganisms", { organism: "yeast", tempC: 30, hours: 24, sealed: true });
const microUnsafe = s.run("microorganisms", { organism: "yeast", tempC: 30, hours: 24, sealed: false });
const microCold = s.run("microorganisms", { organism: "yeast", tempC: 2, hours: 24, sealed: true });
check("microorganisms: growth at optimum", microOk.results.coveragePct > 50,
  microOk.results.coveragePct + " %");
check("microorganisms: never safe to open on the bench", microOk.results.safeToOpen === false);
check("microorganisms: unsealed plate raises a stop warning",
  microUnsafe.results.safetyWarnings.some((w) => /never|stop|inform/i.test(w)));
check("microorganisms: out-of-viable-range gives no growth + warning",
  microCold.results.coveragePct === 0 && microCold.results.safetyWarnings.some((w) => /temperature/i.test(w)));
check("microorganisms assess: sealed-only handling",
  s.assess("microorganisms", {}, microOk.results, { openPlate: "never open outside the cabinet" }).score === 1);

/* ---- microscope optics + consequences ---- */
check("field of view: 4x = 5 mm, 10x = 2 mm, 40x = 0.5 mm",
  s.microscope.fieldOfViewMm(4) === 5 && s.microscope.fieldOfViewMm(10) === 2 && s.microscope.fieldOfViewMm(40) === 0.5);
const evGood = s.microscope.evaluate({ objective: 10, focus: 0.5, illumination: true, stage: { x: 0, y: 0 } }, "onion");
check("good settings: ok, good quality, visible cells", evGood.ok === true && evGood.quality === "good" && evGood.cellsAcross > 0);
check("onion at 10x: ~133 cells across the 2 mm field", evGood.cellsAcross === 133, evGood.cellsAcross + "");
const evCheek = s.microscope.evaluate({ objective: 10, focus: 0.5, illumination: true, stage: { x: 0, y: 0 } }, "cheek");
check("cheek cells are larger (fewer across the field)", evCheek.cellsAcross < evGood.cellsAcross, evCheek.cellsAcross + "");
const ev40 = s.microscope.evaluate({ objective: 40, focus: 0.5, illumination: true, stage: { x: 0, y: 0 } }, "onion");
check("40x zooms in (cells across drops ~4x)", Math.abs(ev40.cellsAcross * 4 - evGood.cellsAcross) <= 2);
const evDark = s.microscope.evaluate({ objective: 40, focus: 0.5, illumination: false, stage: { x: 0, y: 0 } }, "onion");
check("dark field: unusable, no-light issue, named consequence",
  evDark.ok === false && evDark.issues.includes("no-light") && /illuminator/.test(evDark.field));
const evNoSlide = s.microscope.evaluate({ objective: 40, focus: 0.5, illumination: true, stage: { x: 0, y: 0 } }, "none");
check("no slide: unusable, no-slide issue", evNoSlide.ok === false && evNoSlide.issues.includes("no-slide"));
const evBlur = s.microscope.evaluate({ objective: 40, focus: 0.05, illumination: true, stage: { x: 0, y: 0 } }, "onion");
check("far focus: unusable, out-of-focus blur described", evBlur.ok === false && evBlur.issues.includes("out-of-focus") && /blur/.test(evBlur.field));
const evSoft = s.microscope.evaluate({ objective: 40, focus: 0.65, illumination: true, stage: { x: 0, y: 0 } }, "onion");
check("slightly-off focus: still usable but soft", evSoft.ok === true && evSoft.quality === "soft" && evSoft.issues.includes("soft-focus"));
const evOff = s.microscope.evaluate({ objective: 10, focus: 0.5, illumination: true, stage: { x: 1.2, y: 0 } }, "onion");
check("stage off the specimen: unusable empty field", evOff.ok === false && evOff.issues.includes("off-specimen"));
const evBadObj = s.microscope.evaluate({ objective: 60, focus: 0.5, illumination: true, stage: { x: 0, y: 0 } }, "onion");
check("invalid objective is rejected", evBadObj.ok === false && evBadObj.issues.includes("invalid-objective"));
check("specimen registry lists onion + cheek + none",
  s.microscope.specimens.onion && s.microscope.specimens.cheek && s.microscope.specimens.none);
check("evaluate consequence explains what to fix",
  /light|slide|focus|stage|objective/.test(String(evDark.consequence)));
const evScoreGood = s.microscope.evaluate({ objective: 10, focus: 0.5, illumination: true, stage: { x: 0, y: 0 } }, "onion").score;
check("quality score ranks good > soft > unusable",
  evScoreGood > evSoft.score && evSoft.score > evDark.score,
  `${evScoreGood} > ${evSoft.score} > ${evDark.score}`);

/* ---- summary ---- */
if (fails) {
  console.error(`\nFAIL  ${fails} check(s) failed`);
  process.exit(1);
}
console.log(`\nOK  all ${checks.length} checks passed`);
