/**
 * Phase 5 unit tests: virtual student behaviour (js/students.js)
 * (no browser, no THREE).
 *
 * Drives the real student FSM against the real world store (objects.js) and
 * the real science layer: demo questioning, practice reacting to the live
 * microscope state, review collaboration, determinism, zero AI API usage.
 *
 * Run: node scripts/phase5_unit.mjs   (exit 0 = all pass)
 */
import { createWorld } from "../js/objects.js";
import { createScience } from "../js/science.js";
import { createStudents, DIALOGUE, STUDENT_STATES as S } from "../js/students.js";

const checks = [];
let fails = 0;
const check = (name, ok, detail) => {
  checks.push({ name, ok: Boolean(ok), detail });
  if (!ok) fails++;
  console.log(`${ok ? "PASS" : "FAIL"}  ${name}${detail ? "  [" + detail + "]" : ""}`);
};

const science = createScience();

function buildWorld() {
  const world = createWorld();
  world.register({ id: "lesson", kind: "lesson",
    state: { phase: "idle", topic: "general", experimentId: "osmosis", t: 0 } });
  world.register({ id: "micro.front", kind: "microscope",
    state: { objective: 40, focus: 0.5, illumination: false, stage: { x: 0, y: 0 },
      specimen: "onion", stain: "iodine", lastObservation: null } });
  return world;
}

function tickFor(stu, sec, dt = 0.1) {
  const n = Math.round(sec / dt);
  for (let i = 0; i < n; i++) stu.tick(dt);
}

function count(stu, type) {
  return stu.events.filter((e) => e.type === type).length;
}

/* ---- creation ---- */
{
  const world = buildWorld();
  const stu = createStudents({ seed: 7, world, science });
  check("six students created", stu.students.length === 6);
  check("students have seats + traits",
    stu.students.every((s) => typeof s.seat.x === "number" && s.attention > 0 && s.skill > 0 && s.skill <= 1));
  check("unique names + ids", new Set(stu.students.map((s) => s.name)).size === 6 &&
    new Set(stu.students.map((s) => s.id)).size === 6);
  check("initial state idle", stu.statuses().every((s) => s.state === S.IDLE));
  check("dialogue pools present",
    DIALOGUE.ask.microscope.length >= 3 && DIALOGUE.answer.osmosis.length >= 3 &&
    DIALOGUE.mistake.length >= 3 && DIALOGUE.feedback.length >= 3 &&
    DIALOGUE.record.length >= 3 && DIALOGUE.collab.length >= 3);
  check("apiCalls starts at 0", stu.apiCalls() === 0);
}

/* ---- demo phase: watch / look / one question round ---- */
{
  const world = buildWorld();
  const stu = createStudents({ seed: 7, world, science });
  stu.setLesson("demo", "microscope", "osmosis");
  tickFor(stu, 30);
  check("demo: everyone watching", stu.statuses().every((s) => s.state === S.WATCH ||
    s.state === S.LOOK), stu.statuses().map((s) => s.state).join(","));
  check("demo: look events emitted", count(stu, "look") >= 1, "look=" + count(stu, "look"));
  check("demo: exactly one question per demo", count(stu, "ask") === 1, "ask=" + count(stu, "ask"));
  check("demo: raise then ask then listen then respond",
    count(stu, "raise") === 1 && count(stu, "listen") === 1 && count(stu, "respond") >= 1);
  const askEv = stu.events.find((e) => e.type === "ask");
  check("demo: question line comes from the local pool",
    !!askEv && DIALOGUE.ask.microscope.includes(askEv.line), askEv && askEv.line);
  const listenEv = stu.events.find((e) => e.type === "listen");
  check("demo: teacher answer from the local pool",
    !!listenEv && DIALOGUE.answer.microscope.includes(listenEv.line));
  check("demo: exactly one student questions (no pile-on)",
    stu.students.reduce((a, s) => a + s.questions, 0) === 1);
  check("demo: zero AI API calls", stu.apiCalls() === 0);
}

/* ---- practice reacting to simulation state (dark scope) ---- */
{
  const world = buildWorld();
  const stu = createStudents({ seed: 7, world, science });
  stu.setLesson("demo", "microscope", "osmosis");
  tickFor(stu, 20);
  world.set("lesson", { phase: "practice", topic: "microscope" });
  tickFor(stu, 30);
  check("practice: collect event before the station", count(stu, "collect") >= 6,
    "collect=" + count(stu, "collect"));
  check("practice dark: every student made a plausible mistake",
    stu.students.every((s) => s.mistakes >= 1),
    stu.students.map((s) => s.mistakes).join(","));
  check("practice dark: mistake reason names the live scope problem",
    stu.events.filter((e) => e.type === "mistake").every((e) => /no-light|illumination/.test(e.reason || "")));
  check("practice dark: feedback follows each mistake pattern",
    count(stu, "feedback") >= 6 && count(stu, "feedback") <= count(stu, "mistake"));
  check("practice dark: nobody records an unusable field",
    stu.students.every((s) => s.records === 0));
  check("practice dark: patience erodes with mistakes",
    stu.students.some((s) => s.patience < 1));
  check("practice dark: zero API calls", stu.apiCalls() === 0);

  /* teacher fixes the scope mid-lesson: students recover (state-driven) */
  world.set("micro.front", { illumination: true, objective: 10, focus: 0.5 });
  tickFor(stu, 45);
  check("practice fixed: every student records exactly once",
    stu.students.every((s) => s.records === 1),
    stu.students.map((s) => s.records).join(","));
  const rec = stu.events.filter((e) => e.type === "record");
  check("practice fixed: recorded values match the science model",
    rec.length === 6 && rec.every((e) => e.cellsAcross === 133 && e.fovMm === 2),
    "cells=" + ((rec[0] || {}).cellsAcross));
  check("practice fixed: record line from the local pool",
    rec.every((e) => DIALOGUE.record.includes(e.line)));
  check("practice fixed: return + complete events",
    count(stu, "return") === 6 && count(stu, "complete") === 6);
  check("practice fixed: task marked complete",
    stu.students.every((s) => s.task === "complete"));
  check("practice total: still zero API calls", stu.apiCalls() === 0);
}

