# Biology Lab — Standalone 3D Science Laboratory (Three.js r172)

A self-contained, embeddable 3D biology laboratory: autonomous teacher,
navigation, behaviour scenarios, functional equipment, nine science experiment
modules, virtual students, a full lesson engine, dynamic environment/safety,
camera viewpoints and a performance monitor — built on the existing
Flutter/Dart + Three.js stack without replacing either.

This file is the **required handover document** (CSV Global → Required
handover). Per-phase architecture and file-change detail lives in
`docs/PHASE0_AUDIT.md` and `docs/PHASE1_REPORT.md` … `docs/PHASE8_REPORT.md`.

## Run instructions

No install step and no runtime npm dependencies.

```bash
node serve.mjs          # serves on http://127.0.0.1:7456/
PORT=8080 node serve.mjs    # alternate port
```

Open `http://127.0.0.1:7456/` in any WebGL2 browser. Usefull query flags:

| Flag | Effect |
|---|---|
| `?diag=1` | diagnostics dump (`<pre id="__diag">`) used by the smoke gate |
| `?navtest=1` `?behavtest=1` `?studenttest=1` `?lessontest=1` `?envtest=1` | per-phase acceptance harnesses |
| `?camtest=1` `?movtest=1` `?evtest=1` `?microtest=1` `?consisttest=1` | Phase-8 acceptance harnesses |
| `?view=demo` | scripted camera demo (step/pause/resume/replay) |
| `?weather=rain` | initial environment weather |

Embedding: the page talks to a parent frame via `postMessage`
(`window.parent.postMessage`, exit message `penrose-bio-lab-exit`), and exposes
a `window.BioLab` bridge (both asserted by `consisttest`).

## Test instructions

```bash
npm test                          # themes_test (20 themes) + full smoke gate
node scripts/phase1_unit.mjs      # … through phase8_unit.mjs (pure Node, fast)
node scripts/smoke.mjs            # headless browser gate (needs Edge/Chrome; EDGE_PATH overrides)
```

Smoke needs a local headless browser; launches use SwiftShader software GL and
each pass retries up to 3× if its READY title is missing (see
`dumpDom` in `scripts/smoke.mjs`). Virtual-time budgets per pass are
overridable with `SMOKE_<PASS>_VTIME`.

## Test results (verified 2026-10-15, branch `phase1-teacher-nav`)

| Gate | Result | Command |
|---|---|---|
| phase1_unit (nav/controller) | **53/53** | `node scripts/phase1_unit.mjs` |
| phase2_unit (behaviour/scenarios) | **54/54** | `node scripts/phase2_unit.mjs` |
| phase3_unit (equipment) | **41/41** | `node scripts/phase3_unit.mjs` |
| phase4_unit (science/microscopy) | **87/87** | `node scripts/phase4_unit.mjs` |
| phase5_unit (students) | **40/40** | `node scripts/phase5_unit.mjs` |
| phase6_unit (lesson engine) | **62/62** | `node scripts/phase6_unit.mjs` |
| phase7_unit (environment/biology/safety) | **99/99** | `node scripts/phase7_unit.mjs` |
| phase8_unit (camera/perf) | **64/64** | `node scripts/phase8_unit.mjs` |
| themes | **20/20** | `node scripts/themes_test.mjs` |
| smoke (diag + 10 harness passes) | **361/361** | `node scripts/smoke.mjs` |

No failures, no skipped gates. Harness outputs include evidence JSON (path
lengths, foot-slide stats, camera errors, determinism hashes) printed with each
run — results above are from actual runs, not estimates.

## Architecture / file-change report (summary)

| Phase | Commit | Primary files |
|---|---|---|
| 0 audit | (in `191c9da`) | `docs/PHASE0_AUDIT.md` — scene inventory, nav constraints, rig audit |
| 1 teacher navigation | `191c9da` | `js/nav.js` (grid + A*), `js/teacher_controller.js`, `phase1_unit.mjs` |
| 2 behaviour | `8805b92` | `js/behaviour.js` (world store, state machine, window/phone/drawer scenarios), `phase2_unit.mjs` |
| 3 equipment | `815eb07` | `js/objects.js` (action interface + catalogue), `phase3_unit.mjs` |
| 4 science | `8c2cade` | `js/science.js` (9-module registry, microscope flow), `phase4_unit.mjs` |
| 5 students | `3e8a16a` | `js/students.js` (FSM + dialogue pools, zero AI API calls), `phase5_unit.mjs` |
| 6 lesson engine | `b30017f` | `js/lesson.js` (setup→cleanup, 6-dimension assessment, persistence), `phase6_unit.mjs` |
| 7 environment/safety | `f1ec20c` | `js/environment.js`, `js/biology_assets.js`, `js/safety.js`, `phase7_unit.mjs` |
| 8 camera/perf/tests | `73a96ba` | `js/camera.js` (223 lines), `js/perf.js` (168), 5 harnesses, `phase8_unit.mjs` |

