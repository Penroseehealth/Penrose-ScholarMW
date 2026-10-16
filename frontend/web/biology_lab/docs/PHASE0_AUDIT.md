# Phase 0 Audit — Biology Lab Teacher Navigation

Date: 2026-10-15
Branch: `phase1-teacher-nav` (baseline `da76650`)
Scope: pre-implementation audit for the CSV upgrade plan — Phase 1 only
(teacher rig, idle, walking, turning, navigation). No Phase 2 work.

## Scene inventory (exact world coordinates)

Room: `FW=12, FD=10, HX=6, HZ=5, WT=0.25` (index.html:492). Walkable interior
bounds `x,z ∈ [-HX+WT/2, HX-WT/2] = ±5.875`. Grid resolution 0.1 m, teacher
body radius 0.25 m.

| Element | Geometry | Position |
|---|---|---|
| Island benches (6) | 3.0 × 1.2 | (±2.4, −1.5 / 0.7 / 2.9) |
| Front bench | 3.0 × 0.7 | (0, −2.65) |
| Left-wall bench | 7.6 × 0.7, rot 90° | (−5.65, −0.6) |
| Podium platform | 4.64 × 1.15, h 0.45 | x ±2.32, z −4.92..−3.77 |
| Podium steps (6) | 3 per side, 0.3 tread | x ±2.32..±3.22, z −3.77..−2.87 |
| Front cabinets (2) | 0.8 × 0.38 | (±2.75, −4.55) |
| Left-wall cabinet | 0.8 × 0.38, rot 90° | (−4.85, 1.4) |
| Autoclave | 0.62 × 0.6, rot −0.12π | (5.05, −4.55) → AABB (4.74..5.36, −4.85..−4.25) |
| Biosafety cabinet | 1.3 × 0.72 | (4.6, 4.39) → AABB (3.95..5.25, 4.03..4.75) |
| Stools (24) | r 0.15 | bench ends: (bx±0.5, bz±0.92) |

## Teacher rig (existing)

- `assets/teacher.glb` — Ready Player Me avatar, 67-bone Mixamo rig, no
  animation in the GLB.
- `assets/teacher-anim.json` — walk + idle clips retargeted from the Xbot
  Mixamo rig (world-space-delta FK bake, `tools/teacher/build_teacher_anim.py`).
- Foot-lock: per-phase sole-height table sampled from the walk clip silhouette
  (24 phases); body dropped each frame so the planted foot stays on the floor.
- Placement: stands at `CONFIG.teacherStand = (4.6, 3.72)`, facing −z (into the
  room), just in front of the BSC.
- Legacy patrol (`CONFIG.teacherWalk`, off by default): Catmull-Rom loop
  `[(−4.6,−2.8),(4.6,−2.8),(4.6,3.9),(−4.6,3.9)]` driven directly in `teacherStep`.

## Navigation constraints discovered (flood-fill over a rasterised grid)

1. **Sealed alcove**: the strip between podium and front bench
   ((0, −3.4), ~0.27 m wide) is walkable but unreachable — both ends are
   sealed (podium steps to the south, inflated stool tangent to the bench
   corner to the north). It must never be used as a navigation goal and is
   encoded as an explicit unit test.
2. **Disconnected bench pockets**: the narrow strips between island-bench rows
   are sealed off by inflated stool rings. The Euclidean-nearest walkable cell
   to many goals can sit in such a pocket → snapping must retry the next
   candidates until A* actually finds a route (multi-candidate snap).
3. **Open cross-corridors** between bench rows exist only at specific x bands;
   the centre aisle `x ∈ (−0.65, 0.65)` is open end-to-end.
4. **BSC clearance**: floor in front of the BSC starts at `z ≤ 3.78`; the
   teacher stand point (4.6, 3.72) is walkable, (4.6, 3.9) is not.
5. Bench-top interaction points (e.g. equipment on a 3 m bench) can be up to
   ~0.9 m from the nearest walkable floor → goal snap radius must cover ~0.95 m
   while points deep inside a bench still fail as unreachable.

## Integration surface

- `index.html` is a single ES module (`<script type="module">`, no build step,
  `"type": "module"` in package.json — all new `.js` must be true ES modules).
- Teacher code ~1638–1884; podium built at 1155–1180 (`userData.platform`
  available for obstacle registration); furniture placed ~2160–2266 (nav grid
  must be built after these); `frame()` loop 3093+; diag dump `dumpDiag()`.
- Headless test harnesses already exist: `scripts/smoke.mjs` (Edge/Chrome,
  `?diag=1`, virtual-time budget, parses `<pre id="__diag">`), plus
  `scripts/phase1_unit.mjs` pattern for Node-side tests (no THREE/DOM).
- Constraints carried forward: Flutter/Dart shell kept, Three.js r172 vendor
  build, no paid APIs, Penrose copy synced from this workspace with MD5 parity.

## Phase 1 decision

Ship a pure-JS navigation module + teacher state machine + live integration
behind `CONFIG.teacherControl` (legacy patrol stays available behind
`CONFIG.teacherWalk`). Deterministic acceptance via `?navtest=1` in the real
page, not only Node fakes. Phase 2+ (interaction, gestures, speech triggers)
explicitly out of scope.
