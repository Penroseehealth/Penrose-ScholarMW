/**
 * Phase 1 unit tests: navigation + teacher controller (no browser, no THREE).
 *
 * Mirrors the real lab layout from index.html (room 12x10, six island benches,
 * front bench, left-wall bench, podium, cabinets, autoclave, BSC, stools) and
 * drives the controller with a fake rig that integrates ground motion exactly
 * (the browser rig additionally applies foot-lock/mixer — tested in smoke).
 *
 * Run: node scripts/phase1_unit.mjs   (exit 0 = all pass)
 */
import { createNav } from "../js/nav.js";
import { createTeacherController } from "../js/teacher_controller.js";
const LabNav = { create: createNav };
const LabTeacher = { create: createTeacherController };

const checks = [];
const check = (name, ok, detail) => {
  checks.push({ name, ok: Boolean(ok), detail });
  console.log(`${ok ? "PASS" : "FAIL"}  ${name}${detail ? "  [" + detail + "]" : ""}`);
};

/* ---- real lab layout (must match index.html) ---- */
const FW = 12, FD = 10, HX = FW / 2, HZ = FD / 2, WT = 0.25;

function buildLabNav() {
  const nav = LabNav.create();
  const x0 = -HX + WT / 2, x1 = HX - WT / 2, z0 = -HZ + WT / 2, z1 = HZ - WT / 2;
  // perimeter walls (thick slabs just outside the interior)
  nav.addRect(x0 - WT, z0 - WT, x1 + WT, z0, "wall-front");
  nav.addRect(x0 - WT, z1, x1 + WT, z1 + WT, "wall-back");
  nav.addRect(x0 - WT, z0, x0, z1, "wall-left");
  nav.addRect(x1, z0, x1 + WT, z1, "wall-right");
  // six island benches 3.0 x 1.2
  for (const bx of [-2.4, 2.4])
    for (const bz of [-1.5, 0.7, 2.9])
      nav.addRect(bx - 1.5, bz - 0.6, bx + 1.5, bz + 0.6, "island-bench");
  // front bench 3.0 x 0.7 at (0,-2.65); left-wall bench 7.6 x 0.7 rotated at (-HX+0.35,-0.6)
  nav.addRect(-1.5, -3.0, 1.5, -2.3, "front-bench");
  nav.addRectRot(-HX + 0.35, -0.6, 7.6, 0.7, Math.PI / 2, "left-bench");
  // podium 4.64 x 1.15 at front-centre + step aprons
  nav.addRect(-2.32, -4.92, 2.32, -3.77, "podium");
  nav.addRect(-3.22, -3.77, -2.32, -2.87, "podium-steps-l");
  nav.addRect(2.32, -3.77, 3.22, -2.87, "podium-steps-r");
  // storage cabinets 0.8 x 0.38 at (±2.75, -4.55) + left-wall cabinet rotated
  nav.addRect(-3.15, -4.74, -2.35, -4.36, "cab-front-l");
  nav.addRect(2.35, -4.74, 3.15, -4.36, "cab-front-r");
  nav.addRectRot(-HX + 0.8, 1.4, 0.8, 0.38, Math.PI / 2, "cab-left");
  // autoclave 0.62 x 0.6 at (5.05,-4.55)
  nav.addRect(4.74, -4.85, 5.36, -4.25, "autoclave");
  // biosafety cabinet 1.55 x 0.8 at (4.6, 4.44)
  nav.addRect(3.825, 4.04, 5.375, 4.84, "bsc");
  // stools r=0.15 at bench ends
  for (const bx of [-2.4, 2.4])
    for (const bz of [-1.5, 0.7, 2.9])
      for (const sx of [-0.5, 0.5])
        for (const sz of [-0.92, 0.92])
          nav.addCircle(bx + sx, bz + sz, 0.15, "stool");
  nav.build({ x0, z0, x1, z1 }, 0.25, 0.1);
  return nav;
}

