/**
 * Phase 3 unit tests: equipment action catalogue + state consistency
 * (no browser, no THREE).
 *
 * Drives the real nav grid, the real Phase-1 locomotion controller and the
 * real Phase-2 behaviour module against the Phase-3 world-store additions
 * (action registry, wireBalance) with an extended fake rig. Registrations,
 * action definitions and scenarios mirror the host wiring in index.html.
 *
 * Run: node scripts/phase3_unit.mjs   (exit 0 = all pass)
 */
import { createNav } from "../js/nav.js";
import { createTeacherController } from "../js/teacher_controller.js";
import { createBehaviour } from "../js/behaviour.js";
import { createWorld } from "../js/objects.js";

const checks = [];
let fails = 0;
const check = (name, ok, detail) => {
  checks.push({ name, ok: Boolean(ok), detail });
  if (!ok) fails++;
  console.log(`${ok ? "PASS" : "FAIL"}  ${name}${detail ? "  [" + detail + "]" : ""}`);
};

/* ---- real lab layout (must match index.html) ---- */
const FW = 12, FD = 10, HX = FW / 2, HZ = FD / 2, WT = 0.25;

function buildLabNav() {
  const nav = createNav();
  const x0 = -HX + WT / 2, x1 = HX - WT / 2, z0 = -HZ + WT / 2, z1 = HZ - WT / 2;
  nav.addRect(x0 - WT, z0 - WT, x1 + WT, z0, "wall-front");
  nav.addRect(x0 - WT, z1, x1 + WT, z1 + WT, "wall-back");
  nav.addRect(x0 - WT, z0, x0, z1, "wall-left");
  nav.addRect(x1, z0, x1 + WT, z1, "wall-right");
  for (const bx of [-2.4, 2.4])
    for (const bz of [-1.5, 0.7, 2.9]) {
      nav.addRect(bx - 1.5, bz - 0.6, bx + 1.5, bz + 0.6, "island-bench");
      for (const sx of [-0.5, 0.5])
        for (const sz of [-0.92, 0.92])
          nav.addCircle(bx + sx, bz + sz, 0.15, "stool");
    }
  nav.addRect(-1.5, -3.0, 1.5, -2.3, "front-bench");
  nav.addRectRot(-HX + 0.35, -0.6, 7.6, 0.7, Math.PI / 2, "left-bench");
  nav.addRect(-2.32, -4.92, 2.32, -3.77, "podium");
  nav.addRect(-3.22, -3.77, -2.32, -2.87, "podium-steps-l");
  nav.addRect(2.32, -3.77, 3.22, -2.87, "podium-steps-r");
  nav.addRect(-3.15, -4.74, -2.35, -4.36, "cab-front-l");
  nav.addRect(2.35, -4.74, 3.15, -4.36, "cab-front-r");
  nav.addRectRot(-HX + 0.8, 1.4, 0.8, 0.38, Math.PI / 2, "cab-left");
  nav.addRect(4.74, -4.85, 5.36, -4.25, "autoclave");
  nav.addRect(3.825, 4.04, 5.375, 4.84, "bsc");
  nav.build({ x0, z0, x1, z1 }, 0.25, 0.1);
  return nav;
}

/* ---- shared scene constants (mirror host wiring) ---- */
const BSC = { x: 4.6, z: 4.44 };
const STAND = { x: 4.6, z: 3.72 };
const PHONE = { x: 0.55, y: 0.9, z: -2.65 };
const PHONE_APPROACH = { x: 0.55, z: -1.9 };
const WINDOW_LOOK = { x: 3.3, y: 1.9, z: 5 };
const WINDOW_APPROACH = { x: 3.3, z: 4.15 };
const CAB_FR = { x: 2.75, z: -4.55 };
const CAB_APPROACH = { x: 2.75, z: -4.05 };
const SLIDES_HANDLE = { x: 2.75, y: 0.28, z: -4.35 };
const JAR_IN_DRAWER = { x: 2.75, y: 0.22, z: -4.55 };
const BENCH_PLACE = { x: 1.05, y: 0.9, z: -2.65 };
const H = 0.9;
const MICRO = { x: 0.45, z: -2.65 };
const MICRO_APPROACH = { x: 0.5, z: -1.9 };
const TAP_APPROACH = { x: 0, z: -1.9 };
const BAL = { x: -1.05, z: -2.9 };
const BAL_PAN = { x: -1.05, y: H + 0.19, z: -2.95 };
const BAL_APPROACH = { x: -0.5, z: -1.9 };
const BDR_APPROACH = { x: -0.584, z: -1.9 };
const JAR_MASS = 128.5;

