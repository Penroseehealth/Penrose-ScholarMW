/**
 * Scientific simulation layer (Phase 4) for the biology lab.
 *
 * Pure JS — no THREE / no DOM — shared by the live scene and Node unit tests.
 * Scientific calculations are deliberately separate from visual presentation:
 * each experiment module defines objective, apparatus, principles, safety,
 * input parameters, a deterministic run(inputs) producing measurements /
 * results / uncertainty / observations, and an assess(...) function. The host
 * only renders whatever the rules return.
 *
 * Determinism: every module is a pure function of its inputs. Optional
 * measurement noise uses a seeded PRNG (mulberry32) so a given seed always
 * reproduces the same numbers; assumptions and uncertainty are returned with
 * every run rather than hidden.
 *
 * Physics / biology constants used:
 *   R = 8.314 J K^-1 mol^-1, water potential Psi_s = -iCRT (C in mol dm^-3,
 *   reported in MPa), Q10-style thermal rates, Arrhenius + logistic curves
 *   where documented per module.
 */
"use strict";

var R_GAS = 8.314;
var T_KELVIN = 273.15;

function clamp(x, a, b) { return x < a ? a : (x > b ? b : x); }
function round(x, d) { var f = Math.pow(10, d == null ? 2 : d); return Math.round(x * f) / f; }