/* ---- fake rig: exact ground integrator, records locomotion ---- */
function makeFakeRig(x, z, yaw) {
  return {
    radius: 0.25,
    pos: { x, z },
    yaw,
    loco: 0,
    poses: [],
    getPos() { return { x: this.pos.x, z: this.pos.z }; },
    getYaw() { return this.yaw; },
    setPose(nx, nz, nyaw) { this.pos.x = nx; this.pos.z = nz; this.yaw = nyaw; },
    setLocomotion(t) { this.loco = Math.max(0, Math.min(1, t)); },
  };
}

function runToDone(ctl, rig, nav, maxSimSeconds = 60, dt = 1 / 60) {
  const t0 = performance.now();
  let sim = 0;
  const samples = [];
  while (sim < maxSimSeconds) {
    ctl.update(dt);
    sim += dt;
    if (ctl.state === "IDLE" && !ctl.task) break;
    samples.push({ x: rig.pos.x, z: rig.pos.z, loco: rig.loco, state: ctl.state });
  }
  return { sim, wall: performance.now() - t0, samples };
}

/* ================= navigation tests ================= */
const nav = buildLabNav();
const stats = nav.stats();
check("nav builds", !!stats, `cells=${stats && stats.cells} walkable=${stats && stats.walkable} obstacles=${stats && stats.obstacles}`);
check("walkable fraction plausible (25-85%)", stats.walkable / stats.cells > 0.25 && stats.walkable / stats.cells < 0.85,
  (100 * stats.walkable / stats.cells).toFixed(1) + "%");

// corridor points that must be walkable AND connected to the room centre.
// (0,-3.4) is deliberately absent: it lies in the sealed alcove between podium
// and front bench — walkable cells, but no route (see alcove test below).
const aislePts = [
  [0, 0], [0, 4.2], [-4.6, 0], [4.6, 0], [-4.6, -2.8], [-4.6, 3.9], [4.6, 3.4], [0, -1.0],
];

/* flood fill over the nav grid (via isWalkable sampling) to prove connectivity */
function connectedComponent(nav, ox, oz) {
  const cell = 0.1;
  const bounds = { x0: -HX + WT / 2, x1: HX - WT / 2, z0: -HZ + WT / 2, z1: HZ - WT / 2 };
  const nx = Math.round((bounds.x1 - bounds.x0) / cell);
  const nz = Math.round((bounds.z1 - bounds.z0) / cell);
  const seen = new Uint8Array(nx * nz);
  const key = (ix, iz) => iz * nx + ix;
  const ix0 = Math.floor((ox - bounds.x0) / cell), iz0 = Math.floor((oz - bounds.z0) / cell);
  if (ix0 < 0 || iz0 < 0 || ix0 >= nx || iz0 >= nz) return { seen: seen, nx, nz, cell, bounds };
  const q = [key(ix0, iz0)];
  seen[q[0]] = 1;
  const D = [[1, 0], [-1, 0], [0, 1], [0, -1], [1, 1], [1, -1], [-1, 1], [-1, -1]];
  while (q.length) {
    const c = q.pop();
    const cx = c % nx, cz = (c - cx) / nx;
    for (const [ox2, oz2] of D) {
      const ax = cx + ox2, az = cz + oz2;
      if (ax < 0 || az < 0 || ax >= nx || az >= nz) continue;
      const ni = key(ax, az);
      if (seen[ni]) continue;
      if (!nav.isWalkable(bounds.x0 + (ax + 0.5) * cell, bounds.z0 + (az + 0.5) * cell)) continue;
      if (ox2 && oz2) {
        // no corner cutting: both orthogonals must be walkable too
        if (!nav.isWalkable(bounds.x0 + (cx + 0.5) * cell, bounds.z0 + (az + 0.5) * cell)) continue;
        if (!nav.isWalkable(bounds.x0 + (ax + 0.5) * cell, bounds.z0 + (cz + 0.5) * cell)) continue;
      }
      seen[ni] = 1;
      q.push(ni);
    }
  }
  return { seen, nx, nz, cell, bounds };
}
for (const [x, z] of aislePts)
  check(`aisle walkable (${x},${z})`, nav.isWalkable(x, z));