All phases additionally wire their layer through `index.html` (flags,
`buildPhase<N>` IIFE, `frame()` integration, diag blocks, harness dispatch).

Baseline: `da76650` ("Baseline before Phase 1", matches the deployed Penrose
copy). Full detail per phase: `docs/PHASE<N>_REPORT.md`.

Live copy: synced via robocopy to
`Penrose-ScholarMW\frontend\web\biology_lab\` — full-tree MD5 parity
**77/77 files, 0 mismatch** at handover.

## Dependencies and licences

| Dependency | Version | Licence | Evidence |
|---|---|---|---|
| three.js (`vendor/three.module.js`, `vendor/three.core.js`) | r172 | **MIT** (`SPDX-License-Identifier: MIT`, Copyright 2010-2024 Three.js Authors) | header in both vendored files |
| npm runtime packages | none | — | `package.json` has no `dependencies` |
| Node.js (server + tests) | built-ins only; tested on Node 24 | MIT | `serve.mjs`, `scripts/*.mjs` use `node:http/fs/zlib/child_process` only |

Asset provenance (in-repo documentation; **no licence texts ship with the
assets** — see limitations):

| Asset | Provenance documented in repo |
|---|---|
| `assets/teacher.glb` | Ready Player Me avatar on a 67-bone Mixamo rig (`docs/PHASE0_AUDIT.md`) |
| `assets/teacher-anim.json` | Mixamo Xbot walk/idle clips retargeted (`docs/PHASE0_AUDIT.md`, built by `tools/teacher/build_teacher_anim.py`) |
| `assets/microscope.glb`, `student-girl.glb`, `heart.obj/.mtl`, `heart-zanatomy.png`, `lab-chart.jpg`, `biology-teacher*.png` | **not documented** — provenance/licence unknown in this repo |

## Known limitations

1. **All verification is headless (SwiftShader software GL).** Perf-tier
   thresholds in `js/perf.js` degrade/restore correctly in tests but have not
   been profiled on real GPU hardware or low-end classroom devices.
2. **Flutter integration is contract-level only.** Tests assert the bridge API
   and exit message exist (`window.parent.postMessage`, `window.BioLab`);
   no end-to-end Flutter host test runs in this repo.
3. **Sealed regions are unreachable by design** — the podium/front-bench alcove
   and stool-flanked bench pockets are walkable cells that cannot be goals
   (unit-tested); this is intended, not a defect.
4. Harnesses simulate at a fixed 60 Hz step; real-time frame pacing differs,
   so movement/camera evidence bounds apply to the simulated stream.
5. **Asset licence documentation is incomplete** (table above): only three.js
   carries a verifiable licence in-repo. Asset licences must be confirmed by
   the owner before redistribution.

## Unresolved defects / pending items

- **No failing tests or known functional defects** — all 11 gates green
  (9 unit + themes + smoke) at commit `73a96ba`.
- Working tree intentionally carries three pre-existing, phase-external
  deviations, left uncommitted: `_sample_teacher.html` (deleted),
  `assets/biology-teacher.png` (modified), `texprobe.html` (untracked).
- Asset licence confirmation (limitation 5) is the only open documentation task.

## Completed / pending phase list

| Phase | Status |
|---|---|
| 0 Project audit + safety | **Complete** (`da76650` / `191c9da`) |
| 1 Teacher rig + navigation | **Complete** (`191c9da`, 53/53) |
| 2 Behaviour controller + scenarios | **Complete** (`8805b92`, 54/54) |
| 3 Object interaction + equipment | **Complete** (`815eb07`, 41/41) |
| 4 Scientific simulation + microscopy | **Complete** (`8c2cade`, 87/87) |
| 5 Virtual students | **Complete** (`3e8a16a`, 40/40) |
| 6 Lesson engine + assessment | **Complete** (`b30017f`, 62/62) |
| 7 Environment + biology + safety | **Complete** (`f1ec20c`, 99/99) |
| 8 Camera + performance + acceptance tests | **Complete** (`73a96ba`, 64/64, smoke 361/361) |
| Handover documentation | **Complete** (this file) |
| Pending | Asset licence confirmation; real-hardware perf pass (optional) |
