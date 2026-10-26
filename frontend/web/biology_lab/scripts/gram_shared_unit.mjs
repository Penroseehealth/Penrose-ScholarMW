/* Gram foundation unit: reagent table, geometry contract, colour maths and
   the stain-chemistry state machine, verified against reference values written
   here independently of gram_shared.js (same style as phase13_unit.mjs). */
import { readFileSync } from "node:fs";
import {
  REAGENTS, GRAM_GEOMETRY, GRAM_CONTRACT, COLOURLESS, CV_COMPLEX,
  mixHex, lerpHex, fadeHex, runoffColour, createStainState, clamp01, clampTilt,
  makeStubSlide, makeStubPour, makeStubRinse,
} from "../js/gram_shared.js";

let pass = 0, fail = 0;
function ck(name, ok, detail) {
  if (ok) { pass++; console.log("  PASS " + name); }
  else { fail++; console.log("  FAIL " + name + (detail ? " - " + detail : "")); }
}
function hex(c) { return "0x" + c.toString(16).padStart(6, "0"); }
function distWhite(c) {
  return (255 - ((c >> 16) & 255)) + (255 - ((c >> 8) & 255)) + (255 - (c & 255));
}
function isPurple(c) {
  const r = (c >> 16) & 255, g = (c >> 8) & 255, b = c & 255;
  return b >= r && b > g && r > g;
}
function drive(st, tick, seconds, dt) {
  const step = dt || 0.05;
  for (let t = 0; t < seconds; t += step) tick(step);
}

