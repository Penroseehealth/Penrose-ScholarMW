# Phase 5 Report — Virtual Students & Efficient Student AI (biology lab)

Date: 2026-10-15
Branch: `phase1-teacher-nav` (on top of Phase 4 commit `8c2cade`)
Scope: CSV upgrade plan Phase 5 only — student behaviour system (observe,
look, raise hands, ask, listen, respond, collect/return, collaborate, record,
make plausible mistakes, receive feedback, complete) with lightweight state
machines and predefined dialogue. No student avatar meshes or AI API calls
(later phases may add both; the pools are the hook point).

## What shipped

| File | Role |
|---|---|
| `js/students.js` | **New.** Pure JS student layer (`"use strict"`, no THREE/DOM), `createStudents(opts)` exported (+ `DIALOGUE`, `STUDENT_NAMES`, `STUDENT_SEATS`, `STUDENT_STATES`). Six seeded students, each a 16-state FSM (`idle/watch/look/raise/ask/listen/respond/collect/atStation/mistake/feedback/retry/record/return/collaborate/complete`) with per-student traits (`attention`, `skill`, `patience`) drawn from a mulberry32 PRNG (fixed seed → identical event streams). Every phase of the CSV behaviour list is a state or event: demonstration watching with periodic looks, one rotating hand-raise → question → teacher answer → acknowledge per demo; practice = collect apparatus → attempt at the station → (mistake → feedback → retry with backoff) or record → return → complete; review = pairwise collaboration over shared records. **Reacts to live simulation state**: during microscope practice each attempt runs the Phase-4 `science.microscope.evaluate` against the real `micro.front` world state — dark/no-slide/blurred settings produce mistakes whose reason names the actual problem ("observation cannot be recorded until: no-light"), nobody records an unusable field, and when the scope is fixed mid-lesson every student recovers and records the real values (cells across the field, FOV). Non-microscope topics attempt via `science.run(experimentId, defaults)` with a plausible procedural first-attempt failure chance `1 - skill`, then the correct method. **Zero AI usage**: all dialogue comes from local topical pools (`DIALOGUE.ask/answer/mistake/feedback/record/collab/complete`); `apiCalls()` stays 0 by construction and is asserted through a full lesson. API: `add/tick/setLesson/statuses/events/stats/students/lesson/dialogue/STATES/apiCalls`. |
| `index.html` | Phase-5 wiring: `import { createStudents }`; `STUDENTTEST` flag; `phase5` global. New `buildPhase5` IIFE (after buildPhase3): registers `lesson` in the world store (`{phase, topic, experimentId}` — the steering point for any host), creates six students on the left-island bench seats with `science` + `micro.front` linked, exposes `phase5.tick/frame/setLesson/statuses/events`, sets `teacherDiag.students`. The main loop ticks the class every frame (`phase5.frame(dt)`). `dumpDiag` gains a `students:{ready, count, states, questions, mistakes, records, completed, apiCalls, lesson}` block. `?studenttest=1` harness (21 checks): students attached + six seated, lesson registered + defaults wired, demo watch/look/exactly-one-question with raise→ask→listen→respond and pool-sourced lines, practice-in-the-dark mistakes naming the live scope problem + feedback + zero records, scope fixed mid-practice → all six record the science-model values (133 cells, 2 mm FOV) + collect/return/complete, review collaboration with pool lines, whole-lesson `apiCalls === 0`. |
| `scripts/phase5_unit.mjs` | **New.** 40 Node checks (no browser): creation/seats/traits/dialogue pools; demo questioning (one asker, pool lines for question + answer, no pile-on, zero API); practice reacting to the real world store (collect, dark-scope mistakes with `no-light` reasons, feedback cadence, patience erosion, no records), mid-lesson fix → exact records (133 cells/2 mm via the real science module), return/complete; osmosis-topic practice recording the real module result (isotonic 0.308) with 1–30 plausible procedural mistakes; review collaboration (pool lines, partner ids); clean phase switching + idle reset; **determinism** (same seed → identical event stream, different seed diverges); `setLesson` write-through to the world; stats/statuses shape. |
| `scripts/smoke.mjs` | Extended: the `?diag=1` pass additionally asserts `report.students.ready === true && count >= 4 && apiCalls === 0`; new `?studenttest=1` pass auto-asserts every harness check. **179/179** (was 154). |
| `docs/PHASE5_REPORT.md` | This report. |

## Architecture notes

- **Behaviour responds to lesson AND simulation state (CSV acceptance)**:
  students never invent readings — every record is the output of the real
  science module against the real world state. The microscope path is the
  tightest loop: `micro.front.state` → `evaluate` → mistake with the actual
  consequence string, or a record carrying the actual `cellsAcross`/`fovMm`.
  The lesson phase itself lives in the world store (`lesson`), so teacher UI,
  scenarios or tests steer the class with one `world.set`.
- **Lightweight, predefined, zero API (CSV acceptance)**: one FSM per student,
  ~40 lines of transition logic; dialogue selected from local pools with the
  seeded RNG. `apiCalls` is a first-class counter (always 0) so a future
  selective AI hook — appending generated lines to `DIALOGUE` pools offline —
  can be measured without touching the FSM.
- **Deterministic by construction**: fixed seed replays the identical event
  stream (unit-tested), so the studenttest harness and smoke assertions are
  stable; different seeds diverge, proving nothing is hard-coded.
- **Plausible mistakes with consequences**: first-attempt procedural failure
  chance `1 - skill` for non-micro topics (capped cadence with retry backoff),
  state-driven failure for the microscope topic; feedback always follows a
  mistake, patience erodes, and recovery happens the moment the simulation
  state becomes usable — students complete tasks without teacher intervention.
- **No new render cost**: students are state + events only (seats are data).
  Avatar meshes, speech-bubble rendering and student navigation belong to a
  later phase; the event stream (`{t, type, student, line, …}`) is the feed a
  renderer would consume.

## Verification

| Gate | Result |
|---|---|
| `node scripts/phase1_unit.mjs` | 53/53 |
| `node scripts/phase2_unit.mjs` | 54/54 |
| `node scripts/phase3_unit.mjs` | 41/41 |
| `node scripts/phase4_unit.mjs` | 87/87 |
| `node scripts/phase5_unit.mjs` | 40/40 |
| `node scripts/smoke.mjs` | 179/179 (diag + navtest + behavtest + studenttest; zero failures everywhere) |

Studenttest highlights (all asserted by smoke): six students seated and
attached; demo elicits watch/look and exactly one question with pool-sourced
question + answer; practice in the dark produces a mistake per student whose
reason is the live `no-light` consequence, with feedback and zero records;
once the scope is illuminated at 10x every student records the science-model
observation (133 cells across 2 mm) and completes; review produces six
collaboration events; `apiCalls` is 0 after the entire lesson.

## Notes / non-goals

- Students do not mutate shared equipment (only the world `lesson` record);
  collect/return are event-level behaviours, not object moves — object-level
  student manipulation will follow with student avatars.
- The asking rotation guarantees one question per demo segment; richer
  multi-question dialogues would just extend the pools and demo dwell.
- No student meshes, no speech-bubble UI, no AI network calls — all explicitly
  out of Phase 5 scope per the CSV (predefined sequences; selective AI only).
- The `patience` trait erodes with mistakes but does not yet trigger a
  "stuck - ask the teacher" state; the feedback→retry loop already covers the
  CSV's mistake→feedback→complete arc.