// every aisle point must be in the same connected component as (0,0)
{
  const comp = connectedComponent(nav, 0, 0);
  let allConnected = true;
  const missing = [];
  for (const [x, z] of aislePts) {
    const ix = Math.floor((x - comp.bounds.x0) / comp.cell);
    const iz = Math.floor((z - comp.bounds.z0) / comp.cell);
    if (ix < 0 || iz < 0 || ix >= comp.nx || iz >= comp.nz || !comp.seen[iz * comp.nx + ix]) {
      allConnected = false;
      missing.push(`(${x},${z})`);
    }
  }
  check("all aisle points connected to room centre", allConnected, missing.join(" ") || "connected");
  // the podium/front-bench alcove is walkable but deliberately sealed
  const alcoveIx = Math.floor((0 - comp.bounds.x0) / comp.cell);
  const alcoveIz = Math.floor((-3.4 - comp.bounds.z0) / comp.cell);
  const alcoveConnected = comp.seen[alcoveIz * comp.nx + alcoveIx];
  check("alcove (0,-3.4) is sealed off (walkable, unreachable)", nav.isWalkable(0, -3.4) && !alcoveConnected);
}

// bench centres must be blocked
for (const [x, z] of [[-2.4, 0.7], [2.4, -1.5], [0, -2.65], [4.6, 4.39]])
  check(`furniture blocked (${x},${z})`, !nav.isWalkable(x, z));

// path around the central island: from left aisle to right aisle
const p1 = nav.findPath(-4.6, 0.7, 4.6, 0.7);
check("path left→right aisle exists", !!p1 && p1.length >= 2, p1 ? `waypoints=${p1.length}` : "null");
if (p1) {
  let clear = true, minClear = Infinity;
  for (const pt of p1) {
    const c = nav.clearance(pt.x, pt.z);
    minClear = Math.min(minClear, c);
    if (!nav.isWalkable(pt.x, pt.z)) clear = false;
  }
  check("path stays on walkable cells", clear);
  check("path clearance ≥ 0.24 m at every waypoint", minClear >= 0.24, minClear.toFixed(3) + " m");
  // must detour through a gap, not straight through benches
  const straightBlocked = !nav.lineOfSight(-4.6, 0.7, 4.6, 0.7);
  check("direct line is blocked (detour required)", straightBlocked);
}

// goal deep inside a 3 m bench (>0.6 m from any walkable cell) = unreachable snap
const pUn = nav.findPath(-4.6, 0.7, 2.4, 0.7); // bench centre, default maxSnap 0.6
check("goal deep inside bench = null with default snap", pUn === null);
// same goal with the controller's larger snap (0.95) reaches the bench edge
const pUn2 = nav.findPath(-4.6, 0.7, 2.4, 0.7, { maxSnap: 0.95 });
check("goal deep inside bench snaps with maxSnap 0.95", !!pUn2,
  pUn2 ? `end=(${pUn2[pUn2.length - 1].x.toFixed(2)},${pUn2[pUn2.length - 1].z.toFixed(2)})` : "null");
if (pUn2) {
  const end = pUn2[pUn2.length - 1];
  check("snapped end is walkable and off the bench", nav.isWalkable(end.x, end.z) && !nav.isWalkable(2.4, 0.7));
}

// goal outside the room → unreachable (maxSnap fails)
const pOut = nav.findPath(0, 0, 0, -9.5, { maxSnap: 0.6 });
check("goal outside room = null (unreachable)", pOut === null);

/* ================= controller tests ================= */
function freshPair(x, z, yaw, cfg) {
  const rig = makeFakeRig(x, z, yaw);
  const ctl = LabTeacher.create(nav, rig, cfg || {});
  return { rig, ctl };
}