console.log("=== Gram unit: module boundary + reagent table ===");
{
  const src = readFileSync(new URL("../js/gram_shared.js", import.meta.url), "utf8");
  ck("gram_shared.js does not import three",
    !/from\s+["']three["']/.test(src) && !/import\s+["']three["']/.test(src));

  const ids = ["cv", "io", "de", "sa", "sl", "water"];
  ck("all six reagent ids present", ids.every(id => !!REAGENTS[id]),
    Object.keys(REAGENTS).join(","));
  ck("no unexpected reagent ids", Object.keys(REAGENTS).length === 6);
  ck("reference colours: crystal violet", REAGENTS.cv.colour === 0x6a2fa0, hex(REAGENTS.cv.colour));
  ck("reference colours: Gram's iodine", REAGENTS.io.colour === 0x8a5a1f, hex(REAGENTS.io.colour));
  ck("reference colours: decolouriser is colourless", REAGENTS.de.colour === COLOURLESS, hex(REAGENTS.de.colour));
  ck("reference colours: safranin", REAGENTS.sa.colour === 0xe0457b, hex(REAGENTS.sa.colour));
  ck("reference colours: saline is defined", typeof REAGENTS.sl.colour === "number", hex(REAGENTS.sl.colour));
  ck("reference colours: water", REAGENTS.water.colour === 0xcbe7f3, hex(REAGENTS.water.colour));
  const roles = ["primary", "mordant", "decolouriser", "counterstain", "rinse"];
  ids.forEach(function (id) {
    const r = REAGENTS[id];
    ck(id + " has film opacity in (0,1]", r.filmOpacity > 0 && r.filmOpacity <= 1, String(r.filmOpacity));
    ck(id + " has pour duration in (0,10]", r.pourDuration > 0 && r.pourDuration <= 10, String(r.pourDuration));
    ck(id + " has fade constant in (0,10]", r.fade > 0 && r.fade <= 10, String(r.fade));
    ck(id + " has non-negative stain rate", typeof r.stainRate === "number" && r.stainRate >= 0, String(r.stainRate));
    ck(id + " has a known chemistry role", roles.indexOf(r.role) >= 0, r.role);
    ck(id + " id/name fields are consistent", r.id === id && typeof r.name === "string" && r.name.length > 0, r.name);
  });
  ck("only the decolouriser and rinses are colourless/near-clear",
    ["de", "sl", "water"].every(id => distWhite(REAGENTS[id].colour) < 3 * 60));
}

console.log("=== Gram unit: geometry, poses, budgets ===");
{
  const g = GRAM_GEOMETRY;
  ck("slide footprint 0.026 x 0.003 x 0.1",
    g.slide.x === 0.026 && g.slide.y === 0.003 && g.slide.z === 0.1,
    JSON.stringify(g.slide));
  ck("rack pose (-5.425, 0.92, 0.18)",
    g.rackPose.x === -5.425 && g.rackPose.y === 0.92 && g.rackPose.z === 0.18,
    JSON.stringify(g.rackPose));
  ck("sink pose (-5.62, 0.955, -0.60)",
    g.sinkPose.x === -5.62 && g.sinkPose.y === 0.955 && g.sinkPose.z === -0.6,
    JSON.stringify(g.sinkPose));
  ck("warm pose (-5.511, 1.03, -0.19)",
    g.warmPose.x === -5.511 && g.warmPose.y === 1.03 && g.warmPose.z === -0.19,
    JSON.stringify(g.warmPose));
  ck("scope pose (0.45, 0.93, -2.60)",
    g.scopePose.x === 0.45 && g.scopePose.y === 0.93 && g.scopePose.z === -2.6,
    JSON.stringify(g.scopePose));
  ck("tilt band is 25-45 degrees",
    g.tilt.minDeg === 25 && g.tilt.maxDeg === 45
    && Math.abs(g.tilt.minRad - 25 * Math.PI / 180) < 1e-12
    && Math.abs(g.tilt.maxRad - 45 * Math.PI / 180) < 1e-12
    && g.tilt.minRad < g.tilt.maxRad, JSON.stringify(g.tilt));
  const sr = g.streamRadii;
  const positive = Object.keys(sr).every(k => sr[k] > 0);
  ck("stream radii all positive", positive, JSON.stringify(sr));
  ck("tap outer column wider than its core", sr.tapOuter > sr.tapCore && sr.tapCore > 0);
  ck("pour ribbon wider than its droplets", sr.pour > sr.pourDrop && sr.pourDrop > 0);
  const b = g.budgets;
  ck("perf budget: ~45 added meshes", b.maxAddedMeshes === 45, String(b.maxAddedMeshes));
  ck("perf budget: 512px textures", b.maxTexturePx === 512, String(b.maxTexturePx));
  ck("perf budget: <=20Hz repaints", b.maxRepaintHz === 20, String(b.maxRepaintHz));
  const d35 = 35 * Math.PI / 180;
  ck("clampTilt keeps a working-band tilt unchanged", clampTilt(d35) === d35);
  ck("clampTilt bounds magnitude to 45 deg", clampTilt(1.2) === g.tilt.maxRad && clampTilt(-1.2) === -g.tilt.maxRad);
  ck("clampTilt allows the flat rest pose", clampTilt(0) === 0);
  ck("clamp01 clamps and guards non-finite input",
    clamp01(-3) === 0 && clamp01(2) === 1 && clamp01(0.42) === 0.42 && clamp01(NaN) === 0);
}

console.log("=== Gram unit: hex colour maths ===");
{
  ck("mixHex t=0 keeps the source", mixHex(0x000000, 0xffffff, 0) === 0x000000);
  ck("mixHex t=1 reaches the target", mixHex(0x000000, 0xffffff, 1) === 0xffffff);
  ck("mixHex midpoint is exact", mixHex(0x000000, 0xffffff, 0.5) === 0x808080, hex(mixHex(0x000000, 0xffffff, 0.5)));
  ck("mixHex of a colour with itself is stable", mixHex(0x6a2fa0, 0x6a2fa0, 0.37) === 0x6a2fa0);
  ck("mixHex clamps t above 1", mixHex(0x000000, 0xffffff, 3) === 0xffffff);
  ck("mixHex clamps t below 0", mixHex(0x000000, 0xffffff, -1) === 0x000000);
  ck("lerpHex agrees with mixHex", lerpHex(0x6a2fa0, 0xe0457b, 0.3) === mixHex(0x6a2fa0, 0xe0457b, 0.3));
  ck("fadeHex 0 is a no-op", fadeHex(0x6a2fa0, 0) === 0x6a2fa0);
  ck("fadeHex 1 is colourless", fadeHex(0x6a2fa0, 1) === COLOURLESS);
  const f3 = fadeHex(0x6a2fa0, 0.3), f7 = fadeHex(0x6a2fa0, 0.7);
  const ch = c => [(c >> 16) & 255, (c >> 8) & 255, c & 255];
  ck("fadeHex is monotonic toward colourless",
    ch(f7).every((v, i) => v >= ch(f3)[i]), hex(f3) + " -> " + hex(f7));
}

console.log("=== Gram unit: runoff fade ===");
{
  const samples = [0x6a2fa0, 0x8a5a1f, 0xe0457b, 0xcfe6f4, 0xcbe7f3, 0x3b1a66];
  samples.forEach(function (start) {
    const name = hex(start);
    ck("runoff " + name + ": dilution 0 leaves it unchanged", runoffColour(start, 0, 1) === start);
    let cur = start, prev = distWhite(cur), monotonic = true, maxJump = 0;
    for (let i = 0; i < 400; i++) {
      const next = runoffColour(cur, 1, 0.05);
      const d = distWhite(next);
      if (d > prev) monotonic = false;
      const jump = Math.max(
        Math.abs(((next >> 16) & 255) - ((cur >> 16) & 255)),
        Math.abs(((next >> 8) & 255) - ((cur >> 8) & 255)),
        Math.abs((next & 255) - (cur & 255)));
      if (jump > maxJump) maxJump = jump;
      prev = d;
      cur = next;
    }
    ck("runoff " + name + ": fades monotonically toward colourless", monotonic);
    ck("runoff " + name + ": reaches exactly colourless", cur === COLOURLESS, hex(cur));
    ck("runoff " + name + ": never jumps (>40/channel/20Hz call)", maxJump <= 40, String(maxJump));
  });
  ck("colourless runoff stays colourless", runoffColour(COLOURLESS, 1, 30) === COLOURLESS);
  ck("zero dt leaves the colour unchanged", runoffColour(0x6a2fa0, 1, 0) === 0x6a2fa0);
  ck("negative dilution leaves the colour unchanged", runoffColour(0x6a2fa0, -1, 5) === 0x6a2fa0);
  ck("stronger dilution fades faster",
    distWhite(runoffColour(0x6a2fa0, 2, 0.05)) < distWhite(runoffColour(0x6a2fa0, 0.5, 0.05)));
}

console.log("=== Gram unit: stain-state transitions ===");
{
  const st = createStainState();
  let s = st.snapshot();
  ck("fresh state: unstained smear, no film",
    s.pos.alpha === 0 && s.neg.alpha === 0 && s.film.alpha === 0
    && s.pos.colour === COLOURLESS && s.neg.colour === COLOURLESS && s.film.colour === COLOURLESS,
    JSON.stringify(s));

  /* 1. crystal violet: every cell turns purple */
  drive(st, dt => st.applyReagent("cv", dt, 1), 3);
  s = st.snapshot();
  ck("after CV all cells are crystal violet",
    s.pos.colour === 0x6a2fa0 && s.neg.colour === 0x6a2fa0,
    hex(s.pos.colour) + "/" + hex(s.neg.colour));
  ck("after CV both populations fully loaded", s.pos.alpha === 1 && s.neg.alpha === 1);
  ck("after CV the film is purple at the reagent opacity",
    s.film.colour === 0x6a2fa0 && Math.abs(s.film.alpha - REAGENTS.cv.filmOpacity) < 1e-9,
    hex(s.film.colour) + "/" + s.film.alpha);

  /* 2. iodine mordant: deep CV-iodine complex, amber film */
  drive(st, dt => st.applyReagent("io", dt, 1), 3);
  s = st.snapshot();
  ck("iodine deepens both populations to the CV-iodine complex",
    s.pos.colour === CV_COMPLEX && s.neg.colour === CV_COMPLEX,
    hex(s.pos.colour) + "/" + hex(s.neg.colour));
  ck("iodine film is amber-brown", s.film.colour === 0x8a5a1f, hex(s.film.colour));
  const beforeDe = { pos: s.pos.colour, neg: s.neg.colour };

  /* 3. decolouriser: gramNeg loses the dye, gramPos retains it */
  drive(st, dt => st.applyReagent("de", dt, 1), 1);
  s = st.snapshot();
  ck("decolouriser moves gramNeg toward colourless without jumping",
    s.neg.colour !== COLOURLESS && distWhite(s.neg.colour) < distWhite(beforeDe.neg),
    hex(s.neg.colour));
  drive(st, dt => st.applyReagent("de", dt, 1), 14);
  s = st.snapshot();
  ck("after decolourise gramNeg is colourless", s.neg.colour === COLOURLESS, hex(s.neg.colour));
  ck("after decolourise gramNeg loses opacity", s.neg.alpha <= 0.13, String(s.neg.alpha));
  ck("after decolourise gramPos retains the purple complex",
    s.pos.colour === beforeDe.pos, hex(s.pos.colour));

  /* 4. rinse: film washes off, bound stain survives */
  drive(st, dt => st.rinse(dt), 3);
  s = st.snapshot();
  ck("rinse clears the film to colourless", s.film.alpha === 0 && s.film.colour === COLOURLESS);
  ck("rinse does not strip the bound stain",
    s.pos.colour === beforeDe.pos && s.neg.colour === COLOURLESS);
  ck("rinse wets the slide", st.getDamp() > 0.9, String(st.getDamp()));

  /* 5. safranin: colourless gramNeg turns pink-red, gramPos stays purple */
  drive(st, dt => st.applyReagent("sa", dt, 1), 6);
  s = st.snapshot();
  ck("after safranin gramNeg is pink-red", s.neg.colour === 0xe0457b, hex(s.neg.colour));
  ck("after safranin gramNeg regains opacity", Math.abs(s.neg.alpha - 0.85) < 1e-6, String(s.neg.alpha));
  ck("after safranin gramPos stays purple",
    isPurple(s.pos.colour) && s.pos.colour !== 0xe0457b, hex(s.pos.colour));
  ck("safranin only tints gramPos (reference mix stays deep purple)",
    s.pos.colour === 0x451d68, hex(s.pos.colour));
}

console.log("=== Gram unit: stain-state guards and accessors ===");
{
  const blank = createStainState();
  blank.applyReagent("io", 5, 1);
  const b1 = blank.snapshot();
  ck("iodine alone does not colour an unstained smear",
    b1.pos.alpha === 0 && b1.neg.alpha === 0, JSON.stringify(b1));
  blank.applyReagent("de", 5, 1);
  ck("decoloriser alone creates no ghost cells", blank.snapshot().neg.alpha === 0);
  blank.applyReagent("sa", 5, 1);
  ck("safranin alone does not colour an unstained smear", blank.snapshot().neg.alpha === 0);

  const unc = createStainState();
  unc.applyReagent("cv", 5, 0);
  ck("zero coverage applies nothing", unc.snapshot().pos.alpha === 0);
  unc.applyReagent("cv", 0, 1);
  ck("zero dt applies nothing", unc.snapshot().pos.alpha === 0);
  ck("unknown reagent is rejected", unc.applyReagent("mercury", 1, 1) === false);
  ck("known reagent is accepted", unc.applyReagent("cv", 1, 1) === true);

  const w = createStainState();
  drive(w, dt => w.applyReagent("cv", dt, 1), 3);
  drive(w, dt => w.applyReagent("water", dt, 1), 3);
  const w2 = w.snapshot();
  ck("water as a reagent washes off the film but keeps the stain",
    w2.film.alpha === 0 && w2.film.colour === COLOURLESS && w2.pos.colour === 0x6a2fa0,
    JSON.stringify(w2));

  const d = createStainState();
  d.setDamp(0.4);
  ck("setDamp stores the value", Math.abs(d.getDamp() - 0.4) < 1e-12, String(d.getDamp()));
  d.setDamp(5);
  ck("setDamp clamps high", d.getDamp() === 1);
  d.setDamp(-1);
  ck("setDamp clamps low", d.getDamp() === 0);

  const iso = createStainState();
  drive(iso, dt => iso.applyReagent("cv", dt, 1), 3);
  const m1 = iso.snapshot();
  m1.pos.colour = 0x123456;
  m1.film.alpha = 0.77;
  const m2 = iso.snapshot();
  ck("snapshot returns a defensive copy",
    m2.pos.colour === 0x6a2fa0 && m2.film.alpha === REAGENTS.cv.filmOpacity,
    JSON.stringify(m2));
  ck("snapshot has exactly pos/neg/film keys",
    JSON.stringify(Object.keys(m2).sort()) === JSON.stringify(["film", "neg", "pos"]),
    Object.keys(m2).join(","));
}

console.log("=== Gram unit: contract + stub factories ===");
{
  ck("GRAM_CONTRACT pins createGramSlide",
    GRAM_CONTRACT.createGramSlide.includes("setPopulations") && GRAM_CONTRACT.createGramSlide.includes("getImpactPoint")
    && GRAM_CONTRACT.createGramSlide.includes("getLowEdge") && GRAM_CONTRACT.createGramSlide.includes("setTilt")
    && GRAM_CONTRACT.createGramSlide.includes("setWetness"), GRAM_CONTRACT.createGramSlide);
  ck("GRAM_CONTRACT pins createGramPour",
    ["startPour", "tick", "setFilm", "clear"].every(m => GRAM_CONTRACT.createGramPour.includes(m)),
    GRAM_CONTRACT.createGramPour);
  ck("GRAM_CONTRACT pins createGramRinse",
    ["start", "stop", "tick", "streamMode"].every(m => GRAM_CONTRACT.createGramRinse.includes(m)),
    GRAM_CONTRACT.createGramRinse);
  ck("GRAM_CONTRACT pins createGramChoreo",
    ["setStep", "tick"].every(m => GRAM_CONTRACT.createGramChoreo.includes(m))
    && GRAM_CONTRACT.createGramChoreo.includes("chem"), GRAM_CONTRACT.createGramChoreo);

  /* stub slide */
  const slide = makeStubSlide({ position: { x: -5.425, y: 0.9645, z: 0.18 } });
  ck("stub slide exposes the full contract",
    typeof slide.group !== "undefined"
    && ["setPopulations", "setTilt", "setWetness", "getImpactPoint", "getLowEdge"]
      .every(m => typeof slide[m] === "function"));
  slide.setTilt(1.2);
  ck("stub slide clamps tilt to the 45 deg bound", Math.abs(slide.getTilt() - 45 * Math.PI / 180) < 1e-12,
    String(slide.getTilt()));
  slide.setTilt(35 * Math.PI / 180);
  const impact = slide.getImpactPoint();
  const low = slide.getLowEdge();
  ck("stub slide low edge sits below the impact point when tilted",
    low.y < impact.y, low.y + " vs " + impact.y);
  slide.setTilt(0);
  ck("stub slide may rest flat", slide.getTilt() === 0);
  ck("stub slide impact point sits on the upper face untilted",
    Math.abs(slide.getImpactPoint().y - (0.9645 + 0.0015)) < 1e-12
    && slide.getImpactPoint().x === -5.425, JSON.stringify(slide.getImpactPoint()));
  slide.setPopulations({ pos: { colour: 0x6a2fa0, alpha: 1 }, neg: { colour: 0xffffff, alpha: 0 }, film: { colour: 0x6a2fa0, alpha: 0.8 } });
  slide.setWetness(0.7);
  slide.setWetness(7);
  ck("stub slide records calls and clamps wetness",
    slide.calls.populations.length === 1 && slide.getWetness() === 1 && slide.calls.tilts.length === 3);

  /* stub pour */
  let done = 0;
  const pour = makeStubPour();
  ck("stub pour exposes the full contract",
    ["startPour", "tick", "setFilm", "clear"].every(m => typeof pour[m] === "function"));
  pour.startPour("cv", { from: { x: 0, y: 1, z: 0 }, to: { x: -5.425, y: 0.96, z: 0.18 }, onDone: () => { done++; } });
  ck("stub pour records the pour", pour.calls.pours.length === 1 && pour.calls.pours[0].reagentId === "cv" && pour.isPouring());
  for (let i = 0; i < 10; i++) pour.tick(0.05);
  ck("stub pour does not finish early", done === 0 && pour.isPouring(), String(done));
  for (let i = 0; i < Math.ceil(REAGENTS.cv.pourDuration / 0.1) + 2; i++) pour.tick(0.1);
  ck("stub pour fires onDone exactly once", done === 1 && !pour.isPouring(), String(done));
  pour.tick(1);
  ck("stub pour does not refire onDone", done === 1, String(done));
  pour.setFilm({ pos: { colour: 1, alpha: 1 }, neg: { colour: 1, alpha: 1 }, film: { colour: 0x6a2fa0, alpha: 0.88 } });
  pour.clear();
  ck("stub pour records films and clear",
    pour.calls.films.length === 1 && pour.calls.cleared === 1);

  /* stub rinse */
  const rinse = makeStubRinse();
  const tap = { mode: "drip" };
  ck("stub rinse exposes the full contract",
    ["start", "stop", "tick", "streamMode"].every(m => typeof rinse[m] === "function"));
  rinse.start({ tapRef: tap, slide: slide, reagentId: "cv" });
  ck("stub rinse records start", rinse.isRunning() && rinse.calls.starts.length === 1 && rinse.calls.starts[0].reagentId === "cv");
  rinse.streamMode(tap, true);
  ck("stub rinse forces the continuous stream", tap.mode === "stream" && rinse.calls.modes.length === 1);
  rinse.tick(0.05);
  rinse.stop();
  ck("stub rinse records tick and stop", !rinse.isRunning() && rinse.calls.stops === 1 && rinse.calls.ticks === 1 && rinse.calls.lastDt === 0.05);
  rinse.streamMode(tap, false);
  ck("stub rinse restores the previous tap mode", tap.mode === "drip" && rinse.calls.modes.length === 2);
}

console.log(`\nGram shared unit: ${pass} passed, ${fail} failed`);
if (fail) process.exit(1);