/* ---- practice on a non-micro topic: procedural mistake then record ---- */
{
  const world = buildWorld();
  const stu = createStudents({ seed: 3, world, science });
  stu.setLesson("practice", "osmosis", "osmosis");
  tickFor(stu, 60);
  check("osmosis practice: students record via the science run",
    stu.students.every((s) => s.records === 1), stu.students.map((s) => s.records).join(","));
  const rec = stu.events.find((e) => e.type === "record");
  check("osmosis practice: recorded value is the real module result",
    !!rec && rec.value && typeof rec.value.isotonicConcentrationM === "number",
    rec && rec.value && rec.value.isotonicConcentrationM);
  check("osmosis practice: plausible procedural mistakes happen",
    count(stu, "mistake") >= 1 && count(stu, "mistake") <= 30, "mistakes=" + count(stu, "mistake"));
}

/* ---- review: collaboration ---- */
{
  const world = buildWorld();
  const stu = createStudents({ seed: 7, world, science });
  stu.setLesson("practice", "microscope", "osmosis");
  world.set("micro.front", { illumination: true, objective: 10 });
  tickFor(stu, 45);
  world.set("lesson", { phase: "review", topic: "microscope" });
  tickFor(stu, 20);
  check("review: collaboration events among students with records",
    count(stu, "collab") >= 6, "collab=" + count(stu, "collab"));
  check("review: collab lines from the local pool",
    stu.events.filter((e) => e.type === "collab").every((e) => DIALOGUE.collab.includes(e.line)));
  check("review: collab pairs reference a partner",
    stu.events.filter((e) => e.type === "collab").every((e) => typeof e.with === "string"));
}

/* ---- lesson switching resets cleanly ---- */
{
  const world = buildWorld();
  const stu = createStudents({ seed: 7, world, science });
  stu.setLesson("demo", "enzyme", "enzyme");
  tickFor(stu, 15);
  world.set("lesson", { phase: "practice", topic: "enzyme", experimentId: "enzyme" });
  tickFor(stu, 60);
  check("phase switch demo->practice picks up collect/atStation",
    stu.students.every((s) => ["record", "return", "complete", "atStation", "mistake", "feedback", "retry"]
      .includes(s.state)), stu.statuses().map((s) => s.state).join(","));
  world.set("lesson", { phase: "idle", topic: "enzyme" });
  tickFor(stu, 5);
  check("phase idle returns everyone to idle",
    stu.statuses().every((s) => s.state === S.IDLE || s.state === S.COMPLETE),
    stu.statuses().map((s) => s.state).join(","));
}

/* ---- determinism ---- */
{
  function replay(seed) {
    const world = buildWorld();
    const stu = createStudents({ seed, world, science });
    stu.setLesson("demo", "microscope", "osmosis");
    tickFor(stu, 25);
    world.set("lesson", { phase: "practice", topic: "microscope" });
    tickFor(stu, 20);
    world.set("micro.front", { illumination: true, objective: 10 });
    tickFor(stu, 30);
    return stu.events.map((e) => e.type + ":" + (e.line || "")).join("|");
  }
  check("same seed replays the identical event stream", replay(7) === replay(7));
  check("different seed diverges (not hard-coded)", replay(7) !== replay(11));
}

/* ---- setLesson mirrors into the world store ---- */
{
  const world = buildWorld();
  const stu = createStudents({ seed: 7, world, science });
  stu.setLesson("review", "photosynthesis", "photosynthesis");
  const ls = world.get("lesson").state;
  check("setLesson writes through to the world",
    ls.phase === "review" && ls.topic === "photosynthesis" && ls.experimentId === "photosynthesis");
}

/* ---- stats surface for diag ---- */
{
  const world = buildWorld();
  const stu = createStudents({ seed: 7, world, science });
  stu.setLesson("demo", "microscope", "osmosis");
  tickFor(stu, 20);
  const st = stu.stats();
  check("stats: counts + zero apiCalls",
    st.count === 6 && st.questions === 1 && st.apiCalls === 0 && st.events > 0,
    JSON.stringify(st));
  check("statuses expose id/state/task/mistakes/records",
    stu.statuses().every((s) => s.id && s.state && s.task != null &&
      typeof s.mistakes === "number" && typeof s.records === "number"));
}

/* ---- summary ---- */
if (fails) {
  console.error(`\nFAIL  ${fails} check(s) failed`);
  process.exit(1);
}
console.log(`\nOK  all ${checks.length} checks passed`);
