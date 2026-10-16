# Phase 4 Report — Scientific Simulation Layer & Microscope Learning Flow (biology lab)

Date: 2026-10-15
Branch: `phase1-teacher-nav` (on top of Phase 3 commit `815eb07`)
Scope: CSV upgrade plan Phase 4 only — a shared simulation layer separated from
presentation, biology practical modules with documented deterministic rules,
and a microscope learning flow where incorrect settings have meaningful
consequences. No 3D / student-assessment UI work (later phases).

## What shipped

| File | Role |
|---|---|
| `js/science.js` | **New.** Pure JS simulation layer (`"use strict"`, no THREE/DOM), `createScience()` exported. Nine practical modules (`osmosis`, `enzyme`, `foodTests`, `photosynthesis`, `germination`, `respiration`, `transpiration`, `quadrat`, `microorganisms`), each a documented `{id, title, objective, apparatus, principles, safety, inputs, procedure, assumptions, run(inputs), assess(inputs, results, answers)}` record: `run` returns `{measurements, results, uncertainty, observations}` — every number derived from stated equations/assumptions, no arbitrary values. Registry API: `experiments/experiment/defaults/run/assess/constants/osmoticPotential/makeRng/gauss/fieldOfViewMm/specimens/microscope`. Models: Ψs = −iCRT (`osmoticPotential`, MPa); potato osmosis with K = 18 %/MPa school-lab calibration (≈ +9 % gain in pure water, isotonic ≈ 0.31 M, rate k = 0.02 min⁻¹, Q10 = 1.3); enzyme amylase with Arrhenius (Ea = 50 kJ mol⁻¹) + logistic denaturation at 43 °C (computed optimum 39 °C) + Gaussian pH (6.8, σ 0.55); food-test colour thresholds; variegated-leaf starch patterns with dark/light controls; germination cardinal temperatures (5/25/35) + logistic time course + anoxia factors; respirometer with Q10 = 2, KOH = O₂, RQ = 1 (no-KOH ≈ 0); potometer (dark 0.05 mL min⁻¹, light ×1.9, leaf-area proportional); quadrat sampling with seeded `makeRng` + Gaussian cover noise (mean/SD/SE/95 % CI, deterministic per seed); microbial growth logistic with per-organism cardinal temperatures and stop-the-class safety warnings. **Microscope model**: `fieldOfViewMm(objective) = 20/objective` (DIN FN 20 → 4x = 5 mm, 10x = 2 mm, 40x = 0.5 mm); `evaluate(microState, specimenId)` → `{ok, score, quality, fovMm, cellsAcross, issues[], field, consequence}` — issues `invalid-objective` / `no-slide` / `no-light` / `out-of-focus` (>0.25) / `soft-focus` (>0.12, usable) / `off-specimen` (>0.8); only non-soft issues block; cells across the field = FOV ÷ cell width (onion 0.015 mm → 133 at 10x; cheek 0.025 mm → 80); specimen registry onion / cheek / none. |
| `index.html` | Phase-4 wiring: `import { createScience }`; `var science=createScience(); window.BioLabScience=science` (top of the main module). `micro.front` gains `specimen:'onion', stain:'iodine', lastObservation:null`. New `observe` action (priority 4) on `micro.front`: precondition `science.microscope.evaluate(...).ok` (dark / no slide / blurred / off-specimen all fail fast with `precondition:`); steps reach eyepieces → manipulate → `set` the evaluation into `lastObservation`; verify `lastObservation.ok === true`. `phase3.stats.observe` mirrors the latest observation; `dumpDiag` gains `science:{ready, experiments}`. `?behavtest=1` gained 11 Phase-4 checks. |
| `scripts/phase4_unit.mjs` | **New.** 87 Node checks (no browser): registry completeness + documentation shape + defaults merge; determinism (quadrat fixed-seed equality, seed sensitivity, makeRng stream stability); Ψs formula (−2.437 MPa at 20 °C, −2.479 at 25 °C, linear in C and i); osmosis (pure-water gain > 5 %, 1 M loss < −5 %, monotone in C, isotonic ≈ 0.31 M, temperature changes rate not equilibrium, longer time approaches equilibrium, assess scoring both ways); enzyme (optimum 35–41 °C, 70 °C denatured, cold slow, pH optimum, clear-time consistency, assess); food tests (all-positive, colour grades, all-negative, assess); photosynthesis (starch only where chlorophyll, dark control zero, light control full, exposure scaling, assess); germination (suitable ≈ 48 %, water limits to 0, anoxia < 25 % of normal, below Tmin zero, monotone curve, assess); respiration (contraction = O₂, Q10 ≈ 2.0, boiled ≈ 0, no-KOH ≈ 0, time/seed scaling); transpiration (light > dark, leaf-area proportional, volume = rate × time); microorganisms (growth at optimum, never safe to open, unsealed stop-warning, out-of-range warning + zero growth, assess); microscope (FOV 5/2/0.5 mm, onion 133 / cheek 80 cells, 40x zoom factor, every issue path, quality ranking good > soft > unusable, consequence text names the fix). |
| `scripts/smoke.mjs` | Extended: the `?diag=1` pass additionally asserts `report.science.ready === true && report.science.experiments >= 9`; every new behavtest check is auto-asserted. **154/154** (was 143). |