// 1. idle hold: no task, no drift
{
  const { rig, ctl } = freshPair(4.6, 3.72, Math.PI);
  for (let i = 0; i < 180; i++) ctl.update(1 / 60);
  check("idle: no drift without a task", Math.hypot(rig.pos.x - 4.6, rig.pos.z - 3.72) < 1e-6);
  check("idle: state stays IDLE", ctl.state === "IDLE");
}

// 2. goto straight 3 m (teacher at BSC → forward into the room)
{
  const { rig, ctl } = freshPair(4.6, 3.72, Math.PI);
  let done = null;
  ctl.goto(4.6, 0.72, { standOff: 0, label: "straight3m", resolve: (r) => (done = r) });
  const { sim, samples } = runToDone(ctl, rig, nav);
  check("walk 3 m: completes", done && done.status === "arrived", done ? done.status : "no result");
  const endDist = Math.hypot(rig.pos.x - 4.6, rig.pos.z - 0.72);
  check("walk 3 m: arrives within 0.15 m of target", endDist < 0.15, endDist.toFixed(3) + " m");
  check("walk 3 m: sim time sane (2-12 s)", sim > 2 && sim < 12, sim.toFixed(2) + " s");
  // locomotion actually engaged while moving
  const maxLoco = Math.max(...samples.map((s) => s.loco));
  check("walk 3 m: locomotion blend engaged", maxLoco > 0.9, "max=" + maxLoco.toFixed(2));
  // no teleport: max per-frame step < speed*dt*1.5
  let maxStep = 0;
  for (let i = 1; i < samples.length; i++)
    maxStep = Math.max(maxStep, Math.hypot(samples[i].x - samples[i - 1].x, samples[i].z - samples[i - 1].z));
  check("walk 3 m: no teleport (step ≤ 0.03 m)", maxStep <= 0.031, maxStep.toFixed(4) + " m");
  // transitions logged and sane
  const states = ctl.transitions.map((t) => t.to);
  check("walk 3 m: transition log non-empty", ctl.transitions.length >= 1, states.join("→"));
  check("walk 3 m: ends IDLE", ctl.state === "IDLE");
}

// 3. turn-in-place: faceYaw 180° away, tiny goal
{
  const { rig, ctl } = freshPair(0, 4.2, 0);
  let done = null;
  ctl.goto(0.3, 4.2, { standOff: 0, faceYaw: Math.PI, label: "turn180", resolve: (r) => (done = r) });
  const { samples } = runToDone(ctl, rig, nav);
  check("turn: completes", done && done.status === "arrived", done ? done.status : "none");
  let yawErr = Math.abs(((rig.yaw - Math.PI + Math.PI * 3) % (2 * Math.PI)) - Math.PI);
  check("turn: final yaw within 0.1 rad of target", yawErr < 0.1, yawErr.toFixed(3) + " rad");
  const toGoal = Math.hypot(rig.pos.x - 0.3, rig.pos.z - 4.2);
  check("turn: ends at the goal (no wandering)", toGoal < 0.15, toGoal.toFixed(3) + " m from goal");
  const sawTurn = ctl.transitions.some((t) => t.to === "TURN");
  check("turn: TURN state used", sawTurn);
}

// 4. obstacle avoidance: diagonal crossing of the whole bench field
{
  const { rig, ctl } = freshPair(-4.6, -2.8, Math.PI / 2);
  let done = null;
  ctl.goto(4.6, 3.4, { standOff: 0, label: "diagonal", resolve: (r) => (done = r) });
  const { sim, samples } = runToDone(ctl, rig, nav, 90);
  check("avoid: completes", done && done.status === "arrived", done ? `${done.status} in ${sim.toFixed(1)}s` : "none");
  let minClear = Infinity, everBlocked = false;
  for (const s of samples) {
    const c = nav.clearance(s.x, s.z);
    minClear = Math.min(minClear, c);
    if (c < 0.2) everBlocked = true;
  }
  check("avoid: never closer than 0.2 m to raw furniture", !everBlocked, "min=" + minClear.toFixed(3) + " m");
  check("avoid: finishes near goal", Math.hypot(rig.pos.x - 4.6, rig.pos.z - 3.4) < 0.15);
}