function makeWorld() {
  const w = createWorld();
  /* Phase 2 registrations (mirror index.html) */
  w.register({ id: "phone", kind: "phone", pos: { ...PHONE }, state: { ringing: false, answered: false, onHook: true },
    points: { cradle: { x: PHONE.x, y: 1.0, z: -2.62 }, approach: { ...PHONE_APPROACH } } });
  w.register({ id: "phone.handset", kind: "handset", pos: { x: PHONE.x, y: 1.0, z: -2.62 }, state: { heldBy: null } });
  w.register({ id: "window.noise", kind: "marker", pos: { ...WINDOW_LOOK }, points: { look: { ...WINDOW_LOOK }, approach: { ...WINDOW_APPROACH } } });
  w.register({ id: "cabFR", kind: "cabinet", pos: { x: CAB_FR.x, y: 0, z: CAB_FR.z }, points: { approach: { ...CAB_APPROACH }, face: { x: CAB_FR.x, y: 0.3, z: -4.36 } } });
  w.register({ id: "cabFR.slides", kind: "drawer", state: { open: false }, points: { handle: { ...SLIDES_HANDLE } } });
  w.register({ id: "item.jar", kind: "item", pos: { ...JAR_IN_DRAWER }, state: { heldBy: null, loc: "cabFR.slides", massG: JAR_MASS }, points: { pos: { ...JAR_IN_DRAWER } } });
  w.register({ id: "bench.place", kind: "marker", pos: { ...BENCH_PLACE }, points: { target: { ...BENCH_PLACE }, approach: { ...PHONE_APPROACH } } });
  /* Phase 3 registrations (mirror index.html) */
  w.register({ id: "micro.front", kind: "microscope", pos: { x: MICRO.x, y: H, z: MICRO.z },
    state: { objective: 40, focus: 0.5, illumination: false, stage: { x: 0, y: 0 }, slide: "pos" },
    points: { stage: { x: MICRO.x, y: H + 0.2, z: MICRO.z }, nosepiece: { x: MICRO.x, y: H + 0.31, z: MICRO.z },
      rheostat: { x: 0.538, y: H + 0.02, z: -2.622 }, eyepieces: { x: MICRO.x, y: H + 0.44, z: -2.52 },
      approach: { ...MICRO_APPROACH } } });
  w.register({ id: "tap.front", kind: "tap", pos: { x: 0, y: H, z: -2.37 }, state: { running: false, dir: 1 },
    points: { handle: { x: 0.02, y: H + 0.13, z: -2.26 }, spout: { x: 0, y: H + 0.26, z: -2.62 },
      approach: { ...TAP_APPROACH } } });
  w.register({ id: "balance", kind: "balance", pos: { x: BAL.x, y: H, z: BAL.z }, state: { massG: 0, tare: true, onItem: null },
    points: { pan: { ...BAL_PAN }, display: { x: BAL.x, y: H + 0.085, z: -2.83 }, approach: { ...BAL_APPROACH } } });
  w.register({ id: "benchFront.drawer", kind: "drawer", state: { open: false },
    points: { handle: { x: -0.584, y: 0.77, z: -2.29 }, face: { x: -0.584, y: 0.7, z: -2.34 },
      approach: { ...BDR_APPROACH } } });
  return w;
}

