# Phase 7 Report — Dynamic Environment, Biological Assets, Safety-Aware Lesson Logic

Branch `phase1-teacher-nav`. Implements the three Phase-7 rows of
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
| **phase7_unit** | **99/99** (new) |
| smoke | **264/264** (was 220) — diag + navtest + behavtest + studenttest + lessontest + **envtest** |

## Files

| File | Change |
|---|---|
| `js/environment.js` | **New.** Day/night clock (`daylightFactor`, auto/manual lighting policy), artificial lights, fans/aircon, doors/windows, weather (`clear/rain/wind/storm`) with temp/humidity side effects and window-advice rules, timers → alarms, evacuation flag, positioned `sound()` events with distance attenuation `gain = 1/(1+(d/4)²)` vs the listener, derived indicators (`indoorLux`, `ventilationScore`, `comfortIndex`), `serialize/restore`. |
| `js/biology_assets.js` | **New.** Cells (onion 15 µm / cheek 25 µm / leaf mesophyll) with organelle roles and SI sizes, tissues→organs hierarchy, 5-level scale ladder (organ→membrane) with the magnification needed, plant species growth model (germination, thermal response, light/water factors → stage/height/leaves), woodlice choice-chamber model (8/10 damp at 10 min, time-dependent), and an `audit()` of 13 scientific-accuracy checks that must pass — accuracy checked, not assumed. |
| `js/safety.js` | **New.** PPE state per student (goggles/coat/tied hair) with `ppeOk/ppeMissing`, handling gates (glassware/specimen/microscope/sharps/chemical) with corrective feedback + teacher-supervision flags, waste classification (glass/organic/chemical/sharps/general → bin + rule), incident response plans (spill/breakage/fire/chemical → steps, alarm, evacuation, feedback), incident report log with resolve, `intervention(action)` for unsafe actions, `serialize/restore`. |
| `index.html` | Phase-7 wiring: three imports, `ENVTEST` flag, `phase7` global, `buildPhase7` IIFE nested after the settings-panel buttons (env+bio+safety instances, `?weather=` param, WebAudio alarm beep reusing the shared `actx`, button→model listeners for fans/lights/aircons, canvas door/window clicks rerouted through `phase7.setDoor/setWindow` so every open/close is an env event, env→scene mirror in `frame` (lights UI, fan UI, door/window pivots, graded `windowLight.intensity` from `indoorLux`), lightweight biology props on the left-wall bench — germination dish (3 seeds at staggered days), potted cress (stem/leaves scale from the growth model at 2 Hz), woodlice damp/dry choice chamber; `P7.reportViolation` feeds corrective feedback into `lesson.safetyViolation` and raises a safety alarm). `frame` calls `phase7.frame(dt)`; diag gains `environment`, `biology`, `safety` blocks; `?envtest=1` harness (34 checks) + dispatch on both GLB success/fail paths + frame-condition exclusion. |
| `scripts/phase7_unit.mjs` | **New.** 99 checks across the three modules + cross-module integration. |
| `scripts/smoke.mjs` | `ENVTEST_URL` + budget, 3 new diag assertions (environment/biology-audit/safety attached), `?envtest=1` pass auto-asserting every harness check. |
| `docs/PHASE7_REPORT.md` | This file. |

## Acceptance mapping

**Dynamic lab environment** — env state responds to user actions (button and
canvas clicks both write through the model, which records sound/advice events)
and to events (weather changes, timers firing, evacuation pauses the clock);
effects are lightweight (state + one graded light intensity + WebAudio beep +
event log), no new meshes for the environment itself.

**Plants and organisms** — educationally relevant models with `audit()`-verified
scientific accuracy: cell sizes match the Phase-4 microscope model exactly,
tissues/organs reference real cells, growth is blocked without water and outside
the thermal range, woodlice preference matches the classic choice-chamber
result; props on the bench are driven by the same model the tests verify.

**Safety-aware lesson logic** — unsafe actions interrupt: a blocked handling
attempt returns corrective feedback and counts a violation; `reportViolation`
pushes the feedback into the Phase-6 lesson engine (lowering its safety score)
and raises an alarm; incidents carry response plans; fire triggers evacuation
which pauses the simulation clock; incidents can be resolved and the report
reads back totals.

## Bugs found and fixed during Phase 7

1. `serialize/restore` version mismatch in **both** new modules — `restore`
   read `data.state.v` while `serialize` wrote `v` at the top level; restore
   always failed. Fixed to `data.v`.
2. `daylightFactor(18)` returned `1.2e-16` instead of `0` (float epsilon at
   sunset) — snapped near-zero values.
3. Premature `})();` when inserting `buildPhase7` inside the settings-panel
   IIFE — orphaned its original closer; builder now nests cleanly.
4. `students.ids()` does not exist — seeded ids via `statuses().map(...)`.
5. Nucleus-resolvability audit criterion was stricter than the school
   rule-of-thumb it encoded (6.25 µm vs the actual 5 µm) — corrected.

## Test notes

The first smoke run after wiring reported 244/246; three consecutive
subsequent runs report 264/264 exit 0. The variance is in the dynamic
navtest/behavtest harness check counts (timing retries), not the Phase-7
checks.
