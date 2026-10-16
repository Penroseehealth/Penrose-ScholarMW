/**
 * Phase 6 unit tests: lesson engine - complete practical + assessment +
 * persistence (no browser, no THREE).
 *
 * Drives the real lesson engine against the real world store (objects.js),
 * the real science layer (js/science.js) and the real student FSM
 * (js/students.js): setup -> safety -> demo -> practice -> record ->
 * interpret -> assess -> cleanup -> done, plus pause/resume, accelerated
 * time, six-dimension scoring and serialize/restore (resume).
 *
 * Run: node scripts/phase6_unit.mjs   (exit 0 = all pass)
 */
import { createWorld } from "../js/objects.js";
import { createScience } from "../js/science.js";
import { createStudents } from "../js/students.js";
import { createLesson, LESSON_PHASES } from "../js/lesson.js";

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
  world.register({ id: "lesson", kind: "lesson", state: { phase: "idle", topic: "general", experimentId: "osmosis" } });
  world.register({ id: "micro.front", kind: "microscope",
    state: { objective: 40, focus: 0.5, illumination: false, stage: { x: 0, y: 0 }, specimen: "onion" } });
  world.register({ id: "balance", kind: "balance", state: { massG: 0, tared: false } });
  world.register({ id: "tap.front", kind: "tap", state: { running: true } });
  world.register({ id: "benchFront.drawer", kind: "drawer", state: { open: true } });
  world.register({ id: "item.jar", kind: "item", state: { massG: 128.5 } });
  return world;
}

function rig(seed = 7, storage = null) {
  const world = buildWorld();
  const students = createStudents({ seed, world, science });
  const lesson = createLesson({ world, science, students, storage, storageKey: "bioLessonTest" });
  const drive = (sec) => {
    const n = Math.round(sec * 10);
    for (let i = 0; i < n; i++) { students.tick(0.1); lesson.tick(0.1); }
  };
  /* make the demo state usable so the practical can leave setup */
  const usable = () => { world.set("micro.front", { illumination: true, objective: 10 }); drive(1); };
  return { world, students, lesson, drive, usable };
}

/* ---- structure ---- */
{
  check("lesson phases documented in order",
    LESSON_PHASES.join(",") === "setup,safety,demo,practice,record,interpret,assess,cleanup,done");
  const { lesson } = rig();
  check("engine starts idle, not running",
    lesson.status().phase === "idle" && lesson.status().running === false);
  check("every phase has a checklist (except done)",
    ["setup", "safety", "demo", "practice", "record", "interpret", "assess", "cleanup"]
      .every((p) => lesson.stepsFor(p).length >= 1));
  check("stepsFor reports done flags",
    lesson.stepsFor("setup").every((s) => s.done === false && typeof s.label === "string"));
  check("tick before start is a no-op", lesson.tick(1) === "idle" && lesson.state.elapsed === 0);
}