/* ---- action catalogue (mirror index.html buildPhase3 defs) ---- */
function defineActions(world) {
  const pt = (id, name) => world.point(id, name);
  world.defineAction({ id: "micro.front", name: "illuminate", priority: 4,
    pre: { "micro.front.state.illumination": false },
    steps: [{ op: "reach", hand: "R", to: pt("micro.front", "rheostat"), dur: 0.3 },
      { op: "set", id: "micro.front", patch: { illumination: true } }],
    verify: { "micro.front.state.illumination": true }, sound: "micro:click" });
  world.defineAction({ id: "micro.front", name: "darken", priority: 4,
    pre: { "micro.front.state.illumination": true },
    steps: [{ op: "reach", hand: "R", to: pt("micro.front", "rheostat"), dur: 0.3 },
      { op: "set", id: "micro.front", patch: { illumination: false } }],
    verify: { "micro.front.state.illumination": false }, sound: "micro:click" });
  world.defineAction({ id: "micro.front", name: "select-objective", priority: 4,
    pre: (w, opts) => { const m = opts && opts.mag; return m === 4 || m === 10 || m === 40; },
    steps: (w, opts) => { const m = (opts && opts.mag) || 10; return [
      { op: "reach", hand: "R", to: w.point("micro.front", "nosepiece"), dur: 0.3 },
      { op: "manipulate", dur: 0.4, look: w.point("micro.front", "nosepiece") },
      { op: "set", id: "micro.front", patch: { objective: m } }]; },
    verify: (w, opts) => ({ "micro.front.state.objective": (opts && opts.mag) || 10 }),
    sound: "micro:click" });
  world.defineAction({ id: "micro.front", name: "focus", priority: 4,
    pre: (w, opts) => typeof (opts && opts.to) === "number" && opts.to >= 0 && opts.to <= 1,
    steps: (w, opts) => { const f = (opts && opts.to) != null ? opts.to : 0.7; return [
      { op: "reach", hand: "L", to: w.point("micro.front", "stage"), dur: 0.3 },
      { op: "manipulate", dur: 0.4, look: w.point("micro.front", "eyepieces") },
      { op: "set", id: "micro.front", patch: { focus: f } }]; },
    verify: (w, opts) => ({ "micro.front.state.focus": (opts && opts.to) != null ? opts.to : 0.7 }),
    sound: "micro:click" });
  world.defineAction({ id: "tap.front", name: "open", priority: 6,
    pre: { "tap.front.state.running": false },
    steps: [{ op: "reach", hand: "R", to: pt("tap.front", "handle"), dur: 0.3 },
      { op: "set", id: "tap.front", patch: { running: true } }],
    verify: { "tap.front.state.running": true }, sound: "water:on" });
  world.defineAction({ id: "tap.front", name: "close", priority: 6,
    pre: { "tap.front.state.running": true },
    steps: [{ op: "reach", hand: "R", to: pt("tap.front", "handle"), dur: 0.3 },
      { op: "set", id: "tap.front", patch: { running: false } }],
    verify: { "tap.front.state.running": false }, sound: "water:off" });
  world.defineAction({ id: "benchFront.drawer", name: "open", priority: 7,
    pre: { "benchFront.drawer.state.open": false },
    steps: [{ op: "goto", to: pt("benchFront.drawer", "approach"), standOff: 0.05, face: pt("benchFront.drawer", "face") },
      { op: "align", face: pt("benchFront.drawer", "face") },
      { op: "reach", hand: "R", to: pt("benchFront.drawer", "handle"), dur: 0.3 },
      { op: "drawer", id: "benchFront.drawer", open: true, dur: 0.4 }],
    verify: { "benchFront.drawer.state.open": true } });
  world.defineAction({ id: "benchFront.drawer", name: "close", priority: 7,
    pre: { "benchFront.drawer.state.open": true },
    steps: [{ op: "goto", to: pt("benchFront.drawer", "approach"), standOff: 0.05, face: pt("benchFront.drawer", "face") },
      { op: "align", face: pt("benchFront.drawer", "face") },
      { op: "reach", hand: "R", to: pt("benchFront.drawer", "handle"), dur: 0.3 },
      { op: "drawer", id: "benchFront.drawer", open: false, dur: 0.4 }],
    verify: { "benchFront.drawer.state.open": false } });
  world.defineAction({ id: "balance", name: "tare", priority: 5,
    pre: { "balance.state.onItem": null },
    steps: [{ op: "reach", hand: "R", to: pt("balance", "display"), dur: 0.3 },
      { op: "set", id: "balance", patch: { massG: 0, tare: true } }],
    verify: { "balance.state.massG": 0, "balance.state.tare": true }, sound: "micro:click" });
  world.wireBalance("item.jar", "balance", { radius: 0.12, massKey: "massG" });
}