/* seeded PRNG (mulberry32) for reproducible simulated measurement noise */
function makeRng(seed) {
  var s = (seed >>> 0) || 1;
  return function () {
    s |= 0; s = (s + 0x6D2B79F5) | 0;
    var t = Math.imul(s ^ (s >>> 15), 1 | s);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

/* Gaussian noise from a uniform rng (Box-Muller), clamped */
function gauss(rng, sd) {
  var u = 1 - rng(), v = rng();
  return Math.sqrt(-2 * Math.log(u)) * Math.cos(2 * Math.PI * v) * sd;
}

/* osmotic (solute) potential in MPa: Psi_s = -iCRT with C in mol dm^-3.
   C is converted to mol m^-3 (x1000) so the result is in Pa, then /1e6 -> MPa. */
function osmoticPotential(concM, i, tempC) {
  i = i == null ? 1 : i;
  var T = (tempC == null ? 20 : tempC) + T_KELVIN;
  return -(i * concM * 1000 * R_GAS * T) / 1e6;
}

/* ---------- experiment modules ---------- */

var MODULES = {};

MODULES.osmosis = {
  id: "osmosis",
  title: "Osmosis in plant tissue (potato cylinders)",
  objective: "Measure how the mass of potato tissue changes in sucrose solutions of different concentration and relate the result to water potential.",
  apparatus: ["potato cylinders (standard 10 mm bore)", "scale (0.01 g)", "sucrose solutions 0.0-1.0 mol dm^-3", "stopwatch", "beakers", "distilled water"],
  principles: [
    "water moves down a water-potential gradient across a partially permeable membrane",
    "Psi_total = Psi_solute + Psi_pressure; potato tissue starts slightly negative (~-0.75 MPa)",
    "at the isotonic concentration there is no net water movement and mass change is zero",
  ],
  safety: ["cut potato with the board, not the hand", "wash spills on the bench", "no eating or drinking in the lab"],
  inputs: {
    concentrationM: { type: "number", min: 0, max: 1.2, step: 0.05, def: 0.3, label: "Sucrose concentration (mol dm^-3)" },
    minutes: { type: "number", min: 10, max: 180, step: 5, def: 60, label: "Time in solution (minutes)" },
    tempC: { type: "number", min: 10, max: 40, step: 1, def: 20, label: "Solution temperature (deg C)" },
    initialMassG: { type: "number", min: 1, max: 20, step: 0.1, def: 5, label: "Initial cylinder mass (g)" },
  },
  procedure: [
    "weigh a fresh potato cylinder and record its initial mass",
    "place it in a labelled beaker of sucrose solution at the chosen concentration",
    "leave for the chosen time, then blot dry and re-weigh",
    "repeat across concentrations and plot % mass change against concentration",
  ],
  assumptions: [
    "tissue water potential at the start is -0.75 MPa (typical potato)",
    "equilibrium mass change is linear in the water-potential gradient with bulk modulus K = 18 %/MPa (school-lab calibration: ~+9 % gain in pure water, ~-21 % loss in 1.0 mol dm^-3 at 60 min)",
    "uptake/loss follows first-order kinetics with k = 0.02 min^-1 at 20 deg C and Q10 = 1.3",
    "sucrose solution behaves as an ideal dilute solute (i = 1)",
  ],
  run: function (inputs) {
    var C = clamp(Number(inputs.concentrationM) || 0, 0, 1.2);
    var t = clamp(Number(inputs.minutes) || 60, 10, 180);
    var T = clamp(Number(inputs.tempC) || 20, 10, 40);
    var m0 = clamp(Number(inputs.initialMassG) || 5, 1, 20);
    var PSI_TISSUE = -0.75, K = 18, K20 = 0.02, Q10 = 1.3;
    var psiExt = osmoticPotential(C, 1, T);
    var drive = psiExt - PSI_TISSUE;                      /* >0: water enters tissue (moves down its potential gradient) */
    var pctEq = clamp(K * drive, -35, 25);                /* equilibrium % mass change */
    var k = K20 * Math.pow(Q10, (T - 20) / 10);
    var pct = pctEq * (1 - Math.exp(-k * t));
    var mFinal = m0 * (1 + pct / 100);
    var cIso = -PSI_TISSUE * 1000 / (R_GAS * (T + T_KELVIN)); /* conc with zero net change */
    var state = C < cIso - 0.03 ? "turgid (water gained)" :
      (C > cIso + 0.03 ? "plasmolysed (water lost)" : "incipient plasmolysis (isotonic)");
    return {
      measurements: {
        initialMassG: round(m0, 2), finalMassG: round(mFinal, 2), massChangePct: round(pct, 2),
        psiExternalMPa: round(psiExt, 3), psiTissueMPa: PSI_TISSUE,
        minutes: t, tempC: T, concentrationM: C,
      },
      results: {
        massChangePct: round(pct, 2), equilibriumChangePct: round(pctEq, 2),
        isotonicConcentrationM: round(cIso, 3), cellState: state,
        direction: pct > 0.5 ? "water entered the tissue" : (pct < -0.5 ? "water left the tissue" : "no net movement"),
      },
      uncertainty: {
        note: "mass readings to +/-0.02 g; blotting variability dominates; model error typically +/-3 % of the change",
        massErrorG: 0.02, modelErrorPct: 3,
      },
      observations: [
        "mass change " + round(pct, 2) + " % after " + t + " min in " + C + " mol dm^-3 sucrose",
        "external water potential " + round(psiExt, 3) + " MPa vs tissue " + PSI_TISSUE + " MPa",
        "tissue appears " + state,
      ],
    };
  },
  assess: function (inputs, results, answers) {
    var fb = [], score = 0, max = 2;
    var a = answers || {};
    if (a.direction) {
      var want = results.massChangePct > 0.5 ? "gain" : (results.massChangePct < -0.5 ? "loss" : "none");
      var got = /gain|enter/i.test(a.direction) ? "gain" : (/loss|leav/i.test(a.direction) ? "loss" : "none");
      if (got === want) { score++; fb.push("correct: " + results.direction); }
      else fb.push("expected " + want + " because Psi_tissue (-0.75 MPa) vs Psi_ext (" +
        round(osmoticPotential(clamp(Number(inputs.concentrationM) || 0, 0, 1.2), 1,
          clamp(Number(inputs.tempC) || 20, 10, 40)), 3) + " MPa)");
    }
    if (typeof a.isotonicM === "number" && Math.abs(a.isotonicM - results.isotonicConcentrationM) <= 0.08) {
      score++; fb.push("isotonic estimate within tolerance");
    } else if (a.isotonicM != null) fb.push("isotonic estimate should be near " + results.isotonicConcentrationM + " mol dm^-3");
    return { score: score, max: max, feedback: fb };
  },
};

MODULES.enzyme = {
  id: "enzyme",
  title: "Enzyme activity: amylase and starch",
  objective: "Investigate how temperature and pH affect the rate at which amylase breaks down starch, and identify the optimum with an explanation involving denaturation.",
  apparatus: ["water baths", "iodine solution + spotting tile", "amylase solution", "starch suspension", "buffer solutions pH 5-8", "stopwatch", "test tubes"],
  principles: [
    "enzyme-substrate complexes form; rate rises with temperature as kinetic energy increases",
    "above the optimum the enzyme denatures (active site shape is lost) and rate falls sharply",
    "each enzyme has an optimum pH set by ionisation of the active site",
  ],
  safety: ["iodine stains skin and clothing - use a dropper and rinse spills", "hot water baths: no glassware with cracks", "do not mouth-pipette"],
  inputs: {
    tempC: { type: "number", min: 0, max: 80, step: 1, def: 37, label: "Temperature (deg C)" },
    pH: { type: "number", min: 4.5, max: 8.5, step: 0.1, def: 6.8, label: "pH" },
    timeMin: { type: "number", min: 1, max: 30, step: 1, def: 5, label: "Reaction time (minutes)" },
  },
  procedure: [
    "equilibrate amylase and starch at the chosen temperature and pH",
    "mix and start the stopwatch",
    "remove a drop every 30 s and test with iodine on a spotting tile until the blue-black colour no longer appears",
    "record the time for starch to disappear; repeat at other temperatures and pH values",
  ],
  assumptions: [
    "Arrhenius activation energy Ea = 50 kJ mol^-1 below the optimum",
    "denaturation is modelled as a logistic collapse centred at 43 deg C with width 2.2 deg C",
    "pH dependence is Gaussian about pH 6.8 with sigma 0.55",
    "relative rate is normalised to 1.0 at the optimum; absolute rates depend on enzyme concentration",
  ],
  run: function (inputs) {
    var T = clamp(Number(inputs.tempC) || 37, 0, 80);
    var pH = clamp(Number(inputs.pH) || 6.8, 4.5, 8.5);
    var t = clamp(Number(inputs.timeMin) || 5, 1, 30);
    function raw(tempC) {
      var K = tempC + T_KELVIN;
      var arr = Math.exp(-50000 / (R_GAS * K));
      var den = 1 / (1 + Math.exp((tempC - 43) / 2.2));
      return arr * den;
    }
    var rawOpt = 0, optC = 0;
    for (var x = 0; x <= 80; x += 0.5) { var r = raw(x); if (r > rawOpt) { rawOpt = r; optC = x; } }
    var rel = raw(T) / rawOpt;
    var phF = Math.exp(-Math.pow(pH - 6.8, 2) / (2 * 0.55 * 0.55));
    var rate = rel * phF;
    var clearSec = rate > 0.005 ? Math.round(90 / rate) : null;
    var sugarMg = round(rate * t * 4.5, 2);     /* mg mL^-1 reducing sugar after t min */
    return {
      measurements: { tempC: T, pH: pH, timeMin: t, relativeRate: round(rate, 4), starchClearSec: clearSec, reducingSugarMgL: sugarMg },
      results: {
        relativeRate: round(rate, 4), optimumTempC: optC, starchClearSec: clearSec,
        benedict: rate < 0.02 ? "blue (little/no reducing sugar)" : (rate < 0.5 ? "orange (some reducing sugar)" : "brick red (lots of reducing sugar)"),
        interpretation: T > optC + 4 ? "rate reduced by denaturation" : (pH < 5.8 || pH > 7.8 ? "rate reduced by pH away from the optimum" : (T < optC - 4 ? "rate limited by low kinetic energy" : "near optimum conditions")),
      },
      uncertainty: {
        note: "timing to +/-2 s; iodine endpoint is subjective; denaturation curve width is a school-level approximation (+/-3 deg C on the optimum)",
        timingErrorSec: 2, optimumErrorC: 3,
      },
      observations: [
        "starch disappeared after " + (clearSec == null ? "more than 30 min" : clearSec + " s"),
        "relative rate " + round(rate, 3) + " (optimum " + optC + " deg C)",
        "expected Benedict's result: " + (rate < 0.02 ? "blue" : (rate < 0.5 ? "orange" : "brick red")),
      ],
    };
  },
  assess: function (inputs, results, answers) {
    var fb = [], score = 0, max = 2;
    var a = answers || {};
    var optErrC = 3; /* matches the documented uncertainty on the optimum */
    if (typeof a.optimumC === "number" && Math.abs(a.optimumC - results.optimumTempC) <= optErrC) {
      score++; fb.push("optimum within " + optErrC + " deg C of " + results.optimumTempC);
    } else if (a.optimumC != null) fb.push("optimum should be near " + results.optimumTempC + " deg C");
    if (a.reason && /denatur/i.test(a.reason)) { score++; fb.push("correct: denaturation above the optimum"); }
    else if (a.reason) fb.push("mention denaturation of the active site above the optimum");
    return { score: score, max: max, feedback: fb };
  },
};

MODULES.foodTests = {
  id: "foodTests",
  title: "Food tests for macronutrients",
  objective: "Use colourimetric reagents to identify reducing sugars, protein, starch and lipids in a food sample and interpret the results quantitatively.",
  apparatus: ["Benedict's reagent", "Biuret reagent", "iodine solution", "ethanol + distilled water", "water bath", "test tubes", "food samples (blended)"],
  principles: [
    "Benedict's: reducing sugars reduce Cu2+ to a brick-red precipitate on heating",
    "Biuret: peptide bonds complex Cu2+ in alkaline solution giving violet",
    "iodine in KI: starch helices trap iodine giving blue-black",
    "ethanol/water emulsion: lipids dissolve in ethanol then precipitate as a cloudy emulsion",
  ],
  safety: ["Benedict's and Biuret are alkaline - rinse skin", "ethanol is flammable - no open flames near the emulsion test", "glass tubes can crack in the water bath"],
  inputs: {
    reducingSugarG: { type: "number", min: 0, max: 60, step: 0.5, def: 4, label: "Reducing sugar (g per 100 g)" },
    proteinG: { type: "number", min: 0, max: 80, step: 0.5, def: 10, label: "Protein (g per 100 g)" },
    starchG: { type: "number", min: 0, max: 80, step: 0.5, def: 15, label: "Starch (g per 100 g)" },
    lipidG: { type: "number", min: 0, max: 80, step: 0.5, def: 8, label: "Lipid (g per 100 g)" },
  },
  procedure: [
    "blend or crush the food sample and make an aqueous suspension",
    "Benedict's: add sample + reagent, heat 5 min in a water bath, record the colour",
    "Biuret: add sample + NaOH then dilute CuSO4, record the colour",
    "iodine: add sample + iodine on a white tile, record the colour",
    "lipid: dissolve sample in ethanol, add distilled water, look for a cloudy emulsion",
  ],
  assumptions: [
    "colour grades are mapped from concentration with fixed school-level thresholds (Benedict's: 0 blue, >0.5 green, >2 orange, >5 red per 100 g)",
    "all four tests are qualitative/semi-quantitative only - a positive is not a precise mass",
  ],
  run: function (inputs) {
    var rs = clamp(Number(inputs.reducingSugarG) || 0, 0, 60);
    var pr = clamp(Number(inputs.proteinG) || 0, 0, 80);
    var st = clamp(Number(inputs.starchG) || 0, 0, 80);
    var lp = clamp(Number(inputs.lipidG) || 0, 0, 80);
    var ben = rs <= 0.5 ? { positive: false, color: "blue (negative)" }
      : (rs <= 2 ? { positive: true, color: "green (trace)" }
        : (rs <= 5 ? { positive: true, color: "orange" } : { positive: true, color: "brick red" }));
    var biu = pr > 1 ? { positive: true, color: "violet" } : { positive: false, color: "blue (negative)" };
    var iod = st > 0.5 ? { positive: true, color: "blue-black" } : { positive: false, color: "yellow-brown (negative)" };
    var emu = lp > 1 ? { positive: true, color: "cloudy white emulsion" } : { positive: false, color: "clear layers" };
    return {
      measurements: { reducingSugarG: rs, proteinG: pr, starchG: st, lipidG: lp },
      results: { benedict: ben, biuret: biu, iodine: iod, emulsion: emu },
      uncertainty: {
        note: "thresholds are school-lab calibrations; near-threshold values can straddle two colour grades (+/-0.5 g per 100 g)",
        thresholdSlackG: 0.5,
      },
      observations: [
        "Benedict's: " + ben.color, "Biuret: " + biu.color, "iodine: " + iod.color, "ethanol/water: " + emu.color,
      ],
    };
  },
  assess: function (inputs, results, answers) {
    var fb = [], score = 0, max = 2;
    var a = answers || {};
    if (a.starchReagent && /iodine/i.test(a.starchReagent)) { score++; fb.push("iodine tests for starch"); }
    else if (a.starchReagent) fb.push("iodine is the starch reagent");
    if (a.sugarReagent && /benedict/i.test(a.sugarReagent)) { score++; fb.push("Benedict's tests for reducing sugars"); }
    else if (a.sugarReagent) fb.push("Benedict's is the reducing-sugar reagent");
    return { score: score, max: max, feedback: fb };
  },
};

MODULES.photosynthesis = {
  id: "photosynthesis",
  title: "Photosynthesis: starch testing in a variegated leaf",
  objective: "Show that starch is made only in the parts of a leaf that contain chlorophyll and that light is required.",
  apparatus: ["variegated geranium leaf", "controls: dark-kept and fully green leaves", "boiling water", "ethanol", "iodine", "water bath", "forceps"],
  principles: [
    "chlorophyll absorbs light energy to fix CO2 into glucose, stored as starch",
    "destarching removes pre-existing starch so any blue-black result is new",
    "iodine turns blue-black where starch is present",
  ],
  safety: ["boiling water and hot ethanol - use a water bath, never a naked flame", "ethanol vapour is flammable", "handle glassware with tongs"],
  inputs: {
    leafType: { type: "choice", options: ["variegated", "control-light", "control-dark"], def: "variegated", label: "Leaf treatment" },
    lightMinutes: { type: "number", min: 0, max: 240, step: 15, def: 120, label: "Light exposure (minutes)" },
  },
  procedure: [
    "destarch all leaves by keeping them in the dark for 48 h",
    "expose the test leaf to light for the chosen time (controls stay dark / stay green)",
    "kill the leaf in boiling water, then dissolve the chlorophyll in hot ethanol",
    "rinse and spread the leaf on a white tile; flood with iodine and record the pattern",
  ],
  assumptions: [
    "after 48 h destarching stored starch is exhausted in a healthy leaf",
    "variegated regions are treated as binary (chlorophyll present / absent) rather than a gradient",
    "iodine responds only to starch, not to the chlorophyll remaining after ethanol",
  ],
  run: function (inputs) {
    var type = inputs.leafType || "variegated";
    var mins = clamp(Number(inputs.lightMinutes) || 120, 0, 240);
    var regions;
    if (type === "variegated") {
      regions = [
        { name: "green centre", chlorophyll: true, iodine: "blue-black (starch present)", starchMg: round(1.1 * (1 - Math.exp(-mins / 70)), 2) },
        { name: "pale margin", chlorophyll: false, iodine: "pale brown (no starch)", starchMg: 0 },
      ];
    } else if (type === "control-light") {
      regions = [{ name: "whole leaf", chlorophyll: true, iodine: "blue-black (starch present)", starchMg: round(1.1 * (1 - Math.exp(-mins / 70)), 2) }];
    } else {
      regions = [{ name: "whole leaf", chlorophyll: true, iodine: "pale brown (no new starch)", starchMg: 0 }];
    }
    var pattern = regions.map(function (r) { return r.name + ": " + r.iodine; }).join("; ");
    return {
      measurements: { leafType: type, lightMinutes: mins },
      results: { regions: regions, pattern: pattern, lightRequired: type !== "control-dark", chlorophyllRequired: type === "variegated" },
      uncertainty: {
        note: "starch magnitudes are illustrative relative estimates (not absolute mg); incomplete destarching can give faint background staining",
        qualitative: true,
      },
      observations: ["iodine pattern - " + pattern],
    };
  },
  assess: function (inputs, results, answers) {
    var fb = [], score = 0, max = 2;
    var a = answers || {};
    if (a.whyDestarch && /remov|start|store|baseline/i.test(a.whyDestarch)) { score++; fb.push("destarching removes stored starch so the test shows only new starch"); }
    else if (a.whyDestarch) fb.push("explain that destarching removes pre-existing starch");
    if (a.pattern && /chlorophyll|green/i.test(a.pattern)) { score++; fb.push("starch only where chlorophyll was present"); }
    else if (a.pattern) fb.push("starch forms only in chlorophyll-containing regions");
    return { score: score, max: max, feedback: fb };
  },
};

MODULES.germination = {
  id: "germination",
  title: "Seed germination: requirements and conditions",
  objective: "Determine how water, oxygen availability and temperature affect the percentage germination of seeds over time.",
  apparatus: ["cress or bean seeds", "petri dishes with cotton wool", "incubators at different temperatures", "water", "sealed waterlogged dish for anoxia", "counters"],
  principles: [
    "germination needs water (to activate enzymes), oxygen (for aerobic respiration) and a suitable temperature",
    "enzymes controlling germination have cardinal temperatures ( Tmin / Topt / Tmax )",
    "respiration supplies ATP for growth of the radicle",
  ],
  safety: ["wash hands after handling seeds and soil", "mouldy dishes go straight to the waste bag - do not open near the face"],
  inputs: {
    waterPresent: { type: "boolean", def: true, label: "Water provided" },
    oxygenAccess: { type: "choice", options: ["normal", "waterlogged", "none"], def: "normal", label: "Oxygen access" },
    tempC: { type: "number", min: 0, max: 40, step: 1, def: 20, label: "Incubation temperature (deg C)" },
    days: { type: "number", min: 1, max: 10, step: 1, def: 5, label: "Days observed" },
    seeds: { type: "number", min: 5, max: 50, step: 5, def: 20, label: "Number of seeds" },
  },
  procedure: [
    "sow equal numbers of seeds on damp cotton wool in labelled petri dishes",
    "keep one dish at each temperature / oxygen condition; keep cotton wool damp with the same volume of water",
    "count germinated seeds (radicle visible) each day for the chosen number of days",
    "plot cumulative % germination against time for each condition",
  ],
  assumptions: [
    "cardinal temperatures Tmin = 5, Topt = 25, Tmax = 35 deg C with a triangular thermal response",
    "maximum germination is 90 % of seeds when all requirements are met",
    "cumulative germination follows a logistic curve with r = 0.9 per day and midpoint day 4",
    "anoxia factor: waterlogged 0.15, sealed no-oxygen 0.02 of the maximum",
  ],
  run: function (inputs) {
    var water = inputs.waterPresent !== false;
    var ox = inputs.oxygenAccess || "normal";
    var T = clamp(Number(inputs.tempC) || 20, 0, 40);
    var days = clamp(Number(inputs.days) || 5, 1, 10);
    var n = clamp(Number(inputs.seeds) || 20, 5, 50);
    var therm = T <= 5 || T >= 35 ? 0 : (T <= 25 ? (T - 5) / 20 : (35 - T) / 10);
    var oxF = ox === "normal" ? 1 : (ox === "waterlogged" ? 0.15 : 0.02);
    var maxPct = water ? 90 * therm * oxF : 0;
    var curve = [];
    for (var d = 0; d <= days; d++) {
      var pct = d === 0 ? 0 : maxPct / (1 + Math.exp(-0.9 * (d - 4)));
      curve.push({ day: d, germinatedPct: round(pct, 1), count: Math.round(n * pct / 100) });
    }
    var final = curve[curve.length - 1];
    return {
      measurements: { waterPresent: water, oxygenAccess: ox, tempC: T, days: days, seeds: n },
      results: {
        finalGerminatedPct: final.germinatedPct, finalCount: final.count, curve: curve,
        limitingFactor: !water ? "water" : (therm === 0 ? "temperature (outside 5-35 deg C)" : (oxF < 0.5 ? "oxygen availability (" + ox + ")" : "none - conditions suitable")),
      },
      uncertainty: {
        note: "seed viability is typically 85-95 %; counts of 20 seeds carry +/-1 seed (~5 %) sampling error; the logistic curve is an idealisation",
        countError: 1,
      },
      observations: [
        final.count + " of " + n + " seeds germinated by day " + days,
        "limiting factor: " + (water ? (therm === 0 ? "temperature" : (oxF < 0.5 ? "oxygen" : "none")) : "water"),
      ],
    };
  },
  assess: function (inputs, results, answers) {
    var fb = [], score = 0, max = 1;
    var a = answers || {};
    if (a.limitingFactor && new RegExp(results.limitingFactor.split(" ")[0], "i").test(a.limitingFactor)) {
      score++; fb.push("limiting factor identified correctly");
    } else if (a.limitingFactor) fb.push("the limiting factor here is: " + results.limitingFactor);
    return { score: score, max: max, feedback: fb };
  },
};

MODULES.respiration = {
  id: "respiration",
  title: "Respiration in germinating seeds (respirometer)",
  objective: "Measure oxygen uptake by germinating seeds at different temperatures and compare with a boiled control.",
  apparatus: ["respirometer set", "germinating + boiled control seeds", "KOH or NaHCO3 (CO2 absorbent)", "water bath", "manometer fluid", "ruler"],
  principles: [
    "aerobic respiration consumes O2 and releases CO2; with CO2 absorbed the volume contraction equals O2 used",
    "rate increases with temperature (Q10 ~ 2) until enzymes are denatured",
    "boiled (dead) seeds show only negligible microbial/background consumption",
  ],
  safety: ["treat respirometer tubes as fragile - clamp firmly", "KOH is corrosive - wear goggles", "do not open the manometer to the mouth"],
  inputs: {
    tempC: { type: "number", min: 5, max: 45, step: 1, def: 25, label: "Water bath temperature (deg C)" },
    organism: { type: "choice", options: ["germinating-peas", "boiled-control"], def: "germinating-peas", label: "Setup" },
    minutes: { type: "number", min: 5, max: 90, step: 5, def: 30, label: "Measurement time (minutes)" },
    seeds: { type: "number", min: 5, max: 30, step: 5, def: 10, label: "Number of seeds" },
    co2Absorbed: { type: "boolean", def: true, label: "KOH present (absorb CO2)" },
  },
  procedure: [
    "set up matched respirometers with germinating and boiled seeds",
    "add KOH solution to the side arm to absorb CO2",
    "immerse in the water bath for 10 min to equilibrate, then seal and mark the fluid meniscus",
    "record meniscus movement toward the tube after the chosen time; repeat at other temperatures",
  ],
  assumptions: [
    "O2 uptake per seed at 25 deg C is 0.025 mL h^-1 for germinating peas, 0.002 for boiled controls",
    "Q10 = 2 across 5-45 deg C (no denaturation modelled in this range for seeds)",
    "respiratory quotient RQ = 1 for a carbohydrate substrate, so without KOH the net volume change is ~0",
  ],
  run: function (inputs) {
    var T = clamp(Number(inputs.tempC) || 25, 5, 45);
    var germ = (inputs.organism || "germinating-peas") === "germinating-peas";
    var mins = clamp(Number(inputs.minutes) || 30, 5, 90);
    var n = clamp(Number(inputs.seeds) || 10, 5, 30);
    var absorbed = inputs.co2Absorbed !== false;
    var ratePerSeed = (germ ? 0.025 : 0.002) * Math.pow(2, (T - 25) / 10); /* mL O2 h^-1 */
    var o2 = ratePerSeed * n * (mins / 60);
    /* with KOH the contraction equals O2 used; with RQ=1 and no KOH the CO2
       replaces the O2 so the net change is ~0 (a few % from RQ != 1 exactly) */
    var dV = absorbed ? -o2 : -o2 * 0.02;
    return {
      measurements: { tempC: T, minutes: mins, seeds: n, organism: inputs.organism || "germinating-peas", co2Absorbed: absorbed },
      results: {
        o2ConsumedMl: round(o2, 3), volumeChangeMl: round(dV, 3),
        ratePerSeedMlPerH: round(ratePerSeed, 4),
        manometer: dV < -0.01 ? "fluid moves toward the tube (contraction)" : "no measurable movement",
        note: absorbed ? "KOH absorbed the CO2 so contraction = O2 used" : "without KOH the CO2 replaces the O2, so little net change - this is why the absorbent is needed",
      },
      uncertainty: {
        note: "meniscus readings to +/-0.01 mL; microbial contamination of controls can add ~10 %; Q10 = 2 is an average over this range",
        volumeErrorMl: 0.01,
      },
      observations: [
        "volume change " + round(dV, 3) + " mL in " + mins + " min (" + n + " seeds at " + T + " deg C)",
        absorbed ? "contraction equals oxygen consumed" : "no KOH: net change ~0 despite respiration",
      ],
    };
  },
  assess: function (inputs, results, answers) {
    var fb = [], score = 0, max = 1;
    var a = answers || {};
    if (a.direction && (/toward|contract|in$/i.test(a.direction) === (results.volumeChangeMl < -0.01))) {
      score++; fb.push("manometer direction interpreted correctly");
    } else if (a.direction) fb.push("expected movement: " + results.manometer);
    return { score: score, max: max, feedback: fb };
  },
};

MODULES.transpiration = {
  id: "transpiration",
  title: "Transpiration measured with a potometer",
  objective: "Quantify how light and temperature affect the rate of water uptake by a leafy shoot and relate uptake to transpiration.",
  apparatus: ["potometer", "leafy shoot (e.g. ivy or geranium)", "ruler", "lamp", "water bath or warm room", "food colouring in the water"],
  principles: [
    "transpiration is evaporation of water from mesophyll surfaces and diffusion out of stomata",
    "light opens stomata; higher temperature increases the vapour-pressure gradient",
    "uptake measured by the potometer approximately equals water lost (some water is retained in growth)",
  ],
  safety: ["lamp gets hot - keep water off the bulb", "glass capillary: do not chip the end", "reset the potometer without air bubbles entering the shoot"],
  inputs: {
    lightOn: { type: "boolean", def: true, label: "Lamp on" },
    tempC: { type: "number", min: 15, max: 40, step: 1, def: 22, label: "Room temperature (deg C)" },
    leafAreaCm2: { type: "number", min: 5, max: 120, step: 5, def: 40, label: "Leaf surface area (cm^2)" },
    minutes: { type: "number", min: 5, max: 60, step: 5, def: 20, label: "Measurement time (minutes)" },
  },
  procedure: [
    "cut the shoot under water, assemble the potometer with no air bubbles",
    "record the starting position of the meniscus",
    "place the lamp at a fixed distance / adjust the room temperature, then record movement after the chosen time",
    "repeat with different light and temperature settings; calculate % volume lost per minute",
  ],
  assumptions: [
    "baseline uptake at 20 deg C in the dark is 0.05 mL min^-1 for a 40 cm^2 shoot",
    "light multiplies the rate by 1.9 (stomata open); temperature factor is 0.9 + 0.06*(T-20)",
    "uptake is proportional to leaf surface area; uptake underestimates true loss by ~10 % (water retained in the plant)",
  ],
  run: function (inputs) {
    var light = inputs.lightOn !== false;
    var T = clamp(Number(inputs.tempC) || 22, 15, 40);
    var area = clamp(Number(inputs.leafAreaCm2) || 40, 5, 120);
    var mins = clamp(Number(inputs.minutes) || 20, 5, 60);
    var rate = 0.05 * (light ? 1.9 : 0.7) * clamp(0.9 + 0.06 * (T - 20), 0.4, 2.2) * (area / 40);
    var lost = rate * mins;
    return {
      measurements: { lightOn: light, tempC: T, leafAreaCm2: area, minutes: mins },
      results: {
        rateMlPerMin: round(rate, 4), volumeLostMl: round(lost, 3),
        percentOfReservoir: round(lost / 50 * 100, 2),
        comparison: light ? "light raises transpiration (stomata open)" : "darkness closes stomata, lowering transpiration",
      },
      uncertainty: {
        note: "capillary reading +/-0.05 mL; ~10 % of uptake is retained in growth so potometer values slightly underestimate loss; shoot variability between practicals is large",
        volumeErrorMl: 0.05,
      },
      observations: [
        round(lost, 3) + " mL taken up in " + mins + " min (" + round(rate, 4) + " mL/min)",
        light ? "lamp on" : "lamp off", "leaf area " + area + " cm^2",
      ],
    };
  },
  assess: function (inputs, results, answers) {
    var fb = [], score = 0, max = 1;
    var a = answers || {};
    if (a.moreLight && (/yes|more|higher/i.test(a.moreLight) === !!inputs.lightOn)) {
      score++; fb.push("effect of light on transpiration understood");
    } else if (a.moreLight) fb.push("more light increases transpiration because stomata open");
    return { score: score, max: max, feedback: fb };
  },
};

MODULES.quadrat = {
  id: "quadrat",
  title: "Ecological sampling with quadrats",
  objective: "Use random quadrat throws to estimate the percentage cover of a plant species in a field and quantify the sampling uncertainty.",
  apparatus: ["quadrat frame (0.5 x 0.5 m)", "tape measures", "random number table or generator", "record sheet"],
  principles: [
    "random sampling avoids bias from choosing 'interesting' patches",
    "mean cover +/- standard error describes the estimate and its precision",
    "frequency (proportion of throws containing the species) complements cover",
  ],
  safety: ["watch for uneven ground, glass and stinging plants", "work in pairs near paths", "do not touch unknown organisms"],
  inputs: {
    fieldWidthM: { type: "number", min: 5, max: 100, step: 1, def: 20, label: "Field width (m)" },
    fieldLengthM: { type: "number", min: 5, max: 100, step: 1, def: 30, label: "Field length (m)" },
    trueCoverPct: { type: "number", min: 0, max: 100, step: 1, def: 40, label: "True cover of the species (%) - hidden in a real field" },
    throws: { type: "number", min: 5, max: 50, step: 1, def: 10, label: "Number of throws" },
    seed: { type: "number", min: 1, max: 9999, step: 1, def: 42, label: "Random seed" },
  },
  procedure: [
    "lay tapes to mark out the field boundary and a coordinate grid",
    "generate random coordinates and throw the quadrat so its centre lands on the coordinate",
    "estimate % cover of the target species inside the frame",
    "repeat for the chosen number of throws; calculate mean, standard error and frequency",
  ],
  assumptions: [
    "cover readings are normally distributed about the true cover with sigma = 8 %",
    "throws are independent (the field is treated as homogeneous at the scale sampled)",
    "a throw counts as 'present' when estimated cover is above 0 %",
  ],
  run: function (inputs) {
    var W = clamp(Number(inputs.fieldWidthM) || 20, 5, 100);
    var L = clamp(Number(inputs.fieldLengthM) || 30, 5, 100);
    var cover = clamp(Number(inputs.trueCoverPct) || 40, 0, 100);
    var n = clamp(Number(inputs.throws) || 10, 5, 50);
    var rng = makeRng(Number(inputs.seed) || 42);
    var samples = [], xs = 0;
    for (var i = 0; i < n; i++) {
      var x = round(rng() * W, 2), z = round(rng() * L, 2);
      var c = clamp(Math.round(cover + gauss(rng, 8)), 0, 100);
      samples.push({ throw: i + 1, x: x, z: z, coverPct: c });
      xs += c;
    }
    var mean = xs / n;
    var ss = 0;
    for (var j = 0; j < n; j++) ss += Math.pow(samples[j].coverPct - mean, 2);
    var sd = n > 1 ? Math.sqrt(ss / (n - 1)) : 0;
    var se = sd / Math.sqrt(n);
    var present = samples.filter(function (s) { return s.coverPct > 0; }).length;
    return {
      measurements: { fieldWidthM: W, fieldLengthM: L, throws: n, seed: Number(inputs.seed) || 42 },
      results: {
        samples: samples,
        meanCoverPct: round(mean, 2), sdCoverPct: round(sd, 2), seCoverPct: round(se, 2),
        frequencyPct: round(present / n * 100, 1),
        ci95: [round(mean - 1.96 * se, 2), round(mean + 1.96 * se, 2)],
        estimate: "mean cover " + round(mean, 2) + " % (+/-" + round(1.96 * se, 2) + " % at 95 % confidence)",
      },
      uncertainty: {
        note: "each reading is subjective to +/-5 % by eye; standard error shrinks with sqrt(n) throws; a homogeneous-field assumption ignores patchiness at scales below the quadrat",
        readingErrorPct: 5,
      },
      observations: [
        n + " random throws, mean cover " + round(mean, 2) + " %, SE " + round(se, 2) + " %",
        "species found in " + present + " of " + n + " throws",
      ],
    };
  },
  assess: function (inputs, results, answers) {
    var fb = [], score = 0, max = 1;
    var a = answers || {};
    if (typeof a.meanPct === "number" && Math.abs(a.meanPct - results.meanCoverPct) <= results.seCoverPct + 0.6) {
      score++; fb.push("mean cover within one SE of the computed estimate");
    } else if (a.meanPct != null) fb.push("mean should be near " + results.meanCoverPct + " %");
    return { score: score, max: max, feedback: fb };
  },
};

MODULES.microorganisms = {
  id: "microorganisms",
  title: "Safe observation of microbial growth",
  objective: "Observe how temperature affects the growth of safe classroom cultures while practising aseptic, contained handling.",
  apparatus: ["nutrient agar plates (pre-inoculated, sealed)", "incubators at several temperatures", "inoculating loop (optional)", "biosafety cabinet", "disinfectant"],
  principles: [
    "microbial growth follows lag / exponential / stationary phases; modelled here as a logistic curve",
    "each organism has cardinal temperatures; classroom cultures are chosen to be safe and non-pathogenic",
    "sealed plates are opened only in a biosafety cabinet, if at all",
  ],
  safety: [
    "never open a culture plate outside the biosafety cabinet",
    "report any unexpected growth, odour or damaged seals to the teacher",
    "disinfect the bench before and after; autoclave all waste",
  ],
  inputs: {
    organism: { type: "choice", options: ["yeast", "safe-bacteria", "bread-mould"], def: "yeast", label: "Culture" },
    tempC: { type: "number", min: 4, max: 45, step: 1, def: 25, label: "Incubation temperature (deg C)" },
    hours: { type: "number", min: 6, max: 48, step: 6, def: 24, label: "Incubation time (hours)" },
    sealed: { type: "boolean", def: true, label: "Plate remains sealed" },
  },
  procedure: [
    "check the seal and label of the pre-inoculated plate",
    "incubate at the chosen temperature for the chosen time (plates stacked and sealed)",
    "without opening, record colony coverage / turbidity and any colour",
    "compare plates incubated at different temperatures",
  ],
  assumptions: [
    "cardinal temperatures: yeast Tmin 5 / Topt 30 / Tmax 38; safe-bacteria 10 / 37 / 42; bread-mould 5 / 25 / 35",
    "growth is logistic with carrying capacity = full plate coverage; rate scales with the triangular thermal response",
    "sealed classroom plates are treated as contained; opening one without the cabinet is a safety failure, not a measurement",
  ],
  run: function (inputs) {
    var org = inputs.organism || "yeast";
    var T = clamp(Number(inputs.tempC) || 25, 4, 45);
    var hrs = clamp(Number(inputs.hours) || 24, 6, 48);
    var sealed = inputs.sealed !== false;
    var card = org === "yeast" ? [5, 30, 38] : (org === "safe-bacteria" ? [10, 37, 42] : [5, 25, 35]);
    var therm = T <= card[0] || T >= card[2] ? 0 : (T <= card[1] ? (T - card[0]) / (card[1] - card[0]) : (card[2] - T) / (card[2] - card[1]));
    var r = 0.12 * therm;
    var cover = therm === 0 ? 0 : 100 / (1 + Math.exp(-r * (hrs - 18)));
    var warnings = [];
    if (!sealed) warnings.push("plate opened outside the biosafety cabinet - stop and inform the teacher");
    if (T > card[2] || T < card[0]) warnings.push("temperature outside the viable range for " + org + " - no growth expected");
    return {
      measurements: { organism: org, tempC: T, hours: hrs, sealed: sealed },
      results: {
        coveragePct: round(cover, 1), thermalFactor: round(therm, 3),
        growth: cover < 1 ? "no visible growth" : (cover < 30 ? "sparse colonies" : (cover < 70 ? "confident growth" : "near confluent growth")),
        safeToOpen: false,
        safetyWarnings: warnings.length ? warnings : ["plate handled sealed - within classroom safety rules"],
      },
      uncertainty: {
        note: "coverage is estimated by eye through the lid (+/-10 %); inoculum size varies between plates so comparisons should use matched plates",
        coverageErrorPct: 10,
      },
      observations: [
        org + " incubated " + hrs + " h at " + T + " deg C: " + (cover < 1 ? "no visible growth" : round(cover, 1) + " % coverage"),
      ].concat(warnings),
    };
  },
  assess: function (inputs, results, answers) {
    var fb = [], score = 0, max = 1;
    var a = answers || {};
    if (a.openPlate && /never|no|sealed|cabinet/i.test(a.openPlate)) { score++; fb.push("correct: plates stay sealed / are opened only in the cabinet"); }
    else if (a.openPlate) fb.push("a culture plate must never be opened on the open bench");
    return { score: score, max: max, feedback: fb };
  },
};

/* ---------- microscope model (links the Phase-3 equipment state to what a
   student would actually see, and gives incorrect settings consequences) ---------- */

var SPECIMENS = {
  onion: {
    id: "onion", label: "Onion epidermis (plant tissue)",
    cellWidthMm: 0.015, prep: "wet mount with iodine + coverslip",
    features: ["cell wall", "large central vacuole", "nucleus (stained dark)", "brick-shaped cells in rows"],
    notes: "plant cells: rigid wall, no chloroplasts in epidermis",
  },
  cheek: {
    id: "cheek", label: "Human cheek smear (animal tissue)",
    cellWidthMm: 0.025, prep: "smear + methylene blue + coverslip",
    features: ["cell membrane", "irregular rounded outline", "stained nucleus", "cytoplasm"],
    notes: "animal cells: no wall, smaller and more rounded",
  },
  none: { id: "none", label: "No slide", cellWidthMm: 0, prep: "—", features: [], notes: "" },
};

function fieldOfViewMm(objective, ocular) {
  ocular = ocular || 10;
  /* DIN field number 20 mm: specimen-field diameter = FN / objective magnification
     (the 10x ocular convention is already baked into the field number). */
  return 20 / objective;
}

function evaluateMicroscope(microState, specimenId) {
  var st = microState || {};
  var spec = SPECIMENS[specimenId] || SPECIMENS.none;
  var obj = st.objective, focus = st.focus, illum = !!st.illumination;
  var stage = st.stage || { x: 0, y: 0 };
  var issues = [];
  if (obj !== 4 && obj !== 10 && obj !== 40) issues.push("invalid-objective");
  if (spec.id === "none") issues.push("no-slide");
  if (!illum) issues.push("no-light");
  var focusOff = Math.abs((focus == null ? 0.5 : focus) - 0.5);
  if (focusOff > 0.25) issues.push("out-of-focus");
  else if (focusOff > 0.12) issues.push("soft-focus");
  if (Math.abs(stage.x) > 0.8 || Math.abs(stage.y) > 0.8) issues.push("off-specimen");
  var blocking = issues.filter(function (x) { return x !== "soft-focus"; });
  var fov = obj === 4 || obj === 10 || obj === 40 ? fieldOfViewMm(obj, 10) : 0;
  var score = 0;
  if (illum) score += 0.35;
  if (spec.id !== "none") score += 0.25;
  score += 0.3 * Math.max(0, 1 - focusOff / 0.25);
  if (Math.abs(stage.x) <= 0.8 && Math.abs(stage.y) <= 0.8) score += 0.1;
  var cellsAcross = spec.cellWidthMm > 0 && fov > 0 ? Math.round(fov / spec.cellWidthMm) : 0;
  var field;
  if (issues.indexOf("no-light") >= 0) field = "dark field - the illuminator is off";
  else if (issues.indexOf("no-slide") >= 0) field = "empty bright field - no slide on the stage";
  else if (issues.indexOf("off-specimen") >= 0) field = "empty bright field - the stage has moved off the specimen";
  else if (issues.indexOf("out-of-focus") >= 0) field = "uniform blur - the focus knob is far from the specimen plane";
  else {
    field = cellsAcross + " cells across the field at " + obj + "x (" + round(fov, 2) + " mm); " + spec.features.join(", ");
    if (issues.indexOf("soft-focus") >= 0) field = "slightly soft image - " + field;
  }
  return {
    ok: blocking.length === 0,
    score: round(score, 3),
    quality: blocking.length ? "unusable" : (issues.length ? "soft" : "good"),
    objective: obj, totalMag: (obj || 0) * 10,
    fovMm: round(fov, 3),
    cellsAcross: cellsAcross,
    specimen: spec.id, specimenLabel: spec.label, prep: spec.prep,
    issues: issues,
    field: field,
    consequence: blocking.length ? "observation cannot be recorded until: " + blocking.join(", ") : null,
  };
}

/* ---------- registry ---------- */

function createScience() {
  function ids() { return Object.keys(MODULES); }
  function meta() {
    return ids().map(function (id) {
      var m = MODULES[id];
      return { id: m.id, title: m.title, objective: m.objective, apparatus: m.apparatus, principles: m.principles, safety: m.safety, inputs: m.inputs, procedure: m.procedure, assumptions: m.assumptions };
    });
  }
  function experiment(id) { return MODULES[id] || null; }
  function defaults(id) {
    var m = MODULES[id]; if (!m) return null;
    var out = {};
    Object.keys(m.inputs).forEach(function (k) { out[k] = m.inputs[k].def; });
    return out;
  }
  function run(id, inputs, opts) {
    var m = MODULES[id];
    if (!m) return { error: "unknown-experiment:" + id };
    var inp = {}, d = defaults(id);
    Object.keys(d).forEach(function (k) {
      var v = inputs && inputs[k] !== undefined ? inputs[k] : d[k];
      inp[k] = v;
    });
    var r = m.run(inp);
    return { id: id, inputs: inp, measurements: r.measurements, results: r.results, uncertainty: r.uncertainty, observations: r.observations, assumptions: m.assumptions, method: m.procedure };
  }
  function assess(id, inputs, results, answers) {
    var m = MODULES[id];
    if (!m) return { error: "unknown-experiment:" + id };
    return m.assess(inputs || {}, results || m.run(inputs || defaults(id)), answers || {});
  }
  return {
    experiments: meta,
    experiment: experiment,
    defaults: defaults,
    run: run,
    assess: assess,
    constants: { R: R_GAS, T_KELVIN: T_KELVIN },
    osmoticPotential: osmoticPotential,
    makeRng: makeRng,
    gauss: gauss,
    fieldOfViewMm: fieldOfViewMm,
    specimens: SPECIMENS,
    microscope: {
      specimens: SPECIMENS,
      fieldOfViewMm: fieldOfViewMm,
      evaluate: evaluateMicroscope,
    },
  };
}

export { createScience };
