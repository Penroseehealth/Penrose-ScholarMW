# Phase 6 Report — Lesson Engine: Complete Practical + Assessment (biology lab)

Date: 2026-10-15
Branch: `phase1-teacher-nav` (on top of Phase 5 commit `3e8a16a`)
Scope: CSV upgrade plan Phase 6 only — a complete practical session
(preparation/equipment checks, safety briefing, demonstration, student
practice, observation/measurement, recording, interpretation,
assessment/feedback, cleanup, return of equipment) plus student performance
assessment with persistence, pause/resume and accelerated time. No 3D UI
screens (later phases); the engine is driven by the host / test harness.

## What shipped

| File | Role |
|---|---|
| `js/lesson.js` | **New.** Pure JS lesson engine (`"use strict"`, no THREE/DOM), `createLesson(opts)` exported (+ `LESSON_PHASES`, `LESSON_STEPS`). Linear practical: `setup → safety → demo → practice → record → interpret → assess → cleanup → done`, each phase a documented checklist (`LESSON_STEPS`) of condition-based steps that auto-advance against the live world store + student FSM (equipment registered, scope usable, students watched, every student recorded, taps off, lamp off, drawer closed) and manual steps (`safetyAck`, `submitInterpretation`). **Observations are snapshotted the moment practice completes** (students clear their record pointer on the next phase change) and the science model runs then, so `state.results`/`state.conditions` are always the real module output. **Assessment** per student across the six CSV dimensions — procedural accuracy, equipment handling, safety, observations, calculations, scientific reasoning — derived from Phase-5 counters (mistakes/records), safety acknowledgement + violation log, and `science.assess` ratios; each student gets six feedback lines and an `overall`; class `overall()` is the mean. **Pause/resume** (`pause/resume` gate the engine clock), **accelerated time** (`setSpeed(1..60)` scales `tick`; `fastForward(sec, studentTick)` skips long dwells), **persistence** (`serialize()/restore(json)` keep completed steps, conditions, observations, results, feedback and scores; optional `storage` mirror under one key with auto-resume on construction). API: `start(experimentId, topic, conditions) / tick / fastForward / safetyAck / submitInterpretation / pause / resume / setSpeed / status / stepsFor / scores / overall / serialize / restore / safetyViolation`. |
| `index.html` | Phase-6 wiring: `import { createLesson }`; `LESSONTEST` flag; `phase6` global. New `buildPhase6` IIFE (after buildPhase5): engine bound to the real world + science + Phase-5 students, `localStorage` persistence (`bioLessonState`), `P6.start()` defaults to the pure-water osmosis practical, exposes start/status/scores/overall/pause/resume/setSpeed/fastForward/safetyAck/submitInterpretation/serialize/restore/clearStorage; `teacherDiag.lesson`. Main loop ticks the engine (`phase6.frame(dt)`). `dumpDiag` gains `lessonEngine:{ready, phase, running, paused, speed, stepsDone, assessmentComplete, scoresAvailable, experimentId, overall}`. `?lessontest=1` harness (32 checks): engine attached; setup checklist gates on live equipment + usable demo state; safety brief auto + ack required; demo completes after the student question (steered through the world `lesson`); practice completes with six science-model observations and real results (mass +9.43 %); interpretation scored full marks with per-student assess output; six dimensions + feedback + overall; **pause holds the clock, resume restarts, setSpeed clamps 1..60 and advances 10×**; cleanup gates on live tap/scope/drawer state until the practical reaches `done`; **serialize → restore into a fresh engine keeps phase, scores (calculations 1), observations, results, feedback and overall**; wrong answers score below full marks. |
| `scripts/phase6_unit.mjs` | **New.** 62 Node checks (no browser): phase/step documentation; full practical run against the real world + science + students (setup gating on demo-ready, ack gating, demo question, six observations, real results, ratio-1 assessment, dimensions in [0,1], high overall, cleanup gating, students idle at done); interpretation edge cases (wrong → 0, partial → 0.5); pause/resume/speed/fastForward semantics; safety violations lowering the safety dimension; serialize/restore round-trips (garbage rejected, completed practical resumes at cleanup with scores + overall intact, storage auto-resume); determinism (same seed → identical serialize + overall); restart-after-done and start-refuses-while-running. |
| `scripts/smoke.mjs` | Extended: the `?diag=1` pass additionally asserts `report.lessonEngine.ready === true`; new `?lessontest=1` pass auto-asserts every harness check. **220/220** (was 179). |
| `docs/PHASE6_REPORT.md` | This report. |