/* ---- scenario tables (mirror host wiring in index.html) ---- */
function scenarios(world) {
  const pt = (id, name) => world.point(id, name);
  const drawerRetrieve = [
    { op: "plan", dur: 0.3 },
    { op: "listen", look: pt("cabFR", "face"), dur: 0.3 },
    { op: "goto", to: pt("cabFR", "approach"), standOff: 0.05, face: pt("cabFR", "face") },
    { op: "align", face: pt("cabFR", "face") },
    { op: "reach", hand: "R", to: pt("cabFR.slides", "handle"), dur: 0.3 },
    { op: "drawer", id: "cabFR.slides", open: true, dur: 0.4 },
    { op: "reach", hand: "R", to: pt("item.jar", "pos"), dur: 0.3 },
    { op: "grasp", obj: "item.jar", dur: 0.2 },
    { op: "set", id: "item.jar", patch: { loc: "held" } },
    { op: "drawer", id: "cabFR.slides", open: false, dur: 0.3 },
    { op: "goto", to: pt("bench.place", "approach"), standOff: 0.05, face: pt("bench.place", "target") },
    { op: "reach", hand: "R", to: pt("bench.place", "target"), dur: 0.3 },
    { op: "release", obj: "item.jar", at: pt("bench.place", "target") },
    { op: "set", id: "item.jar", patch: { loc: "bench.place" } },
    { op: "verify", expect: { "item.jar.state.loc": "bench.place", "cabFR.slides.state.open": false } },
  ];
  return {
    drawerRetrieve,
    microscope: () => [
      { op: "plan", dur: 0.3 },
      { op: "listen", look: pt("micro.front", "eyepieces"), dur: 0.3 },
      { op: "goto", to: pt("micro.front", "approach"), standOff: 0.05, face: pt("micro.front", "stage") },
      { op: "align", face: pt("micro.front", "stage") },
    ].concat(world.actionSteps("micro.front", "illuminate", {}))
      .concat(world.actionSteps("micro.front", "select-objective", { mag: 10 }))
      .concat(world.actionSteps("micro.front", "focus", { to: 0.72 })),
    tap: () => [
      { op: "plan", dur: 0.3 },
      { op: "listen", look: pt("tap.front", "spout"), dur: 0.3 },
      { op: "goto", to: pt("tap.front", "approach"), standOff: 0.05, face: pt("tap.front", "handle") },
      { op: "align", face: pt("tap.front", "handle") },
    ].concat(world.actionSteps("tap.front", "open", {}))
      .concat([{ op: "manipulate", dur: 0.5, look: pt("tap.front", "spout") }])
      .concat(world.actionSteps("tap.front", "close", {})),
    weigh: () => [
      { op: "plan", dur: 0.3 },
      { op: "goto", to: pt("bench.place", "approach"), standOff: 0.05, face: pt("bench.place", "target") },
      { op: "align", face: pt("bench.place", "target") },
      { op: "reach", hand: "R", to: pt("item.jar"), dur: 0.3 },
      { op: "grasp", obj: "item.jar", dur: 0.2 },
      { op: "set", id: "item.jar", patch: { loc: "held" } },
      { op: "goto", to: pt("balance", "approach"), standOff: 0.05, face: pt("balance", "pan") },
      { op: "align", face: pt("balance", "pan") },
      { op: "reach", hand: "R", to: pt("balance", "pan"), dur: 0.3 },
      { op: "release", obj: "item.jar", at: pt("balance", "pan") },
      { op: "set", id: "item.jar", patch: { loc: "balance.pan" } },
      { op: "verify", expect: { "balance.state.massG": JAR_MASS, "balance.state.onItem": "item.jar",
        "item.jar.state.loc": "balance.pan", "item.jar.state.heldBy": null } },
    ],
  };
}