// 5. unreachable goal → clean failure, no movement
{
  const { rig, ctl } = freshPair(0, 0, 0);
  let done = null;
  ctl.goto(0, -9.5, { standOff: 0, label: "outside", resolve: (r) => (done = r) });
  for (let i = 0; i < 60; i++) ctl.update(1 / 60);
  check("unreachable: immediate unreachable result", done && done.status === "unreachable", done ? done.status : "none");
  check("unreachable: no movement", Math.hypot(rig.pos.x, rig.pos.z) < 1e-6);
  check("unreachable: back to IDLE", ctl.state === "IDLE");
}

// 6. interruption: long walk cancelled mid-flight, new short walk wins
{
  const { rig, ctl } = freshPair(-4.6, -2.8, Math.PI / 2);
  let first = null;
  ctl.goto(4.6, 3.4, { standOff: 0, label: "long", resolve: (r) => (first = r) });
  for (let i = 0; i < 120; i++) ctl.update(1 / 60); // ~2 s in
  const midState = ctl.state;
  check("interrupt: mid-walk state is NAVIGATE/APPROACH", midState === "NAVIGATE" || midState === "APPROACH", midState);
  let second = null;
  ctl.goto(0, -1.0, { standOff: 0, label: "short", resolve: (r) => (second = r) });
  check("interrupt: first task reports interrupted", first && first.status === "interrupted", first ? first.status : "pending");
  const { sim } = runToDone(ctl, rig, nav, 60);
  check("interrupt: second task completes", second && second.status === "arrived", second ? second.status : "none");
  check("interrupt: arrives at second goal", Math.hypot(rig.pos.x - 0, rig.pos.z + 1.0) < 0.15);
}

// 7. timeout: absurdly small timeout → timeout status, stops
{
  const { rig, ctl } = freshPair(-4.6, -2.8, Math.PI / 2, { timeout: 0.5 });
  let done = null;
  ctl.goto(4.6, 3.9, { standOff: 0, label: "tooshort", resolve: (r) => (done = r) });
  runToDone(ctl, rig, nav, 10);
  check("timeout: reports timeout", done && done.status === "timeout", done ? done.status : "none");
  check("timeout: returns IDLE", ctl.state === "IDLE");
}

// 8. standOff: stop ~0.85 m short of a bench-edge target
{
  const { rig, ctl } = freshPair(0, 0, 0);
  // target = centre of the front bench (0,-2.65); walkable floor stops at
  // z≈-3.275 (0.625 m out), so standOff 0.85 must trim the path back further
  let done = null;
  ctl.goto(0, -2.65, { standOff: 0.85, label: "standoff", resolve: (r) => (done = r) });
  runToDone(ctl, rig, nav, 60);
  check("standOff: completes", done && done.status === "arrived", done ? done.status : "none");
  const d = Math.hypot(rig.pos.x - 0, rig.pos.z + 2.65);
  check("standOff: stops at the requested 0.85 m (±0.08)", Math.abs(d - 0.85) < 0.08, d.toFixed(2) + " m");
  check("standOff: final position walkable", nav.isWalkable(rig.pos.x, rig.pos.z));
  check("standOff: final position clear of bench edge (≥0.45)", nav.clearance(rig.pos.x, rig.pos.z) >= 0.45, nav.clearance(rig.pos.x, rig.pos.z).toFixed(3) + " m");
}

/* ---- summary ---- */
const failed = checks.filter((c) => !c.ok).length;
console.log(`\nphase1_unit: ${checks.length - failed}/${checks.length} checks passed`);
process.exit(failed === 0 ? 0 : 1);