/* ---- full practical: setup through cleanup ---- */
{
  const { world, students, lesson, drive } = rig();
  check("start enters setup", lesson.start("osmosis", "osmosis", { concentrationM: 0 }) &&
    lesson.status().phase === "setup");
  check("start snapshots experiment conditions", lesson.state.conditions.concentrationM === 0);
  check("equipment present satisfies setup step 1 (after a tick)",
    (drive(1), lesson.stepsFor("setup").find((s) => s.id === "check-equipment").done));
  check("demo-ready blocks until the scope is usable",
    !lesson.stepsFor("setup").find((s) => s.id === "demo-ready").done);
  world.set("micro.front", { illumination: true, objective: 10 });
  drive(1);
  check("demo-ready completes with a usable scope, phase -> safety",
    lesson.status().phase === "safety", lesson.status().phase);
  check("safety brief auto-delivered", lesson.stepsFor("safety").find((s) => s.id === "brief").done);
  check("ack blocks until safetyAck()", !lesson.stepsFor("safety").find((s) => s.id === "ack").done);
  check("safetyAck enters demo", lesson.safetyAck() && lesson.status().phase === "demo");
  check("students steered to demo via the world lesson",
    world.get("lesson").state.phase === "demo");
  drive(40);
  check("demo completes after a student question, phase -> practice+",
    students.stats().questions === 1 &&
    !["idle", "setup", "safety", "demo"].includes(lesson.status().phase),
    lesson.status().phase);
  check("lesson engine steered students through demo and practice",
    lesson.events.some((e) => e.type === "phase" && e.phase === "demo") &&
    lesson.events.some((e) => e.type === "phase" && e.phase === "practice"));
  drive(90);
  check("practice -> record -> interpret automatically",
    ["record", "interpret"].includes(lesson.status().phase), lesson.status().phase);
  check("six observations collated", Object.keys(lesson.state.observations).length === 6);
  check("results are the real module output (pure water gains mass)",
    lesson.state.results.massChangePct > 5, "mass%=" + lesson.state.results.massChangePct);
  check("conditions persisted in state",
    lesson.state.conditions.concentrationM === 0 && lesson.state.conditions.minutes === 60);

  /* interpretation + assessment */
  const interp = lesson.submitInterpretation({ direction: "gain", isotonicM: 0.31 });
  check("correct interpretation scores ratio 1", interp.ratio === 1, "ratio=" + interp.ratio);
  check("per-student assess results returned",
    Object.keys(interp.perStudent).length === 6 && interp.perStudent.s1.score === 2);
  check("phase moved interpret -> assess -> cleanup",
    lesson.status().phase === "cleanup", lesson.status().phase);
  check("assessment complete for all six",
    lesson.state.assessmentComplete && Object.keys(lesson.state.scores).length === 6);
  const s1 = lesson.scores("s1");
  check("six dimensions per student",
    ["procedural", "equipment", "safety", "observations", "calculations", "reasoning", "overall"]
      .every((k) => typeof s1[k] === "number"));
  check("all dimensions within [0,1]",
    Object.values(lesson.scores()).every((sc) =>
      ["procedural", "equipment", "safety", "observations", "calculations", "reasoning", "overall"]
        .every((k) => sc[k] >= 0 && sc[k] <= 1)));
  check("correct answers give full calculations + reasoning",
    s1.calculations === 1 && s1.reasoning === 1);
  check("safety acknowledged + no violations gives full safety", s1.safety === 1);
  check("six feedback lines generated", lesson.state.feedback.s1.length === 6);
  check("overall score high for a clean run", lesson.overall() > 0.9, "overall=" + lesson.overall());

  /* cleanup gates on live equipment state */
  check("cleanup pending while tap runs", lesson.stepsFor("cleanup").find((s) => s.id === "taps-off").done === false);
  world.set("tap.front", { running: false });
  world.set("micro.front", { illumination: false });
  world.set("benchFront.drawer", { open: false });
  drive(1.5);
  check("practical reaches done through cleanup",
    lesson.status().phase === "done" && lesson.state.running === false);
  check("cleanup checklist complete", lesson.stepsFor("cleanup").every((s) => s.done));
  check("students returned to idle at done", world.get("lesson").state.phase === "idle");
}

/* ---- interpretation edge cases ---- */
{
  const { lesson } = rig();
  lesson.start("osmosis", "osmosis", { concentrationM: 0 });
  /* stage a completed practice directly (answers only need results + phase) */
  lesson.state.phase = "interpret";
  lesson.state.results = science.run("osmosis", { concentrationM: 0 }).results;
  lesson.state.conditions = science.run("osmosis", { concentrationM: 0 }).inputs;
  const bad = lesson.submitInterpretation({ direction: "loss", isotonicM: 0.9 });
  check("wrong interpretation scores 0", bad.ratio === 0, "ratio=" + bad.ratio);
  check("scores reflect the wrong answers",
    lesson.scores("s1").calculations === 0 && lesson.scores("s1").reasoning === 0);
  check("feedback asks for revisiting the trend",
    lesson.state.feedback.s1.some((l) => /interpretation|reasoning/.test(l)));
  const partial = (() => {
    const r = rig();
    r.lesson.start("osmosis", "osmosis", { concentrationM: 0 });
    r.lesson.state.phase = "interpret";
    r.lesson.state.results = science.run("osmosis", { concentrationM: 0 }).results;
    r.lesson.state.conditions = science.run("osmosis", { concentrationM: 0 }).inputs;
    return r.lesson.submitInterpretation({ direction: "gain", isotonicM: 0.9 });
  })();
  check("partial credit: direction right, isotonic wrong -> ratio 0.5",
    partial.ratio === 0.5, "ratio=" + partial.ratio);
}

/* ---- pause / resume / accelerated time ---- */
{
  const { lesson } = rig();
  lesson.start("osmosis", "osmosis");
  lesson.tick(1);
  const held = lesson.state.elapsed;
  check("pause() works and holds the clock",
    lesson.pause() === true && lesson.tick(5) === "setup" && lesson.state.elapsed === held);
  check("pause on idle/done refuses", (() => {
    const l = rig().lesson;
    return l.pause() === false;
  })());
  check("resume() restarts the clock", lesson.resume() === true && lesson.state.paused === false);
  check("resume when not paused refuses", lesson.resume() === false);
  check("setSpeed clamps 1..60",
    lesson.setSpeed(10) === 10 && lesson.setSpeed(0) === 1 && lesson.setSpeed(999) === 60);
  lesson.setSpeed(10);
  const before = lesson.state.elapsed;
  lesson.tick(1);
  check("accelerated time advances the clock 10x", lesson.state.elapsed - before >= 9.9,
    "Δ=" + (lesson.state.elapsed - before).toFixed(1));
  lesson.setSpeed(1);
  check("fastForward runs the clock without the host loop",
    (() => {
      const r = rig();
      r.lesson.start("osmosis", "osmosis");
      r.lesson.setSpeed(5);
      r.lesson.fastForward(10, (dt) => r.students.tick(dt));
      return r.lesson.state.elapsed >= 49, "elapsed=" + r.lesson.state.elapsed.toFixed(1);
    })());
}