## Architecture notes

- **One engine owns the practical arc (CSV)**: every CSV element maps to a
  phase/step — preparation + equipment checks (setup, gated on the live
  world-store registrations and a usable demonstration scope), safety
  briefing + acknowledgement, teacher demonstration (students steered to
  `demo` via the world `lesson` until a question is asked), student practice
  (students steered to `practice`, completing via the science model),
  observation/measurement + recording (snapshot + `science.run` results),
  interpretation (`science.assess` per student), assessment/feedback (six
  dimensions + feedback lines), cleanup + return of equipment (taps off,
  lamp off, drawer closed gate `done`).
- **Assessment spans the CSV dimensions (CSV)**: procedural accuracy and
  equipment handling from the student FSM's mistake/record counters;
  safety from the acknowledgement flag + a violation log (`safetyViolation`
  hook, e.g. a student opening a culture plate); observations from recorded
  runs; calculations and scientific reasoning from the interpretation's
  `science.assess` ratio (per-student answers supported). Everything the
  assessment needs is inside `state`, so scores survive serialization.
- **Pause/resume + accelerated time (CSV)**: the engine clock only advances
  while running and not paused; `setSpeed` scales it (clamped 1–60);
  `fastForward` runs the clock without the host loop. The science model is
  already instantaneous, so a "60-minute" osmosis run is a pure function call
  — acceleration applies to the session dwell timers.
- **Persistence / resume (CSV acceptance)**: every event persists through an
  optional storage mirror; `serialize()/restore(json)` round-trip keeps
  phase, checklist, conditions, observations, results, feedback and scores —
  a reloaded page (or a test) resumes with the assessment still available.
  Determinism (same seed → identical serialize) makes resume verifiable.
- **Composition, not coupling**: the engine talks to Phase 5 only through
  the student manager's public counters and the world `lesson` record; to
  Phase 4 only through `run/assess/defaults`; to Phase 3 only through world
  state. Any layer can be driven or stubbed independently (the unit tests do
  exactly that with the real modules).

## Verification

| Gate | Result |
|---|---|
| `node scripts/phase1_unit.mjs` | 53/53 |
| `node scripts/phase2_unit.mjs` | 54/54 |
| `node scripts/phase3_unit.mjs` | 41/41 |
| `node scripts/phase4_unit.mjs` | 87/87 |
| `node scripts/phase5_unit.mjs` | 40/40 |
| `node scripts/phase6_unit.mjs` | 62/62 |
| `node scripts/smoke.mjs` | 220/220 (diag + navtest + behavtest + studenttest + lessontest; zero failures everywhere) |

Lessontest highlights (all asserted by smoke): full practical from setup
through cleanup; interpretation full marks (ratio 1) with correct answers;
pause holds the engine clock, setSpeed 10× advances it 10×; cleanup gated on
live tap/scope/drawer state until `done`; serialize → fresh-engine restore
keeps phase, scores (calculations 1), six observations, real results and the
overall; wrong answers score below full marks.

## Notes / non-goals

- The teacher UI for running the practical (buttons for brief/interpret,
  a progress panel) belongs to a later phase — `?lessontest=1` and the unit
  harnesses are the current drivers; `window.BioLabPhase6` is the host API.
- Cleanup verifies state (taps/lamp/drawer) but does not yet *drive* the
  teacher through physical cleanup actions; that follows the Phase-3 action
  catalogue once the teacher is steered by the lesson engine.
- Student avatars/collect-return object moves remain Phase-5+ scope; the
  engine sees their event-level equivalents (collect/return events).
- `localStorage` persistence is best-effort (quota/private-mode failures are
  swallowed); `serialize()` is the portable format.
- Only the osmosis practical is wired as the default session; other
  experiments work through `start(experimentId, topic, conditions)` but have
  no lesson-specific step variations yet.