/* ---- extended fake rig ---- */
function makeFakeRig(x, z, yaw) {
  return {
    radius: 0.25,
    pos: { x, z },
    yaw,
    look: null,
    lean: 0,
    attached: [],
    detached: [],
    getPos() { return { x: this.pos.x, z: this.pos.z }; },
    getYaw() { return this.yaw; },
    setPose(nx, nz, nyaw) { this.pos.x = nx; this.pos.z = nz; this.yaw = nyaw; },
    setLocomotion() {},
    setLook(pt) { this.look = pt; },
    setLean(v) { this.lean = v; },
    setReach() {},
    headWorldPos() { return { x: this.pos.x, y: 1.62, z: this.pos.z }; },
    attachToHand(obj, hand) { this.attached.push({ obj, hand }); },
    detachFromHand(obj, at) { this.detached.push({ obj, at }); },
  };
}

function build() {
  const nav = buildLabNav();
  const world = makeWorld();
  defineActions(world);
  const rig = makeFakeRig(STAND.x, STAND.z, Math.PI);
  const loco = createTeacherController(nav, {
    radius: rig.radius,
    getPos: () => rig.getPos(),
    getYaw: () => rig.getYaw(),
    setPose: (x, z, y) => rig.setPose(x, z, y),
    setLocomotion: () => {},
  }, { speed: 1.05 });
  const behav = createBehaviour({ nav, rig, world, loco });
  /* test-side mirror of the host stats (index.html buildPhase3 subscriber) */
  const stats = { tapToggles: 0, tapRunning: false, balanceMass: 0, jarOnPan: false, lampOn: false, objective: 40 };
  world.subscribe((ev) => {
    if (ev.id === "tap.front") {
      stats.tapRunning = !!world.get("tap.front").state.running;
      stats.tapToggles++;
    }
    if (ev.id === "balance") stats.balanceMass = world.get("balance").state.massG;
    if (ev.id === "item.jar") stats.jarOnPan = world.get("balance").state.onItem === "item.jar";
    if (ev.id === "micro.front") {
      stats.lampOn = !!world.get("micro.front").state.illumination;
      stats.objective = world.get("micro.front").state.objective;
    }
  });
  return { nav, world, rig, loco, behav, sc: scenarios(world), stats };
}

function drive(behav, maxSim = 120, dt = 1 / 60) {
  let sim = 0;
  const states = new Set();
  while (sim < maxSim) {
    behav.update(dt);
    states.add(behav.state);
    sim += dt;
    if (!behav.active && behav.pendingCount() === 0) break;
  }
  return { sim, states };
}