## Architecture notes

- **Simulation separated from presentation (CSV)**: `js/science.js` is a pure
  module — no rendering, no scene graph, no DOM. It is loaded once by the host,
  exposed as `window.BioLabScience` for diagnostics, and unit-tested directly
  under Node. Any future UI (student console, assessment screen) consumes the
  same `run`/`assess` contract the tests do.
- **Documented, deterministic rules**: every module carries its equations and
  school-level assumptions in `assumptions[]`; `run` is a pure function of
  inputs; the only stochastic module (`quadrat`) is seeded (`makeRng`, seed in
  `measurements`) and asserts equal samples for equal seeds. Uncertainty is
  returned alongside results (timing, reading, sampling and model error), and
  the microscope returns a per-observation `consequence` string naming what to
  fix.
- **Microscope learning flow with meaningful consequences**: the Phase-3
  equipment state (`objective`, `focus`, `illumination`, `stage`) is now scored
  by the science model before the teacher can record an observation. Acting on
  `observe` with the illuminator off, no slide, focus far from the specimen
  plane, the stage off the specimen, or an invalid objective fails at the
  precondition with a `precondition:` reason — the same fail-fast contract as
  every other catalogue action. With good settings the evaluation (visible
  field description, cells across the field, FOV for the objective) is written
  into world state (`lastObservation`) and mirrored into `phase3.stats.observe`.
  Soft focus is deliberately non-blocking (quality drops, image still usable),
  matching how a real bench behaves; the chosen specimen determines the visible
  cell density (onion vs cheek).
- **One action contract preserved**: `observe` is defined with the same
  `{pre, steps, verify}` shape as Phase-3 actions, so manual `interact`,
  scripted scenarios and the unit harness all share one definition.

## Verification

| Gate | Result |
|---|---|
| `node scripts/phase1_unit.mjs` | 53/53 |
| `node scripts/phase2_unit.mjs` | 54/54 |
| `node scripts/phase3_unit.mjs` | 41/41 |
| `node scripts/phase4_unit.mjs` | 87/87 |
| `node scripts/smoke.mjs` | 154/154 (diag + navtest + behavtest; behavtest zero failures, no page errors) |

Behavtest Phase-4 highlights (all asserted by smoke): science layer attached
(9 experiments); osmosis pure-water gain / 1 M loss through the real module;
FOV 10x = 2 mm; dark field unusable; good settings usable; `interact(micro.front,
observe)` after illuminate + 10x completes and the observation is recorded in
the world (`lastObservation.ok`, cells across the field > 0); `observe` blocked
by precondition when the illuminator is then switched off; assessment scores a
correct osmosis answer full marks.

## Notes / non-goals

- The other 15 microscopes are not yet wired to `evaluate` — only the
  front-bench scope (`micro.front`) is registered for observation, consistent
  with Phase 3's "one fully wired scope" decision.
- Specimen selection on the front scope is state (`specimen`), but there is no
  yet a user-facing slide-preparation action; the model already rejects
  `none` with a `no-slide` consequence for the future prep flow.
- Experiment selection/consumption UX (student console, marking) belongs to a
  later phase; `assess` is exposed and unit-tested but not yet surfaced in the
  scene UI.
- Respirometer denaturation is not modelled in 5–45 °C (documented assumption:
  Q10 = 2 average over the seed range), unlike the enzyme module.
