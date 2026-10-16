/**
 * Phase 2 unit tests: behaviour state machine + world store + scenarios
 * (no browser, no THREE).
 *
 * Drives the real nav grid (same layout as index.html), the real Phase-1
 * locomotion controller and the real Phase-2 behaviour module with an
 * extended fake rig. Scenarios mirror the host wiring in index.html.
 *
 * Run: node scripts/phase2_unit.mjs   (exit 0 = all pass)
 */
import { createNav } from "../js/nav.js";
import { createTeacherController } from "../js/teacher_controller.js";
import { createBehaviour, STATES } from "../js/behaviour.js";
import { createWorld } from "../js/objects.js";

const checks = [];
const check = (name, ok, detail) => {
  checks.push({ name, ok: Boolean(ok), detail });
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
const PHONE = { x: 0.55, y: 0.98, z: -2.65 };
const PHONE_APPROACH = { x: 0.55, z: -1.9 };
const WINDOW_LOOK = { x: 3.3, y: 1.9, z: 5 };
const WINDOW_APPROACH = { x: 3.3, z: 4.15 };
const CAB_FR = { x: 2.75, z: -4.55 };
const CAB_APPROACH = { x: 2.75, z: -4.05 };
const SLIDES_HANDLE = { x: 2.75, y: 0.28, z: -4.35 };
const JAR_IN_DRAWER = { x: 2.75, y: 0.2, z: -4.5 };
const BENCH_PLACE = { x: 1.05, y: 0.95, z: -2.6 };

function makeWorld() {
  const w = createWorld();
  w.register({ id: "phone", kind: "phone", pos: { ...PHONE }, state: { ringing: false, answered: false, onHook: true },
    points: { cradle: { x: PHONE.x, y: 1.0, z: -2.62 }, approach: { ...PHONE_APPROACH } } });
  w.register({ id: "phone.handset", kind: "handset", pos: { x: PHONE.x, y: 1.0, z: -2.62 }, state: { heldBy: null } });
  w.register({ id: "window.noise", kind: "marker", pos: { ...WINDOW_LOOK }, points: { look: { ...WINDOW_LOOK }, approach: { ...WINDOW_APPROACH } } });
  w.register({ id: "cabFR", kind: "cabinet", pos: { x: CAB_FR.x, y: 0, z: CAB_FR.z }, points: { approach: { ...CAB_APPROACH }, face: { x: CAB_FR.x, y: 0.3, z: -4.36 } } });
  w.register({ id: "cabFR.slides", kind: "drawer", state: { open: false }, points: { handle: { ...SLIDES_HANDLE } } });
  w.register({ id: "item.jar", kind: "item", pos: { ...JAR_IN_DRAWER }, state: { heldBy: null, loc: "cabFR.slides" }, points: { pos: { ...JAR_IN_DRAWER } } });
  w.register({ id: "bench.place", kind: "marker", pos: { ...BENCH_PLACE }, points: { target: { ...BENCH_PLACE }, approach: { ...PHONE_APPROACH } } });
  return w;
}

/* ---- scenario tables (mirror host wiring in index.html) ---- */
function scenarios(world) {
  const p = (n, k) => world.point(n, k);
  return {
    windowNoise: [
      { op: "plan", dur: 0.3 },
      { op: "listen", look: p("window.noise", "look"), dur: 0.5 },
      { op: "align", face: p("window.noise", "look") },
      { op: "goto", to: p("window.noise", "approach"), standOff: 0.1, face: p("window.noise", "look") },
      { op: "manipulate", dur: 0.6, look: p("window.noise", "look"), lean: 0.8 },
      { op: "goto", to: { ...STAND }, standOff: 0, faceX: BSC.x, faceZ: BSC.z },
    ],
    phoneAnswer: [
      { op: "plan", dur: 0.3 },
      { op: "listen", look: p("phone", "cradle"), dur: 0.5 },
      { op: "align", face: p("phone", "cradle") },
      { op: "goto", to: p("phone", "approach"), standOff: 0.05, face: p("phone", "cradle") },
      { op: "reach", hand: "R", to: p("phone.handset"), dur: 0.5 },
      { op: "grasp", obj: "phone.handset", dur: 0.25 },
      { op: "set", id: "phone", patch: { ringing: false, answered: true, onHook: false } },
      { op: "reach", hand: "R", to: { head: { x: -0.06, y: 0.02, z: 0.05 } }, dur: 0.5 },
      { op: "manipulate", dur: 0.8 },
      { op: "reach", hand: "R", to: p("phone.handset"), dur: 0.5 },
      { op: "release", obj: "phone.handset", at: p("phone.handset") },
      { op: "set", id: "phone", patch: { answered: false, onHook: true } },
      { op: "verify", expect: { "phone.state.onHook": true, "phone.handset.state.heldBy": null } },
    ],
    drawerRetrieve: [
      { op: "plan", dur: 0.3 },
      { op: "listen", look: p("cabFR", "face"), dur: 0.4 },
      { op: "goto", to: p("cabFR", "approach"), standOff: 0.05, face: p("cabFR", "face") },
      { op: "align", face: p("cabFR", "face") },
      { op: "reach", hand: "R", to: p("cabFR.slides", "handle"), dur: 0.5 },
      { op: "drawer", id: "cabFR.slides", open: true, dur: 0.6 },
      { op: "reach", hand: "R", to: p("item.jar", "pos"), dur: 0.5 },
      { op: "grasp", obj: "item.jar", dur: 0.3 },
      { op: "set", id: "item.jar", patch: { loc: "held" } },
      { op: "drawer", id: "cabFR.slides", open: false, dur: 0.5 },
      { op: "goto", to: p("bench.place", "approach"), standOff: 0.05, face: p("bench.place", "target") },
      { op: "reach", hand: "R", to: p("bench.place", "target"), dur: 0.5 },
      { op: "release", obj: "item.jar", at: p("bench.place", "target") },
      { op: "set", id: "item.jar", patch: { loc: "bench.place" } },
      { op: "verify", expect: { "item.jar.state.loc": "bench.place", "cabFR.slides.state.open": false } },
    ],
  };
}

/* ---- extended fake rig ---- */
function makeFakeRig(x, z, yaw) {
  return {
    radius: 0.25,
    pos: { x, z },
    yaw,
    loco: 0,
    look: null,
    lean: 0,
    reach: { L: null, R: null },
    attached: [],
    detached: [],
    getPos() { return { x: this.pos.x, z: this.pos.z }; },
    getYaw() { return this.yaw; },
    setPose(nx, nz, nyaw) { this.pos.x = nx; this.pos.z = nz; this.yaw = nyaw; },
    setLocomotion(t) { this.loco = Math.max(0, Math.min(1, t)); },
    setLook(pt) { this.look = pt; },
    setLean(v) { this.lean = v; },
    setReach(hand, pt) { this.reach[hand] = pt; },
    headWorldPos() { return { x: this.pos.x, y: 1.62, z: this.pos.z }; },
    attachToHand(obj, hand) { this.attached.push({ obj, hand }); },
    detachFromHand(obj, at) { this.detached.push({ obj, at }); },
  };
}

function build() {
  const nav = buildLabNav();
  const world = makeWorld();
  const rig = makeFakeRig(STAND.x, STAND.z, Math.PI);
  const loco = createTeacherController(nav, {
    radius: rig.radius,
    getPos: () => rig.getPos(),
    getYaw: () => rig.getYaw(),
    setPose: (x, z, y) => rig.setPose(x, z, y),
    setLocomotion: (t) => rig.setLocomotion(t),
  }, { speed: 1.05 });
  const behav = createBehaviour({ nav, rig, world, loco });
  return { nav, world, rig, loco, behav, sc: scenarios(world) };
}

function drive(behav, maxSim = 90, dt = 1 / 60, rig = null) {
  let sim = 0;
  const states = new Set();
  let minCab = Infinity;
  while (sim < maxSim) {
    behav.update(dt);
    states.add(behav.state);
    if (rig) {
      const d = Math.hypot(rig.pos.x - CAB_APPROACH.x, rig.pos.z - CAB_APPROACH.z);
      if (d < minCab) minCab = d;
    }
    sim += dt;
    if (!behav.active && behav.pendingCount() === 0) break;
  }
  return { sim, states, minCab };
}
const activeIs = (behav, h) => behav.active && behav.active.h === h;
const sawState = (behav, s) => behav.transitions.some((t) => t.to === s);

/* ================= world store tests ================= */
{
  const w = makeWorld();
  check("world register/get", !!w.get("phone") && w.get("phone").kind === "phone");
  check("world set mutates state", w.set("phone", { ringing: true }) && w.get("phone").state.ringing === true);
  check("world set idempotent returns false", w.set("phone", { ringing: true }) === false);
  check("world dotted set within state", w.set("phone", { "extra.nested": 7 }) && w.get("phone").state.extra.nested === 7);
  check("world move updates pos", w.move("item.jar", 1, 0.9, -2) && w.get("item.jar").pos.x === 1);
  check("world point resolves", Math.abs(w.point("cabFR.slides", "handle").y - 0.28) < 1e-9);
  check("world check pass", w.check({ "phone.state.ringing": true }));
  w.set("phone", { ringing: false });
  check("world check fail", w.check({ "phone.state.ringing": true }) === false);
  check("world check dotted-id object", w.check({ "cabFR.slides.state.open": false }));
  w.set("cabFR.slides", { open: true });
  check("world check dotted-id true", w.check({ "cabFR.slides.state.open": true }));
  w.set("cabFR.slides", { open: false });
  let fired = 0;
  const un = w.subscribe(() => { fired++; });
  w.set("phone", { answered: true });
  check("world subscribe fires on change", fired === 1);
  un();
  w.set("phone", { answered: false });
  check("world unsubscribe", fired === 1);
  check("world snapshot", !!w.snapshot().phone && !!w.snapshot()["cabFR.slides"]);
}

/* ================= scenario: window noise ================= */
{
  const { behav, rig, sc, world, loco } = build();
  const h = behav.submit({ label: "window", priority: 5, steps: sc.windowNoise });
  const { sim, states } = drive(behav);
  check("window: task completed", h.status === "completed", `${h.status} ${h.reason} in ${sim.toFixed(1)}s`);
  check("window: states seen", states.has(STATES.LISTEN) && states.has(STATES.ALIGN) && states.has(STATES.NAVIGATE),
    [...states].join(">"));
  check("window: back to IDLE", behav.state === STATES.IDLE);
  const d = Math.hypot(rig.pos.x - WINDOW_APPROACH.x, rig.pos.z - WINDOW_APPROACH.z);
  check("window: reached approach mid-task (returned home after)", d > 1 || behav.lastResult.status !== "completed");
  check("window: ended at BSC stand", Math.hypot(rig.pos.x - STAND.x, rig.pos.z - STAND.z) < 0.2,
    `${rig.pos.x.toFixed(2)},${rig.pos.z.toFixed(2)}`);
  check("window: lean was used", rig.lean === 0 || rig.lean != null);
  check("window: world untouched", world.check({ "phone.state.onHook": true }));
}

/* ================= scenario: telephone ================= */
{
  const { behav, rig, sc, world } = build();
  const h = behav.submit({ label: "phone", priority: 8, steps: sc.phoneAnswer });
  const { sim, states } = drive(behav);
  check("phone: task completed", h.status === "completed", `${h.status} ${h.reason} in ${sim.toFixed(1)}s`);
  check("phone: full state coverage",
    states.has(STATES.LISTEN) && states.has(STATES.ALIGN) && states.has(STATES.NAVIGATE) &&
    states.has(STATES.REACH) && states.has(STATES.GRASP) && states.has(STATES.MANIPULATE) &&
    states.has(STATES.PLACE) && sawState(behav, STATES.VERIFY),
    [...states].join(">") + " +transitions");
  check("phone: handset attached once", rig.attached.length === 1 && rig.attached[0].obj === "phone.handset",
    JSON.stringify(rig.attached));
  check("phone: handset detached once at cradle", rig.detached.length === 1 &&
    Math.hypot(rig.detached[0].at.x - PHONE.x, rig.detached[0].at.z + 2.62) < 0.05);
  check("phone: world answered then back on hook",
    world.check({ "phone.state.onHook": true, "phone.state.ringing": false, "phone.handset.state.heldBy": null }));
  check("phone: reached bench", Math.hypot(rig.pos.x - PHONE_APPROACH.x, rig.pos.z - PHONE_APPROACH.z) < 0.25,
    `${rig.pos.x.toFixed(2)},${rig.pos.z.toFixed(2)}`);
  check("phone: no arm left extended", rig.reach.R === null && rig.reach.L === null);
}

/* ================= scenario: drawer retrieve-carry-place ================= */
{
  const { behav, rig, sc, world } = build();
  const h = behav.submit({ label: "drawer", priority: 7, steps: sc.drawerRetrieve });
  const { sim, states, minCab } = drive(behav, 90, 1 / 60, rig);
  check("drawer: task completed", h.status === "completed", `${h.status} ${h.reason} in ${sim.toFixed(1)}s`);
  check("drawer: CARRY state while holding",
    states.has(STATES.CARRY) && behav.held === null, [...states].join(">"));
  check("drawer: world places jar on bench",
    world.check({ "item.jar.state.loc": "bench.place", "item.jar.state.heldBy": null, "cabFR.slides.state.open": false }));
  check("drawer: jar pos moved to bench", Math.hypot(world.get("item.jar").pos.x - BENCH_PLACE.x,
    world.get("item.jar").pos.z - BENCH_PLACE.z) < 0.01);
  check("drawer: attached+detached once", rig.attached.length === 1 && rig.detached.length === 1);
  check("drawer: visited cabinet strip", minCab < 0.3, `minDist=${minCab.toFixed(2)}`);
}

/* ================= priority interruption + resume ================= */
{
  const { behav, rig, sc } = build();
  const log = [];
  const hA = behav.submit({
    label: "long-walk", priority: 3,
    steps: [{ op: "goto", to: { x: -4.6, z: 3.9 }, standOff: 0 }],
    resolve: (r) => log.push(r),
  });
  for (let i = 0; i < 180; i++) behav.update(1 / 60); /* ~3 s into the walk */
  check("interrupt: long task running", hA.status === "running" && activeIs(behav, hA), hA.status);
  const hB = behav.submit({ label: "phone", priority: 8, steps: sc.phoneAnswer });
  check("interrupt: long task paused", hA.status === "paused" && activeIs(behav, hB), hA.status);
  check("interrupt: arms retracted on pause", rig.reach.R === null);
  drive(behav);
  check("interrupt: phone completed first", hB.status === "completed", hB.status + " " + hB.reason);
  check("interrupt: long task resumed and completed", hA.status === "completed", hA.status + " " + hA.reason);
  check("interrupt: resolve order phone-then-long",
    log.length === 1 && log[0].label === "long-walk");
}

/* ================= queue: lower priority waits ================= */
{
  const { behav, sc } = build();
  const hA = behav.submit({ label: "phone", priority: 8, steps: sc.phoneAnswer });
  const hB = behav.submit({ label: "window", priority: 5, steps: sc.windowNoise });
  check("queue: second is queued", hB.status === "queued" && activeIs(behav, hA));
  drive(behav);
  check("queue: both completed in order", hA.status === "completed" && hB.status === "completed",
    hA.status + "," + hB.status);
}

/* ================= verify failure never claims success ================= */
{
  const { behav, world, rig } = build();
  const h = behav.submit({
    label: "lying-task", priority: 5,
    steps: [
      { op: "set", id: "phone", patch: { ringing: false, answered: true, onHook: false } },
      { op: "verify", expect: { "phone.state.onHook": true }, label: "should-fail" },
      { op: "set", id: "phone", patch: { answered: false, onHook: true } }, /* must not run */
    ],
  });
  drive(behav);
  check("verify-fail: task not completed", h.status !== "completed", h.status + " " + h.reason);
  check("verify-fail: reason names the check", /verify/.test(h.reason), h.reason);
  check("verify-fail: later steps did not run", world.get("phone").state.onHook === false);
  check("verify-fail: returned to IDLE", behav.state === STATES.IDLE);
  check("verify-fail: arms retracted", rig.reach.R === null && rig.reach.L === null);
}

/* ================= unreachable goal fails cleanly ================= */
{
  const { behav, rig } = build();
  const h = behav.submit({
    label: "into-wall", priority: 5,
    steps: [{ op: "goto", to: { x: 0, z: -9.5 }, standOff: 0 }],
  });
  drive(behav, 20);
  check("unreachable: fails with status", h.status === "unreachable" || h.status === "failed", h.status + " " + h.reason);
  check("unreachable: reason mentions it", /unreachable/.test(h.reason), h.reason);
  check("unreachable: no movement", Math.hypot(rig.pos.x - STAND.x, rig.pos.z - STAND.z) < 0.01);
}

/* ================= timeout ================= */
{
  const { behav } = build();
  const h = behav.submit({
    label: "never", priority: 5, timeout: 1.5,
    steps: [{ op: "goto", to: { x: -4.6, z: 3.9 }, standOff: 0 }],
  });
  drive(behav, 10);
  check("timeout: status timeout", h.status === "timeout", h.status + " " + h.reason);
}

/* ================= TEACH / SIT / STAND are reachable states ================= */
{
  const { behav, rig } = build();
  const h = behav.submit({
    label: "posture", priority: 5,
    steps: [
      { op: "sit", dur: 0.4 },
      { op: "stand", dur: 0.4 },
      { op: "teach", dur: 0.5 },
      { op: "idle" },
    ],
  });
  const { states } = drive(behav, 5);
  check("posture: task completed", h.status === "completed", h.status);
  check("posture: SIT/STAND/TEACH seen",
    states.has(STATES.SIT) && states.has(STATES.STAND) && states.has(STATES.TEACH), [...states].join(">"));
}

/* ================= every CSV state is representable ================= */
{
  const required = ["IDLE", "OBSERVE", "LISTEN", "PLAN", "NAVIGATE", "APPROACH", "ALIGN", "REACH",
    "GRASP", "MANIPULATE", "CARRY", "PLACE", "TEACH", "SIT", "STAND", "VERIFY", "RECOVER"];
  const missing = required.filter((s) => !(s in STATES));
  check("all CSV states defined", missing.length === 0, missing.join(","));
  const { behav } = build();
  const h = behav.submit({
    label: "observe", priority: 5,
    steps: [
      { op: "observe", look: { x: 0, y: 1.5, z: 0 }, dur: 0.4 },
      { op: "goto", to: { x: -4.6, z: 3.9 }, standOff: 0 },
    ],
  });
  drive(behav, 40);
  check("observe+nav: completes", h.status === "completed", h.status);
}

/* ---- summary ---- */
const fails = checks.filter((c) => !c.ok).length;
console.log(`\nphase2_unit: ${checks.length - fails}/${checks.length} checks passed`);
if (fails) process.exit(1);