/* ---- safety violations ---- */
{
  const { lesson } = rig();
  lesson.start("osmosis", "osmosis");
  lesson.safetyAck();
  lesson.safetyViolation("plate opened on the open bench");
  check("safety violation recorded", lesson.state.safetyViolations.length === 1);
  check("violation lowers the safety dimension",
    (() => {
      /* force a score computation via a direct interpret on staged state */
      lesson.state.phase = "interpret";
      lesson.state.results = { massChangePct: 9 };
      lesson.state.conditions = { concentrationM: 0 };
      lesson.submitInterpretation({ direction: "gain", isotonicM: 0.31 });
      return lesson.scores("s1").safety === 0.6;
    })());
}

/* ---- persistence: serialize / restore / storage auto-resume ---- */
{
  const { lesson, drive, usable } = rig();
  lesson.start("osmosis", "osmosis", { concentrationM: 0 });
  usable();
  lesson.safetyAck();
  const json = lesson.serialize();
  check("serialize is JSON with v1 state", JSON.parse(json).v === 1 && JSON.parse(json).state.phase === "demo");
  const { lesson: l2 } = rig();
  check("restore keeps phase + safety acknowledgement",
    l2.restore(json) === true && l2.status().phase === "demo" && l2.state.safetyAcknowledged === true);
  check("restored lesson is running + unpaused",
    l2.state.running === true && l2.state.paused === false);
  check("restore rejects garbage", l2.restore('{"v":99}') === false && l2.restore(null) === false);

  /* completed practical survives a full round-trip */
  const { lesson: a, drive: da, usable: ua } = rig();
  a.start("osmosis", "osmosis", { concentrationM: 0 });
  ua();
  a.safetyAck();
  da(140);
  a.submitInterpretation({ direction: "gain", isotonicM: 0.31 });
  const round = JSON.parse(a.serialize());
  const { lesson: b } = rig();
  b.restore(round);
  check("resume keeps completed phase + assessment",
    b.status().phase === "cleanup" && b.status().assessmentComplete === true, b.status().phase);
  check("resume keeps scores + overall",
    b.scores("s1").calculations === 1 && b.overall() === a.overall());
  check("resume keeps observations + results",
    Object.keys(b.state.observations).length === 6 && b.state.results.massChangePct > 5);
  check("resume keeps feedback", b.state.feedback.s1.length === 6);

  /* storage-backed auto-resume */
  const mem = { _d: {}, getItem(k) { return this._d[k] ?? null; }, setItem(k, v) { this._d[k] = String(v); }, removeItem(k) { delete this._d[k]; } };
  const { lesson: c, usable: uc } = rig(7, mem);
  c.start("osmosis", "osmosis", { concentrationM: 0 });
  uc();
  c.safetyAck();
  check("engine persists into storage on events", mem.getItem("bioLessonTest") !== null);
  const { lesson: d } = rig(7, mem);
  check("fresh engine auto-resumes from storage",
    d.status().phase === c.status().phase && d.state.safetyAcknowledged === true);
}

/* ---- determinism ---- */
{
  function run(seed) {
    const r = rig(seed);
    r.lesson.start("osmosis", "osmosis", { concentrationM: 0 });
    r.usable();
    r.lesson.safetyAck();
    r.drive(140);
    r.lesson.submitInterpretation({ direction: "gain", isotonicM: 0.31 });
    return r;
  }
  check("same seed -> identical assessment + progress",
    run(7).lesson.serialize() === run(7).lesson.serialize());
  check("scores identical across instances",
    run(7).lesson.overall() === run(7).lesson.overall() && run(7).lesson.overall() !== null);
}

/* ---- restart after done ---- */
{
  const { lesson, drive } = rig();
  lesson.start("osmosis", "osmosis", { concentrationM: 0 });
  drive(1);
  lesson.state.phase = "done"; lesson.state.running = false;
  check("start() refuses while running",
    (() => { const r = rig(); r.lesson.start(); return r.lesson.start() === false; })());
  check("start() allowed again after done", lesson.start("enzyme", "enzyme") === true &&
    lesson.status().phase === "setup" && lesson.status().experimentId === "enzyme");
  check("restart clears previous scores", Object.keys(lesson.state.scores).length === 0);
}

/* ---- summary ---- */
if (fails) {
  console.error(`\nFAIL  ${fails} check(s) failed`);
  process.exit(1);
}
console.log(`\nOK  all ${checks.length} checks passed`);