/* ================= tests ================= */
function run() {
  const B = build();
  const { world, behav, rig, sc, stats } = B;

  /* ---- 1. action registry ---- */
  let threw = false;
  try { world.defineAction({ name: "x" }); } catch { threw = true; }
  check("defineAction requires id+name", threw);
  check("action lookup", !!world.action("tap.front", "open") && world.action("tap.front", "nope") === null);
  check("actionsFor lists names",
    world.actionsFor("micro.front").join(",") === "illuminate,darken,select-objective,focus",
    world.actionsFor("micro.front").join(","));
  check("checkPre declarative true", world.checkPre("tap.front", "open", {}) === true);
  world.set("tap.front", { running: true });
  check("checkPre declarative false once running", world.checkPre("tap.front", "open", {}) === false);
  world.set("tap.front", { running: false });
  check("checkPre fn opts 10x true", world.checkPre("micro.front", "select-objective", { mag: 10 }) === true);
  check("checkPre fn opts 7x false", world.checkPre("micro.front", "select-objective", { mag: 7 }) === false);
  const stepsIllum = world.actionSteps("micro.front", "illuminate", {});
  check("actionSteps appends verify+sound",
    stepsIllum[stepsIllum.length - 2].op === "verify" && stepsIllum[stepsIllum.length - 1].op === "emit",
    stepsIllum.map((s) => s.op).join(">"));
  const stepsSel = world.actionSteps("micro.front", "select-objective", { mag: 4 });
  check("actionSteps fn steps + fn verify",
    stepsSel.some((s) => s.op === "set" && s.patch && s.patch.objective === 4) &&
    stepsSel[stepsSel.length - 2].expect["micro.front.state.objective"] === 4);
  check("actionSteps unknown -> null", world.actionSteps("tap.front", "nope", {}) === null);

  /* ---- 2. microscope: scenario + state + mirror + preconditions ---- */
  const hM = behav.submit({ label: "scen-microscope", priority: 4, steps: sc.microscope() });
  drive(behav, 90);
  check("microscope scenario completed", hM.status === "completed", hM.status + " " + hM.reason);
  check("microscope state consistent",
    world.check({ "micro.front.state.illumination": true, "micro.front.state.objective": 10, "micro.front.state.focus": 0.72 }));
  check("microscope stats mirrored", stats.lampOn === true && stats.objective === 10);
  const hIll2 = behav.interact("micro.front", "illuminate");
  check("re-illuminate precondition-blocked", hIll2.status === "failed" && /precondition/.test(hIll2.reason),
    hIll2.status + " " + hIll2.reason);
  const hSel = behav.interact("micro.front", "select-objective", { mag: 4 });
  drive(behav, 60);
  check("select-objective 4x via interact", hSel.status === "completed" &&
    world.check({ "micro.front.state.objective": 4 }) && stats.objective === 4, hSel.status);
  const hSelBad = behav.interact("micro.front", "select-objective", { mag: 7 });
  check("invalid mag rejected by fn precondition", hSelBad.status === "failed" &&
    /precondition/.test(hSelBad.reason), hSelBad.reason);
  const hDark = behav.interact("micro.front", "darken");
  drive(behav, 60);
  check("darken via interact", hDark.status === "completed" &&
    world.check({ "micro.front.state.illumination": false }) && stats.lampOn === false);
  const hDark2 = behav.interact("micro.front", "darken");
  check("re-darken precondition-blocked", hDark2.status === "failed" && /precondition/.test(hDark2.reason));

  /* ---- 3. tap: scenario + interact + mirror ---- */
  const hT = behav.submit({ label: "scen-tap", priority: 6, steps: sc.tap() });
  drive(behav, 90);
  check("tap scenario completed", hT.status === "completed", hT.status + " " + hT.reason);
  check("tap closed after scenario", world.check({ "tap.front.state.running": false }));
  const hTO = behav.interact("tap.front", "open");
  drive(behav, 40);
  check("tap open via interact", hTO.status === "completed" && world.check({ "tap.front.state.running": true }) &&
    stats.tapRunning === true && stats.tapToggles >= 3, "toggles=" + stats.tapToggles);
  const hTO2 = behav.interact("tap.front", "open");
  check("tap re-open precondition-blocked", hTO2.status === "failed" && /precondition/.test(hTO2.reason));
  const hTC = behav.interact("tap.front", "close");
  drive(behav, 40);
  check("tap close via interact", hTC.status === "completed" && world.check({ "tap.front.state.running": false }) &&
    stats.tapRunning === false);

  /* ---- 4. bench drawer via catalogue ---- */
  const hDO = behav.interact("benchFront.drawer", "open");
  drive(behav, 90);
  check("bench drawer opens via action", hDO.status === "completed" &&
    world.check({ "benchFront.drawer.state.open": true }), hDO.status);
  const hDO2 = behav.interact("benchFront.drawer", "open");
  check("drawer re-open precondition-blocked", hDO2.status === "failed" && /precondition/.test(hDO2.reason));
  const hDC = behav.interact("benchFront.drawer", "close");
  drive(behav, 90);
  check("bench drawer closes via action", hDC.status === "completed" &&
    world.check({ "benchFront.drawer.state.open": false }));

  /* ---- 5. verify gate: a lying action can never complete ---- */
  world.defineAction({ id: "micro.front", name: "bad-focus", priority: 4,
    steps: [{ op: "set", id: "micro.front", patch: { focus: 0.9 } }],
    verify: { "micro.front.state.focus": 0.1 } });
  const hBad = behav.interact("micro.front", "bad-focus");
  drive(behav, 20);
  check("lying action fails its verify", hBad.status === "failed" && /verify/.test(hBad.reason),
    hBad.status + " " + (hBad.reason || ""));

  /* ---- 6. drawer retrieve (jar -> bench) then weigh ---- */
  const hD = behav.submit({ label: "scen-drawer", priority: 7, steps: sc.drawerRetrieve });
  drive(behav, 120);
  check("drawer retrieve completed (jar on bench)", hD.status === "completed" &&
    world.check({ "item.jar.state.loc": "bench.place", "item.jar.state.heldBy": null }), hD.status);
  const att0 = rig.attached.length;
  const hWg = behav.submit({ label: "scen-weigh", priority: 5, steps: sc.weigh() });
  drive(behav, 140);
  check("weigh scenario completed", hWg.status === "completed", hWg.status + " " + hWg.reason);
  check("balance reads specimen mass",
    world.check({ "balance.state.massG": JAR_MASS, "balance.state.onItem": "item.jar" }) &&
    stats.balanceMass === JAR_MASS && stats.jarOnPan === true,
    "massG=" + world.get("balance").state.massG);
  check("jar resting on pan", world.check({ "item.jar.state.loc": "balance.pan", "item.jar.state.heldBy": null }));
  const jp = world.get("item.jar").pos;
  check("jar world pos at pan", Math.hypot(jp.x - BAL_PAN.x, jp.z - BAL_PAN.z) < 0.05,
    jp.x.toFixed(3) + "," + jp.z.toFixed(3));
  check("jar was carried", rig.attached.length > att0, "attach=" + rig.attached.length);
  const hTare1 = behav.interact("balance", "tare");
  check("tare blocked while item on pan", hTare1.status === "failed" && /precondition/.test(hTare1.reason));
  /* lift the jar off: wireBalance clears the readout */
  world.move("item.jar", BENCH_PLACE.x, BENCH_PLACE.y, BENCH_PLACE.z);
  check("balance clears when item removed",
    world.check({ "balance.state.massG": 0, "balance.state.onItem": null, "balance.state.tare": true }) &&
    stats.balanceMass === 0 && stats.jarOnPan === false);
  const hTare2 = behav.interact("balance", "tare");
  drive(behav, 60);
  check("tare completes once pan is empty", hTare2.status === "completed" &&
    world.check({ "balance.state.massG": 0, "balance.state.tare": true }), hTare2.status);

  /* ---- 7. interruption + no-action fail-fast ---- */
  const hLong = behav.submit({ label: "p3-long", priority: 2, steps: [{ op: "goto", to: { x: -4.6, z: 3.9 }, standOff: 0 }] });
  for (let i = 0; i < 90; i++) behav.update(1 / 60);
  check("long task running before interrupt", hLong.status === "running", hLong.status);
  const hInt = behav.interact("tap.front", "open");
  check("interact preempts long task", hLong.status === "paused" && hInt.status === "running",
    hLong.status + "/" + hInt.status);
  drive(behav, 120);
  check("interrupting interact completed", hInt.status === "completed", hInt.status);
  check("long task resumed after interact", hLong.status === "completed", hLong.status);
  behav.interact("tap.front", "close") && drive(behav, 60);
  const hNA = behav.interact("balance", "teleport");
  check("unknown action fails fast", hNA.status === "failed" && /no-action/.test(hNA.reason), hNA.reason);

  console.log(`\nphase3_unit: ${checks.length - fails}/${checks.length} checks passed`);
  if (fails > 0) process.exit(1);
}

try {
  run();
} catch (err) {
  console.error("phase3_unit: exception", err);
  process.exit(1);
}
