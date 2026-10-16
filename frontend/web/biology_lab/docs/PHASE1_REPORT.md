# Phase 1 Report — Teacher Navigation (biology lab)

Date: 2026-10-15
Branch: `phase1-teacher-nav` (from baseline `da76650`)
Scope: CSV upgrade plan Phase 1 only — teacher rig control, idle/walk/turn,
navigation. Phase 2+ intentionally not started.

## What shipped

| File | Role |
|---|---|
| `js/nav.js` | Obstacle registry (rect / rotated rect / circle), radius-inflated walkability grid (0.1 m cells, 0.25 m agent), multi-candidate snap, 8-connected A* (no corner cutting, binary heap), string-pull smoothing with quarter-cell line-of-sight, clearance probe |
| `js/teacher_controller.js` | State machine IDLE / TURN / NAVIGATE / APPROACH / RECOVER; `goto(x,z,opts)` with `{standOff,faceYaw,faceX,faceZ,timeout,label,resolve}`, `.cancel()`, `stop()`; waypoint follower with per-waypoint arrive radii, accel/decel, safety look-ahead, stuck detection, recover snap-back |
| `index.html` | Live integration: imports both modules; `CONFIG.teacherControl:true`; nav grid built from the real furniture coordinates after placement (~line 2306); teacher rig adapter (pose + walk/idle crossfade + foot-lock blended by locomotion); `window.BioLab={nav,ctl,teacher,goto}`; diag dump now reports `teacher.control` and `nav` stats; `?navtest=1` acceptance harness |
| `scripts/phase1_unit.mjs` | 53 Node checks (no THREE/DOM): grid geometry, flood-fill connectivity, sealed alcove, A*, controller walk/turn/avoid/unreachable/interrupt/timeout/standOff |
| `scripts/smoke.mjs` | Extended: second headless pass on `?navtest=1` parses `pre#__navtest` and asserts every navtest check; existing `?diag=1` pass additionally asserts `teacher.control` and live nav stats |

## Architecture notes

- **Grid build**: obstacles mirror the built meshes exactly (same world
  coordinates), registered once after furniture; walls as perimeter slabs;
  stools as circles at bench ends; podium from `userData.platform` plus step
  aprons; BSC/autoclave/cabinets as AABBs. Rasterised inflated by the teacher
  radius so `isWalkable` is already agent-aware.
- **Snap**: goals inside furniture snap to walkable cells within 0.95 m, but
  the Euclidean-nearest cell can be a disconnected pocket (bench strips sealed
  by stool rings) — `findPath` retries up to 6 goal × 6 start candidates until
  A* succeeds.
- **standOff**: not applied by pre-pulling the goal (could land inside an
  obstacle); instead the path end is trimmed back along the waypoints, with
  the exact standOff crossing interpolated by binary search and accepted only
  if that point is on walkable floor.
- **Follower**: intermediate waypoints use `wpArriveDist = 0.04` (≈ half a
  cell) so the walker does not "arrive" early and cut corners into inflated
  benches; the final point uses `arriveDist = 0.1` with a decelerating stop.
- **Foot-lock**: the existing per-phase sole table drives `position.y`, now
  scaled by the walk/idle blend so the planted foot stays on the floor through
  the whole gait transition.

## Bugs found and fixed during integration

1. **Corner-cutting blocked steps** — `arriveDist = 0.1` let the follower
   arrive up to 10 cm early at corner waypoints and clip inflated obstacles.
   Fixed with `wpArriveDist = 0.04`.
2. **LOS undersampling let string-pull keep bad segments** — line-of-sight
   sampled at half-cell (0.05 m) steps and straddled the thin (~7 cm) blocked
   sliver where a diagonal segment clips an inflated bench corner. The walker
   stepped into it mid-segment, RECOVER fired, and re-pathing from *inside*
   the inflated zone failed forever (every look-ahead step blocked) → bogus
   `unreachable`. Fixed two ways: LOS now samples at quarter-cell (0.025 m),
   and the controller records `lastWalkable` and snaps back to it before
   re-pathing if a bad step left the rig in blocked space.
3. **Comment containing a literal `<pre id="__navtest">`** broke the smoke
   harness regex (it matched the script source in the serialized DOM instead
   of the real element). Reworded the comment.

## Test results (real runs, this machine)

```
node scripts/phase1_unit.mjs
  phase1_unit: 53/53 checks passed
  (nav builds cells=11564 walkable=4233 obstacles=44, 36.6% walkable)

node scripts/smoke.mjs
  smoke: 79/79 checks passed
  - 56 pre-existing ?diag=1 scene checks (all still pass)
  - teacher controller created (Phase 1)
  - nav grid built in the live scene
  - navtest: 19/19 checks (NAVTESTREADY, report emitted, grid built,
    walkable fraction sane, controller created, starts idle at BSC stand,
    straight walk arrives, ends near target, walk blend engaged,
    diagonal route arrives, ends near target, standOff arrival,
    standOff distance 0.85 m, unreachable reported, no movement on
    unreachable, first task interrupted, second task arrives, second goal
    reached, returns to BSC stand, zero failures)
```

Navtest scenarios exercised in the real page (fixed-step drive of the live
rig + nav grid, not Node fakes): straight walk, ~9 m diagonal with obstacle
avoidance, standOff approach to the front bench, unreachable goal (clean
failure, no movement), mid-walk task interruption, and return to the BSC
stand point with final facing.

## Notes / follow-ups (Phase 2+)

- The alcove (0, −3.4) between podium and front bench is walkable but sealed;
  any future "go to podium front" interaction must target the north side.
- Goal points on bench tops (~0.9 m from the floor edge) rely on the 0.95 m
  snap; deeper points correctly fail as unreachable.
- The teacher currently navigates only on the ground floor; podium stairs are
  registered as obstacles (no stair climbing in Phase 1).
- Synced to `Penrose-ScholarMW/frontend/web/biology_lab/` with MD5 parity
  (50 files).
