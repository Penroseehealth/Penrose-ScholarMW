# Phase 8 Report — Camera Viewpoints, Performance Monitor, Acceptance Harnesses

Branch `phase1-teacher-nav`. Implements the three Phase-8 rows of
`general_science_lab_upgrade_master_prompt.csv`.

## Gates

| Suite | Result |
|---|---|
| phase1_unit | 53/53 |
| phase2_unit | 54/54 |
| phase3_unit | 41/41 |
| phase4_unit | 87/87 |
| phase5_unit | 40/40 |
| phase6_unit | 62/62 |
| phase7_unit | 99/99 |
| **phase8_unit** | **64/64** (new) |
| smoke | **361/361** (was 264) — diag + navtest + behavtest + studenttest + lessontest + envtest + **camtest + movtest + evtest + microtest + consisttest** |

## Files

| File | Change |
|---|---|
| `js/camera.js` | **New.** Camera rig with six modes: `orbit` (the original user controls, preserved untouched), `studentEye` (settles between a seat and its bench, near-horizontal), `teacherFollow` (behind the teacher, re-aims continuously), `equipmentCloseup` (narrow fov on a selected object, selection kept), `eyepiece` (looks straight down the optical axis of the selected microscope, very narrow fov), and demo views. All non-orbit switches are tweened with angular speed capped at 2.2 rad/s (no disorienting jumps), logged, and fully reversible to `orbit`. Demo player: `demoSet` (step list), `play/pause/resume/replay/prev/frame`, position + angular-speed tracking. Exports `CAM_MODES`, `wrapPi`, `lookFrom`. |
| `js/perf.js` | **New.** Performance monitor: frame-time sampler (p95), tier degradation/restore (`high`→`medium`→`low`) from slow frames, per-system update budgets (students ~10 Hz) via `shouldRun(name, time)`, single-animation-loop guard with duplicate-loop detection and `release()`, listener registry balance tracking, bounded bridge queue (cap + overflow counter + per-tick flush), asset-reuse counter, `snapshot()` carrying tier/fps/listeners. |
| `index.html` | Phase-8 wiring: two imports; `CAMTEST/MOVTEST/EVTEST/MICROTEST/CONSISTTEST` query flags (all five excluded from the normal `frame()` start condition and dispatched on both GLB success and fail paths); `buildPhase8` IIFE (rig + perf instances, `[data-view]` buttons → `rig.setView('orbit')`, `?view=demo` demo queue, `phase8.frame(dt)` call in `frame()`, `slowTier` gates phase3/5/7 systems through `perf.shouldRun`); diag gains `cameraRig` + `perfMon` blocks; five acceptance harnesses (`runCamTest` 20 checks, `runMovTest` 11, `runEvTest` 15, `runMicroTest` 14, `runConsistTest` 21). +614 lines net. |
| `scripts/phase8_unit.mjs` | **New.** 64 checks: helpers (wrapPi/ease/lookFrom), camera rig (modes, transitions ≤2.2 rad/s, fov, orbit restoration), demo player (play/pause/resume/prev/replay), perf monitor (tiers, budgets, loop guard, listener balance, bridge queue), rig+perf cross-checks. |
| `scripts/smoke.mjs` | Five new passes with per-pass virtual-time budgets and dedicated profiles; diag assertions for `cameraRig`/`perfMon`; **`dumpDom` retry helper** — every pass now relaunches up to 3× while its READY title is missing (repeated swiftshader launches occasionally flake under system load and must not fail a deterministic harness); FAIL details printed. |
| `docs/PHASE8_REPORT.md` | This file. |

## Acceptance mapping

**Camera viewpoints** — orbit stays the user's default; five additional modes
cover student eye-level, teacher follow, equipment close-up, microscope eyepiece,
and demo step/pause/resume/replay. Every transition is eased with a bounded
angular speed so the user is never whipped around. Verified in-canvas by
`camtest` (fov mirrors the rig, follow sits behind the teacher, eyepiece looks
down the optical axis, transitions settle, view buttons restore orbit).

**Performance** — tiers derived from frame-time p95 degrade and restore
automatically; slow tiers gate expensive per-system updates instead of dropping
frames silently; the single-loop guard detects duplicate animation loops and
leaked listeners; the bridge queue is bounded with overflow accounting; assets
are reused. Verified by `phase8_unit` (20 perf checks) and `consisttest`
(sampling active, draw calls bounded, exactly one loop, listeners balanced,
transition rings bounded, bridge + exit control present).

**Acceptance suites** — all four CSV suites are now automated:
movement (`movtest`: no foot slide, teleport, obstacle detour, off-map refusal,
recovery; evidence includes path lengths, planted-foot stats and the bounded
arrival snap), events (`evtest`: window/phone/drawer/carry, sound orientation,
interrupt→pause→resume, all with world/attach/detach evidence), microscopy
(`microtest`: seated at the scope, illumination/objective/focus with visual
response mirrored in stats, 10x vs 40x cell counts from the real science model,
pointing at a diagram region, lamp returned to safe state), consistency+safety
(`consisttest`: world snapshot stability, science determinism, safety
interruption→lesson, breakage incident, unreachable recovery, three.js r172,
perf, memory/leak proxies, Flutter bridge).

## Bugs found and fixed during Phase 8

1. **Arrival snap counted as a teleport.** The controller's final settle snaps
   at most `arriveDist` (0.1 m) onto the exact goal at task end; the harness
   recorded it as a 0.0976 m body step. The resolving step is now excluded from
   walk measurements and reported separately as `evidence.arrivalSnap`.
2. **Foot-slide false positive.** Swing/toe-off samples and pose snaps inside
   the planted-foot window inflated the max slide. Stance is now defined as
   sole near the ground **and** height nearly constant (`Δy < 0.002 m`), the
   threshold adapts to the rig's sole height, and body steps >0.08 m are
   recorded as `poseSnaps` rather than slide; max slide dropped to 0.0267 m
   (gate 0.03) with `poseSnaps=0`.
3. **Fixed-step harness loops too short.** `microtest`/`evtest` used 600-step
   caps; real walks from the podium/exhibit exceeded them and every later task
   queued behind the stuck one (9 cascading failures). Replaced with a
   `drive(maxSec)` helper that steps until `teacherBehav.pendingCount()` drains.
4. **`smoke.mjs` flaky under load.** Full runs intermittently missed READY
   titles for a contiguous block of passes (different blocks each run) —
   swiftshader launches flaking, not harness logic. Centralised launches in
   `dumpDom()` with up to 3 attempts per pass and an exit-code/title warning;
   full suite then passed 361/361.
5. **Duplicate `samples++`** in the movtest walk loop (double-counted frames)
   — removed during the arrival-snap restructure.

## Notes

- Vendored `vendor/three.module.js` (10,558 lines) + `vendor/three.core.js`
  are counted separately from project lines per the reporting rule; project
  code added in Phase 8: `js/camera.js` 223, `js/perf.js` 168,
  `scripts/phase8_unit.mjs` 178, `index.html` +614 net,
  `scripts/smoke.mjs` +~150 net (273 changed).
- Harness budgets (override with `SMOKE_<PASS>_VTIME`): camtest 300000,
  movtest 600000, evtest 900000, microtest 600000, consisttest 300000.
- Debug aid: `one_pass.mjs <pass>` (temp workspace) runs a single harness
  headlessly with per-check details and full evidence JSON.
